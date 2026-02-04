# MAPS Troubleshooting Guide

Common issues and solutions.

## Installation Issues

### Issue: Import Error for maps module

```
ModuleNotFoundError: No module named 'maps'
```

**Solution:**
```bash
# Install in editable mode
pip install -e .

# Or add to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/path/to/MAPS-core/src"
```

## Parsing Issues

### Issue: Namespace errors in XML

```
KeyError: '{http://www.cancer.gov/LIDC}ResponseHeader'
```

**Solution:**
The parser handles namespaces automatically. If you see this error:

```python
# Check your parse case detection
from maps import detect_parse_case
parse_case = detect_parse_case(xml_root)
print(f"Detected: {parse_case}")
```

### Issue: Empty DataFrame returned

**Possible causes:**
1. Wrong parse case detected
2. XML structure doesn't match profile
3. Required fields missing

**Solution:**
```python
# Enable detailed logging
import logging
logging.basicConfig(level=logging.DEBUG)

# Check structure
from maps import analyze_xml_structure
structure = analyze_xml_structure('file.xml')
print(structure)
```

## Profile System Issues

### Issue: Profile not found

```
ValueError: Profile 'my_profile' not found
```

**Solution:**
```python
# List available profiles
from maps.profile_manager import get_profile_manager
manager = get_profile_manager()
profiles = manager.list_profiles()
for p in profiles:
    print(p.profile_name)
```

### Issue: Profile validation fails

**Solution:**
```python
# Check validation errors
is_valid, errors = manager.validate_profile(profile)
if not is_valid:
    for error in errors:
        print(f"Error: {error}")
```

## Keyword Extraction Issues

### Issue: PDF extraction returns empty results

**Possible causes:**
1. PDF is image-based (scanned)
2. PDF is encrypted
3. Text encoding issues

**Solution:**
```python
from maps import PDFKeywordExtractor

extractor = PDFKeywordExtractor()
try:
    metadata, keywords = extractor.extract_from_pdf('paper.pdf')
    print(f"Pages: {metadata.page_count}")
    print(f"Keywords found: {len(keywords)}")
except Exception as e:
    print(f"Error: {e}")
```

## API Issues

### Issue: Server won't start

```
OSError: [Errno 48] Address already in use
```

**Solution:**
```bash
# Check what's using port 8000
lsof -i :8000

# Kill the process
kill -9 <PID>

# Or use different port
python scripts/run_server.py --port 8001
```

### Issue: File upload fails

```
413 Request Entity Too Large
```

**Solution:**
Update configuration:

```bash
# In .env
MAPS_MAX_UPLOAD_SIZE=209715200  # 200MB
```

### Issue: CORS errors

```
Access to XMLHttpRequest has been blocked by CORS policy
```

**Solution:**
```bash
# In .env
MAPS_CORS_ORIGINS=["http://localhost:3000", "https://yourdomain.com"]
```

## Performance Issues

### Issue: Slow batch processing

**Solution:**
```python
# Reduce batch size
results = parse_multiple(files, batch_size=50)  # Instead of 1000

# Or process in parallel (if you have multiple cores)
import multiprocessing
pool = multiprocessing.Pool(processes=4)
results = pool.map(parse_radiology_sample, files)
```

### Issue: High memory usage

**Solution:**
```python
import gc

# Process in smaller batches with cleanup
for batch in chunk_list(files, 100):
    results = parse_multiple(batch)
    # Process results
    del results
    gc.collect()
```

## Database Issues

### Issue: Database connection fails

```
sqlalchemy.exc.OperationalError: could not connect to server
```

**Solution:**
```bash
# Check database is running
pg_isready -h localhost -p 5432

# Test connection
psql -h localhost -U maps_user -d maps_db
```

### Issue: Slow queries

**Solution:**
```sql
-- Add indexes
CREATE INDEX idx_study_uid ON documents(study_instance_uid);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM documents WHERE study_instance_uid = '...';
```

## Testing Issues

### Issue: Tests fail with import errors

**Solution:**
```bash
# Install test dependencies
pip install pytest pytest-cov

# Run from project root
cd /path/to/MAPS-core
pytest
```

## General Tips

### Enable Debug Logging

```python
import logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
```

### Verify Installation

```python
import maps
print(f"MAPS version: {maps.__version__}")

# Test basic functionality
from maps import parse_radiology_sample
# Should not raise ImportError
```

### Get Help

1. Check documentation in `docs/`
2. Review examples in `examples/`
3. Check issue tracker on GitHub
4. Enable debug logging for detailed error messages
