"""
MAPS Canonical Schema Definitions

Provides Pydantic v2 models for normalizing diverse data formats
into a common canonical representation.
"""

from .canonical import (
    CanonicalDocument,
    DocumentMetadata,
    RadiologyCanonicalDocument,
    InvoiceCanonicalDocument,
    Entity,
    ExtractedEntities,
    ExtractionMetadata,
    ValidationResult,
    canonical_to_dict,
    dict_to_canonical,
    merge_canonical_documents
)

__all__ = [
    'CanonicalDocument',
    'DocumentMetadata',
    'RadiologyCanonicalDocument',
    'InvoiceCanonicalDocument',
    'Entity',
    'ExtractedEntities',
    'ExtractionMetadata',
    'ValidationResult',
    'canonical_to_dict',
    'dict_to_canonical',
    'merge_canonical_documents'
]
