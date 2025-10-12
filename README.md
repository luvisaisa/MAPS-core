# MAPS - Medical Annotation Processing System

XML parser for medical imaging annotation data with GUI and CLI interfaces.

## Features

- Automatic parse case detection (7 supported formats)
- Multi-format XML parsing (standard + LIDC-IDRI)
- Nodule characteristic extraction
- ROI coordinate mapping
- Excel export
- Batch processing
- **GUI Application** (Tkinter-based)
- Command-line interface
- **Schema-agnostic data ingestion** (NEW)
- Profile-based parsing system
- Pydantic v2 canonical schemas
- **Keyword extraction from PDFs** (NEW)
- Medical term normalization and search
- Boolean query support

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### GUI Application

```bash
python scripts/launch_gui.py
```

Features:
- File/folder selection
- Progress tracking
- Real-time logging
- One-click parsing and export

### CLI (Programmatic)

```python
from src.maps.parser import parse_radiology_sample

# Parse single file
main_df, unblinded_df = parse_radiology_sample('data/sample.xml')
```

### Batch Processing

```python
from src.maps.parser import parse_multiple

xml_files = ['file1.xml', 'file2.xml']
main_dfs, unblinded_dfs = parse_multiple(xml_files)
```

## Supported Parse Cases

- **Complete_Attributes**: Full annotation data
- **Core_Attributes_Only**: Essential fields
- **With_Reason_Partial**: Minimal data
- **LIDC_Single_Session**: LIDC with one reader
- **LIDC_Multi_Session_X**: LIDC with 2-4 readers

See [docs/PARSE_CASES.md](docs/PARSE_CASES.md) for details.

## Schema-Agnostic System

MAPS now supports flexible data ingestion through a profile-based mapping system:

```python
from maps import get_profile_manager, RadiologyCanonicalDocument

# Load a profile
manager = get_profile_manager()
profile = manager.load_profile("lidc_idri_standard")

# Create canonical documents with type safety
doc = RadiologyCanonicalDocument(
    document_metadata={"title": "CT Scan", "date": "2024-01-15"},
    study_instance_uid="1.2.840.113654.2.55.12345",
    modality="CT"
)
```

Benefits:
- Parse any format without code changes
- Type-safe with Pydantic v2 validation
- Profile inheritance and reusability
- Extensible canonical schema

See [docs/SCHEMA_AGNOSTIC.md](docs/SCHEMA_AGNOSTIC.md) for details.

## Keyword Extraction

Extract and analyze medical keywords from research papers and XML files:

```python
from maps import KeywordNormalizer, PDFKeywordExtractor, KeywordSearchEngine

# Normalize medical terms
normalizer = KeywordNormalizer()
normalized = normalizer.normalize("GGO")  # → "ground glass opacity"
synonyms = normalizer.get_all_forms("nodule")  # → ["nodule", "lesion", "mass", ...]

# Extract from PDFs
extractor = PDFKeywordExtractor()
metadata, keywords = extractor.extract_from_pdf("paper.pdf")

# Search with boolean queries
search_engine = KeywordSearchEngine(normalizer)
results = search_engine.search("lung AND nodule")
```

Features:
- Medical terminology normalization
- Abbreviation expansion (CT → computed tomography)
- Multi-word term detection
- PDF metadata and keyword extraction
- Boolean search (AND/OR operators)
- Synonym expansion for comprehensive search

See [docs/KEYWORD_EXTRACTION.md](docs/KEYWORD_EXTRACTION.md) for details.

## Documentation

- [Schema-Agnostic System](docs/SCHEMA_AGNOSTIC.md)
- [Keyword Extraction](docs/KEYWORD_EXTRACTION.md)
- [GUI Guide](docs/GUI_GUIDE.md)
- [Parse Cases](docs/PARSE_CASES.md)
- [Examples](examples/)
