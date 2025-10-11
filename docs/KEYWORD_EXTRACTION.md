# Keyword Extraction System

## Overview

MAPS includes a comprehensive keyword extraction system for medical literature analysis. The system can extract, normalize, and search medical keywords from various sources including PDFs, XML files, and text documents.

## Components

### 1. Keyword Normalizer

Normalizes medical keywords using a medical terminology dictionary with support for:

- **Synonym mapping**: Maps variant forms to canonical forms (e.g., "lung" → "pulmonary")
- **Abbreviation expansion**: Expands medical abbreviations (e.g., "CT" → "computed tomography")
- **Multi-word term detection**: Identifies compound medical terms ("ground glass opacity")
- **Stopword filtering**: Removes common non-medical words
- **Search expansion**: Expands queries with synonyms for comprehensive search

#### Usage

```python
from maps import KeywordNormalizer

normalizer = KeywordNormalizer()

# Normalize a keyword
normalized = normalizer.normalize("lung nodule")
# Returns: "pulmonary nodule"

# Expand abbreviations
expanded = normalizer.normalize("GGO")
# Returns: "ground glass opacity"

# Get all synonym forms (for search)
synonyms = normalizer.get_all_forms("nodule")
# Returns: ["nodule", "lesion", "mass", "growth", "tumor"]

# Detect multi-word terms in text
text = "Patient has ground glass opacity in right upper lobe"
terms = normalizer.detect_multi_word_terms(text)
# Returns: [("ground glass opacity", 12, 32), ("right upper lobe", 36, 52)]
```

### 2. PDF Keyword Extractor

Extracts keywords from research papers in PDF format:

- **Metadata extraction**: Title, authors, year, DOI, journal
- **Abstract extraction**: Automatic detection and extraction
- **Author keywords**: Extracts author-provided keywords
- **Body text keywords**: Extracts medical terms from full text
- **Page tracking**: Tracks which page keywords appear on
- **Context preservation**: Saves surrounding context for each keyword

#### Usage

```python
from maps import PDFKeywordExtractor

extractor = PDFKeywordExtractor()

# Extract from single PDF
metadata, keywords = extractor.extract_from_pdf("research_paper.pdf")

print(f"Title: {metadata.title}")
print(f"Year: {metadata.year}")
print(f"Abstract: {metadata.abstract[:200]}...")
print(f"Author keywords: {metadata.author_keywords}")

# View extracted keywords
for kw in keywords:
    print(f"{kw.text} ({kw.category}) - Page {kw.page_number}")
    print(f"  Context: {kw.context[:100]}...")
    print(f"  Frequency: {kw.frequency}")
    print(f"  Normalized: {kw.normalized_form}")
```

#### Keyword Categories

- **metadata**: Keywords from title, authors, journal
- **abstract**: Keywords extracted from abstract
- **keyword**: Author-provided keywords
- **body**: Keywords from body text

### 3. Keyword Search Engine

Full-text search across extracted keywords with:

- **Boolean operators**: AND, OR support
- **Synonym expansion**: Automatically expands queries with synonyms
- **Relevance scoring**: Ranks results by relevance
- **Category filtering**: Filter by keyword category
- **Result highlighting**: Highlights matched terms in context

#### Usage

```python
from maps import KeywordSearchEngine, KeywordNormalizer

normalizer = KeywordNormalizer()
search_engine = KeywordSearchEngine(normalizer)

# Index keywords
keywords = [
    ("lung nodule", "body", "Patient has lung nodule in RUL"),
    ("ground glass opacity", "abstract", "GGO observed"),
    ("computed tomography", "metadata", "CT scan results")
]
search_engine.index_keywords(keywords)

# Simple search
response = search_engine.search("nodule")
print(f"Found {response.total_results} results")

# Boolean search with AND
response = search_engine.search("lung AND opacity")

# Boolean search with OR
response = search_engine.search("pulmonary OR nodule")

# Process results
for result in response.results:
    print(f"{result.keyword_text} (relevance: {result.relevance_score:.2f})")
    print(f"  Matched terms: {result.matched_query_terms}")
    print(f"  Context: {result.context}")
```

## Medical Terms Dictionary

The system uses a JSON dictionary (`data/medical_terms.json`) containing:

```json
{
  "synonyms": {
    "pulmonary": ["lung", "pneumonic", "pulmonic"],
    "nodule": ["lesion", "mass", "growth", "tumor"]
  },
  "abbreviations": {
    "CT": "computed tomography",
    "GGO": "ground glass opacity",
    "RUL": "right upper lobe"
  },
  "multi_word_terms": [
    "ground glass opacity",
    "computed tomography",
    "right upper lobe"
  ],
  "stopwords": [
    "the", "and", "or", "in", "of", "to"
  ]
}
```

### Customizing the Dictionary

You can extend the dictionary by editing `data/medical_terms.json`:

1. Add new synonyms under `"synonyms"`
2. Add abbreviations under `"abbreviations"`
3. Add multi-word terms to `"multi_word_terms"`
4. Add domain-specific stopwords to `"stopwords"`

## Integration with MAPS

The keyword extraction system integrates seamlessly with other MAPS components:

### With XML Parser

```python
from maps import parse_radiology_sample, KeywordNormalizer

# Parse XML
main_df, unblinded_df = parse_radiology_sample("scan.xml")

# Extract keywords from characteristics
normalizer = KeywordNormalizer()
characteristics = main_df['Characteristics'].iloc[0]

# Normalize characteristic values
for char_name, value in characteristics.items():
    normalized = normalizer.normalize(f"{char_name} {value}")
    print(f"{char_name}: {normalized}")
```

### With Canonical Schema

```python
from maps import RadiologyCanonicalDocument, KeywordNormalizer

doc = RadiologyCanonicalDocument(
    document_metadata={"title": "CT scan with GGO findings"},
    study_instance_uid="1.2.3.4",
    modality="CT"
)

normalizer = KeywordNormalizer()
normalized_title = normalizer.normalize(doc.document_metadata.title)
# Automatically expands "GGO" and normalizes medical terms
```

## Best Practices

1. **Always normalize before storage**: Store canonical forms in databases
2. **Expand synonyms for search**: Use `get_all_forms()` for comprehensive search
3. **Preserve original forms**: Keep both original and normalized for display
4. **Use multi-word detection**: Detect compound terms before single-word extraction
5. **Context is key**: Always save context snippets with keywords

## Performance Considerations

- **Dictionary loading**: Dictionary is loaded once at initialization
- **Batch normalization**: Use `normalize_batch()` for multiple keywords
- **Index caching**: Search engine builds index once, reuses for multiple queries
- **PDF processing**: Process large PDFs with `max_pages` parameter

## Future Enhancements

- Database integration for persistent keyword storage
- Machine learning-based keyword extraction
- Semantic search using word embeddings
- Interactive keyword approval workflow
- API endpoints for keyword search
