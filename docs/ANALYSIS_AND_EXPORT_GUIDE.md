# Analysis and Export Guide

Comprehensive guide for filtering, viewing, and exporting data from the Case Identifier System.

##  Available Views

### 1. `master_analysis_table` (View)
**Purpose**: Comprehensive view with all data joined - best for ad-hoc queries and filtering

**Columns**:
- **File Info**: `file_id`, `filename`, `file_type`, `file_size_bytes`, `import_timestamp`, `processing_status`, `file_metadata`
- **Segment Info**: `segment_type`, `segment_id`, `segment_timestamp`, `position_in_file`
- **Content**: `content_preview` (first 200 chars)
- **Keywords**: `keyword_count`, `keywords` (JSON array)
- **Indicators**: `has_numeric_data`, `has_text_data`
- **Patterns**: `case_pattern_count`, `associated_cases` (JSON array)

**Use Cases**:
- Real-time queries with filters
- Exploratory analysis
- Custom reporting

**Example Query**:
```sql
-- All XML files with qualitative content
SELECT * FROM master_analysis_table
WHERE file_type = 'xml' 
  AND segment_type = 'qualitative'
ORDER BY import_timestamp DESC;

-- Files with high keyword density
SELECT filename, segment_type, keyword_count, keywords
FROM master_analysis_table
WHERE keyword_count >= 5
ORDER BY keyword_count DESC;

-- Cross-validated cases only
SELECT DISTINCT filename, associated_cases
FROM master_analysis_table
WHERE case_pattern_count > 0
  AND associated_cases::jsonb @> '[{"cross_validated": true}]';
```

---

### 2. `export_ready_table` (Materialized View)
**Purpose**: Pre-computed, optimized for fast exports - refresh periodically for latest data

**Columns**:
- **Core**: `file_id`, `filename`, `file_type`, `import_date`, `processing_status`
- **Classification**: `segment_type`, `segment_id`
- **Content**: `text_content`, `numeric_content`
- **Keywords**: `keywords_list` (comma-separated), `keyword_count`, `max_relevance_score`
- **Flags**: `has_numeric_associations`, `case_pattern_count`
- **Metadata**: `metadata_flat` (key=value pairs)

**Use Cases**:
- Fast exports to CSV/Excel
- Dashboard data sources
- Batch processing

**Refresh Command**:
```sql
-- Manual refresh
REFRESH MATERIALIZED VIEW export_ready_table;

-- Or use the function for stats
SELECT * FROM refresh_export_table();
-- Returns: {total_rows, refresh_duration, refresh_timestamp}
```

**Example Query**:
```sql
-- Export-ready data for all qualitative segments
SELECT * FROM export_ready_table
WHERE segment_type = 'qualitative'
ORDER BY import_date DESC;

-- High-relevance keywords only
SELECT * FROM export_ready_table
WHERE max_relevance_score >= 5.0;
```

---

### 3. `unified_segments` (View)
**Purpose**: All segments across types - simple union for basic queries

**Columns**:
- `segment_type` (quantitative/qualitative/mixed)
- `segment_id`
- `file_id`
- `content` (JSONB)
- `position_in_file`
- `extraction_timestamp`

**Example Query**:
```sql
-- Count segments by type
SELECT segment_type, COUNT(*) as count
FROM unified_segments
GROUP BY segment_type;

-- All segments from specific file
SELECT * FROM unified_segments
WHERE file_id = 'your-file-uuid';
```

---

### 4. `cross_type_keywords` (View)
**Purpose**: High-signal keywords appearing in BOTH quantitative and qualitative content

**Columns**:
- `keyword_id`, `term`, `normalized_term`, `relevance_score`
- `quantitative_occurrences`, `qualitative_occurrences`, `mixed_occurrences`
- `file_count`

**Example Query**:
```sql
-- Top cross-validated keywords
SELECT term, relevance_score, 
       quantitative_occurrences, qualitative_occurrences, file_count
FROM cross_type_keywords
ORDER BY relevance_score DESC
LIMIT 20;
```

---

### 5. `keyword_numeric_associations` (View)
**Purpose**: All numeric values associated with keywords

**Columns**:
- `keyword_id`, `term`
- `occurrence_id`, `file_id`, `filename`
- `segment_type`, `associated_values`, `surrounding_context`
- `occurrence_timestamp`

**Example Query**:
```sql
-- All numeric associations for "malignancy"
SELECT * FROM keyword_numeric_associations
WHERE term ILIKE '%malignancy%';
```

---

##  Helper Functions

### 1. `filter_analysis_table()`
**Purpose**: Complex filtering with multiple criteria

**Parameters**:
- `p_file_types` (TEXT[]): File extensions, e.g., `ARRAY['xml', 'pdf']`
- `p_segment_types` (segment_type_enum[]): `ARRAY['quantitative', 'qualitative', 'mixed']`
- `p_min_keyword_count` (INTEGER): Minimum keywords required
- `p_has_case_patterns` (BOOLEAN): TRUE = only with patterns, FALSE = only without
- `p_date_from` (TIMESTAMPTZ): Start date
- `p_date_to` (TIMESTAMPTZ): End date
- `p_keyword_search` (TEXT): Search term in keywords

**Example**:
```sql
-- XML files with qualitative content and at least 3 keywords
SELECT * FROM filter_analysis_table(
    p_file_types := ARRAY['xml'],
    p_segment_types := ARRAY['qualitative'],
    p_min_keyword_count := 3
);

-- Recent imports with case patterns
SELECT * FROM filter_analysis_table(
    p_has_case_patterns := TRUE,
    p_date_from := '2024-01-01'::TIMESTAMPTZ
);

-- Search for "malignancy" keyword
SELECT * FROM filter_analysis_table(
    p_keyword_search := 'malignancy'
);
```

---

### 2. `find_files_with_keywords()`
**Purpose**: Find files containing ALL specified keywords

**Parameters**:
- `keyword_terms` (TEXT[]): Array of keywords

**Example**:
```sql
-- Files with both "spiculation" and "malignancy"
SELECT * FROM find_files_with_keywords(
    ARRAY['spiculation', 'malignancy']
);
```

---

### 3. `get_keyword_contexts()`
**Purpose**: Get all contexts where a keyword appears

**Parameters**:
- `keyword_term` (TEXT): Single keyword

**Example**:
```sql
-- All contexts for "nodule"
SELECT * FROM get_keyword_contexts('nodule');
```

---

##  Python Export Utilities

### Installation
```bash
# Already in your environment
pip install supabase
```

### Quick Start
```python
from src.maps.analysis_exporter import AnalysisExporter

# Initialize
exporter = AnalysisExporter()

# Print summary stats
exporter.print_summary()

# Export all data to CSV
exporter.export_to_csv('./exports/all_data.csv')

# Export with filters
qualitative_data = exporter.filter_by_criteria(
    segment_types=['qualitative'],
    min_keyword_count=3
)
exporter.export_to_json('./exports/qualitative_filtered.json', data=qualitative_data)
```

### Available Methods

#### `get_master_table(filters=None)`
```python
# Get all qualitative XML segments
data = exporter.get_master_table({
    'segment_type': 'qualitative',
    'file_type': 'xml'
})
```

#### `get_export_table(limit=None)`
```python
# Get pre-computed fast export data
data = exporter.get_export_table(limit=1000)
```

#### `filter_by_criteria(...)`
```python
# Complex filtering
data = exporter.filter_by_criteria(
    file_types=['xml', 'pdf'],
    segment_types=['qualitative'],
    min_keyword_count=5,
    has_case_patterns=True,
    date_from='2024-01-01',
    keyword_search='malignancy'
)
```

#### `refresh_export_table()`
```python
# Refresh materialized view
stats = exporter.refresh_export_table()
print(f"Refreshed {stats['total_rows']} rows in {stats['refresh_duration']}")
```

#### `export_to_csv(output_path, data=None, use_export_table=True, filters=None)`
```python
# Export to CSV
exporter.export_to_csv(
    './exports/data.csv',
    use_export_table=True  # Fast pre-computed data
)

# Export with filters
exporter.export_to_csv(
    './exports/qualitative.csv',
    filters={'segment_type': 'qualitative'}
)
```

#### `export_to_json(output_path, data=None, use_export_table=True, filters=None, pretty=True)`
```python
# Pretty JSON
exporter.export_to_json('./exports/data.json', pretty=True)

# Compact JSON
exporter.export_to_json('./exports/data.json', pretty=False)
```

#### `export_by_file_type(file_type, output_dir='./exports')`
```python
# Export all XML data (CSV + JSON)
exporter.export_by_file_type('xml')
```

#### `export_high_relevance_keywords(min_relevance=5.0, output_dir='./exports')`
```python
# Export high-value keywords
exporter.export_high_relevance_keywords(min_relevance=10.0)
```

#### `get_summary_stats()` / `print_summary()`
```python
# Get stats as dict
stats = exporter.get_summary_stats()

# Print formatted summary
exporter.print_summary()
```

---

##  Common Workflows

### 1. Export All Data for Excel Analysis
```python
from src.maps.analysis_exporter import AnalysisExporter

exporter = AnalysisExporter()

# Refresh materialized view for latest data
exporter.refresh_export_table()

# Export to CSV (opens in Excel)
exporter.export_to_csv('./exports/complete_dataset.csv', use_export_table=True)
```

### 2. Filter and Export by File Type
```python
# Export all XML files
exporter.export_by_file_type('xml', output_dir='./exports/xml')

# Export all PDFs
exporter.export_by_file_type('pdf', output_dir='./exports/pdf')
```

### 3. Find High-Value Content
```python
# Find segments with many keywords and case patterns
high_value = exporter.filter_by_criteria(
    min_keyword_count=10,
    has_case_patterns=True
)

exporter.export_to_json('./exports/high_value_segments.json', data=high_value)
```

### 4. Export Recent Imports
```python
from datetime import datetime, timedelta

# Last 7 days
week_ago = (datetime.now() - timedelta(days=7)).isoformat()
recent = exporter.filter_by_criteria(date_from=week_ago)

exporter.export_to_csv('./exports/recent_imports.csv', data=recent)
```

### 5. Search and Export by Keyword
```python
# Find all content mentioning "malignancy"
malignancy_data = exporter.filter_by_criteria(
    keyword_search='malignancy'
)

exporter.export_to_csv('./exports/malignancy_cases.csv', data=malignancy_data)
```

### 6. Generate Analysis Report
```python
exporter = AnalysisExporter()

# Print summary
exporter.print_summary()

# Export by type
exporter.export_by_file_type('xml')

# Export high-relevance keywords
exporter.export_high_relevance_keywords(min_relevance=8.0)

print(" Analysis report complete - check ./exports directory")
```

---

##  Quick Reference

### Fastest Queries
```sql
-- Use export_ready_table for speed
SELECT * FROM export_ready_table LIMIT 1000;
```

### Most Flexible Queries
```sql
-- Use master_analysis_table for filtering
SELECT * FROM master_analysis_table
WHERE keyword_count >= 5 AND segment_type = 'qualitative';
```

### Most Accurate Queries
```sql
-- Refresh materialized view first
SELECT * FROM refresh_export_table();
SELECT * FROM export_ready_table;
```

### Best for Python Export
```python
# Fast: uses export_ready_table
exporter.export_to_csv('./data.csv', use_export_table=True)

# Flexible: uses master_analysis_table
exporter.export_to_csv('./data.csv', use_export_table=False, filters={'segment_type': 'qualitative'})
```

---

##  Refresh Strategy

### When to Refresh `export_ready_table`

**Refresh after**:
- Importing new files
- Extracting keywords
- Detecting case patterns
- Any bulk data changes

**How to refresh**:
```python
# Python
exporter.refresh_export_table()

# SQL
SELECT * FROM refresh_export_table();
```

**Performance**: Materialized views are MUCH faster for large datasets (10x-100x)

---

##  Example: Complete Analysis Pipeline

```python
from src.maps.analysis_exporter import AnalysisExporter

# Initialize
exporter = AnalysisExporter()

print("="*60)
print("ANALYSIS PIPELINE")
print("="*60)

# 1. Print current stats
print("\n1. Current Statistics:")
exporter.print_summary()

# 2. Refresh export table
print("\n2. Refreshing export table...")
stats = exporter.refresh_export_table()
print(f"   Refreshed {stats['total_rows']} rows in {stats['refresh_duration']}")

# 3. Export all data
print("\n3. Exporting all data...")
exporter.export_to_csv('./exports/all_data.csv')
exporter.export_to_json('./exports/all_data.json')

# 4. Export by content type
print("\n4. Exporting by content type...")
for seg_type in ['quantitative', 'qualitative', 'mixed']:
    data = exporter.filter_by_criteria(segment_types=[seg_type])
    if data:
        exporter.export_to_csv(f'./exports/{seg_type}_segments.csv', data=data)

# 5. Export high-relevance keywords
print("\n5. Exporting high-relevance keywords...")
exporter.export_high_relevance_keywords(min_relevance=5.0)

# 6. Export cross-validated patterns
print("\n6. Exporting case patterns...")
# Direct SQL query for patterns
response = exporter.supabase.table('case_patterns').select('*').eq('cross_type_validated', True).execute()
if response.data:
    exporter.export_to_json('./exports/validated_patterns.json', data=response.data)

print("\n Analysis pipeline complete!")
print("   Check ./exports directory for all files")
```

---

##  Next Steps

After deploying views:

1. **Run `migrations/003_analysis_views.sql` in Supabase SQL Editor**
   - URL: https://supabase.com/dashboard/project/lfzijlkdmnnrttsatrtc/sql/new
   
2. **Import LIDC data**:
   ```bash
   python3 scripts/pylidc_bridge_cli.py
   ```

3. **Refresh export table**:
   ```python
   from src.maps.analysis_exporter import AnalysisExporter
   exporter = AnalysisExporter()
   exporter.refresh_export_table()
   ```

4. **Export and analyze**:
   ```python
   exporter.export_to_csv('./exports/lidc_data.csv')
   exporter.print_summary()
   ```

---

##  Additional Resources

- **Schema Documentation**: `migrations/002_unified_case_identifier_schema.sql`
- **Python API**: `src/maps/analysis_exporter.py`
- **Case Identifier System**: `docs/CASE_IDENTIFIER_README.md`
- **PyLIDC Bridge**: `docs/PYLIDC_SUPABASE_BRIDGE.md`
