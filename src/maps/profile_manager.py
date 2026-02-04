"""
Profile Manager for MAPS Schema-Agnostic Data Ingestion System

Handles loading, validation, storage, and retrieval of mapping profiles.

Version: 1.0.0
"""

import json
import logging
import os
from typing import Optional, List, Dict, Any
from pathlib import Path
from datetime import datetime
from uuid import uuid4

from .schemas.profile import (
    Profile,
    profile_to_dict,
    dict_to_profile,
    FileType
)

logger = logging.getLogger(__name__)


class ProfileManager:
    """
    Manages profile definitions for mapping source formats to canonical schema.

    Supports:
    - Loading profiles from JSON files or database
    - Validating profile schemas
    - Caching profiles for performance
    - Profile inheritance
    - Version control
    """

    def __init__(self,
                 profile_directory: Optional[str] = None,
                 db_connection = None,
                 use_database: bool = False):
        """
        Initialize the ProfileManager.

        Args:
            profile_directory: Path to directory containing profile JSON files
            db_connection: Database connection object (for PostgreSQL repository)
            use_database: Whether to use database for profile storage (vs. file system)
        """
        self.profile_directory = profile_directory or os.path.join(
            os.path.dirname(__file__),
            "profiles"
        )
        self.db_connection = db_connection
        self.use_database = use_database

        self._profile_cache: Dict[str, Profile] = {}
        self._profiles_by_id: Dict[str, Profile] = {}

        if not use_database:
            Path(self.profile_directory).mkdir(parents=True, exist_ok=True)
            self._load_all_profiles()

    def _load_all_profiles(self):
        """Load all profiles from the profile directory into cache"""
        if not os.path.exists(self.profile_directory):
            return

        for filename in os.listdir(self.profile_directory):
            if filename.endswith('.json'):
                filepath = os.path.join(self.profile_directory, filename)
                try:
                    with open(filepath, 'r') as f:
                        profile_data = json.load(f)
                    profile = dict_to_profile(profile_data)
                    self._add_to_cache(profile)
                except Exception as e:
                    logger.error(f"Failed to load profile {filename}: {e}")

    def _add_to_cache(self, profile: Profile):
        """Add a profile to the cache"""
        self._profile_cache[profile.profile_name] = profile
        if profile.profile_id:
            self._profiles_by_id[profile.profile_id] = profile

    def load_profile(self, profile_identifier: str) -> Optional[Profile]:
        """
        Load a profile by name or ID.

        Args:
            profile_identifier: Profile name or UUID

        Returns:
            Profile object or None if not found
        """
        if profile_identifier in self._profile_cache:
            return self._profile_cache[profile_identifier]
        if profile_identifier in self._profiles_by_id:
            return self._profiles_by_id[profile_identifier]

        if self.use_database and self.db_connection:
            return self._load_from_database(profile_identifier)

        return self._load_from_file(profile_identifier)

    def _load_from_file(self, profile_name: str) -> Optional[Profile]:
        """Load a profile from a JSON file"""
        filepath = os.path.join(self.profile_directory, f"{profile_name}.json")
        if not os.path.exists(filepath):
            return None

        try:
            with open(filepath, 'r') as f:
                profile_data = json.load(f)
            profile = dict_to_profile(profile_data)
            self._add_to_cache(profile)
            return profile
        except Exception as e:
            logger.error(f"Error loading profile {profile_name}: {e}")
            return None

    def _load_from_database(self, profile_identifier: str) -> Optional[Profile]:
        """Load a profile from the database"""
        return None

    def save_profile(self, profile: Profile, overwrite: bool = False) -> bool:
        """
        Save a profile to storage.

        Args:
            profile: Profile to save
            overwrite: Whether to overwrite existing profile

        Returns:
            True if saved successfully, False otherwise
        """
        if not profile.profile_id:
            profile.profile_id = str(uuid4())

        if not profile.created_at:
            profile.created_at = datetime.utcnow().isoformat()
        profile.updated_at = datetime.utcnow().isoformat()

        existing = self.load_profile(profile.profile_name)
        if existing and not overwrite:
            logger.warning(f"Profile '{profile.profile_name}' already exists. Use overwrite=True to replace.")
            return False

        if self.use_database and self.db_connection:
            success = self._save_to_database(profile)
        else:
            success = self._save_to_file(profile)

        if success:
            self._add_to_cache(profile)

        return success

    def _save_to_file(self, profile: Profile) -> bool:
        """Save a profile to a JSON file"""
        filepath = os.path.join(self.profile_directory, f"{profile.profile_name}.json")

        try:
            profile_dict = profile_to_dict(profile, exclude_none=False)
            with open(filepath, 'w') as f:
                json.dump(profile_dict, f, indent=2, default=str)
            logger.info(f"Profile '{profile.profile_name}' saved to {filepath}")
            return True
        except Exception as e:
            logger.error(f"Error saving profile {profile.profile_name}: {e}")
            return False

    def _save_to_database(self, profile: Profile) -> bool:
        """Save a profile to the database"""
        return False

    def list_profiles(self,
                     file_type: Optional[FileType] = None,
                     active_only: bool = True) -> List[Profile]:
        """
        List all profiles, optionally filtered by file type and active status.

        Args:
            file_type: Filter by file type (None = all)
            active_only: Only return active profiles

        Returns:
            List of Profile objects
        """
        profiles = list(self._profile_cache.values())

        if file_type:
            profiles = [p for p in profiles if p.file_type == file_type]

        if active_only:
            profiles = [p for p in profiles if p.is_active]

        return profiles

    def delete_profile(self, profile_identifier: str) -> bool:
        """
        Delete a profile by name or ID.

        Args:
            profile_identifier: Profile name or UUID

        Returns:
            True if deleted successfully
        """
        profile = self.load_profile(profile_identifier)
        if not profile:
            logger.warning(f"Profile '{profile_identifier}' not found")
            return False

        if profile.profile_name in self._profile_cache:
            del self._profile_cache[profile.profile_name]
        if profile.profile_id and profile.profile_id in self._profiles_by_id:
            del self._profiles_by_id[profile.profile_id]

        if self.use_database and self.db_connection:
            return self._delete_from_database(profile)
        else:
            return self._delete_from_file(profile)

    def _delete_from_file(self, profile: Profile) -> bool:
        """Delete a profile JSON file"""
        filepath = os.path.join(self.profile_directory, f"{profile.profile_name}.json")
        try:
            if os.path.exists(filepath):
                os.remove(filepath)
                logger.info(f"Profile '{profile.profile_name}' deleted")
            return True
        except Exception as e:
            logger.error(f"Error deleting profile {profile.profile_name}: {e}")
            return False

    def _delete_from_database(self, profile: Profile) -> bool:
        """Delete a profile from database"""
        return False

    def validate_profile(self, profile: Profile) -> tuple[bool, List[str]]:
        """
        Validate a profile's schema and configuration.

        Args:
            profile: Profile to validate

        Returns:
            Tuple of (is_valid, list_of_errors)
        """
        errors = []

        if not profile.profile_name:
            errors.append("Profile name is required")

        if not profile.file_type:
            errors.append("File type is required")

        if not profile.mappings or len(profile.mappings) == 0:
            errors.append("Profile must have at least one field mapping")

        target_paths = set()
        for i, mapping in enumerate(profile.mappings):
            if not mapping.source_path:
                errors.append(f"Mapping {i}: source_path is required")

            if not mapping.target_path:
                errors.append(f"Mapping {i}: target_path is required")

            if mapping.target_path in target_paths:
                errors.append(f"Duplicate target_path: {mapping.target_path}")
            target_paths.add(mapping.target_path)

        for required_field in profile.validation_rules.required_fields:
            if required_field not in target_paths:
                errors.append(
                    f"Required field '{required_field}' is not mapped in profile"
                )

        if profile.parent_profile_id:
            parent = self.load_profile(profile.parent_profile_id)
            if parent and parent.parent_profile_id == profile.profile_id:
                errors.append("Circular profile inheritance detected")

        is_valid = len(errors) == 0
        return is_valid, errors

    def resolve_profile_with_inheritance(self, profile: Profile) -> Profile:
        """
        Resolve a profile by merging with its parent profile.

        Args:
            profile: Profile with potential parent

        Returns:
            Resolved Profile with inherited mappings
        """
        if not profile.parent_profile_id:
            return profile

        parent = self.load_profile(profile.parent_profile_id)
        if not parent:
            logger.warning(f"Parent profile {profile.parent_profile_id} not found")
            return profile

        parent = self.resolve_profile_with_inheritance(parent)

        merged_mappings = {m.source_path: m for m in parent.mappings}
        for mapping in profile.mappings:
            merged_mappings[mapping.source_path] = mapping

        profile.mappings = list(merged_mappings.values())

        return profile

    def export_profile(self, profile_identifier: str, output_path: str) -> bool:
        """Export a profile to a JSON file at specified path"""
        profile = self.load_profile(profile_identifier)
        if not profile:
            return False

        try:
            profile_dict = profile_to_dict(profile, exclude_none=False)
            with open(output_path, 'w') as f:
                json.dump(profile_dict, f, indent=2, default=str)
            logger.info(f"Profile exported to {output_path}")
            return True
        except Exception as e:
            logger.error(f"Error exporting profile: {e}")
            return False

    def import_profile(self, input_path: str) -> Optional[Profile]:
        """Import a profile from a JSON file"""
        try:
            with open(input_path, 'r') as f:
                profile_data = json.load(f)
            profile = dict_to_profile(profile_data)

            is_valid, errors = self.validate_profile(profile)
            if not is_valid:
                logger.error(f"Invalid profile: {', '.join(errors)}")
                return None

            self.save_profile(profile)
            return profile
        except Exception as e:
            logger.error(f"Error importing profile: {e}")
            return None


# =====================================================================
# SINGLETON INSTANCE
# =====================================================================

_profile_manager_instance: Optional[ProfileManager] = None

def get_profile_manager(
    profile_directory: Optional[str] = None,
    db_connection = None,
    use_database: bool = False
) -> ProfileManager:
    """Get the singleton ProfileManager instance"""
    global _profile_manager_instance
    if _profile_manager_instance is None:
        _profile_manager_instance = ProfileManager(
            profile_directory=profile_directory,
            db_connection=db_connection,
            use_database=use_database
        )
    return _profile_manager_instance
