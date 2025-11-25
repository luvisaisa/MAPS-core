# MAPS Implementation Roadmap
**Last Updated**: November 23, 2025
**Project**: Medical Annotation Processing Suite (MAPS)

---

## EXECUTIVE SUMMARY

This document outlines the implementation roadmap for transforming MAPS into a comprehensive, ML-powered research data platform. The plan is divided into:

1. **WEEK 1** (Immediate): Core functionality + extensible architecture foundation
2. **MONTHS 2-3** (Future): Multi-format support, ML integration, research metadata

---

# PART 1: WEEK 1 IMPLEMENTATION PLAN

**Timeline**: 7 Days
**Goal**: Production-ready keyword detection, parse detection, and complete API integration with extensible architecture for future features

---

## DAY 1-2: Architecture Foundation + Keyword System

### Task 1.1: Create Abstract Base Classes

**Purpose**: Establish extensible architecture that makes adding new file formats trivial

**Files to Create**:
```
src/maps/extractors/
 __init__.py
 base.py              # BaseKeywordExtractor abstract class
 factory.py           # KeywordExtractorFactory for auto-selection
 xml_keyword_extractor.py    # Moved from root, refactored
 pdf_keyword_extractor.py    # Moved from root, refactored

src/maps/detectors/
 __init__.py
 base.py              # BaseStructureDetector abstract class
 factory.py           # DetectorFactory for auto-selection
 xml_structure_detector.py   # Refactored from structure_detector.py
```

**BaseKeywordExtractor Interface**:
```python
from abc import ABC, abstractmethod
from typing import List, Dict, Optional
from dataclasses import dataclass

@dataclass
class ExtractedKeyword:
    text: str
    category: str
    context: str
    source_field: str
    confidence: float = 1.0
    frequency: int = 1

class BaseKeywordExtractor(ABC):
    @abstractmethod
    def can_extract(self, file_path: str) -> bool:
        """Check if this extractor handles this file format"""
        pass

    @abstractmethod
    def extract_keywords(self, file_path: str,
                        extraction_config: Optional[Dict] = None) -> List[ExtractedKeyword]:
        """Extract keywords from file using format-specific logic"""
        pass

    @abstractmethod
    def get_supported_categories(self) -> List[str]:
        """Return categories this extractor can identify"""
        pass
```

**BaseStructureDetector Interface**:
```python
from abc import ABC, abstractmethod
from typing import Dict, Any

class BaseStructureDetector(ABC):
    @abstractmethod
    def can_detect(self, file_path: str) -> bool:
        """Check if this detector handles this file format"""
        pass

    @abstractmethod
    def detect_structure(self, file_path: str) -> Dict[str, Any]:
        """
        Detect document structure/parse case.

        Returns:
            {
                "parse_case": "case_name",
                "confidence": 0.95,
                "format_version": "1.0",
                "detected_fields": [...],
                "metadata": {...}
            }
        """
        pass

    @abstractmethod
    def get_structure_signature(self, file_path: str) -> str:
        """Generate unique signature for caching"""
        pass
```

**Factory Pattern**:
```python
# extractors/factory.py
class KeywordExtractorFactory:
    def __init__(self):
        from .xml_keyword_extractor import XMLKeywordExtractor
        from .pdf_keyword_extractor import PDFKeywordExtractor

        self.extractors: List[BaseKeywordExtractor] = [
            XMLKeywordExtractor(),
            PDFKeywordExtractor(),
            # Future: CSVKeywordExtractor(), JSONKeywordExtractor()
        ]

    def get_extractor(self, file_path: str) -> Optional[BaseKeywordExtractor]:
        """Auto-select appropriate extractor for file"""
        for extractor in self.extractors:
            if extractor.can_extract(file_path):
                return extractor
        return None

    def register_extractor(self, extractor: BaseKeywordExtractor):
        """Plugin system for custom extractors"""
        self.extractors.append(extractor)
```

### Task 1.2: Refactor Existing Extractors

**XML Keyword Extractor** (`extractors/xml_keyword_extractor.py`):
- Move from `src/maps/xml_keyword_extractor.py` to `src/maps/extractors/`
- Inherit from `BaseKeywordExtractor`
- Implement required methods: `can_extract()`, `extract_keywords()`, `get_supported_categories()`
- Keep all existing functionality (LIDC characteristics, anatomical terms, etc.)
- Update imports throughout codebase

**PDF Keyword Extractor** (`extractors/pdf_keyword_extractor.py`):
- Move from `src/maps/pdf_keyword_extractor.py` to `src/maps/extractors/`
- Inherit from `BaseKeywordExtractor`
- Implement required methods
- Keep approval queue functionality for candidate keywords
- Keep page tracking and context extraction

### Task 1.3: Keyword Definition Management API

**New API Endpoints** (`src/maps/api/routers/keywords.py`):

```python
@router.post("/definitions/import")
async def import_keyword_definitions(
    file: UploadFile,
    keyword_repo: KeywordRepository = Depends(get_keyword_repository)
) -> dict:
    """
    Bulk import keyword definitions from CSV.

    CSV Format:
    keyword,definition,category,source_refs,vocabulary_source
    pulmonary nodule,"A rounded opacity...",pathology,"RadLex:RID123",radlex
    """
    # Parse CSV
    # Validate fields
    # Bulk insert to canonical_keywords table
    # Return {imported: 100, failed: 5, errors: [...]}
    pass

@router.put("/{keyword_id}/definition")
async def update_keyword_definition(
    keyword_id: str,
    definition: str,
    source_refs: Optional[str] = None,
    keyword_repo: KeywordRepository = Depends(get_keyword_repository)
) -> dict:
    """Update keyword definition"""
    pass

@router.get("/{keyword_id}/citations")
async def get_keyword_citations(
    keyword_id: str,
    keyword_repo: KeywordRepository = Depends(get_keyword_repository)
) -> List[dict]:
    """Get citations for keyword definition"""
    pass

@router.post("/{keyword_id}/aliases")
async def add_keyword_alias(
    keyword_id: str,
    alias: str,
    synonym_type: str = "variant",
    keyword_repo: KeywordRepository = Depends(get_keyword_repository)
) -> dict:
    """Add synonym/alias to keyword"""
    pass
```

**Validation Rules**:
- Definition: 50-500 characters
- Category: Must be in predefined list
- Source refs: AMA citation format (optional validation)
- Vocabulary source: Must be in [radlex, snomed, mesh, umls, manual]

### Task 1.4: Test Keyword System End-to-End

**Test Cases**:
1. Upload XML file → Extract keywords → Verify in database
2. Upload PDF file → Extract keywords → Check approval queue
3. Import keyword definitions CSV → Verify canonical_keywords table
4. Update keyword definition via API → Verify persistence
5. Search keywords → Verify results include definitions

---

## DAY 3-4: Parse Case Detection + Structure Detection

### Task 2.1: Refactor Structure Detector

**Existing File**: `src/maps/structure_detector.py`

**Refactor to**: `src/maps/detectors/xml_structure_detector.py`

**Changes**:
- Inherit from `BaseStructureDetector`
- Implement `can_detect()`: Check for XML file extension
- Implement `detect_structure()`: Current logic, return standardized dict
- Keep database integration with `ParseCaseRepository`
- Keep caching functionality

**Retain Features**:
- Database-driven parse case definitions
- In-memory caching with TTL
- Detection history tracking
- Confidence scoring

### Task 2.2: Profile-Based Detection (Optional Enhancement)

**Add to Profile Schema**:
```json
{
  "profile_name": "lidc_idri_standard",
  "file_type": "XML",
  "structure_detection": {
    "enabled": true,
    "case_identification_rules": [
      {
        "case_name": "lidc_multi_session_4_radiologists",
        "required_fields": ["study_uid", "series_uid", "reading_session"],
        "field_patterns": {
          "reading_session": {"min_count": 4, "path": "/LidcReadMessage/readingSession"}
        },
        "confidence_threshold": 0.9
      }
    ]
  }
}
```

**Implementation**:
- Profile-based rules as **optional override** to database detection
- If no profile rules, fall back to database-driven detection
- Document in `EXTENSIBILITY_GUIDE.md`

### Task 2.3: Approval Queue Integration

**Verify Workflow**:
1. Parse document → Structure detector runs
2. If confidence < 0.75 → Add to approval queue
3. Reviewer approves/rejects
4. Approved documents update parse case statistics
5. System learns from approvals (future ML training data)

**Test**:
- Create document with ambiguous structure
- Verify appears in approval queue
- Approve via API endpoint
- Verify `document_content.confidence_score` updated

### Task 2.4: Test Structure Detection

**Test Cases**:
1. Upload LIDC XML (4 radiologists) → Detect `lidc_multi_session_4`
2. Upload LIDC XML (2 radiologists) → Detect `lidc_multi_session_2`
3. Upload ambiguous XML → Goes to approval queue
4. Approve queue item → Parse case assigned correctly
5. Cache performance → Second detection uses cache

---

## DAY 5-6: Complete API Integration

### Task 3.1: Backend API Testing

**Test All Endpoints**:

**Profiles**:
- `GET /api/v1/profiles` → List all profiles
- `POST /api/v1/profiles` → Create profile (already fixed)
- `GET /api/v1/profiles/{name}` → Get profile details
- `PUT /api/v1/profiles/{name}` → Update profile
- `DELETE /api/v1/profiles/{name}` → Delete profile

**Parsing**:
- `POST /api/v1/parse/xml` → Upload XML file, parse, return canonical document
- `POST /api/v1/parse/pdf` → Upload PDF, extract keywords
- `POST /api/v1/parse/batch` → Batch upload multiple files

**Keywords**:
- `GET /api/v1/keywords/search?q=nodule` → Search keywords
- `GET /api/v1/keywords/{id}` → Get keyword details with definition
- `GET /api/v1/keywords/categories` → List keyword categories
- `POST /api/v1/keywords/extract` → Extract from text

**Approval Queue**:
- `GET /api/v1/approval-queue` → List pending items
- `GET /api/v1/approval-queue/stats` → Get statistics
- `POST /api/v1/approval-queue/{id}/approve` → Approve item
- `POST /api/v1/approval-queue/{id}/reject` → Reject item
- `POST /api/v1/approval-queue/batch-approve` → Batch approve

**Analytics**:
- `GET /api/v1/analytics/summary` → Dashboard summary
- `GET /api/v1/analytics/keywords` → Keyword statistics
- `GET /api/v1/analytics/parse-cases` → Parse case distribution

### Task 3.2: Frontend Integration

**Update API Client** (`web/src/services/api.ts`):

**Add Error Handling**:
```typescript
// Centralized error handler
const handleApiError = (error: any) => {
  if (error.response) {
    // Server responded with error status
    const message = error.response.data?.detail || 'An error occurred';
    throw new Error(message);
  } else if (error.request) {
    // Request made but no response
    throw new Error('Network error. Please check your connection.');
  } else {
    throw new Error(error.message);
  }
};

// Apply to all API calls
export const api = {
  profiles: {
    list: async () => {
      try {
        const response = await axios.get('/api/v1/profiles');
        return response.data;
      } catch (error) {
        handleApiError(error);
      }
    },
    // ... other methods
  }
};
```

**Add Loading States**:
```typescript
// Use React Query for automatic loading/error states
import { useQuery, useMutation } from '@tanstack/react-query';

const useProfiles = () => {
  return useQuery({
    queryKey: ['profiles'],
    queryFn: api.profiles.list,
    // Automatic loading, error, refetch states
  });
};
```

### Task 3.3: File Upload Workflow

**Test End-to-End**:

**Profile Creation**:
1. Navigate to Profiles page
2. Click "Create Profile"
3. Fill form (name, file type, mappings)
4. Submit → Verify appears in profile list
5. Use profile for file upload

**File Upload (XML)**:
1. Navigate to Parse/Upload page
2. Select profile from dropdown
3. Upload XML file
4. Progress bar shows upload progress
5. Parse results display:
   - Parse case detected
   - Confidence score
   - Extracted fields
   - Keywords found
6. Click "View Keywords" → Navigate to keyword search with pre-filled query
7. Export results to Excel

**File Upload (PDF)**:
1. Upload PDF research paper
2. View extracted metadata (title, authors, journal)
3. View extracted keywords with context
4. Approve candidate keywords from approval queue
5. Search for approved keywords

### Task 3.4: Error Handling & User Experience

**Error Scenarios to Handle**:

**Upload Errors**:
- File too large → "File exceeds 50MB limit"
- Invalid file type → "Only XML and PDF files supported"
- Empty file → "File is empty or corrupted"

**Parse Errors**:
- XML malformed → "XML syntax error at line 42: ..."
- Profile mismatch → "Required field 'study_uid' not found in document"
- Low confidence → "Parse confidence low (0.65). Sent to approval queue."

**Network Errors**:
- API timeout → "Request timed out. Please try again."
- Connection lost → "Unable to connect to server. Check your network."
- 500 error → "Server error. Please contact support."

**UI Improvements**:
- Toast notifications for success/error
- Loading spinners during API calls
- Retry buttons for failed operations
- Breadcrumb navigation
- Progress indicators for batch uploads

---

## DAY 7: Testing, Documentation, Foundation Prep

### Task 4.1: Comprehensive End-to-End Testing

**Test Scenario 1: XML Research Workflow**
1. Create LIDC profile (if not exists)
2. Upload LIDC XML annotation file
3. Verify parse case detected correctly
4. Review extracted keywords (subtlety, malignancy, etc.)
5. View keyword details with definitions
6. Search for "spiculation" → View all occurrences
7. Export results to Excel
8. Open Excel file, verify formatting

**Test Scenario 2: PDF Literature Review**
1. Upload 5 research papers (PDFs)
2. Verify metadata extraction (DOI, authors, journal)
3. Check approval queue for candidate keywords
4. Approve 10 keywords, reject 5
5. Search approved keywords
6. View context snippets
7. Link papers to dataset (future feature, verify API ready)

**Test Scenario 3: Approval Queue Workflow**
1. Upload ambiguous XML file
2. Verify appears in approval queue with confidence score
3. Review suggested parse case
4. Approve with override (select different case)
5. Verify document updated
6. Check parse case statistics updated

**Test Scenario 4: Multi-Profile Testing**
1. Create custom profile for new XML format
2. Upload file using custom profile
3. Verify fields mapped correctly
4. Export canonical document as JSON
5. Verify schema compliance

### Task 4.2: Create Extensibility Documentation

**File**: `docs/EXTENSIBILITY_GUIDE.md`

**Content**:
```markdown
# MAPS Extensibility Guide

## Overview
MAPS uses abstract base classes and factory patterns to make adding new file formats, extractors, and detectors straightforward without modifying existing code.

## Adding a New File Format (e.g., CSV)

### Step 1: Create Parser
Implement `BaseParser` in `src/maps/parsers/csv_parser.py`:

\`\`\`python
from .base import BaseParser
from ..schemas.canonical import CanonicalDocument

class CSVParser(BaseParser):
    def can_parse(self, file_path: str) -> bool:
        return file_path.lower().endswith(('.csv', '.tsv'))

    def validate(self, file_path: str) -> tuple[bool, Optional[str]]:
        # Check CSV is well-formed
        pass

    def parse(self, file_path: str) -> CanonicalDocument:
        # Read CSV, apply profile mappings, return CanonicalDocument
        pass
\`\`\`

### Step 2: Create Keyword Extractor
Implement `BaseKeywordExtractor` in `src/maps/extractors/csv_keyword_extractor.py`:

\`\`\`python
from .base import BaseKeywordExtractor, ExtractedKeyword

class CSVKeywordExtractor(BaseKeywordExtractor):
    def can_extract(self, file_path: str) -> bool:
        return file_path.lower().endswith(('.csv', '.tsv'))

    def extract_keywords(self, file_path: str, extraction_config: Optional[Dict] = None) -> List[ExtractedKeyword]:
        # Extract from specified columns
        pass

    def get_supported_categories(self) -> List[str]:
        return ['metadata', 'diagnosis', 'treatment']
\`\`\`

### Step 3: Create Structure Detector
Implement `BaseStructureDetector` in `src/maps/detectors/csv_structure_detector.py`:

\`\`\`python
from .base import BaseStructureDetector

class CSVStructureDetector(BaseStructureDetector):
    def can_detect(self, file_path: str) -> bool:
        return file_path.lower().endswith(('.csv', '.tsv'))

    def detect_structure(self, file_path: str) -> Dict[str, Any]:
        # Detect CSV structure (headers, column types, row count)
        return {
            "parse_case": "csv_tabular",
            "confidence": 0.95,
            "detected_fields": ["column1", "column2"],
            "metadata": {"row_count": 1000, "column_count": 15}
        }
\`\`\`

### Step 4: Register in Factories
No code changes needed! Factories auto-discover implementations.

Or manually register:
\`\`\`python
from maps.extractors.factory import KeywordExtractorFactory
from maps.extractors.csv_keyword_extractor import CSVKeywordExtractor

factory = KeywordExtractorFactory()
factory.register_extractor(CSVKeywordExtractor())
\`\`\`

### Step 5: Create Profile
Create `profiles/labcorp_results.json`:

\`\`\`json
{
  "profile_name": "labcorp_results",
  "file_type": "CSV",
  "mappings": [
    {"source_path": "Patient ID", "target_path": "patient_id", "data_type": "string"},
    {"source_path": "Test Date", "target_path": "test_date", "data_type": "date"}
  ]
}
\`\`\`

### Step 6: Test
1. Upload CSV file via UI or API
2. Verify parsing works
3. Check keywords extracted
4. Verify structure detected

Done! No modifications to existing code required.

## Adding ML Models (Future)

### Step 1: Create Model Class
Implement `BaseMLModel` in `src/maps/ml/keyword_extractor_model.py`

### Step 2: Train Model
Use existing keyword_sources table as training data

### Step 3: Register Model
Add to model registry

### Step 4: Use in API
Call model in `/keywords/extract` endpoint

See ML IMPLEMENTATION PLAN in PART 2 for details.
```

### Task 4.3: Create Placeholder Files for Future Features

**Purpose**: Document where future features will be implemented

**Create Stub Files**:

**CSV Parser** (`src/maps/parsers/csv_parser.py`):
```python
"""
CSV Parser Implementation

TODO: Implement in Week 2
- Use pandas.read_csv() for robust parsing
- Support profile-based column mapping
- Handle date formats, encoding detection
- Type inference with profile override
"""

from .base import BaseParser

class CSVParser(BaseParser):
    """CSV file parser - TO BE IMPLEMENTED"""
    pass
```

**JSON Parser** (`src/maps/parsers/json_parser.py`):
```python
"""
JSON Parser Implementation

TODO: Implement in Week 3
- Use jsonpath-ng for JSONPath expressions
- Support nested object flattening
- Handle arrays with wildcard syntax
- FHIR resource validation
"""

from .base import BaseParser

class JSONParser(BaseParser):
    """JSON file parser - TO BE IMPLEMENTED"""
    pass
```

**ML Base Model** (`src/maps/ml/base_model.py`):
```python
"""
Base ML Model Interface

TODO: Implement in Week 5-7
- Abstract interface for all ML models
- Training pipeline orchestration
- Model versioning and storage
- Prediction logging
"""

from abc import ABC, abstractmethod
from typing import Any, Dict, List

class BaseMLModel(ABC):
    """Abstract base class for ML models"""

    @abstractmethod
    def train(self, training_data: Any) -> Dict[str, float]:
        """Train model and return metrics"""
        pass

    @abstractmethod
    def predict(self, input_data: Any) -> Any:
        """Make prediction"""
        pass

    @abstractmethod
    def save(self, path: str) -> None:
        """Save model to disk"""
        pass

    @abstractmethod
    def load(self, path: str) -> None:
        """Load model from disk"""
        pass
```

**Research Metadata Migration** (`migrations/014_research_metadata.sql`):
```sql
-- Research Metadata Schema
-- TODO: Implement in Week 10-11

/*
Tables to create:
- datasets (TCIA, Kaggle, private datasets)
- dataset_cases (individual cases in datasets)
- publications (papers, DOIs, journals)
- authors (researchers, ORCIDs)
- publication_authors (many-to-many)
- research_studies (clinical trials, NCT numbers)
- study_outcomes (primary/secondary outcomes)
- annotators (radiologists, algorithms)
- annotation_sessions (provenance tracking)

See PART 2 of IMPLEMENTATION_ROADMAP.md for schema details.
*/
```

### Task 4.4: Update Documentation

**Files to Update**:

**README.md**:
- Add "Recent Updates" section
- Mention Week 1 accomplishments
- Link to IMPLEMENTATION_ROADMAP.md

**docs/API_REFERENCE.md**:
- Document new keyword definition endpoints
- Add examples for file upload
- Document approval queue API

**CLAUDE.md**:
- Update with new architecture (extractors, detectors)
- Document factory pattern usage
- Add extensibility notes

---

## WEEK 1 DELIVERABLES CHECKLIST

### Code
- [ ] `src/maps/extractors/base.py` - BaseKeywordExtractor
- [ ] `src/maps/extractors/factory.py` - KeywordExtractorFactory
- [ ] `src/maps/extractors/xml_keyword_extractor.py` - Refactored
- [ ] `src/maps/extractors/pdf_keyword_extractor.py` - Refactored
- [ ] `src/maps/detectors/base.py` - BaseStructureDetector
- [ ] `src/maps/detectors/factory.py` - DetectorFactory
- [ ] `src/maps/detectors/xml_structure_detector.py` - Refactored
- [ ] `src/maps/api/routers/keywords.py` - Definition endpoints added
- [ ] Placeholder files created (CSV, JSON parsers, ML base)

### Testing
- [ ] All pytest tests passing
- [ ] XML upload → parse → view keywords (working)
- [ ] PDF upload → extract → search (working)
- [ ] Profile creation → file upload (working)
- [ ] Approval queue workflow (working)
- [ ] Dashboard with real data (working)
- [ ] Error handling tested
- [ ] Performance acceptable (<2s parse time)

### Documentation
- [ ] `docs/EXTENSIBILITY_GUIDE.md` created
- [ ] `docs/IMPLEMENTATION_ROADMAP.md` created (this file)
- [ ] `docs/API_REFERENCE.md` updated
- [ ] README.md updated
- [ ] CLAUDE.md updated

### Integration
- [ ] Frontend talking to backend (no mock data)
- [ ] File uploads working
- [ ] Results displaying correctly
- [ ] Error messages user-friendly
- [ ] Loading states working
- [ ] Navigation working

### Deployment
- [ ] Backend API running (localhost:8000)
- [ ] Frontend running (localhost:5173)
- [ ] Database migrations applied
- [ ] Sample data seeded
- [ ] No critical errors in logs
- [ ] Ready for production deployment

---

# PART 2: FUTURE IMPLEMENTATION PLAN (Months 2-3)

**Note**: This is the full plan for future reference. Implement after Week 1 foundation is complete.

---

## PHASE 2: CSV/Excel Parser Implementation (Weeks 2-3)

### Week 2: CSV Parser

**Goal**: Support CSV files for lab results, registry data, tabular datasets

**Tasks**:
1. Implement `CSVParser` in `src/maps/parsers/csv_parser.py`
2. Implement `CSVKeywordExtractor` in `src/maps/extractors/csv_keyword_extractor.py`
3. Implement `CSVStructureDetector` in `src/maps/detectors/csv_structure_detector.py`
4. Create sample profiles (Labcorp CBC, patient demographics, etc.)
5. Add frontend CSV upload UI
6. Test end-to-end

**Implementation Details**:
```python
import pandas as pd
from .base import BaseParser

class CSVParser(BaseParser):
    def parse(self, file_path: str) -> CanonicalDocument:
        # Read CSV with encoding detection
        df = pd.read_csv(file_path, encoding=self._detect_encoding(file_path))

        # Apply profile mappings
        mapped_data = {}
        for mapping in self.profile.mappings:
            source_col = mapping.source_path
            target_field = mapping.target_path

            if source_col in df.columns:
                values = df[source_col].tolist()
                mapped_data[target_field] = values

        # Create canonical document
        return CanonicalDocument(
            metadata={"source_format": "CSV", "row_count": len(df)},
            content=mapped_data
        )
```

**CSV Keyword Extraction**:
- Extract from specified columns (profile-driven)
- Auto-detect keyword columns (unique values < 30% of rows)
- Category assignment based on column headers

### Week 3: Excel Parser

**Goal**: Support Excel files (multi-sheet, formatted data)

**Tasks**:
1. Implement `ExcelParser` using openpyxl
2. Handle multi-sheet workbooks
3. Handle merged cells, formulas
4. Create Excel-specific profiles
5. Test with real datasets

**Special Handling**:
- Multi-sheet: Profile specifies which sheet
- Merged cells: Take first cell value, warn about data loss
- Formulas: Evaluate or preserve formula text (configurable)
- Date formats: Auto-detect Excel date serial numbers

---

## PHASE 3: ML Foundation Infrastructure (Weeks 4-7)

### Week 4: ML Architecture & Database Schema

**Goal**: Establish ML infrastructure foundation

**Tasks**:
1. Create `src/maps/ml/` module
2. Implement `BaseMLModel` abstract class
3. Create ML database schema (migration 015)
4. Implement model registry
5. Create training pipeline framework

**Database Schema**:
```sql
CREATE TABLE ml_models (
  id UUID PRIMARY KEY,
  model_name TEXT,
  model_type TEXT,  -- keyword_extraction, case_classification, quality_prediction
  version TEXT,
  framework TEXT,  -- scikit-learn, transformers, spacy
  model_path TEXT,
  training_date TIMESTAMPTZ,
  metrics JSONB,
  hyperparameters JSONB,
  is_active BOOLEAN
);

CREATE TABLE ml_predictions (
  id UUID PRIMARY KEY,
  model_id UUID REFERENCES ml_models(id),
  document_id UUID REFERENCES documents(id),
  prediction_type TEXT,
  predicted_value TEXT,
  confidence_score NUMERIC,
  features_used JSONB,
  created_at TIMESTAMPTZ
);

CREATE TABLE ml_training_runs (
  id UUID PRIMARY KEY,
  model_id UUID REFERENCES ml_models(id),
  dataset_size INTEGER,
  cross_validation_scores JSONB,
  feature_importance JSONB,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
```

### Week 5-6: Keyword Extraction Model

**Goal**: ML-powered keyword extraction (NER)

**Approach 1 (Quick): spaCy + scispaCy**
```python
import spacy

class KeywordExtractionModel(BaseMLModel):
    def __init__(self):
        self.nlp = spacy.load('en_core_sci_md')
        # Add custom entity ruler for LIDC terms
        ruler = self.nlp.add_pipe("entity_ruler")
        patterns = self._load_lidc_patterns()
        ruler.add_patterns(patterns)

    def extract(self, text: str) -> List[ExtractedKeyword]:
        doc = self.nlp(text)
        keywords = []
        for ent in doc.ents:
            keywords.append(ExtractedKeyword(
                text=ent.text,
                category=self._map_entity_label(ent.label_),
                context=ent.sent.text,
                source_field="ml_extraction",
                confidence=ent._.score if hasattr(ent._, 'score') else 1.0
            ))
        return keywords
```

**Approach 2 (Advanced): Fine-tuned BioBERT**
```python
from transformers import AutoModelForTokenClassification, AutoTokenizer

class BioNERModel(BaseMLModel):
    def __init__(self):
        self.model = AutoModelForTokenClassification.from_pretrained(
            'dmis-lab/biobert-base-cased-v1.1',
            num_labels=len(self.label_list)
        )
        self.tokenizer = AutoTokenizer.from_pretrained('dmis-lab/biobert-base-cased-v1.1')

    def train(self, training_data: List[Tuple[str, List[Keyword]]]):
        # Fine-tune on your keyword_sources table
        # BIO tagging format: B-ANATOMY, I-ANATOMY, O
        pass

    def extract(self, text: str) -> List[ExtractedKeyword]:
        # Tokenize, predict, decode to keywords
        pass
```

**Training Data**:
- Use existing `keyword_sources` table (20K+ labeled keywords)
- Approval queue decisions (approved vs. rejected)
- Manual annotations (if available)

**API Endpoint**:
```python
@router.post("/ml/extract-keywords")
async def ml_extract_keywords(
    text: str,
    model_version: str = "latest"
) -> List[ExtractedKeyword]:
    model = model_registry.get_model("keyword_extraction", model_version)
    keywords = model.extract(text)
    return keywords
```

### Week 7: Case Classification Model

**Goal**: Automatically classify documents by parse case

**Features for Classification**:
```python
class DocumentFeatureExtractor:
    def extract(self, doc: CanonicalDocument) -> np.ndarray:
        features = {
            # Structural
            'field_count': len(doc.model_dump(exclude_none=True)),
            'has_study_uid': doc.metadata.get('study_uid') is not None,
            'has_series_uid': doc.metadata.get('series_uid') is not None,
            'entity_count': len(doc.extracted_entities) if doc.extracted_entities else 0,

            # Content
            'text_length': len(str(doc.content)),
            'numeric_field_ratio': self._count_numeric_fields(doc),
            'keyword_diversity': len(set(doc.keywords)) / max(len(doc.keywords), 1),

            # Metadata
            'file_type_xml': doc.metadata.get('source_format') == 'XML',
            'file_type_pdf': doc.metadata.get('source_format') == 'PDF',

            # Pattern matching
            'has_lidc_pattern': self._check_lidc_pattern(doc),
            'has_cxr_pattern': self._check_cxr_pattern(doc)
        }
        return self._vectorize(features)
```

**Model**:
```python
from sklearn.ensemble import RandomForestClassifier

class CaseClassifier(BaseMLModel):
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=100, max_depth=10)
        self.feature_extractor = DocumentFeatureExtractor()

    def train(self, documents: List[CanonicalDocument], labels: List[str]):
        X = [self.feature_extractor.extract(doc) for doc in documents]
        y = labels

        # Cross-validation
        from sklearn.model_selection import cross_val_score
        scores = cross_val_score(self.model, X, y, cv=5)

        # Train on full dataset
        self.model.fit(X, y)

        return {"accuracy": scores.mean(), "std": scores.std()}

    def predict(self, doc: CanonicalDocument) -> Tuple[str, float]:
        features = self.feature_extractor.extract(doc)
        probs = self.model.predict_proba([features])[0]
        case_name = self.model.classes_[probs.argmax()]
        confidence = probs.max()
        return case_name, confidence
```

**Integration with Approval Queue**:
- Documents with confidence < 0.75 → approval queue
- Manual approval updates training data
- Periodic retraining (weekly/monthly)
- Track model performance over time

---

## PHASE 4: JSON & DICOM Support (Weeks 8-9)

### Week 8: JSON Parser (FHIR Support)

**Goal**: Support JSON files, especially FHIR resources

**Implementation**:
```python
from jsonpath_ng import parse as jsonpath_parse

class JSONParser(BaseParser):
    def parse(self, file_path: str) -> CanonicalDocument:
        with open(file_path, 'r') as f:
            data = json.load(f)

        mapped_data = {}
        for mapping in self.profile.mappings:
            # JSONPath: "$.patient.name[0].family"
            jsonpath_expr = jsonpath_parse(mapping.source_path)
            matches = jsonpath_expr.find(data)

            if matches:
                value = matches[0].value
                mapped_data[mapping.target_path] = value

        return CanonicalDocument(
            metadata={"source_format": "JSON"},
            content=mapped_data
        )
```

**FHIR Profile Example**:
```json
{
  "profile_name": "fhir_r4_patient",
  "file_type": "JSON",
  "mappings": [
    {"source_path": "$.id", "target_path": "patient_id"},
    {"source_path": "$.name[0].family", "target_path": "family_name"},
    {"source_path": "$.birthDate", "target_path": "birth_date", "data_type": "date"},
    {"source_path": "$.gender", "target_path": "gender"}
  ],
  "keyword_extraction": {
    "extraction_paths": [
      "$.condition[*].code.coding[*].display",
      "$.medicationStatement[*].medicationCodeableConcept.text",
      "$.allergyIntolerance[*].code.text"
    ]
  }
}
```

**JSON Keyword Extractor**:
```python
class JSONKeywordExtractor(BaseKeywordExtractor):
    def extract_keywords(self, file_path: str, extraction_config: Dict) -> List[ExtractedKeyword]:
        with open(file_path, 'r') as f:
            data = json.load(f)

        keywords = []
        for path in extraction_config.get('extraction_paths', []):
            jsonpath_expr = jsonpath_parse(path)
            matches = jsonpath_expr.find(data)

            for match in matches:
                keywords.append(ExtractedKeyword(
                    text=str(match.value),
                    category=self._infer_category(path),
                    context=json.dumps(match.context.value, indent=2)[:200],
                    source_field=path
                ))

        return keywords
```

### Week 9: DICOM Metadata Parser

**Goal**: Extract metadata from DICOM imaging files

**Implementation**:
```python
import pydicom

class DICOMParser(BaseParser):
    def parse(self, file_path: str) -> CanonicalDocument:
        ds = pydicom.dcmread(file_path, stop_before_pixels=True)

        # Extract standard DICOM tags
        metadata = {
            "study_instance_uid": str(ds.StudyInstanceUID),
            "series_instance_uid": str(ds.SeriesInstanceUID),
            "patient_id": str(ds.PatientID),
            "study_date": str(ds.StudyDate),
            "modality": str(ds.Modality),
            "slice_thickness": float(ds.SliceThickness) if 'SliceThickness' in ds else None,
            "scanner_manufacturer": str(ds.Manufacturer) if 'Manufacturer' in ds else None
        }

        return CanonicalDocument(
            metadata=metadata,
            content={}
        )
```

**Database Schema**:
```sql
-- migration 016
CREATE TABLE imaging_studies (
  id UUID PRIMARY KEY,
  study_instance_uid TEXT UNIQUE,
  study_date DATE,
  modality TEXT,
  patient_age INTEGER,
  patient_sex TEXT,
  scanner_manufacturer TEXT,
  slice_thickness NUMERIC
);

ALTER TABLE documents ADD COLUMN imaging_study_id UUID REFERENCES imaging_studies(id);
```

---

## PHASE 5: Research Metadata (Weeks 10-11)

### Week 10: Dataset Provenance & Publications

**Goal**: Track datasets, publications, citations

**Dataset Schema**:
```sql
-- migration 017
CREATE TABLE datasets (
  id UUID PRIMARY KEY,
  dataset_name TEXT UNIQUE,
  dataset_source TEXT,
  version TEXT,
  release_date DATE,
  total_cases INTEGER,
  modalities TEXT[],
  access_url TEXT,
  license TEXT
);

CREATE TABLE dataset_cases (
  id UUID PRIMARY KEY,
  dataset_id UUID REFERENCES datasets(id),
  case_id TEXT,
  subject_id TEXT,
  metadata JSONB
);

ALTER TABLE documents ADD COLUMN dataset_case_id UUID REFERENCES dataset_cases(id);
```

**Publication Schema**:
```sql
CREATE TABLE publications (
  id UUID PRIMARY KEY,
  doi TEXT UNIQUE,
  pmid TEXT,
  title TEXT,
  journal TEXT,
  impact_factor NUMERIC,
  publication_date DATE,
  abstract TEXT,
  keywords TEXT[],
  citation_count INTEGER
);

CREATE TABLE authors (
  id UUID PRIMARY KEY,
  orcid TEXT UNIQUE,
  full_name TEXT,
  h_index INTEGER
);

CREATE TABLE publication_authors (
  publication_id UUID REFERENCES publications(id),
  author_id UUID REFERENCES authors(id),
  author_position INTEGER,
  PRIMARY KEY (publication_id, author_id)
);
```

**PubMed Integration**:
```python
from Bio import Entrez

class PubMedIntegration:
    def __init__(self, email: str):
        Entrez.email = email

    def fetch_by_pmid(self, pmid: str) -> Publication:
        handle = Entrez.efetch(db="pubmed", id=pmid, retmode="xml")
        records = Entrez.read(handle)
        # Parse XML and create Publication object
        pass

    def fetch_by_doi(self, doi: str) -> Publication:
        # DOI → PMID lookup, then fetch
        pass
```

### Week 11: Clinical Trials & Annotation Provenance

**Clinical Trial Schema**:
```sql
-- migration 018
CREATE TABLE research_studies (
  id UUID PRIMARY KEY,
  study_id TEXT UNIQUE,  -- NCT number
  study_type TEXT,
  title TEXT,
  primary_investigator TEXT,
  sample_size INTEGER,
  start_date DATE,
  end_date DATE
);

CREATE TABLE study_outcomes (
  id UUID PRIMARY KEY,
  study_id UUID REFERENCES research_studies(id),
  outcome_type TEXT,
  outcome_measure TEXT,
  result_value NUMERIC,
  p_value NUMERIC
);
```

**Annotation Provenance Schema**:
```sql
-- migration 019
CREATE TABLE annotators (
  id UUID PRIMARY KEY,
  annotator_id TEXT UNIQUE,
  annotator_type TEXT,
  credentials TEXT,
  specialty TEXT
);

CREATE TABLE annotation_sessions (
  id UUID PRIMARY KEY,
  annotator_id UUID REFERENCES annotators(id),
  document_id UUID REFERENCES documents(id),
  session_start TIMESTAMPTZ,
  session_end TIMESTAMPTZ,
  software_used TEXT
);

ALTER TABLE keyword_sources ADD COLUMN session_id UUID REFERENCES annotation_sessions(id);
```

---

## PHASE 6: ML Quality & Context Explanation (Week 12+)

### Quality Prediction Model

**Goal**: Predict data quality scores

```python
class QualityPredictor(BaseMLModel):
    def predict(self, doc: CanonicalDocument) -> Dict[str, float]:
        features = self._extract_quality_features(doc)

        return {
            "completeness_score": self.model_completeness.predict([features])[0],
            "accuracy_score": self.model_accuracy.predict([features])[0],
            "overall_score": self._calculate_overall(features)
        }

    def _extract_quality_features(self, doc: CanonicalDocument) -> np.ndarray:
        return {
            'non_null_fields': self._count_non_null(doc),
            'validation_errors': len(doc.validation_errors),
            'parse_confidence': doc.confidence_score,
            'has_required_fields': self._check_required(doc)
        }
```

### Context Explanation with LLMs

**Goal**: Generate explanations for keywords in context

```python
class ContextExplainer:
    def __init__(self, api_key: str):
        self.client = anthropic.Client(api_key)

    def explain_keyword(self, keyword: str, context: str, category: str) -> str:
        prompt = f"""Explain this medical term in context:

        Term: {keyword}
        Category: {category}
        Context: {context}

        Provide a 2-3 sentence explanation suitable for medical researchers.
        Focus on clinical significance and interpretation."""

        response = self.client.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=200,
            messages=[{"role": "user", "content": prompt}]
        )

        return response.content[0].text
```

**Caching Strategy**:
- Cache common keyword explanations
- Generate on-demand for rare keywords
- Batch processing for efficiency

---

## IMPLEMENTATION PRIORITIES

### Must-Have (Week 1):
-  Abstract base classes (foundation)
-  Keyword extraction working (XML + PDF)
-  Parse case detection working
-  Full API integration
-  Approval queue workflow

### Should-Have (Weeks 2-4):
- CSV/Excel parsers
- Data validation engine
- ML infrastructure foundation
- Dataset provenance

### Nice-to-Have (Weeks 5-11):
- Keyword extraction ML model
- Case classification ML model
- JSON/DICOM parsers
- Publication tracking
- Clinical trial metadata
- Annotation provenance

### Future (Month 4+):
- Quality prediction ML
- Context explanation (LLM)
- Advanced analytics
- External ontology sync
- Real-time collaboration features

---

## SUCCESS METRICS

### Week 1:
- All existing features working
- Zero critical bugs
- API integration complete
- Foundation extensible

### Month 2:
- 4 file formats supported (XML, PDF, CSV, Excel)
- ML keyword extraction >90% precision/recall
- Validation engine operational

### Month 3:
- 6 file formats (add JSON, DICOM)
- Case classification >95% accuracy
- Research metadata tracking functional
- Publication import working

---

## TECHNICAL STACK SUMMARY

**Parsing**:
- pandas (CSV)
- openpyxl (Excel)
- jsonpath-ng (JSON)
- pydicom (DICOM)

**ML/NLP**:
- spaCy + scispaCy
- transformers (BioBERT)
- scikit-learn
- XGBoost
- ONNX Runtime

**External APIs**:
- Entrez/PubMed (biopython)
- OpenCitations
- RadLex API

**Database**:
- PostgreSQL 16+
- JSONB storage
- GIN indexes

---

**END OF ROADMAP**

Next: Implement Week 1 tasks (see checklist above)
