# Schema-Agnostic Refactoring: Quick Start Guide

**Last Updated:** October 18, 2025  
**Status:** Foundation Complete |  Ready for Implementation

---

## What's Been Built

A **complete foundation** has been created for transforming the radiology XML parser into a **schema-agnostic, profile-based data ingestion system**. The following components are ready:

### Completed Components

1. **PostgreSQL Database Schema** (`/migrations/001_initial_schema.sql`)
   - Flexible JSONB storage for normalized data
   - Full-text search capabilities
   - Comprehensive audit logging
   - Profile management system

2. **Canonical Schema Models** (`/src/maps/schemas/canonical.py`)
   - Pydantic v2 models for data validation
   - `CanonicalDocument` base class
   - `RadiologyCanonicalDocument` for your existing use case
   - Entity extraction support

3. **Profile System** (`/src/maps/schemas/profile.py`)
   - Complete profile definition schema
   - Field mapping configuration
   - Transformation engine support
   - Validation rules

4. **Profile Manager** (`/src/maps/profile_manager.py`)
   - Load/save profiles from JSON or database
   - Profile validation and caching
   - Profile inheritance support

5. **Docker Infrastructure** (`docker-compose.yml`, `Dockerfile`)
   - PostgreSQL 16 with health checks
   - pgAdmin for database management
   - FastAPI container ready for Phase 9
   - Development profiles for easy setup

6. **Comprehensive Documentation** - `/docs/IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC.md` - Detailed phase-by-phase instructions
   - `/docs/SCHEMA_AGNOSTIC_SUMMARY.md` - Architecture overview and summary

---

## Quick Start (5 Minutes)

### Step 1: Install Dependencies
```bash
cd "/Users/isa/Desktop/python projects/XML PARSE"
source .venv/bin/activate  # Or create new venv if needed
pip install -r requirements.txt
```

### Step 2: Start PostgreSQL
```bash
docker-compose up -d postgres
# Wait a few seconds for startup
docker-compose ps  # Check status
```

### Step 3: Apply Database Migration
```bash
export PGPASSWORD=changeme
psql -h localhost -U ra_d_ps_user -d ra_d_ps_db \
     -f migrations/001_initial_schema.sql
```

### Step 4: Test Profile Manager
```bash
python3 -c "
from src.maps.profile_manager import get_profile_manager
manager = get_profile_manager()
print(f' Profile manager initialized')
print(f' Profiles loaded: {len(manager.list_profiles())}')
"
```

### Step 5: Test Canonical Schema
```bash
python3 -c "
from src.maps.schemas.canonical import RadiologyCanonicalDocument, DocumentMetadata
from datetime import datetime

doc = RadiologyCanonicalDocument(
    document_metadata=DocumentMetadata(
        title='Test Radiology Report',
        date=datetime.now()
    ),
    study_instance_uid='1.2.3.4.5',
    modality='CT'
)
print(f' Canonical schema working')
print(f' Document type: {doc.document_metadata.document_type}')
"
```

---

## What to Do Next

### Option 1: Let Copilot Continue (Recommended)
Use the detailed implementation guide at `/docs/IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC.md`.

**Next phases in order:**
1. **Phase 4:** Create LIDC-IDRI profile (4-6 hours)
2. **Phase 5:** Implement generic XML parser (12-16 hours)
3. **Phase 6:** Create parser factory (4 hours)
4. **Phase 7:** PostgreSQL repository layer (8-10 hours)
5. **Phase 8:** Ingestion orchestrator (6-8 hours)

### Option 2: Explore the Foundation
```bash
# View database schema
psql -h localhost -U ra_d_ps_user -d ra_d_ps_db -c "\d+ documents"
psql -h localhost -U ra_d_ps_user -d ra_d_ps_db -c "\d+ document_content"

# Open pgAdmin (optional)
docker-compose --profile dev up -d pgadmin
# Navigate to http://localhost:5050
# Email: admin@maps.local, Password: admin

# Review canonical schema
python3 -c "
from src.maps.schemas.canonical import CanonicalDocument
import json
schema = CanonicalDocument.model_json_schema()
print(json.dumps(schema, indent=2))
"
```

### Option 3: Create Your First Profile Manually
```bash
# Create profiles directory
mkdir -p profiles

# Create a simple test profile
cat > profiles/test_simple.json << 'EOF'
{
  "profile_name": "test_simple",
  "file_type": "XML",
  "description": "Simple test profile",
  "mappings": [
    {
      "source_path": "/root/title",
      "target_path": "document_metadata.title",
      "data_type": "string",
      "required": true
    }
  ],
  "validation_rules": {
    "required_fields": ["document_metadata.title"]
  }
}
EOF

# Test loading
python3 -c "
from src.maps.profile_manager import get_profile_manager
manager = get_profile_manager()
profile = manager.import_profile('profiles/test_simple.json')
if profile:
    print(f' Profile \"{profile.profile_name}\" loaded successfully')
    is_valid, errors = manager.validate_profile(profile)
    print(f'Valid: {is_valid}')
"
```

---

## Architecture Overview

```
Source Files (XML/JSON/CSV/PDF)
        ↓
Profile Manager (selects mapping profile)
        ↓
Generic Parser (profile-driven extraction)
        ↓
Canonical Schema (Pydantic validation)
        ↓
PostgreSQL (JSONB storage + full-text search)
        ↓
REST API (FastAPI - Phase 9)
        ↓
GUI for Non-Technical Users
```

---

## Key Files Reference

| File | Purpose | Status |
|------|---------|--------|
| `migrations/001_initial_schema.sql` | PostgreSQL schema |  Ready to apply |
| `src/maps/schemas/canonical.py` | Data models |  Complete |
| `src/maps/schemas/profile.py` | Profile models |  Complete |
| `src/maps/profile_manager.py` | Profile management |  Complete |
| `docker-compose.yml` | Infrastructure |  Complete |
| `requirements.txt` | Dependencies |  Updated |
| `docs/IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC.md` | Full guide |  Complete |
| `docs/SCHEMA_AGNOSTIC_SUMMARY.md` | Architecture summary |  Complete |

---

## Testing

### Run Existing Tests (Should Still Pass)
```bash
pytest -q
```

### Test New Components
```bash
# Test canonical schema
python3 -m pytest tests/test_canonical_schema.py -v  # Will need to create

# Test profile manager
python3 -m pytest tests/test_profile_manager.py -v   # Will need to create
```

---

## Common Questions

### Q: Will this break my existing radiology parsing?
**A:** No. The new system is designed to coexist with your existing code. Migrate gradually.

### Q: Do I need to rewrite my parser.py?
**A:** Not immediately. First, we create a profile that captures your existing parsing logic, then build a generic parser that uses that profile. Your old code stays until migration is complete.

### Q: Why PostgreSQL instead of SQLite?
**A:** PostgreSQL provides:
- JSONB for flexible schema storage
- Full-text search (pg_trgm)
- Better scalability for large datasets
- Advanced indexing for complex queries
- Better support for concurrent writes

### Q: Can I keep using Excel exports?
**A:** Absolutely. The MAPS Excel export format will be preserved. The new system adds PostgreSQL as an additional export option.

### Q: What if I want to add CSV parsing later?
**A:** create a `CSVParser` class (implementing `BaseParser`), register it with `ParserFactory`, and create profiles for your CSV formats. No changes to core logic needed.

---

## Next Steps for Copilot

**To continue implementation, tell Copilot:** > "Continue with Phase 4: Create the LIDC-IDRI profile. Analyze the existing parser.py (particularly the `parse_radiology_sample` function starting at line 427) and extract all XPath patterns, field mappings, and transformations. Create a comprehensive profile at `/profiles/lidc_idri_standard.json` that captures this logic."

**Or:** > "Follow the implementation guide at `/docs/IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC.md` starting with Phase 4."

---

## Support Resources

- **Implementation Guide:** `/docs/IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC.md` (comprehensive step-by-step)
- **Architecture Summary:** `/docs/SCHEMA_AGNOSTIC_SUMMARY.md` (high-level overview)
- **Original Instructions:** `/.github/copilot-instructions.md` (project context)

---

## Summary

You now have:
-  A complete PostgreSQL schema for flexible data storage
-  Pydantic models for data validation
-  A profile system for defining mappings
-  A profile manager for CRUD operations
-  Docker infrastructure for development
-  Comprehensive documentation for implementation

**Next:** Create the LIDC-IDRI profile and build the generic XML parser.

**Time to Full System:** Estimated 6-8 weeks with focused development.

---

**Ready to proceed? Start PostgreSQL, apply the migration, and begin Phase 4!** 