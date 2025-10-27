"""API response models"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime


class HealthResponse(BaseModel):
    """Health check response"""
    status: str = Field(..., description="Health status")
    timestamp: str = Field(..., description="Current timestamp")
    service: str = Field(..., description="Service name")
    version: str = Field(..., description="API version")


class StatusResponse(BaseModel):
    """Detailed status response"""
    status: str = Field(..., description="Overall status")
    components: Dict[str, str] = Field(..., description="Component statuses")
    timestamp: str = Field(..., description="Current timestamp")


class ParseResponse(BaseModel):
    """Parse result response"""
    status: str = Field(..., description="Parse status")
    filename: str = Field(..., description="Original filename")
    profile: Optional[str] = Field(None, description="Profile used")
    document: Optional[Dict[str, Any]] = Field(None, description="Parsed document")


class BatchParseResponse(BaseModel):
    """Batch parse response"""
    total: int = Field(..., description="Total files submitted")
    successful: int = Field(..., description="Successfully parsed files")
    failed: int = Field(..., description="Failed files")
    results: List[Dict[str, Any]] = Field(default_factory=list, description="Parse results")
    errors: List[Dict[str, Any]] = Field(default_factory=list, description="Error details")


class PDFMetadataResponse(BaseModel):
    """PDF metadata"""
    title: Optional[str] = Field(None, description="PDF title")
    authors: List[str] = Field(default_factory=list, description="Authors")
    abstract: Optional[str] = Field(None, description="Abstract")
    page_count: int = Field(..., description="Total pages")


class KeywordResponse(BaseModel):
    """Keyword response"""
    keyword: str = Field(..., description="Keyword text")
    frequency: int = Field(..., description="Frequency in document")
    normalized_form: str = Field(..., description="Normalized keyword")
    category: Optional[str] = Field(None, description="Keyword category")


class PDFParseResponse(BaseModel):
    """PDF parse response"""
    status: str = Field(..., description="Parse status")
    filename: str = Field(..., description="Original filename")
    metadata: PDFMetadataResponse = Field(..., description="PDF metadata")
    keywords: List[KeywordResponse] = Field(default_factory=list, description="Extracted keywords")


class ProfileMetadata(BaseModel):
    """Profile metadata"""
    name: str = Field(..., description="Profile name")
    file_type: str = Field(..., description="File type")
    description: str = Field(..., description="Profile description")


class ProfileListResponse(BaseModel):
    """Profile list response"""
    profiles: List[ProfileMetadata] = Field(default_factory=list, description="Available profiles")


class ProfileDetailResponse(BaseModel):
    """Profile detail response"""
    profile_name: str = Field(..., description="Profile name")
    file_type: str = Field(..., description="File type")
    description: str = Field(..., description="Description")
    mappings: List[Dict[str, Any]] = Field(default_factory=list, description="Field mappings")
    validation_rules: Dict[str, Any] = Field(default_factory=dict, description="Validation rules")


class KeywordSearchResult(BaseModel):
    """Keyword search result"""
    keyword: str = Field(..., description="Matched keyword")
    relevance: float = Field(..., description="Relevance score")
    matched_terms: List[str] = Field(default_factory=list, description="Matched search terms")


class KeywordSearchResponse(BaseModel):
    """Keyword search response"""
    query: str = Field(..., description="Original query")
    expanded_query: str = Field(..., description="Expanded query with synonyms")
    total_results: int = Field(..., description="Total results found")
    results: List[KeywordSearchResult] = Field(default_factory=list, description="Search results")


class KeywordNormalizeResponse(BaseModel):
    """Keyword normalization response"""
    original: str = Field(..., description="Original keyword")
    normalized: str = Field(..., description="Normalized form")
    all_forms: List[str] = Field(default_factory=list, description="All known forms")


class AnalysisStatistics(BaseModel):
    """Analysis statistics"""
    total_entities: int = Field(..., description="Total entities extracted")
    nodules: int = Field(..., description="Nodules found")
    confidence: float = Field(..., description="Overall confidence score")


class AnalysisResponse(BaseModel):
    """Auto-analysis response"""
    status: str = Field(..., description="Analysis status")
    filename: str = Field(..., description="Original filename")
    document: Optional[Dict[str, Any]] = Field(None, description="Canonical document")
    statistics: AnalysisStatistics = Field(..., description="Analysis statistics")
