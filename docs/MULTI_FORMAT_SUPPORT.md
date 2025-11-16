# MAPS Multi-Format File Support

MAPS (Medical Annotation Processing System) supports multiple file formats for comprehensive medical annotation data processing.

## Supported File Formats

### 1. XML Files (.xml)
**Primary format for LIDC-IDRI annotations**

- **Parser**: `src/maps/parser.py`
- **API Endpoint**: `POST /api/v1/parse/xml`
- **Features**:
  - Full LIDC-IDRI XML parsing
  - Multiple radiologist annotations
  - Nodule characteristics extraction
  - Parse case detection (4 different structural variants)
  - Schema-agnostic normalization

**Example Usage**:
```python
from src.maps.parser import parse_radiology_sample

main_df, unblinded_df = parse_radiology_sample('annotation.xml')
```

### 2. JSON Files (.json)
**Alternative structured data format**

- **Parser**: Native JSON parsing with schema validation
- **Features**:
  - Direct canonical schema ingestion
  - JSON-formatted annotations
  - Metadata preservation

### 3. PDF Files (.pdf)
**Research papers and documentation**

- **Parser**: `src/maps/pdf_keyword_extractor.py`
- **API Endpoint**: `POST /api/v1/parse/pdf`
- **Features**:
  - Keyword extraction from research papers
  - Metadata extraction (title, authors, DOI, journal)
  - Abstract and body text analysis
  - MeSH term detection
  - Page-level keyword tracking
  - Integration with keyword normalizer

**Example Usage**:
```python
from src.maps.pdf_keyword_extractor import PDFKeywordExtractor

extractor = PDFKeywordExtractor()
metadata, keywords = extractor.extract_from_pdf('paper.pdf')
```

**Extracted Data**:
- Title, authors, journal, year, DOI
- Abstract content
- Author-provided keywords
- MeSH terms
- Body text keywords with page numbers and context

### 4. ZIP Archives (.zip)
**Batch processing of multiple files**

- **Parser**: `src/maps/api/services/parse_service.py`
- **API Endpoint**: `POST /api/v1/parse/zip`
- **Features**:
  - Automatic extraction of nested directories
  - Recursive file discovery
  - Support for mixed file types (XML, JSON, PDF)
  - Automatic filtering of supported formats
  - Bulk processing optimization

**Example Usage**:
```bash
# Upload ZIP containing multiple annotation folders
curl -X POST http://localhost:8000/api/v1/parse/zip \
  -F "file=@annotations.zip"
```

**Response Format**:
```json
{
  "status": "success",
  "zip_filename": "annotations.zip",
  "extracted_count": 150,
  "files": [
    {
      "filename": "case001.xml",
      "path": "batch1/case001.xml",
      "size": 45231,
      "type": "XML"
    },
    {
      "filename": "paper.pdf",
      "path": "docs/paper.pdf",
      "size": 2048576,
      "type": "PDF"
    }
  ],
  "processing_time_ms": 1234.5
}
```

## Web Interface Upload

### File Uploader Component
**Location**: `web/src/components/FileUploader/FileUploader.tsx`

**Features**:
- Drag & drop support for all formats
- Multiple file selection (up to 1000 files)
- Folder/directory upload with automatic filtering
- ZIP file upload and extraction
- Visual badges for file types (XML, JSON, PDF, ZIP)
- File size validation (100MB per file)
- Progress indicators for extraction

**Accepted MIME Types**:
```typescript
accept: {
  'application/xml': ['.xml'],
  'application/json': ['.json'],
  'text/xml': ['.xml'],
  'application/pdf': ['.pdf'],
  'application/zip': ['.zip'],
  'application/x-zip-compressed': ['.zip'],
}
```

### Upload Workflow

1. **Select Files**:
   - Click "Select Multiple Files" for individual files
   - Click "Select Folders" for entire directories
   - Drag & drop files or folders directly

2. **Automatic Filtering**:
   - Only XML, JSON, PDF, and ZIP files are accepted
   - Other file types are automatically filtered out
   - Warning message if no valid files found

3. **ZIP Extraction**:
   - ZIP files are automatically detected
   - Server-side extraction of contents
   - Recursive processing of nested folders
   - Only supported formats extracted

4. **Batch Processing**:
   - All files processed in single batch job
   - Real-time progress tracking via WebSocket/SSE
   - Individual file status updates
   - Error handling per file

## Backend Processing Pipeline

### Parse Service
**Location**: `src/maps/api/services/parse_service.py`

**Methods**:
- `parse_xml()` - XML annotation parsing
- `parse_pdf()` - PDF keyword extraction
- `extract_zip()` - ZIP archive extraction
- `parse_batch()` - Batch processing orchestration

### Batch Router
**Location**: `src/maps/api/routers/batch.py`

**Endpoints**:
- `POST /batch/create` - Create batch job
- `GET /batch/{job_id}` - Check job status
- `GET /batch/{job_id}/results` - Get results
- `WS /batch/jobs/{job_id}/ws` - WebSocket progress
- `GET /batch/jobs/{job_id}/progress` - SSE progress

## Database Schema

### Document Model
**Table**: `documents`

**Columns**:
```python
file_type = Column(String(10))  # XML, JSON, PDF, ZIP
file_path = Column(String(500))
file_size = Column(Integer)
content_type = Column(String(100))
parse_case = Column(String(50))  # For XML files
```

### Keyword Model
**Table**: `keywords`

**Columns**:
```python
source_type = Column(String(50))  # 'xml', 'pdf', 'research_paper'
source_file = Column(String(500))
page_number = Column(Integer, nullable=True)  # For PDFs
```

## Use Cases

### 1. LIDC-IDRI Dataset Processing
```bash
# Upload ZIP of entire LIDC dataset
# Contains nested folders with XML annotations
annotations.zip
 LIDC-IDRI-0001/
    1.3.6.1.4.1.14519.5.2.1.6279.6001.*.xml
 LIDC-IDRI-0002/
    1.3.6.1.4.1.14519.5.2.1.6279.6001.*.xml
 ...
```

### 2. Research Literature Analysis
```bash
# Upload PDFs for keyword extraction
papers.zip
 radiology_paper_2023.pdf
 lung_nodule_study.pdf
 annotation_methods.pdf
```

### 3. Mixed Format Batch
```bash
# Single ZIP with multiple formats
batch_upload.zip
 annotations/
    case001.xml
    case002.xml
 metadata/
    study_info.json
    patient_data.json
 docs/
     protocol.pdf
```

## Performance Considerations

### File Size Limits
- **Individual files**: 100MB (configurable)
- **Total batch**: 1000 files
- **ZIP archives**: No explicit limit, but extraction time increases

### Processing Times (Approximate)
- **XML parsing**: 50-200ms per file
- **PDF extraction**: 500ms-2s per file
- **ZIP extraction**: 100ms-5s depending on size
- **Batch job**: Depends on file count and types

### Optimization Tips
1. Use ZIP for large batches (reduces HTTP overhead)
2. Process XML files before PDFs (faster parsing)
3. Enable parallel processing for independent files
4. Use folder upload for organized datasets
5. Monitor WebSocket progress for large jobs

## Error Handling

### Common Errors
- **Invalid file format**: File extension not supported
- **Corrupted ZIP**: Cannot extract archive
- **File size exceeded**: Over 100MB limit
- **Parse error**: Invalid XML/JSON structure
- **PDF extraction failed**: Encrypted or damaged PDF

### Error Recovery
- Individual file failures don't stop batch
- Error details logged per file
- Partial results available for successful files
- Retry mechanism for transient failures

## API Integration Examples

### Python Client
```python
import requests

# Upload multiple file types
files = [
    ('files', open('annotation.xml', 'rb')),
    ('files', open('metadata.json', 'rb')),
    ('files', open('paper.pdf', 'rb')),
]

response = requests.post(
    'http://localhost:8000/api/v1/parse/upload',
    files=files,
    data={'profile': 'lidc_idri_standard'}
)
```

### JavaScript/TypeScript
```typescript
const files = [
  new File(['...'], 'annotation.xml'),
  new File(['...'], 'paper.pdf'),
  new File(['...'], 'batch.zip'),
];

const response = await apiClient.uploadFiles(
  files,
  'lidc_idri_standard',
  (progress) => console.log(progress)
);
```

### cURL
```bash
# Upload ZIP file
curl -X POST http://localhost:8000/api/v1/parse/zip \
  -F "file=@dataset.zip"

# Upload multiple files
curl -X POST http://localhost:8000/api/v1/parse/upload \
  -F "files=@file1.xml" \
  -F "files=@file2.pdf" \
  -F "files=@file3.json" \
  -F "profile=lidc_idri_standard"
```

## Future Enhancements

### Planned Features
- [ ] DICOM image support (.dcm)
- [ ] CSV annotation format
- [ ] Excel spreadsheet support (.xlsx)
- [ ] Word document parsing (.docx)
- [ ] TAR/GZ archive support
- [ ] Streaming ZIP extraction for large files
- [ ] Parallel extraction and parsing
- [ ] Cloud storage integration (S3, Azure Blob)

### Under Consideration
- RAR archive support
- 7-Zip support
- Encrypted ZIP handling
- Password-protected PDFs
- OCR for scanned PDFs
- Real-time streaming upload

## References

- **XML Parser**: LIDC-IDRI XML schema documentation
- **PDF Extractor**: PyPDFPlumber library
- **ZIP Handler**: Python zipfile standard library
- **API Documentation**: `/docs` endpoint (Swagger UI)
- **Schema Documentation**: `docs/SCHEMA_AGNOSTIC_SUMMARY.md`
