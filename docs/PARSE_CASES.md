# Parse Case Detection

MAPS automatically detects different XML schema formats and adjusts parsing accordingly.

## Supported Parse Cases

### 1. Complete_Attributes
Full radiologist annotation data with all characteristics.

**Expected fields:**
- Header: StudyInstanceUID, SeriesInstanceUID, Modality, DateService, TimeService
- Characteristics: All 9 nodule characteristics
- ROI: Complete coordinate data

### 2. Core_Attributes_Only
Essential attributes with partial characteristics.

**Expected fields:**
- Header: StudyInstanceUID, SeriesInstanceUID, DateService
- Characteristics: Subtlety, Malignancy
- ROI: Image SOP and coordinates

### 3. With_Reason_Partial
Minimal attribute set.

**Expected fields:**
- Header: StudyInstanceUID, SeriesInstanceUID
- Characteristics: Subtlety only
- ROI: Image SOP only

### 4. LIDC Formats
LIDC-IDRI dataset specific formats.

**Variants:**
- LIDC_Single_Session: One reading session
- LIDC_Multi_Session_2: Two radiologists
- LIDC_Multi_Session_3: Three radiologists
- LIDC_Multi_Session_4: Four radiologists

**Expected fields:**
- Header: StudyInstanceUID, SeriesInstanceUID, DateService, TimeService
- Characteristics: Subtlety (primary)
- ROI: Complete coordinate data

## Detection Logic

Parse case is determined by:
1. Root element tag (LIDC vs standard format)
2. Reading session count
3. Presence of header fields (Modality, DateService)
4. Available characteristic attributes

## Usage

```python
from src.maps.parser import detect_parse_case, parse_radiology_sample

# Detect case
case = detect_parse_case('file.xml')
print(f"Detected: {case}")

# Parse will automatically use detected case
main_df, unblinded_df = parse_radiology_sample('file.xml')
```
