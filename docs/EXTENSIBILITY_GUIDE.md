# MAPS Extensibility Guide

This guide explains how to extend the MAPS system with new parsers, extractors, detectors, and data formats.

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Adding New File Format Support](#adding-new-file-format-support)
3. [Creating Custom Extractors](#creating-custom-extractors)
4. [Implementing Structure Detectors](#implementing-structure-detectors)
5. [Parser Interface](#parser-interface)
6. [Profile System Integration](#profile-system-integration)
7. [Testing Extensions](#testing-extensions)

---

## Architecture Overview

The MAPS system uses a **factory-based architecture** with separation of concerns:

```

              Parse Request                      

                 
                 

         Structure Detector                      
   (identifies schema/parse case)                

                 
                 

           Extractor Factory                     
    (selects appropriate extractor)              

                 
                 

         Format-Specific Extractor               
   (XMLExtractor, PDFExtractor, etc.)            

                 
                 

              Parser                             
   (transforms to standard schema)               

```

---

## Adding New File Format Support

### Step 1: Create Extractor Class

Create a new extractor in `src/maps/extractors/`:

```python
# src/maps/extractors/json_extractor.py
from .base import BaseExtractor
from typing import Dict, Any
import json

class JSONExtractor(BaseExtractor):
    """Extract data from JSON files"""
    
    def extract(self, file_path: str, profile: Any = None) -> Dict[str, Any]:
        """
        Extract data from JSON file.
        
        Args:
            file_path: Path to JSON file
            profile: Optional profile for custom extraction rules
            
        Returns:
            Dictionary with extracted data
        """
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        return {
            'format': 'JSON',
            'data': data,
            'metadata': {
                'keys': list(data.keys()) if isinstance(data, dict) else [],
                'type': type(data).__name__
            }
        }
    
    def validate(self, data: Dict[str, Any]) -> bool:
        """Validate extracted data"""
        return 'data' in data and data.get('format') == 'JSON'
```

### Step 2: Register in Factory

Update `src/maps/extractors/factory.py`:

```python
from .json_extractor import JSONExtractor

class ExtractorFactory:
    _extractors = {
        'xml': XMLExtractor,
        'pdf': PDFExtractor,
        'json': JSONExtractor,  # Add new extractor
        'csv': CSVExtractor,
    }
    
    @classmethod
    def register_extractor(cls, format_name: str, extractor_class):
        """Register custom extractor"""
        cls._extractors[format_name.lower()] = extractor_class
```

### Step 3: Update Router

Add endpoint in `src/maps/api/routers/parse.py`:

```python
@router.post("/json", response_model=ParseResponse)
async def parse_json(
    file: UploadFile = File(...),
    profile: Optional[str] = None,
    extract_keywords: bool = True,
    db: Session = Depends(get_db)
):
    """Parse JSON file"""
    service = ParseService(db)
    
    content = await file.read()
    result = await service.parse_file(
        content,
        file.filename,
        file_type='json',
        profile=profile,
        extract_keywords=extract_keywords
    )
    return result
```

---

## Creating Custom Extractors

### BaseExtractor Interface

All extractors must inherit from `BaseExtractor`:

```python
from abc import ABC, abstractmethod
from typing import Dict, Any

class BaseExtractor(ABC):
    """Base class for data extractors"""
    
    @abstractmethod
    def extract(self, file_path: str, profile: Any = None) -> Dict[str, Any]:
        """
        Extract data from file.
        
        Returns:
            Dictionary containing:
            - 'format': str - File format identifier
            - 'data': Any - Extracted data
            - 'metadata': Dict - Additional information
        """
        pass
    
    @abstractmethod
    def validate(self, data: Dict[str, Any]) -> bool:
        """
        Validate extracted data structure.
        
        Returns:
            True if data is valid, False otherwise
        """
        pass
```

### Example: CSV Extractor

```python
import csv
from .base import BaseExtractor

class CSVExtractor(BaseExtractor):
    def extract(self, file_path: str, profile: Any = None) -> Dict[str, Any]:
        rows = []
        headers = []
        
        with open(file_path, 'r') as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames
            rows = list(reader)
        
        return {
            'format': 'CSV',
            'data': rows,
            'metadata': {
                'headers': headers,
                'row_count': len(rows),
                'column_count': len(headers)
            }
        }
    
    def validate(self, data: Dict[str, Any]) -> bool:
        return (
            data.get('format') == 'CSV' and
            'data' in data and
            isinstance(data['data'], list)
        )
```

---

## Implementing Structure Detectors

Detectors identify the schema or "parse case" of a file.

### BaseDetector Interface

```python
from abc import ABC, abstractmethod
from typing import Optional, Dict

class BaseDetector(ABC):
    @abstractmethod
    def detect(self, file_path: str) -> Optional[str]:
        """
        Detect structure/parse case of file.
        
        Returns:
            Parse case identifier (e.g., 'LIDC_STANDARD', 'CUSTOM_v2')
            or None if unable to detect
        """
        pass
    
    @abstractmethod
    def get_confidence(self) -> float:
        """
        Return confidence score (0.0 to 1.0)
        """
        pass
```

### Example: XML Structure Detector

```python
import xml.etree.ElementTree as ET
from .base import BaseDetector

class XMLStructureDetector(BaseDetector):
    def __init__(self):
        self.confidence = 0.0
        
    def detect(self, file_path: str) -> Optional[str]:
        try:
            tree = ET.parse(file_path)
            root = tree.getroot()
            
            # Check for LIDC-IDRI format
            if root.tag == 'LidcReadMessage':
                self.confidence = 0.95
                return 'LIDC_STANDARD'
            
            # Check for custom format
            elif root.tag == 'MedicalImageAnnotation':
                if root.find('.//StudyInstanceUID') is not None:
                    self.confidence = 0.85
                    return 'CUSTOM_v1'
            
            # Unknown structure
            self.confidence = 0.3
            return 'UNKNOWN_XML'
            
        except Exception as e:
            self.confidence = 0.0
            return None
    
    def get_confidence(self) -> float:
        return self.confidence
```

---

## Parser Interface

Parsers transform extracted data into the standardized schema.

### Example: JSON Parser

```python
from typing import Dict, Any
from ..parsers.base import BaseParser

class JSONParser(BaseParser):
    def parse(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Transform JSON data to standard schema.
        
        Expected input from JSONExtractor:
        {
            'format': 'JSON',
            'data': {...},
            'metadata': {...}
        }
        
        Returns standardized schema:
        {
            'document_id': str,
            'source_file': str,
            'parse_case': str,
            'extracted_data': {...},
            'confidence_score': float
        }
        """
        json_data = data.get('data', {})
        
        return {
            'document_id': json_data.get('id', 'unknown'),
            'source_file': data.get('source_file', 'unknown.json'),
            'parse_case': 'JSON_STANDARD',
            'extracted_data': json_data,
            'confidence_score': 0.9,  # High confidence for valid JSON
            'metadata': data.get('metadata', {})
        }
```

---

## Profile System Integration

Profiles define how to map source fields to target schema.

### Creating a Profile

```python
from src.maps.schemas.profile import Profile, FieldMapping

profile = Profile(
    profile_name="custom_json_profile",
    file_type="JSON",
    description="Parse custom JSON medical records",
    mappings=[
        FieldMapping(
            source_path="$.patient.id",  # JSONPath
            target_path="patient_id",
            required=True
        ),
        FieldMapping(
            source_path="$.study.date",
            target_path="study_date",
            required=False,
            transformation="date_format"
        )
    ],
    validation_rules={
        "min_confidence": 0.7,
        "required_fields": ["patient_id"]
    }
)
```

### Using Profile in Extractor

```python
class JSONExtractor(BaseExtractor):
    def extract(self, file_path: str, profile: Profile = None) -> Dict[str, Any]:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        if profile:
            # Apply profile mappings
            mapped_data = {}
            for mapping in profile.mappings:
                value = self._get_value_by_path(data, mapping.source_path)
                if mapping.transformation:
                    value = self._apply_transformation(value, mapping.transformation)
                mapped_data[mapping.target_path] = value
            
            data = mapped_data
        
        return {
            'format': 'JSON',
            'data': data,
            'profile_applied': profile.profile_name if profile else None
        }
```

---

## Testing Extensions

### Unit Tests

Create tests in `tests/extractors/test_json_extractor.py`:

```python
import pytest
from src.maps.extractors.json_extractor import JSONExtractor

def test_json_extraction():
    extractor = JSONExtractor()
    result = extractor.extract('tests/fixtures/sample.json')
    
    assert result['format'] == 'JSON'
    assert 'data' in result
    assert extractor.validate(result)

def test_invalid_json():
    extractor = JSONExtractor()
    with pytest.raises(json.JSONDecodeError):
        extractor.extract('tests/fixtures/invalid.json')
```

### Integration Tests

Test end-to-end flow in `tests/integration/test_json_parse.py`:

```python
from fastapi.testclient import TestClient
from src.maps.api.main import app

client = TestClient(app)

def test_parse_json_endpoint():
    with open('tests/fixtures/sample.json', 'rb') as f:
        response = client.post(
            '/api/v1/parse/json',
            files={'file': ('sample.json', f, 'application/json')}
        )
    
    assert response.status_code == 200
    data = response.json()
    assert data['status'] == 'success'
    assert 'document_id' in data
```

---

## Validation & Approval Queue

### Low-Confidence Detection

If a parser returns confidence < profile threshold, it goes to approval queue:

```python
def parse_file(self, content: bytes, filename: str, profile: Profile):
    # Extract and parse
    data = extractor.extract(file_path, profile)
    result = parser.parse(data)
    
    # Check confidence threshold
    if result['confidence_score'] < profile.validation_rules.get('min_confidence', 0.7):
        # Add to approval queue
        self.add_to_approval_queue(result, reason='low_confidence')
        return {
            'status': 'pending_approval',
            'confidence': result['confidence_score'],
            'queue_id': queue_entry.id
        }
    
    # High confidence - process normally
    return {
        'status': 'success',
        'confidence': result['confidence_score'],
        'data': result
    }
```

---

## Best Practices

### 1. Error Handling
```python
def extract(self, file_path: str, profile: Any = None) -> Dict[str, Any]:
    try:
        # Extraction logic
        pass
    except FileNotFoundError:
        raise ExtractorError(f"File not found: {file_path}")
    except Exception as e:
        raise ExtractorError(f"Extraction failed: {str(e)}")
```

### 2. Logging
```python
import logging
logger = logging.getLogger(__name__)

def extract(self, file_path: str, profile: Any = None):
    logger.info(f"Extracting data from {file_path}")
    # ... extraction logic
    logger.debug(f"Extracted {len(data)} records")
```

### 3. Performance
```python
# Cache expensive operations
from functools import lru_cache

@lru_cache(maxsize=100)
def _load_schema(self, schema_name: str):
    # Load and cache schema definitions
    pass
```

### 4. Validation
```python
from pydantic import BaseModel, validator

class ExtractedData(BaseModel):
    format: str
    data: dict
    metadata: dict
    
    @validator('format')
    def format_must_be_uppercase(cls, v):
        return v.upper()
```

---

## Complete Example: Adding DICOM Support

### 1. Create Extractor
```python
# src/maps/extractors/dicom_extractor.py
import pydicom
from .base import BaseExtractor

class DICOMExtractor(BaseExtractor):
    def extract(self, file_path: str, profile=None) -> dict:
        ds = pydicom.dcmread(file_path)
        
        return {
            'format': 'DICOM',
            'data': {
                'patient_id': str(ds.PatientID),
                'study_uid': str(ds.StudyInstanceUID),
                'series_uid': str(ds.SeriesInstanceUID),
                'modality': str(ds.Modality)
            },
            'metadata': {
                'manufacturer': str(ds.get('Manufacturer', '')),
                'rows': int(ds.Rows),
                'columns': int(ds.Columns)
            }
        }
    
    def validate(self, data: dict) -> bool:
        return data.get('format') == 'DICOM' and 'patient_id' in data['data']
```

### 2. Register
```python
# src/maps/extractors/factory.py
from .dicom_extractor import DICOMExtractor

ExtractorFactory.register_extractor('dicom', DICOMExtractor)
```

### 3. Add Endpoint
```python
# src/maps/api/routers/parse.py
@router.post("/dicom")
async def parse_dicom(file: UploadFile = File(...), db: Session = Depends(get_db)):
    service = ParseService(db)
    content = await file.read()
    return await service.parse_file(content, file.filename, file_type='dicom')
```

### 4. Test
```python
# tests/extractors/test_dicom_extractor.py
def test_dicom_extraction():
    extractor = DICOMExtractor()
    result = extractor.extract('tests/fixtures/sample.dcm')
    assert result['format'] == 'DICOM'
    assert 'patient_id' in result['data']
```

---

## Registry Pattern (Advanced)

For dynamic extension loading:

```python
# src/maps/registry.py
class ExtensionRegistry:
    _extractors = {}
    _detectors = {}
    _parsers = {}
    
    @classmethod
    def register_extractor(cls, name: str, extractor_class):
        cls._extractors[name] = extractor_class
    
    @classmethod
    def get_extractor(cls, name: str):
        return cls._extractors.get(name)
    
    @classmethod
    def list_extractors(cls):
        return list(cls._extractors.keys())

# Usage in plugins
from src.maps.registry import ExtensionRegistry

@ExtensionRegistry.register_extractor('custom_format')
class CustomExtractor(BaseExtractor):
    # Implementation
    pass
```

---

## Resources

- [BaseExtractor Source](../src/maps/extractors/base.py)
- [ExtractorFactory Source](../src/maps/extractors/factory.py)
- [Profile Schema](../src/maps/schemas/profile.py)
- [API Routers](../src/maps/api/routers/)
- [Test Fixtures](../tests/fixtures/)

---

## Support

For questions or issues with extensions:
1. Check existing extractors in `src/maps/extractors/`
2. Review test examples in `tests/`
3. Consult API documentation at `http://localhost:8000/docs`
4. Open an issue in the repository

---

**Last Updated:** November 23, 2025  
**Version:** 1.0.0
