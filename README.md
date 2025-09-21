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

## Documentation

- [GUI Guide](docs/GUI_GUIDE.md)
- [Parse Cases](docs/PARSE_CASES.md)
- [Examples](examples/)
