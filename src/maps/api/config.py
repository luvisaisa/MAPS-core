"""API configuration settings"""

from pydantic_settings import BaseSettings
from typing import List


class APISettings(BaseSettings):
    """API configuration"""

    # Application
    app_name: str = "MAPS API"
    app_version: str = "1.0.0"
    debug: bool = False

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    reload: bool = False

    # CORS
    cors_origins: List[str] = ["*"]
    cors_credentials: bool = True
    cors_methods: List[str] = ["*"]
    cors_headers: List[str] = ["*"]

    # File upload
    max_upload_size: int = 100 * 1024 * 1024  # 100 MB
    allowed_extensions: List[str] = [".xml", ".pdf", ".zip"]

    # Logging
    log_level: str = "INFO"

    # Profiles
    profile_directory: str = "./profiles"

    class Config:
        env_file = ".env"
        env_prefix = "MAPS_"


def get_settings() -> APISettings:
    """Get API settings"""
    return APISettings()
