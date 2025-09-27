"""
Profile Definition Schema and Models

Defines the structure for mapping profiles that transform source formats
into the canonical schema.

Version: 1.0.0
"""

from typing import Optional, Dict, Any, List
from enum import Enum
from pydantic import BaseModel, Field, ConfigDict


# =====================================================================
# ENUMS
# =====================================================================

class FileType(str, Enum):
    """Supported file types"""
    XML = "XML"
    JSON = "JSON"
    CSV = "CSV"
    PDF = "PDF"
    DOCX = "DOCX"
    OTHER = "OTHER"


class DataType(str, Enum):
    """Data types for field mapping"""
    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    DECIMAL = "decimal"
    BOOLEAN = "boolean"
    DATE = "date"
    DATETIME = "datetime"
    ARRAY = "array"
    OBJECT = "object"


class TransformationType(str, Enum):
    """Available transformation types"""
    PARSE_DATE = "parse_date"
    NORMALIZE_CURRENCY = "normalize_currency"
    TRIM_WHITESPACE = "trim_whitespace"
    UPPERCASE = "uppercase"
    LOWERCASE = "lowercase"
    EXTRACT_NUMBERS = "extract_numbers"
    CONCATENATE_FIELDS = "concatenate_fields"
    SPLIT_STRING = "split_string"
    REGEX_EXTRACT = "regex_extract"
    CONDITIONAL = "conditional"
    LOOKUP = "lookup"
    CUSTOM = "custom"


class OperatorType(str, Enum):
    """Operators for conditional logic"""
    EQUALS = "equals"
    NOT_EQUALS = "not_equals"
    CONTAINS = "contains"
    STARTS_WITH = "starts_with"
    ENDS_WITH = "ends_with"
    REGEX_MATCH = "regex_match"
    GREATER_THAN = "greater_than"
    LESS_THAN = "less_than"
    IS_NULL = "is_null"
    IS_NOT_NULL = "is_not_null"


# =====================================================================
# FIELD MAPPING MODELS
# =====================================================================

class Transformation(BaseModel):
    """Defines a data transformation to apply during mapping"""
    model_config = ConfigDict(extra='allow')

    transformation_type: TransformationType = Field(
        ...,
        description="Type of transformation to apply"
    )
    parameters: Dict[str, Any] = Field(
        default_factory=dict,
        description="Parameters for the transformation"
    )
    order: int = Field(
        default=0,
        description="Order in which to apply this transformation (lower = first)"
    )


class ConditionalRule(BaseModel):
    """Conditional logic for when to apply a mapping or transformation"""
    model_config = ConfigDict(extra='allow')

    field: str = Field(
        ...,
        description="Field to evaluate (can be source or target field)"
    )
    operator: OperatorType = Field(
        ...,
        description="Comparison operator"
    )
    value: Optional[Any] = Field(
        None,
        description="Value to compare against (not needed for is_null/is_not_null)"
    )
    case_sensitive: bool = Field(
        default=True,
        description="Whether string comparisons are case-sensitive"
    )


class FieldMapping(BaseModel):
    """
    Defines how a single source field maps to a canonical schema field.

    This is the core unit of a profile's mapping definition.
    """
    model_config = ConfigDict(extra='allow')

    source_path: str = Field(
        ...,
        description="Path to the source field (XPath for XML, JSONPath for JSON, column name for CSV)"
    )
    source_attribute: Optional[str] = Field(
        None,
        description="For XML: attribute name if extracting an attribute rather than element text"
    )

    target_path: str = Field(
        ...,
        description="Path in canonical schema (e.g., 'document_metadata.title' or 'fields.invoice_number')"
    )

    data_type: DataType = Field(
        default=DataType.STRING,
        description="Expected data type of the field"
    )
    required: bool = Field(
        default=False,
        description="Whether this field is required in the source"
    )
    default_value: Optional[Any] = Field(
        None,
        description="Default value if source field is missing or null"
    )

    transformations: List[Transformation] = Field(
        default_factory=list,
        description="List of transformations to apply to the source value, in order"
    )

    conditions: List[ConditionalRule] = Field(
        default_factory=list,
        description="Conditions that must be met for this mapping to apply"
    )

    description: Optional[str] = Field(
        None,
        description="Human-readable description of this mapping"
    )
    examples: List[str] = Field(
        default_factory=list,
        description="Example source values for documentation"
    )


# =====================================================================
# VALIDATION RULES MODELS
# =====================================================================

class ValidationRule(BaseModel):
    """Single validation rule for a field"""
    model_config = ConfigDict(extra='allow')

    field: str = Field(
        ...,
        description="Field path to validate"
    )
    rule_type: str = Field(
        ...,
        description="Type of validation: required, format, range, regex, custom"
    )
    parameters: Dict[str, Any] = Field(
        default_factory=dict,
        description="Parameters for the validation rule"
    )
    error_message: Optional[str] = Field(
        None,
        description="Custom error message if validation fails"
    )
    severity: str = Field(
        default="error",
        description="Severity level: error, warning, info"
    )


class ValidationRules(BaseModel):
    """Collection of validation rules for a profile"""
    model_config = ConfigDict(extra='allow')

    required_fields: List[str] = Field(
        default_factory=list,
        description="List of required canonical schema field paths"
    )
    custom_validators: List[ValidationRule] = Field(
        default_factory=list,
        description="Custom validation rules"
    )
    allow_extra_fields: bool = Field(
        default=True,
        description="Whether to allow fields not defined in mappings"
    )
    strict_types: bool = Field(
        default=False,
        description="Whether to enforce strict type checking"
    )


# =====================================================================
# MAIN PROFILE MODEL
# =====================================================================

class Profile(BaseModel):
    """
    Complete profile definition for mapping a source format to canonical schema.

    This is the main configuration object that drives the parsing and normalization process.
    """
    model_config = ConfigDict(extra='allow')

    profile_id: Optional[str] = Field(
        None,
        description="UUID of the profile (assigned by system)"
    )
    profile_name: str = Field(
        ...,
        description="Unique name for the profile"
    )

    file_type: FileType = Field(
        ...,
        description="Type of file this profile handles"
    )
    source_format_description: Optional[str] = Field(
        None,
        description="Description of the source format (e.g., 'LIDC-IDRI XML v3.2')"
    )

    canonical_schema_version: str = Field(
        default="1.0",
        description="Version of canonical schema this profile targets"
    )
    target_document_type: Optional[str] = Field(
        None,
        description="Specific canonical document type (e.g., 'RadiologyCanonicalDocument')"
    )

    mappings: List[FieldMapping] = Field(
        ...,
        description="List of field mappings from source to canonical schema"
    )

    validation_rules: ValidationRules = Field(
        default_factory=ValidationRules,
        description="Validation rules for the canonical output"
    )

    description: Optional[str] = Field(
        None,
        description="Human-readable description of what this profile does"
    )
    version: str = Field(
        default="1.0.0",
        description="Version of this profile"
    )
    is_active: bool = Field(
        default=True,
        description="Whether this profile is currently active"
    )
    is_default: bool = Field(
        default=False,
        description="Whether this is the default profile for its file type"
    )

    parent_profile_id: Optional[str] = Field(
        None,
        description="ID of parent profile to inherit from"
    )

    created_by: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
    last_used_at: Optional[str] = None

    custom_parser_config: Dict[str, Any] = Field(
        default_factory=dict,
        description="Format-specific parser configuration"
    )


# =====================================================================
# UTILITY FUNCTIONS
# =====================================================================

def profile_to_dict(profile, exclude_none: bool = True) -> Dict[str, Any]:
    """Convert a Profile to a dictionary suitable for JSON storage"""
    return profile.model_dump(
        mode='json',
        exclude_none=exclude_none,
        by_alias=True
    )


def dict_to_profile(data: Dict[str, Any]):
    """Convert a dictionary to a Profile"""
    return Profile.model_validate(data)
