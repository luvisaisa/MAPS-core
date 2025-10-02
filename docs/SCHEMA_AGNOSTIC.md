# Schema-Agnostic Data Ingestion System

## Overview

MAPS now includes a schema-agnostic data ingestion system that enables parsing of any XML, JSON, CSV, or other structured data format without requiring code changes. This is accomplished through a profile-based mapping system that transforms diverse source formats into a common canonical schema.

## Architecture

### Core Components

1. **Canonical Schema** (`src/maps/schemas/canonical.py`)
   - Flexible Pydantic v2 models for normalized document representation
   - Base `CanonicalDocument` class with extensibility
   - Domain-specific variants: `RadiologyCanonicalDocument`, `InvoiceCanonicalDocument`
   - Entity extraction models for dates, people, organizations, medical terms, etc.

2. **Profile System** (`src/maps/schemas/profile.py`)
   - Profile definitions map source fields to canonical schema
   - Field-level transformations (date parsing, normalization, etc.)
   - Conditional logic and validation rules
   - Profile inheritance for reusability

3. **Profile Manager** (`src/maps/profile_manager.py`)
   - CRUD operations for profiles (file-based or database)
   - Profile validation and inheritance resolution
   - Caching for performance
   - Import/export capabilities

4. **Base Parser Interface** (`src/maps/parsers/base.py`)
   - Abstract interface all parsers must implement
   - Common validation and error handling
   - Batch processing support

## Data Flow

```
Source File (XML/JSON/CSV/PDF)
       ↓
Profile Manager (loads appropriate profile)
       ↓
Parser (profile-driven extraction)
       ↓
Canonical Document (Pydantic validation)
       ↓
Storage/Export (PostgreSQL/SQLite/Excel)
```

## Usage Examples

### Loading a Profile

```python
from maps import get_profile_manager

manager = get_profile_manager()
profile = manager.load_profile("lidc_idri_standard")
```

### Creating a Canonical Document

```python
from maps import RadiologyCanonicalDocument, DocumentMetadata
from datetime import datetime

doc = RadiologyCanonicalDocument(
    document_metadata=DocumentMetadata(
        title="CT Chest Scan",
        date=datetime(2024, 1, 15),
        author="Dr. Smith"
    ),
    study_instance_uid="1.2.840.113654.2.55.12345",
    modality="CT",
    nodules=[
        {
            "nodule_id": "1",
            "characteristics": {
                "subtlety": 3,
                "confidence": 4,
                "diameter_mm": 8.5
            }
        }
    ]
)
```

### Validating a Profile

```python
manager = get_profile_manager()
profile = manager.load_profile("my_custom_profile")

is_valid, errors = manager.validate_profile(profile)
if not is_valid:
    for error in errors:
        print(f"Validation error: {error}")
```

## Profile Structure

Profiles are JSON files that define:

- **Metadata**: Name, description, file type, version
- **Mappings**: Source field → Canonical field transformations
- **Validation Rules**: Required fields, data type constraints
- **Transformations**: Data manipulation (parsing, normalization, regex extraction)
- **Conditional Logic**: When to apply specific mappings

Example profile snippet:

```json
{
  "profile_name": "lidc_idri_standard",
  "file_type": "XML",
  "mappings": [
    {
      "source_path": "/LidcReadMessage/ResponseHeader/StudyInstanceUID",
      "target_path": "study_instance_uid",
      "data_type": "string",
      "required": true
    }
  ],
  "validation_rules": {
    "required_fields": ["study_instance_uid"],
    "allow_extra_fields": true
  }
}
```

## Benefits

1. **No Code Changes**: Add support for new formats by creating profiles
2. **Type Safety**: Pydantic v2 validation ensures data integrity
3. **Flexibility**: Canonical schema accommodates diverse document types
4. **Reusability**: Profile inheritance reduces duplication
5. **Versioning**: Track changes to profiles and canonical schema
6. **Future-Proof**: Easy to extend for new requirements

## Migration from Legacy Parser

The legacy `parse_radiology_sample()` function continues to work. New implementations should use the profile-based system for maximum flexibility.

## Next Steps

- Generic XML parser implementation (profile-driven)
- Profile auto-generation from sample files
- Web interface for profile management
- Profile repository with pre-built profiles for common formats
