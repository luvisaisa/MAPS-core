"""
MAPS Adapters for External Systems

Provides adapter classes for integrating external medical imaging systems
and datasets with the MAPS canonical schema.
"""

from .pylidc_adapter import PyLIDCAdapter

__all__ = ['PyLIDCAdapter']
