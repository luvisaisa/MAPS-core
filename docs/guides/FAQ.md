# Frequently Asked Questions (FAQ)

## General Questions

### What is MAPS?

MAPS (Medical Annotation Processing System) is a Python-based tool for parsing and processing medical imaging annotation data, particularly from radiology XML files. It supports multiple formats, profile-based parsing, keyword extraction, and provides both CLI and REST API interfaces.

### What file formats does MAPS support?

- XML files (various radiology formats)
- LIDC-IDRI XML format
- PDF files (for keyword extraction)
- Custom XML formats via profile system

### Is MAPS free to use?

Yes, MAPS is open source under the MIT License. You can use it freely for commercial and non-commercial purposes.

### What Python versions are supported?

MAPS requires Python 3.8 or higher. Tested on Python 3.8, 3.9, 3.10, 3.11, and 3.12.

## Installation & Setup

### How do I install MAPS?

```bash
git clone https://github.com/luvisaisa/MAPS-core.git
cd MAPS-core
pip install -r requirements.txt
pip install -e .
```

### Do I need a database?

No, database integration is optional. MAPS works with file-based processing by default. PostgreSQL integration is available if needed.

### Can I use MAPS without the GUI?

Yes, you can use MAPS via:
- Python API (import maps)
- Command-line scripts
- REST API endpoints
- Batch processing scripts

## Parsing Questions

### How do I know which profile to use?

The system can auto-detect parse cases for known formats. For custom formats, create a profile that maps your XML structure to the canonical schema.

### What if my XML format isn't supported?

Create a custom profile:
1. Analyze your XML structure
2. Create profile JSON mapping your fields to canonical schema
3. Validate with ProfileManager
4. Use with XMLParser

### Can I parse multiple files at once?

Yes:
```python
from maps import parse_multiple

results = parse_multiple(xml_files, batch_size=100)
```

### How do I handle parsing errors?

Enable debug logging to see detailed error messages:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Profile System

### What is a profile?

A profile defines how to map source data fields to the canonical schema. It includes field mappings, data types, transformations, and validation rules.

### Can I modify existing profiles?

Yes, profiles are JSON files in the `profiles/` directory. You can edit them or create new ones based on existing profiles.

### How do I validate a profile?

```python
from maps.profile_manager import get_profile_manager

manager = get_profile_manager()
profile = manager.load_profile("my_profile")
is_valid, errors = manager.validate_profile(profile)
```

## Keyword Extraction

### How accurate is keyword extraction?

Keyword extraction uses medical terminology normalization and synonym mapping. Accuracy depends on:
- Quality of medical terms dictionary
- Text formatting in source documents
- Proper medical terminology usage

### Can I add custom medical terms?

Yes, edit `data/medical_terms.json` to add:
- Synonyms
- Abbreviations
- Multi-word terms
- Custom stopwords

### Does it work with non-English text?

Currently optimized for English medical terminology. Multi-language support could be added via custom medical terms dictionaries.

## REST API

### How do I start the API server?

```bash
python scripts/run_server.py
```

Or:
```bash
uvicorn maps.api.app:create_app --factory --port 8000
```

### Is the API secure?

The API includes basic security features:
- CORS configuration
- File size limits
- Input validation
- Error handling

For production, add:
- Authentication/authorization
- Rate limiting
- HTTPS
- API keys

### Can I use the API from JavaScript?

Yes:
```javascript
// Parse XML file
const formData = new FormData();
formData.append('file', xmlFile);

const response = await fetch('http://localhost:8000/api/parse/parse/xml', {
  method: 'POST',
  body: formData
});

const result = await response.json();
```

## Performance

### How fast is parsing?

Typical performance:
- Single XML file: 50-200ms
- Batch of 100 files: 3-5 seconds
- Batch of 1000 files: 30-40 seconds

Performance varies with:
- File size
- XML complexity
- System resources

### How can I improve performance?

- Use batch processing
- Enable profile caching
- Reduce batch size if memory-constrained
- Use multiprocessing for very large datasets
- See `docs/PERFORMANCE.md` for details

### Does it support parallel processing?

Yes, you can use Python's multiprocessing:
```python
from multiprocessing import Pool

pool = Pool(processes=4)
results = pool.map(parse_radiology_sample, xml_files)
```

## Data Output

### What output formats are supported?

- Pandas DataFrames
- Excel files (.xlsx)
- CSV files
- JSON
- PostgreSQL database
- SQLite database

### Can I customize Excel output?

Yes, specify format type:
```python
export_excel(df, 'output.xlsx', format='template')
# Options: 'standard', 'template', 'multi-folder'
```

### How do I export to database?

```python
from maps.database import RadiologyDatabase

db = RadiologyDatabase('output.db')
db.insert_batch(parsed_data)
```

## Troubleshooting

### GUI won't launch

Check tkinter installation:
```bash
# Ubuntu/Debian
sudo apt-get install python3-tk

# Test import
python3 -c "import tkinter"
```

### Import errors

Ensure MAPS is installed:
```bash
pip install -e .

# Or set PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/path/to/MAPS-core/src"
```

### Parsing returns empty results

Check:
1. XML structure matches expected format
2. Correct profile selected
3. Required fields present
4. Enable debug logging for details

See `docs/TROUBLESHOOTING.md` for more solutions.

## Contributing

### How can I contribute?

See `docs/CONTRIBUTING.md` for guidelines on:
- Code contributions
- Bug reports
- Feature requests
- Documentation improvements

### Where do I report bugs?

Report issues on GitHub: https://github.com/luvisaisa/MAPS-core/issues

Include:
- MAPS version
- Python version
- Error messages
- Steps to reproduce

## Support

### Where can I get help?

1. Check documentation in `docs/`
2. Review examples in `examples/`
3. Search existing GitHub issues
4. Create new issue on GitHub

### Is commercial support available?

Currently, MAPS is community-supported. For specific needs, contact the maintainers.
