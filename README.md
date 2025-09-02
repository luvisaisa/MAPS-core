# MAPS - Medical Annotation Processing System

XML parser for medical imaging annotation data.

## Installation

```bash
pip install -r requirements.txt
```

## Usage

```python
from src.maps.parser import parse_radiology_sample

# Parse single file
main_df, unblinded_df = parse_radiology_sample('data/sample.xml')

# Export to Excel
from src.maps.parser import export_excel
export_excel(main_df, 'output.xlsx')
```

## Features

- Parse medical imaging XML files
- Extract header, nodule, ROI, and characteristic data
- Export to Excel
- Batch processing support
