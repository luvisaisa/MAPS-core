# API Reference - MAPS

## REST API Endpoints

Base URL: `http://localhost:8000/api`

### Health & Status

#### GET /health
Health check endpoint.

```bash
curl http://localhost:8000/api/health
```

Response:
```json
{
  "status": "healthy",
  "service": "MAPS API",
  "timestamp": "2026-02-03T12:00:00Z"
}
```

#### GET /status
System status with component health.

### Parsing Endpoints

#### POST /parse/xml
Parse XML file with optional profile.

```bash
curl -X POST "http://localhost:8000/api/parse/xml" \
  -F "file=@sample.xml" \
  -F "profile_name=lidc_idri_standard"
```

#### POST /parse/batch
Batch parse multiple XML files.

#### POST /parse/pdf
Extract keywords from PDF file.

### Profile Endpoints

#### GET /profiles
List available parsing profiles.

#### GET /profiles/{name}
Get specific profile configuration.

#### POST /profiles/{name}/validate
Validate profile configuration.

### Keyword Endpoints

#### GET /keywords/search
Search keywords with boolean queries.

```bash
curl "http://localhost:8000/api/keywords/search?query=lung&expand_synonyms=true"
```

#### GET /keywords/normalize
Normalize medical keyword.

```bash
curl "http://localhost:8000/api/keywords/normalize?keyword=CT"
```

### Analysis Endpoints

#### POST /analysis/analyze/xml
Auto-analyze XML file and extract entities.

### Detection Endpoints

#### POST /detection/detect
Detect XML parse case without full parsing.

### Export Endpoints

#### POST /export/excel
Export data to Excel format.

#### POST /export/csv
Export data to CSV format.

### Statistics Endpoints

#### GET /statistics/system
Get system statistics (CPU, memory, disk).

---

## Python API

### Core Functions

```python
from maps import (
    parse_radiology_sample,
    parse_multiple,
    export_excel,
    detect_parse_case,
    get_expected_attributes_for_case
)

# Parse single file
main_df, unblinded_df = parse_radiology_sample("sample.xml")

# Batch parse
main_dfs, unblinded_dfs = parse_multiple(["file1.xml", "file2.xml"])

# Detect parse case
parse_case = detect_parse_case("sample.xml")

# Export to Excel
export_excel(main_df, "output.xlsx")
```

### Schema Classes

```python
from maps import (
    CanonicalDocument,
    RadiologyCanonicalDocument,
    Profile,
    ProfileManager
)

# Load profile
manager = ProfileManager()
profile = manager.load_profile("lidc_idri_standard")
```

### Keyword Extraction

```python
from maps import (
    KeywordNormalizer,
    KeywordSearchEngine,
    XMLKeywordExtractor,
    PDFKeywordExtractor
)

# Normalize keywords
normalizer = KeywordNormalizer()
normalized = normalizer.normalize("CT scan")

# Search
engine = KeywordSearchEngine(normalizer)
results = engine.search("lung nodule")
```

### Adapters

```python
from maps import PyLIDCAdapter

# Convert LIDC scan to canonical format
adapter = PyLIDCAdapter()
canonical_doc = adapter.scan_to_canonical(scan)
```

---

*Last Updated: February 2026*
*Version: 1.0.1*
