# MAPS - Medical Annotation Processing System

XML parser for medical imaging annotation data with automatic schema detection.

## Features

- Automatic parse case detection (7 supported formats)
- Multi-format XML parsing (standard + LIDC-IDRI)
- Nodule characteristic extraction
- ROI coordinate mapping
- Excel export
- Batch processing

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### Basic Parsing

```python
from src.maps.parser import parse_radiology_sample

# Parse single file (automatic format detection)
main_df, unblinded_df = parse_radiology_sample('data/sample.xml')
```

### Batch Processing

```python
from src.maps.parser import parse_multiple

# Parse multiple files
xml_files = ['file1.xml', 'file2.xml', 'file3.xml']
main_dfs, unblinded_dfs = parse_multiple(xml_files)
```

### Parse Case Detection

```python
from src.maps.parser import detect_parse_case

# Detect XML format
case = detect_parse_case('data/sample.xml')
print(f"Format: {case}")
# Output: Complete_Attributes, LIDC_Multi_Session_4, etc.
```

## Supported Parse Cases

- **Complete_Attributes**: Full annotation data
- **Core_Attributes_Only**: Essential fields
- **With_Reason_Partial**: Minimal data
- **LIDC_Single_Session**: LIDC with one reader
- **LIDC_Multi_Session_X**: LIDC with 2-4 readers

See [docs/PARSE_CASES.md](docs/PARSE_CASES.md) for details.

## Examples

See `examples/` directory for usage examples.
