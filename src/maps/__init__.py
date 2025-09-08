"""MAPS - Medical Annotation Processing System

Core functionality for parsing medical imaging XML annotation data.
"""

__version__ = "0.2.0"

from .parser import (
    parse_radiology_sample,
    parse_multiple,
    export_excel,
    detect_parse_case,
    get_expected_attributes_for_case
)

__all__ = [
    'parse_radiology_sample',
    'parse_multiple',
    'export_excel',
    'detect_parse_case',
    'get_expected_attributes_for_case'
]
