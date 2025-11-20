# Consolidated Keyword View Documentation

## Overview

The **Consolidated Keyword View** (`v_keyword_consolidated`) provides a comprehensive, unified view of all keyword data in the MAPS system, combining:

- Core keyword metadata (text, category, definition, references)
- Statistical information (frequency, document count, TF-IDF scores)
- Source tracking (XML, PDF, research papers)
- Synonym counts
- Standardization metadata (vocabulary source, standard flags)

This view simplifies keyword queries and supports advanced analytics for radiology terminology research.

---

## Database Schema Enhancements

### New Keyword Columns

Migration `002_add_keyword_enhancements.sql` adds the following columns to the `keywords` table:

| Column | Type | Description |
|--------|------|-------------|
| `definition` | TEXT | Formal medical/technical definition from literature |
| `source_refs` | TEXT | Semicolon-separated reference IDs (e.g., "1;13;25") |
| `is_standard` | BOOLEAN | True if from standardized vocabulary (RadLex, LOINC, etc.) |
| `vocabulary_source` | VARCHAR(100) | Source vocabulary name (e.g., "RadLex", "Lung-RADS") |

### Existing Keyword Schema

| Column | Type | Description |
|--------|------|-------------|
| `keyword_id` | INTEGER | Primary key (auto-increment) |
| `keyword_text` | VARCHAR(255) | The keyword/term (unique) |
| `normalized_form` | VARCHAR(255) | Lowercase normalized form |
| `category` | VARCHAR(100) | Category classification |
| `description` | TEXT | Internal notes/description |
| `created_at` | TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMP | Last update timestamp |

---

## Consolidated View: `v_keyword_consolidated`

### View Definition

```sql
CREATE OR REPLACE VIEW v_keyword_consolidated AS
SELECT
    k.keyword_id,
    k.keyword_text,
    k.normalized_form,
    k.category,
    COALESCE(k.definition, k.description) AS definition,
    k.source_refs,
    k.is_standard,
    k.vocabulary_source,

    -- Statistics from keyword_statistics table
    ks.total_frequency,
    ks.document_count,
    ks.idf_score,
    ks.avg_tf_idf,
    ks.last_calculated AS stats_last_calculated,

    -- Synonym count
    (SELECT COUNT(*) FROM keyword_synonyms
     WHERE canonical_keyword_id = k.keyword_id) AS synonym_count,

    -- Source file counts
    (SELECT COUNT(DISTINCT source_file) FROM keyword_sources
     WHERE keyword_id = k.keyword_id) AS unique_source_files,
    (SELECT COUNT(*) FROM keyword_sources
     WHERE keyword_id = k.keyword_id AND source_type = 'xml') AS xml_source_count,
    (SELECT COUNT(*) FROM keyword_sources
     WHERE keyword_id = k.keyword_id AND source_type = 'pdf') AS pdf_source_count,
    (SELECT COUNT(*) FROM keyword_sources
     WHERE keyword_id = k.keyword_id AND source_type = 'research_paper') AS paper_source_count,

    -- Timestamps
    k.created_at,
    k.updated_at
FROM keywords k
LEFT JOIN keyword_statistics ks ON k.keyword_id = ks.keyword_id
ORDER BY k.category, k.keyword_text;
```

### View Columns

| Column | Type | Description |
|--------|------|-------------|
| `keyword_id` | INTEGER | Unique keyword identifier |
| `keyword_text` | VARCHAR(255) | The keyword/term |
| `normalized_form` | VARCHAR(255) | Normalized lowercase form |
| `category` | VARCHAR(100) | Keyword category |
| `definition` | TEXT | Formal definition (from `definition` or `description`) |
| `source_refs` | TEXT | Reference IDs (semicolon-separated) |
| `is_standard` | BOOLEAN | Standard vocabulary flag |
| `vocabulary_source` | VARCHAR(100) | Source vocabulary name |
| `total_frequency` | INTEGER | Total occurrences across all documents |
| `document_count` | INTEGER | Number of unique documents containing keyword |
| `idf_score` | FLOAT | Inverse Document Frequency score |
| `avg_tf_idf` | FLOAT | Average TF-IDF score |
| `stats_last_calculated` | TIMESTAMP | Last statistics calculation time |
| `synonym_count` | INTEGER | Number of synonyms for this keyword |
| `unique_source_files` | INTEGER | Number of unique source files |
| `xml_source_count` | INTEGER | Count of XML sources |
| `pdf_source_count` | INTEGER | Count of PDF sources |
| `paper_source_count` | INTEGER | Count of research paper sources |
| `created_at` | TIMESTAMP | Keyword creation time |
| `updated_at` | TIMESTAMP | Last update time |

---

## Category-Specific Views

The migration creates specialized views for each keyword category:

### 1. `v_keywords_standardization_reporting`
Keywords related to standardization and reporting (RADS, RadLex, structured reports, etc.)

```sql
SELECT * FROM v_keywords_standardization_reporting;
```

### 2. `v_keywords_radiologist_cognition`
Keywords related to radiologist cognition, errors, and diagnostic patterns

```sql
SELECT * FROM v_keywords_radiologist_cognition;
```

### 3. `v_keywords_imaging_biomarkers`
Keywords related to imaging biomarkers, radiomics, and computational analysis

```sql
SELECT * FROM v_keywords_imaging_biomarkers;
```

### 4. `v_keywords_pulmonary_nodules`
Keywords related to pulmonary nodules, lung cancer screening, and databases

```sql
SELECT * FROM v_keywords_pulmonary_nodules;
```

### 5. `v_keywords_ner_metrics`
Keywords related to Named Entity Recognition (NER) performance metrics

```sql
SELECT * FROM v_keywords_ner_metrics;
```

---

## Helper Functions

### 1. `get_keywords_by_category(p_category VARCHAR)`

Get all keywords for a specific category with basic statistics.

**Example:**
```sql
SELECT * FROM get_keywords_by_category('standardization_and_reporting');
```

**Returns:**
- `keyword_id`
- `keyword_text`
- `definition`
- `source_refs`
- `total_frequency`
- `document_count`

### 2. `search_keywords_full(p_search_term TEXT)`

Full-text search across keyword text, normalized form, and definition with match type ranking.

**Example:**
```sql
SELECT * FROM search_keywords_full('lung');
```

**Returns:**
- `keyword_id`
- `keyword_text`
- `normalized_form`
- `category`
- `definition`
- `source_refs`
- `match_type` ('exact', 'partial', 'normalized', 'definition', 'other')

Results are ranked by match type (exact matches first).

---

## Usage Examples

### Query 1: Get All Keywords with Statistics

```sql
SELECT
    keyword_text,
    category,
    definition,
    total_frequency,
    document_count,
    synonym_count
FROM v_keyword_consolidated
ORDER BY total_frequency DESC
LIMIT 20;
```

### Query 2: Find Keywords from Specific Vocabulary

```sql
SELECT
    keyword_text,
    definition,
    source_refs,
    vocabulary_source
FROM v_keyword_consolidated
WHERE vocabulary_source = 'RadLex'
ORDER BY keyword_text;
```

### Query 3: Get Top Keywords by Category

```sql
SELECT
    category,
    keyword_text,
    total_frequency,
    document_count
FROM v_keyword_consolidated
WHERE category = 'imaging_biomarkers_and_computation'
ORDER BY total_frequency DESC
LIMIT 10;
```

### Query 4: Find Keywords with Multiple Sources

```sql
SELECT
    keyword_text,
    unique_source_files,
    xml_source_count,
    pdf_source_count,
    paper_source_count
FROM v_keyword_consolidated
WHERE unique_source_files > 5
ORDER BY unique_source_files DESC;
```

### Query 5: Search for Keywords with References

```sql
SELECT
    keyword_text,
    definition,
    source_refs
FROM v_keyword_consolidated
WHERE source_refs IS NOT NULL
  AND source_refs LIKE '%1%'  -- Find keywords citing reference #1
ORDER BY keyword_text;
```

### Query 6: Get Standardized Keywords Only

```sql
SELECT
    keyword_text,
    vocabulary_source,
    definition,
    is_standard
FROM v_keyword_consolidated
WHERE is_standard = TRUE
ORDER BY vocabulary_source, keyword_text;
```

---

## Python API Usage

### Example 1: Query Consolidated View

```python
from maps.database.keyword_repository import KeywordRepository

# Initialize repository
repo = KeywordRepository(
    database='ra_d_ps_db',
    user='ra_d_ps_user',
    password='changeme'
)

# Get all keywords (uses v_keyword_consolidated internally)
keywords = repo.get_all_keywords(limit=100)

for kw in keywords:
    print(f"{kw.keyword_text}: {kw.definition}")
    print(f"  Category: {kw.category}")
    print(f"  Sources: {kw.source_refs}")
    print()
```

### Example 2: Search Keywords

```python
from maps.database.keyword_repository import KeywordRepository

repo = KeywordRepository()

# Search for keywords containing "lung"
results = repo.search_keywords(query='lung', limit=20)

for kw in results:
    print(f"{kw.keyword_text} ({kw.category})")
    if kw.definition:
        print(f"  Definition: {kw.definition[:100]}...")
```

### Example 3: Get Keywords by Category

```python
from maps.database.keyword_repository import KeywordRepository

repo = KeywordRepository()

# Get all imaging biomarker keywords
keywords = repo.get_keywords_by_category('imaging_biomarkers_and_computation')

print(f"Found {len(keywords)} imaging biomarker keywords:")
for kw in keywords:
    print(f"  - {kw.keyword_text}")
```

---

## Import Process

### Step 1: Apply Migration

```bash
# Apply the keyword enhancement migration
bash scripts/apply_keyword_migration.sh

# Or manually:
psql -h localhost -U ra_d_ps_user -d ra_d_ps_db -f migrations/002_add_keyword_enhancements.sql
```

### Step 2: Import CSV Data

```bash
# Import keyword data from CSV
python scripts/import_keyword_csv.py data/keywords_radiology_standard.csv \
  --vocabulary-source "radiology_standard" \
  --is-standard

# Dry run first to preview
python scripts/import_keyword_csv.py data/keywords_radiology_standard.csv \
  --dry-run \
  --verbose
```

### Step 3: Verify Import

```sql
-- Check total keywords
SELECT COUNT(*) FROM keywords;

-- Check categories
SELECT category, COUNT(*) as count
FROM v_keyword_consolidated
GROUP BY category
ORDER BY count DESC;

-- View sample data
SELECT * FROM v_keyword_consolidated LIMIT 10;
```

---

## Data Model: Keyword Categories

The current system uses the following keyword categories:

1. **`standardization_and_reporting`**
   - RADS systems (Lung-RADS, etc.)
   - Terminology ontologies (RadLex, LOINC)
   - Structured reporting concepts

2. **`radiologist_cognition_and_diagnostics`**
   - Cognitive errors and biases
   - Diagnostic signs and patterns
   - Clinical decision-making concepts

3. **`imaging_biomarkers_and_computation`**
   - Radiomics features
   - NLP/NER concepts
   - Computational imaging methods

4. **`pulmonary_nodules_and_databases`**
   - Nodule characteristics
   - Lung cancer screening
   - Public databases (LIDC-IDRI, TCIA)

5. **`ner_performance_metrics`**
   - True positive, false positive, etc.
   - Precision, recall, F-measure

---

## Reference Sources Table

The migration creates a `keyword_reference_sources` table to store metadata for citations:

```sql
CREATE TABLE keyword_reference_sources (
    source_id INTEGER PRIMARY KEY,
    citation TEXT NOT NULL,
    title TEXT,
    authors TEXT,
    journal TEXT,
    year INTEGER,
    doi TEXT,
    url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### Example: Insert Reference Sources

```sql
INSERT INTO keyword_reference_sources (source_id, citation, title, authors, journal, year, doi)
VALUES
(1, 'ACR Lung-RADS v2022', 'Lung CT Screening Reporting and Data System', 'American College of Radiology', 'ACR', 2022, NULL),
(2, 'RadLex Ontology', 'RadLex: A lexicon for uniform indexing and retrieval of radiology information', 'Langlotz CP', 'RadioGraphics', 2006, '10.1148/rg.261055143');
```

---

## Analytics Queries

### Most Frequent Keywords

```sql
SELECT
    keyword_text,
    category,
    total_frequency,
    document_count,
    unique_source_files
FROM v_keyword_consolidated
WHERE total_frequency > 0
ORDER BY total_frequency DESC
LIMIT 50;
```

### Keywords by Source Type

```sql
SELECT
    keyword_text,
    category,
    xml_source_count,
    pdf_source_count,
    paper_source_count,
    (xml_source_count + pdf_source_count + paper_source_count) as total_sources
FROM v_keyword_consolidated
WHERE (xml_source_count + pdf_source_count + paper_source_count) > 0
ORDER BY total_sources DESC;
```

### Category Distribution

```sql
SELECT
    category,
    COUNT(*) as keyword_count,
    SUM(total_frequency) as total_occurrences,
    AVG(document_count) as avg_doc_count
FROM v_keyword_consolidated
GROUP BY category
ORDER BY keyword_count DESC;
```

### Keywords Without Definitions

```sql
SELECT
    keyword_text,
    category
FROM v_keyword_consolidated
WHERE definition IS NULL OR definition = ''
ORDER BY category, keyword_text;
```

---

## Troubleshooting

### Problem: View not found

**Solution:**
```bash
# Reapply migration
bash scripts/apply_keyword_migration.sh
```

### Problem: No data in view

**Solution:**
```bash
# Import keyword data
python scripts/import_keyword_csv.py data/keywords_radiology_standard.csv --is-standard
```

### Problem: Statistics are NULL

**Solution:**
```python
from maps.database.keyword_repository import KeywordRepository

repo = KeywordRepository()

# Update statistics for all keywords
keywords = repo.get_all_keywords()
for kw in keywords:
    repo.update_keyword_statistics(kw.keyword_id)
```

---

## Maintenance

### Update Statistics

```sql
-- Update statistics for a specific keyword
UPDATE keyword_statistics
SET last_calculated = CURRENT_TIMESTAMP
WHERE keyword_id = 123;

-- Or use Python API
from maps.database.keyword_repository import KeywordRepository
repo = KeywordRepository()
repo.update_keyword_statistics(keyword_id=123)
```

### Refresh View (if needed)

```sql
-- Views are automatically updated when underlying tables change
-- No manual refresh needed

-- To recreate view:
DROP VIEW IF EXISTS v_keyword_consolidated CASCADE;
-- Then reapply migration
```

---

## Future Enhancements

Planned improvements to the keyword system:

1. **Full-Text Search**: PostgreSQL `tsvector` for advanced search
2. **Keyword Relationships**: Ontology-based hierarchies (parent/child terms)
3. **Multi-language Support**: Translations and language-specific definitions
4. **Version Control**: Track changes to keyword definitions over time
5. **ML Integration**: Automatic keyword extraction and synonym detection

---

## References

- **Migration File**: `migrations/002_add_keyword_enhancements.sql`
- **Import Script**: `scripts/import_keyword_csv.py`
- **Sample Data**: `data/keywords_radiology_standard.csv`
- **Python Models**: `src/maps/database/keyword_models.py`
- **Repository**: `src/maps/database/keyword_repository.py`

---

**Last Updated:** November 22, 2025
**Version:** 1.0.0
**Migration:** 002
