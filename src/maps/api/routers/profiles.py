"""Profiles router for profile management"""

from fastapi import APIRouter, HTTPException
from typing import List
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("")
async def list_profiles():
    """
    List all available parsing profiles.

    Returns:
        List of profile names and metadata
    """
    try:
        from maps.profile_manager import get_profile_manager
        manager = get_profile_manager()
        profiles = manager.list_profiles()

        return {
            "profiles": [
                {
                    "name": p.profile_name,
                    "file_type": p.file_type,
                    "description": p.description
                } for p in profiles
            ]
        }
    except Exception as e:
        logger.error(f"Failed to list profiles: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{name}")
async def get_profile(name: str):
    """
    Get specific profile by name.

    Args:
        name: Profile name

    Returns:
        Full profile configuration
    """
    try:
        from maps.profile_manager import get_profile_manager
        manager = get_profile_manager()
        profile = manager.load_profile(name)

        if not profile:
            raise HTTPException(status_code=404, detail=f"Profile '{name}' not found")

        return {
            "profile_name": profile.profile_name,
            "file_type": profile.file_type,
            "description": profile.description,
            "mappings": [m.model_dump() for m in profile.mappings],
            "validation_rules": profile.validation_rules.model_dump()
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get profile: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{name}/validate")
async def validate_profile(name: str):
    """
    Validate profile configuration.

    Args:
        name: Profile name

    Returns:
        Validation results
    """
    try:
        from maps.profile_manager import get_profile_manager
        manager = get_profile_manager()
        profile = manager.load_profile(name)

        if not profile:
            raise HTTPException(status_code=404, detail=f"Profile '{name}' not found")

        is_valid, errors = manager.validate_profile(profile)

        return {
            "profile_name": name,
            "is_valid": is_valid,
            "errors": errors
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Validation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
