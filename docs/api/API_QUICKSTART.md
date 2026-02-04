# MAPS REST API Quick Start

## Overview

The MAPS REST API provides programmatic access to all radiology data processing features including XML/PDF parsing, PYLIDC integration, keyword extraction, and data export.

## Installation

### 1. Install Dependencies

```bash
pip install fastapi uvicorn sqlalchemy psycopg2-binary python-multipart
```

### 2. Configure Environment

Create `.env` file:

```bash
# Database
SUPABASE_DB_URL=postgresql://user:password@host:port/database

# API Settings
LOG_LEVEL=INFO
```

### 3. Start API Server

```bash
python start_api.py
```

Or using uvicorn directly:

```bash
uvicorn src.maps.api.main:app --reload
```

API will be available at:
- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Quick Examples

### Parse XML File

```bash
curl -X POST "http://localhost:8000/api/v1/parse/xml" \
  -F "file=@radiology_scan.xml" \
  -F "profile=lidc_idri_standard" \
  -F "extract_keywords=true"
```

Response:
```json
{
  "status": "success",
  "document_id": "uuid-here",
  "parse_case": "LIDC_Multi_Session_4",
  "keywords_extracted": 45,
  "processing_time_ms": 123.45
}
```

### Detect Parse Case

```bash
curl -X POST "http://localhost:8000/api/v1/parse-cases/detect" \
  -F "file=@scan.xml"
```

Response:
```json
{
  "detected_parse_case": "LIDC_Multi_Session_4",
  "confidence": 1.0,
  "file_type": "XML",
  "structure_analysis": {
    "root_element": "LidcReadMessage",
    "session_count": 4,
    "has_unblinded_reads": false
  }
}
```

### List Parse Cases

```bash
curl "http://localhost:8000/api/v1/parse-cases"
```

### Export Data

```bash
# Export LIDC analysis-ready CSV
curl "http://localhost:8000/api/v1/export/lidc-analysis-ready?format=csv" \
  --output lidc_analysis.csv

# Export with TCIA links
curl "http://localhost:8000/api/v1/export/lidc-with-links?format=csv" \
  --output lidc_with_links.csv
```

### Search Keywords

```bash
curl "http://localhost:8000/api/v1/keywords/search?query=malignancy&limit=10"
```

### Query Supabase Views

```bash
# Get LIDC patient summary
curl "http://localhost:8000/api/v1/views/lidc/patient-summary?limit=100"

# Get 3D contours for specific patient
curl "http://localhost:8000/api/v1/views/lidc/3d-contours?patient_id=LIDC-IDRI-0001"
```

### Import PYLIDC Data

```bash
curl -X POST "http://localhost:8000/api/v1/pylidc/import" \
  -H "Content-Type: application/json" \
  -d '{
    "patient_id": "LIDC-IDRI-0001",
    "extract_keywords": true,
    "detect_parse_case": true
  }'
```

### Get Analytics

```bash
# Database summary
curl "http://localhost:8000/api/v1/analytics/summary"

# Parse case distribution
curl "http://localhost:8000/api/v1/analytics/parse-cases"

# Keyword statistics
curl "http://localhost:8000/api/v1/analytics/keywords"
```

### Database Operations

```bash
# Refresh materialized views
curl -X POST "http://localhost:8000/api/v1/db/refresh-views"

# Backfill canonical keywords
curl -X POST "http://localhost:8000/api/v1/db/backfill-keywords"

# Get statistics
curl "http://localhost:8000/api/v1/db/statistics"
```

## Python Client Example

```python
import requests

# Base URL
BASE_URL = "http://localhost:8000/api/v1"

# Parse XML file
with open("scan.xml", "rb") as f:
    response = requests.post(
        f"{BASE_URL}/parse/xml",
        files={"file": f},
        data={
            "profile": "lidc_idri_standard",
            "extract_keywords": True,
            "detect_parse_case": True
        }
    )
    result = response.json()
    print(f"Document ID: {result['document_id']}")
    print(f"Parse Case: {result['parse_case']}")

# Export data
response = requests.get(f"{BASE_URL}/export/lidc-analysis-ready?format=csv")
with open("export.csv", "wb") as f:
    f.write(response.content)

# Search keywords
response = requests.get(
    f"{BASE_URL}/keywords/search",
    params={"query": "malignancy", "limit": 10}
)
keywords = response.json()
```

## R Client Example

```r
library(httr)
library(jsonlite)

base_url <- "http://localhost:8000/api/v1"

# Get LIDC analysis data
response <- GET(paste0(base_url, "/export/lidc-analysis-ready?format=csv"))
data <- read.csv(text = content(response, "text"))

# Get parse case statistics
response <- GET(paste0(base_url, "/analytics/parse-cases"))
stats <- fromJSON(content(response, "text"))
```

## Interactive Documentation

Open http://localhost:8000/docs in your browser for:
- Interactive API testing
- Complete endpoint documentation
- Request/response schemas
- Example payloads

## Next Steps

- Review complete API documentation: `/docs/API_REFERENCE.md`
- Implement authentication (TODO)
- Add rate limiting (TODO)
- Deploy to production server

## Current Status

**Implemented:**
- All 12 routers with endpoints
- Pydantic request/response models
- Configuration and dependencies
- Parse case detection service
- Service layer stubs

**TODO (Service Implementation):**
- Complete parse service using maps.parser
- Complete PYLIDC service using maps.adapters.pylidc_adapter
- Complete keyword service using maps.keyword_search_engine
- Complete export service using maps.exporters
- Complete visualization service using maps.lidc_3d_utils
- Database query implementations
- Authentication and authorization
- Rate limiting
- Caching layer
