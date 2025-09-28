"""
Profile Manager for MAPS Schema-Agnostic Data Ingestion System

Handles loading, validation, storage, and retrieval of mapping profiles.

Version: 1.0.0
"""

import json
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
                    print(f"Failed to load profile {filename}: {e}")

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
            print(f"Error loading profile {profile_name}: {e}")
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
            print(f"Profile '{profile.profile_name}' already exists. Use overwrite=True to replace.")
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
            print(f"Profile '{profile.profile_name}' saved to {filepath}")
            return True
        except Exception as e:
            print(f"Error saving profile {profile.profile_name}: {e}")
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
            print(f"Profile '{profile_identifier}' not found")
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
                print(f"Profile '{profile.profile_name}' deleted")
            return True
        except Exception as e:
            print(f"Error deleting profile {profile.profile_name}: {e}")
            return False

    def _delete_from_database(self, profile: Profile) -> bool:
        """Delete a profile from database"""
        return False


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
