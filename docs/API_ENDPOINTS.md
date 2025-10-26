# MAPS REST API Endpoints

REST API for medical annotation processing system.

## Base URL

```
http://localhost:8000/api
```

## Interactive Documentation

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Endpoints

### Health Check

#### GET /api/health

Check API health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-26T12:00:00",
  "service": "MAPS API",
  "version": "1.0.0"
}
```

#### GET /api/status

Get detailed component status.

**Response:**
```json
{
  "status": "operational",
  "components": {
    "parser": "ready",
    "profiles": "ready",
    "keywords": "ready"
  },
  "timestamp": "2025-10-26T12:00:00"
}
```

### Parser Endpoints

#### POST /api/parse/parse/xml

Parse uploaded XML file.

**Parameters:**
- `file` (form-data): XML file to parse
- `profile_name` (query, optional): Parsing profile (default: lidc_idri_standard)

**Response:**
```json
{
  "status": "success",
  "filename": "sample.xml",
  "profile": "lidc_idri_standard",
  "document": { ... }
}
```

#### POST /api/parse/parse/batch

Parse multiple XML files.

**Parameters:**
- `files` (form-data): List of XML files
- `profile_name` (query, optional): Parsing profile

**Response:**
```json
{
  "total": 5,
  "successful": 4,
  "failed": 1,
  "results": [...],
  "errors": [...]
}
```

#### POST /api/parse/parse/pdf

Extract keywords from PDF file.

**Parameters:**
- `file` (form-data): PDF file to parse

**Response:**
```json
{
  "status": "success",
  "filename": "paper.pdf",
  "metadata": {
    "title": "Research Paper",
    "authors": ["Author 1", "Author 2"],
    "abstract": "...",
    "page_count": 15
  },
  "keywords": [...]
}
```

### Profile Endpoints

#### GET /api/profiles

List all available parsing profiles.

**Response:**
```json
{
  "profiles": [
    {
      "name": "lidc_idri_standard",
      "file_type": "XML",
      "description": "LIDC-IDRI radiology format"
    }
  ]
}
```

#### GET /api/profiles/{name}

Get specific profile configuration.

**Parameters:**
- `name` (path): Profile name

**Response:**
```json
{
  "profile_name": "lidc_idri_standard",
  "file_type": "XML",
  "description": "LIDC-IDRI radiology format",
  "mappings": [...],
  "validation_rules": {...}
}
```

### Keyword Endpoints

#### GET /api/keywords/search

Search for keywords using boolean queries.

**Parameters:**
- `query` (query): Search query (supports AND/OR operators)
- `expand_synonyms` (query, optional): Expand synonyms (default: true)
- `min_relevance` (query, optional): Minimum relevance score (default: 0.0)

**Response:**
```json
{
  "query": "lung AND nodule",
  "expanded_query": "lung AND (nodule OR lesion OR mass)",
  "total_results": 10,
  "results": [
    {
      "keyword": "pulmonary nodule",
      "relevance": 0.95,
      "matched_terms": ["lung", "nodule"]
    }
  ]
}
```

#### GET /api/keywords/normalize

Normalize medical keyword.

**Parameters:**
- `keyword` (query): Keyword to normalize
- `expand_abbreviations` (query, optional): Expand abbreviations (default: true)

**Response:**
```json
{
  "original": "GGO",
  "normalized": "ground glass opacity",
  "all_forms": ["GGO", "ground glass opacity", "ground-glass opacity"]
}
```

### Analysis Endpoints

#### POST /api/analysis/analyze/xml

Auto-analyze XML file and extract entities.

**Parameters:**
- `file` (form-data): XML file to analyze
- `populate_entities` (query, optional): Populate entities (default: true)

**Response:**
```json
{
  "status": "success",
  "filename": "scan.xml",
  "document": {...},
  "statistics": {
    "total_entities": 25,
    "nodules": 3,
    "confidence": 0.87
  }
}
```

## Running the Server

```bash
# Using the launch script
python scripts/run_server.py

# Or using uvicorn directly
uvicorn maps.api.app:create_app --factory --reload --port 8000
```

## Example Usage

### cURL

```bash
# Health check
curl http://localhost:8000/api/health

# Parse XML file
curl -X POST http://localhost:8000/api/parse/parse/xml \
  -F "file=@sample.xml" \
  -F "profile_name=lidc_idri_standard"

# Search keywords
curl "http://localhost:8000/api/keywords/search?query=lung+AND+nodule"
```

### Python

```python
import requests

# Parse XML file
with open('sample.xml', 'rb') as f:
    response = requests.post(
        'http://localhost:8000/api/parse/parse/xml',
        files={'file': f},
        params={'profile_name': 'lidc_idri_standard'}
    )
    print(response.json())

# Search keywords
response = requests.get(
    'http://localhost:8000/api/keywords/search',
    params={'query': 'lung AND nodule'}
)
print(response.json())
```

## Error Responses

All endpoints return standard error responses:

```json
{
  "detail": "Error message"
}
```

**Status Codes:**
- `200`: Success
- `400`: Bad request (invalid input)
- `404`: Not found
- `500`: Internal server error
