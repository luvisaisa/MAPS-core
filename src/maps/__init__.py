"""MAPS - Medical Annotation Processing System

Core functionality for parsing medical imaging XML annotation data.
"""

__version__ = "0.5.0"

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
from .gui import NYTXMLGuiApp

# Schema-agnostic components
from .schemas.canonical import (
    CanonicalDocument,
    RadiologyCanonicalDocument,
    InvoiceCanonicalDocument,
    DocumentMetadata,
    Entity,
    ExtractedEntities,
    ValidationResult
)

from .schemas.profile import (
    Profile,
    FieldMapping,
    ValidationRules,
    FileType,
    DataType
)

from .profile_manager import ProfileManager, get_profile_manager

from .parsers.base import BaseParser

# Keyword extraction system
from .keyword_normalizer import KeywordNormalizer
from .pdf_keyword_extractor import (
    PDFKeywordExtractor,
    PDFMetadata,
    ExtractedPDFKeyword
)
from .keyword_search import (
    KeywordSearchEngine,
    SearchResult,
    SearchResponse,
    QueryParser
)

__all__ = [
    # Legacy parser API
    'parse_radiology_sample',
    'parse_multiple',
    'export_excel',
    'detect_parse_case',
    'get_expected_attributes_for_case',
    'extract_roi_data',
    'extract_characteristics',
    'extract_reading_sessions',
    'get_parse_statistics',
    'analyze_xml_structure',
    'NYTXMLGuiApp',
    # Canonical schemas
    'CanonicalDocument',
    'RadiologyCanonicalDocument',
    'InvoiceCanonicalDocument',
    'DocumentMetadata',
    'Entity',
    'ExtractedEntities',
    'ValidationResult',
    # Profile system
    'Profile',
    'FieldMapping',
    'ValidationRules',
    'FileType',
    'DataType',
    'ProfileManager',
    'get_profile_manager',
    # Parser interface
    'BaseParser',
    # Keyword extraction
    'KeywordNormalizer',
    'PDFKeywordExtractor',
    'PDFMetadata',
    'ExtractedPDFKeyword',
    'KeywordSearchEngine',
    'SearchResult',
    'SearchResponse',
    'QueryParser'
]
