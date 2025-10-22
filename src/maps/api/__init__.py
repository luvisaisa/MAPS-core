"""MAPS REST API

FastAPI-based REST API for medical annotation processing.
"""

from .app import create_app

__all__ = ['create_app']
