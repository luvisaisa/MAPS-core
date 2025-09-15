"""MAPS - Medical Annotation Processing System

Core functionality for parsing medical imaging XML annotation data.
"""

__version__ = "0.2.1"

from .parser import (
    parse_radiology_sample,
    parse_multiple,
    export_excel,
    detect_parse_case,
    get_expected_attributes_for_case,
    extract_roi_data,
    extract_characteristics,
    extract_reading_sessions,
    get_parse_statistics
)

from .structure_detector import analyze_xml_structure

__all__ = [
    'parse_radiology_sample',
    'parse_multiple',
    'export_excel',
    'detect_parse_case',
    'get_expected_attributes_for_case',
    'extract_roi_data',
    'extract_characteristics',
    'extract_reading_sessions',
    'get_parse_statistics',
    'analyze_xml_structure'
]
