# MAPS Performance Optimization Guide

Performance tips and best practices for MAPS system.

## Parsing Performance

### Batch Processing

Process multiple files efficiently:

```python
from maps import parse_multiple

# Use batch_size to control memory usage
results = parse_multiple(
    xml_files,
    batch_size=100,  # Process 100 files at a time
    progress_callback=lambda i, total: print(f"{i}/{total}")
)
```

### Streaming Large Files

For very large XML files:

```python
import xml.etree.ElementTree as ET

# Use iterparse for streaming
for event, elem in ET.iterparse('large_file.xml', events=('start', 'end')):
    if elem.tag == 'Nodule':
        # Process nodule
        elem.clear()  # Clear element to save memory
```

## Profile System Performance

### Profile Caching

Profiles are cached automatically:

```python
from maps.profile_manager import get_profile_manager

# First load - reads from disk
manager = get_profile_manager()
profile1 = manager.load_profile("lidc_idri_standard")

# Subsequent loads - from cache
profile2 = manager.load_profile("lidc_idri_standard")  # Fast!
```

### Profile Validation

Validate profiles once:

```python
# Validate before batch processing
is_valid, errors = manager.validate_profile(profile)
if is_valid:
    # Process all files with confidence
    for xml_file in files:
        parser.parse(xml_file)
```

## Keyword Extraction Performance

### Normalization Caching

The KeywordNormalizer caches results:

```python
from maps import KeywordNormalizer

normalizer = KeywordNormalizer()

# First call - computes normalization
result1 = normalizer.normalize("GGO")

# Second call - cached
result2 = normalizer.normalize("GGO")  # Instant!
```

### Batch Keyword Extraction

Extract keywords in bulk:

```python
from maps import KeywordSearchEngine

search_engine = KeywordSearchEngine(normalizer)

# Process all keywords at once
keywords = ["lung", "nodule", "opacity"]
for keyword in keywords:
    search_engine.add_keyword(keyword)

# Single search operation
results = search_engine.search_all()
```

## API Performance

### Response Caching

Enable caching for frequently accessed endpoints:

```python
from maps.api.cache import cache_response

@router.get("/profiles")
@cache_response(ttl=600)  # Cache for 10 minutes
async def list_profiles():
    # Expensive operation cached
    return manager.list_profiles()
```

### Concurrent Requests

Use async processing:

```python
import asyncio

# Process multiple files concurrently
tasks = [parse_xml_async(file) for file in files]
results = await asyncio.gather(*tasks)
```

### File Upload Limits

Configure upload size limits to prevent memory issues:

```python
# In .env
MAPS_MAX_UPLOAD_SIZE=104857600  # 100MB

# Streaming uploads for large files
@router.post("/upload")
async def upload_large_file(file: UploadFile):
    async with aiofiles.open(f"uploads/{file.filename}", 'wb') as f:
        while chunk := await file.read(1024 * 1024):  # 1MB chunks
            await f.write(chunk)
```

## Database Performance

### Batch Inserts

Insert multiple documents efficiently:

```python
from maps.database import RadiologyDatabase

db = RadiologyDatabase()

# Batch insert instead of individual inserts
documents = [doc1, doc2, doc3, ...]
db.insert_batch(documents)  # Much faster!
```

### Index Optimization

Create indexes for frequently queried fields:

```sql
-- PostgreSQL
CREATE INDEX idx_study_uid ON documents(study_instance_uid);
CREATE INDEX idx_parse_case ON documents(parse_case);
CREATE INDEX idx_created_at ON documents(created_at);
```

### Connection Pooling

Use connection pooling for concurrent requests:

```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20
)
```

## Memory Optimization

### Clear References

Free memory after processing:

```python
import gc

for xml_file in large_file_list:
    result = parse_radiology_sample(xml_file)
    # Process result
    del result
    gc.collect()  # Force garbage collection
```

### Generator Functions

Use generators for large datasets:

```python
def process_files_generator(files):
    for file in files:
        yield parse_radiology_sample(file)

# Memory-efficient iteration
for result in process_files_generator(large_file_list):
    # Process one at a time
    handle_result(result)
```

## Profiling Tools

### Time Profiling

```python
import cProfile
import pstats

# Profile parsing operation
profiler = cProfile.Profile()
profiler.enable()

parse_radiology_sample('data/sample.xml')

profiler.disable()
stats = pstats.Stats(profiler)
stats.sort_stats('cumulative')
stats.print_stats(20)  # Top 20 slowest functions
```

### Memory Profiling

```python
from memory_profiler import profile

@profile
def batch_parse(files):
    return parse_multiple(files)

batch_parse(xml_files)
```

## Benchmarks

Typical performance on standard hardware (Intel i7, 16GB RAM):

| Operation | Files | Time | Throughput |
|-----------|-------|------|------------|
| Single XML Parse | 1 | 50ms | 20 files/sec |
| Batch Parse | 100 | 3.5s | 28 files/sec |
| Batch Parse | 1000 | 32s | 31 files/sec |
| Keyword Extraction (PDF) | 1 | 1.2s | - |
| Auto-Analysis | 1 | 180ms | 5.5 files/sec |
| Excel Export | 100 rows | 200ms | - |

## Optimization Checklist

- [ ] Use batch processing for multiple files
- [ ] Enable profile caching
- [ ] Configure appropriate batch sizes for memory
- [ ] Use database indexes for queries
- [ ] Enable API response caching
- [ ] Set reasonable file upload limits
- [ ] Use streaming for large files
- [ ] Clear references after processing
- [ ] Monitor memory usage with profilers
- [ ] Use connection pooling for databases
