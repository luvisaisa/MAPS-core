# MAPS Quick Start Guide

Get started with MAPS in 5 minutes.

## Installation

```bash
git clone https://github.com/luvisaisa/MAPS-core.git
cd MAPS-core
pip install -r requirements.txt
pip install -e .
```

## Parse Your First XML File

```python
from maps import parse_radiology_sample

# Parse single file
main_df, unblinded_df = parse_radiology_sample('data/sample.xml')
print(f"Parsed {len(main_df)} records")
```

## Use the REST API

```bash
# Start server
python scripts/run_server.py

# Test in browser
open http://localhost:8000/docs
```

## Next Steps

- Read full documentation in `docs/`
- Try examples in `examples/`
- Create custom profiles for your XML format
