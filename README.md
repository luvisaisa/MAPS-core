# MAPS - Medical Annotation Processing System

## Overview

**MAPS (Medical Annotation Processing System)** is a comprehensive Python-based application designed to parse, analyze, and export medical imaging annotation data from various medical imaging systems and file formats. Built specifically for handling complex medical imaging session data with multiple observer readings, nodule annotations, coordinate mappings, and research literature.

MAPS combines a powerful FastAPI backend with a modern React web interface, supporting **XML, JSON, PDF, and ZIP files**, providing real-time updates, advanced analytics, keyword extraction, and seamless Supabase integration for scalable data management.

## Purpose

This system was developed to address the challenges of processing heterogeneous medical annotation data formats, providing researchers and medical professionals with tools to:

### File Format Support
- **XML**: Parse LIDC-IDRI and other medical imaging annotations
- **JSON**: Process structured annotation data
- **PDF**: Extract keywords from research papers and documentation
- **ZIP**: Batch process entire datasets with automatic extraction
- **Folders**: Recursive directory processing with multi-file support

### Core Capabilities
- Extract observer readings, confidence scores, and nodule characteristics
- Handle multi-session observer reviews and unblinded readings
- Export data to standardized Excel templates and SQLite databases
- **Import PYLIDC data directly to Supabase PostgreSQL**
- **Schema-agnostic parsing with automatic parse case detection**
- **Automatic keyword extraction from medical documents and PDFs**
- Perform advanced analytics on radiologist agreement and data quality
- Process up to 1000 files per batch with real-time progress tracking

##  Supabase Integration (NEW!)

**Import radiology data from PYLIDC to Supabase PostgreSQL with automatic parse case detection and keyword extraction.**

### Quick Start

1. **Set up Supabase**: Create a project at [supabase.com](https://supabase.com)
2. **Configure**: Copy `.env.example` to `.env` and add your Supabase credentials
3. **Migrate**: Apply database schema: `psql "$SUPABASE_DB_URL" -f migrations/*.sql`
4. **Import**: Run `python scripts/pylidc_to_supabase.py --limit 10`

** Full guide**: [docs/QUICKSTART_SUPABASE.md](docs/QUICKSTART_SUPABASE.md)

### Features

 **Schema-Agnostic Design**: Automatically detects XML structure patterns
 **PYLIDC Integration**: Direct import from LIDC-IDRI dataset
 **Parse Case Tracking**: Know which XML schema was used for each document
 **Keyword Extraction**: Automatic medical term extraction with categories
 **JSONB Storage**: Flexible PostgreSQL storage with GIN indexes
 **Full-Text Search**: Fast document search by keywords and content
 **Analytics Ready**: Materialized views and helper functions included

### Example Usage

```python
from maps.database.enhanced_document_repository import EnhancedDocumentRepository
from maps.adapters.pylidc_adapter import PyLIDCAdapter
import pylidc as pl

# Initialize repository with parse case and keyword tracking
repo = EnhancedDocumentRepository(
    enable_parse_case_tracking=True,
    enable_keyword_extraction=True
)

# Import PYLIDC scan
adapter = PyLIDCAdapter()
scan = pl.query(pl.Scan).first()
canonical_doc = adapter.scan_to_canonical(scan)

# Insert with automatic detection
doc, content, parse_case, keywords = repo.insert_canonical_document_enhanced(
    canonical_doc,
    source_file=f"pylidc://{scan.patient_id}",
    detect_parse_case=True,
    extract_keywords=True
)

print(f"Imported: {scan.patient_id}")
print(f"Parse case: {parse_case}")
print(f"Keywords extracted: {keywords}")
```

** Documentation**:
- [Quick Start Guide](docs/QUICKSTART_SUPABASE.md) - Get started in 5 minutes
- [Schema-Agnostic Guide](docs/SUPABASE_SCHEMA_AGNOSTIC_GUIDE.md) - Complete architecture documentation
- [Examples](examples/supabase_integration.py) - Usage examples

##  Complete Auto-Triggered Analysis System (NEW!)

**Fully automatic keyword extraction, case detection, and analytics on EVERY import using database triggers!**

### System Overview

The system automatically processes ALL imports (XML, PDF, LIDC, JSON) through a complete pipeline:

```
ANY IMPORT → Automatic Triggers → Keywords Extracted → Case Detected → Views Updated → Ready for Analysis
```

### Key Features

####  **Automatic Processing (No Manual Scripts!)**
- **Triggers on INSERT**: Automatic keyword extraction from all segment types
- **Hybrid Case Detection**: Filename regex (1.0 confidence) + keyword signature (0.0-1.0)
- **Confidence Thresholding**: Auto-assign ≥0.8, manual review <0.8
- **Cross-Type Validation**: Keywords appearing in both qualitative and quantitative segments

####  **Universal Views (All Data Types)**
- `file_summary` - Per-file aggregated statistics
- `segment_statistics` - Per-segment metrics (word count, numeric density, keywords)
- `numeric_data_flat` - Auto-extracted numeric fields from JSONB
- `cases_with_evidence` - Established cases with linked data
- `unresolved_segments` - Orphaned data needing assignment
- `case_identifier_validation` - Completeness metrics with actionable recommendations

####  **LIDC Medical Views (Specialized for Radiology)**
- `lidc_patient_summary` - Patient-level consensus (9 characteristics: subtlety, malignancy, etc.)
- `lidc_nodule_analysis` - Per-nodule with per-radiologist columns
- `lidc_patient_cases` - Case-level rollup with TCIA links
- `lidc_3d_contours` - Spatial coordinates for 3D visualization
- `lidc_contour_slices` - Per-slice polygon data
- `lidc_nodule_spatial_stats` - Derived spatial statistics

####  **CSV-Ready Export Views (For Non-Technical Users)**
- `export_universal_wide` - All data types, flattened
- `export_lidc_analysis_ready` - SPSS/R/Stata format (one row per radiologist rating)
- `export_lidc_with_links` - Patient summary with TCIA download links
- `export_radiologist_data` - Inter-rater analysis format
- `export_top_keywords` - Top 1000 keywords by relevance

####  **Public Access (Anonymous Read-Only via RLS)**
- All export views accessible to anonymous users
- LIDC medical views (de-identified data)
- Universal analysis views
- Internal processing tables restricted to authenticated users

####  **Canonical Keyword Semantics (NEW!)**
- **Curated Medical Concepts**: Lung-RADS®, RadLex, LIDC-IDRI, TCIA, Radiomics, cTAKES, NER
- **Categories**: Standardization Systems, Diagnostic Concepts, Imaging Biomarkers, Performance Metrics
- **AMA Citations**: Full references to source papers and documentation
- **Topic Tags**: Filtering by "LIDC", "Radiomics", "NLP", "Reporting", "Biomarkers", etc.
- **Bidirectional Navigation**: Keyword → Files/Segments/Cases AND File/Case → Keywords

####  **Keyword Navigation Views**
- `keyword_directory` - Complete catalog with usage stats and citations
- `keyword_occurrence_map` - Where-used at segment level
- `file_keyword_summary` - Keywords per file
- `case_keyword_summary` - Keywords per case
- `keyword_subject_category_summary` - Rollup by category
- `keyword_topic_tag_summary` - Rollup by tag

### 3D Visualization & Analysis

The system includes complete 3D contour processing utilities:

```python
from maps.lidc_3d_utils import (
    extract_nodule_mesh,
    calculate_consensus_contour,
    compute_inter_rater_reliability,
    generate_3d_visualization,
    get_tcia_download_script
)

# Extract 3D mesh for 3D printing
mesh_path = extract_nodule_mesh("LIDC-IDRI-0001", "1", contour_data, "stl")

# Calculate consensus from multiple radiologists
consensus = calculate_consensus_contour([rad1, rad2, rad3, rad4], method='average')

# Compute inter-rater reliability
ratings = {
    "malignancy": [4, 5, 4, 4],
    "subtlety": [3, 3, 4, 3]
}
metrics = compute_inter_rater_reliability(ratings)
print(f"ICC: {metrics['malignancy_icc']:.3f}")

# Generate interactive 3D visualization
html_path = generate_3d_visualization("LIDC-IDRI-0001", "1", contour_data)
```

### Database Migrations

The complete system is deployed via 14 SQL migrations:

1. **001_initial_schema** - Core tables (already existed)
2. **002_unified_case_identifier** - Schema-agnostic foundation (already existed)
3. **003-005** - Various enhancements (already existed)
4. **006_automatic_triggers** - Keyword extraction triggers  NEW
5. **007_case_detection_system** - Hybrid case detection  NEW
6. **008_universal_views** - Cross-format views  NEW
7. **009_lidc_specific_views** - Medical analysis views  NEW
8. **010_lidc_3d_contour_views** - Spatial visualization  NEW
9. **011_export_views** - CSV-ready materialized views  NEW
10. **012_public_access_policies** - RLS for anonymous read  NEW
11. **013_keyword_semantics** - Canonical keywords + citations  NEW
12. **014_keyword_navigation_views** - Keyword discovery  NEW

### Quick Commands

```bash
# Apply all migrations (run in order)
for i in {001..014}; do
    psql "$SUPABASE_DB_URL" -f migrations/$(printf "%03d" $i)*.sql
done

# Refresh all export views
psql "$SUPABASE_DB_URL" -c "SELECT * FROM refresh_all_export_views();"

# Backfill canonical keyword links
psql "$SUPABASE_DB_URL" -c "SELECT * FROM backfill_canonical_keyword_ids();"

# Check database statistics
psql "$SUPABASE_DB_URL" -c "SELECT * FROM public_database_statistics;"
```

### Python API Examples

```python
# Query keyword directory
from sqlalchemy import create_engine
engine = create_engine(os.getenv("SUPABASE_DB_URL"))

# Get all keywords in a category
query = """
SELECT * FROM keyword_directory
WHERE subject_category = 'Radiologist Perceptive and Diagnostic Concepts'
ORDER BY total_occurrences DESC
"""
keywords = pd.read_sql(query, engine)

# Get canonical keywords for a specific file
query = "SELECT * FROM get_file_canonical_keywords(%s)"
file_keywords = pd.read_sql(query, engine, params=[file_id])

# Search by topic tag
query = "SELECT * FROM search_keywords_by_tag('LIDC')"
lidc_keywords = pd.read_sql(query, engine)

# Get where a keyword is used
query = "SELECT * FROM get_canonical_keyword_occurrences('malignancy')"
occurrences = pd.read_sql(query, engine)
```

### Web Dashboard Features (Planned)

- **Keywords Tab**: Browse canonical keywords, filter by category/tag
- **Keyword Detail Modal**: Click any keyword → see all files/segments/cases
- **Clickable Keyword Chips**: Throughout the dashboard for easy navigation
- **TCIA Integration**: Direct links to study pages and DICOM downloads
- **3D Visualization**: In-browser nodule rendering with Plotly
- **Case Assignment Interface**: Manual review queue for confidence <0.8

** Complete Documentation**: [Analysis and Export System Guide](docs/ANALYSIS_AND_EXPORT_GUIDE.md)

## Architecture Overview

### Core Components

```
MAPS/
 main.py                     # Application entry point
 XMLPARSE.py                 # Core GUI application and parsing engine
 radiology_database.py       # SQLite database operations and analytics
 config.py                   # Configuration management
 enhanced_logging.py         # Advanced logging system
 performance_config.py       # Performance optimization settings
```

### Data Flow Architecture

```
XML Files → Parser Engine → Data Validation → Export Engine → Output Files
    ↓           ↓              ↓               ↓            ↓
Multi-format  Structure    Quality Checks   Template     Excel/SQLite
Detection     Analysis     Missing Values   Formatting   + Analytics
```

## Technical Stack

- **Language**: Python 3.8+
- **GUI Framework**: Tkinter (custom-styled)
- **Data Processing**: Pandas, NumPy
- **Excel Operations**: OpenPyXL
- **Database**: SQLite3
- **XML Processing**: ElementTree
- **File Operations**: Cross-platform file handling

## Project Structure

### Main Application (`main.py`)
- Entry point for the GUI application
- Window configuration and initialization
- Import error handling and system compatibility checks

### Core Parser (`XMLPARSE.py`)
The heart of the application containing:

#### GUI Components
- **NYTXMLGuiApp**: Main application class
- File/folder selection interfaces
- Progress tracking with live updates
- Export format selection dialogs
- Real-time processing feedback

#### Parsing Engine
- **parse_radiology_sample()**: Main XML parsing function
- **detect_parse_case()**: Intelligent XML structure detection
- **parse_multiple()**: Batch processing with memory optimization
- Multi-format support (NYT, LIDC, custom formats)

#### Data Processing
- **Template transformation**: Radiologist 1-4 column format
- **Nodule-centric organization**: Grouping by file and nodule
- **Quality validation**: Missing value detection and reporting
- **Memory optimization**: Batch processing for large datasets

#### Export Systems
- **Excel Export**: Multiple format options with rich formatting
- **SQLite Export**: Relational database with analytics capabilities
- **Template Format**: User-defined column structure
- **Multi-sheet organization**: Separate sheets per folder/parse case

### Database Operations (`radiology_database.py`)
- **RadiologyDatabase class**: SQLite wrapper with medical data focus
- **Batch operations**: Efficient data insertion and querying
- **Analytics engine**: Radiologist agreement analysis
- **Quality reporting**: Data completeness and consistency checks
- **Excel integration**: Database-to-Excel export with formatting

## Features

### 1. XML Parsing Capabilities

#### Multi-Format Support
- **NYT Format**: Standard radiology XML with ResponseHeader structure
- **LIDC Format**: Lung Image Database Consortium XML structure
- **Custom Formats**: Extensible parsing for new XML schemas
- **Automatic Detection**: Intelligent format recognition

#### Parse Case Classification
```
Complete_Attributes      - Full radiologist data (confidence, subtlety, obscuration, reason)
With_Reason_Partial     - Includes reason field with partial attributes
Core_Attributes_Only    - Essential attributes without reason
Minimal_Attributes      - Limited attribute set
No_Characteristics      - Structure without characteristic data
LIDC_Single_Session     - Single LIDC reading session
LIDC_Multi_Session_X    - Multiple LIDC sessions (2-4 radiologists)
No_Sessions_Found       - XML without readable sessions
XML_Parse_Error         - Malformed or unparseable XML
Detection_Error         - Structure analysis failure
```

#### Data Extraction
- **Radiologist Information**: ID, session type, reading timestamps
- **Nodule Characteristics**: Confidence, subtlety, obscuration, diagnostic reason
- **Coordinate Data**: X, Y, Z coordinates with edge mapping
- **Medical Metadata**: StudyInstanceUID, SeriesInstanceUID, SOP_UID, modality
- **Session Classification**: Standard vs. Detailed coordinate sessions

### 2. File Processing Systems

#### Single File Processing
- Individual XML file parsing
- Immediate feedback on parse results
- Error handling and reporting
- Data preview capabilities

#### Folder Processing
- Recursive XML file discovery
- Batch processing with progress tracking
- Per-folder statistics and reporting
- Error isolation (continue on failure)

#### Multi-Folder Processing **New Feature:**
- **Combined Output**: Single Excel file with multiple sheets
- **Folder Organization**: Separate sheet per source folder
- **Template Format**: Radiologist 1-4 repeating column structure
- **Single Database**: Combined SQLite database for all folders
- **Progress Tracking**: Real-time processing updates with live logging

### 3. Export Formats

#### Excel Export Options

##### Standard Export
- **Parse case sheets**: Separate sheets by XML structure type
- **Session separation**: Detailed vs. Standard coordinate sessions
- **Color coding**: Parse case-based row highlighting
- **Missing value highlighting**: Orange highlighting for MISSING values
- **Auto-formatting**: Column width adjustment and alignment

##### Template Format **New Feature:**
- **Radiologist Columns**: Repeating "Radiologist 1", "Radiologist 2", "Radiologist 3", "Radiologist 4"
- **Compact Ratings**: Format like "Conf:5 | Sub:3 | Obs:2 | Reason:1"
- **Color Coordination**: Each radiologist column gets unique color scheme
- **Comprehensive Headers**: FileID, NoduleID, ParseCase, SessionType, coordinates, metadata

##### Multi-Folder Excel **New Feature:**
- **Combined Sheet**: "All Combined" with data from all folders
- **Individual Sheets**: One sheet per source folder
- **Consistent Formatting**: Template format across all sheets
- **Navigation**: Easy switching between folder views

#### SQLite Database Export

##### Database Structure
```sql
-- Core tables for relational data organization
sessions        - Individual radiologist reading sessions
nodules         - Unique nodule instances with metadata
radiologists    - Radiologist information and statistics
files           - Source file tracking and metadata
batches         - Processing batch management
quality_issues  - Data quality problem tracking
```

##### Analytics Capabilities
- **Radiologist Agreement**: Inter-rater reliability calculations
- **Data Quality Metrics**: Completeness, consistency analysis
- **Performance Statistics**: Processing time and success rates
- **Batch Tracking**: Historical processing information

##### Advanced Querying
- SQL query interface for custom analysis
- Predefined analytical views
- Export capabilities to Excel with formatting
- Integration with external analysis tools

### 4. Data Quality & Validation

#### Quality Checks
- **Missing Value Detection**: Identification of MISSING vs #N/A vs empty values
- **Data Completeness Analysis**: Per-column and overall completeness statistics
- **Type Validation**: Ensuring numeric fields contain valid numbers
- **Structure Validation**: XML schema compliance checking

#### User Interaction
- **Quality Warnings**: User prompts for data quality issues
- **Continue/Cancel Options**: User choice on problematic data
- **Detailed Reporting**: Comprehensive quality statistics
- **Column Hiding**: Auto-hide columns with >85% missing values

#### Error Handling
- **Graceful Degradation**: Continue processing on individual file failures
- **Error Logging**: Detailed error tracking with timestamps
- **User Feedback**: Clear error messages and resolution suggestions
- **Recovery Options**: Partial processing results preservation

### 5. User Interface

#### Main Interface
- **Clean Design**: Aptos font, consistent color scheme (#d7e3fc)
- **Intuitive Layout**: Logical workflow progression
- **File Management**: Easy file/folder selection and management
- **Export Options**: Clear choice between Excel and SQLite formats

#### Progress Tracking **Enhanced Feature:**
- **Live Progress Bars**: Visual progress indication
- **Real-time Logging**: Timestamped activity log with color coding
- **File-by-file Updates**: Individual file processing status
- **Statistics Display**: Success/failure counts, processing rates
- **Auto-close Options**: Configurable completion behavior

#### Visual Feedback
- **Color-coded Messages**: Info (blue), success (green), warning (orange), error (red)
- **Creator Signature**: Animated signature popup on startup
- **Status Updates**: Contextual status information
- **Error Popups**: Temporary error notifications

### 6. Performance Optimization

#### Memory Management
- **Batch Processing**: Process files in configurable batches
- **Garbage Collection**: Explicit memory cleanup
- **Data Streaming**: Minimize memory footprint for large datasets
- **Efficient Data Structures**: Optimized data organization

#### Processing Optimization
- **Smart Sampling**: Intelligent sampling for column width calculation
- **Vectorized Operations**: Pandas optimization for data manipulation
- **Batch Database Operations**: Efficient SQLite bulk insertions
- **Parallel Processing Ready**: Architecture supports future parallelization

#### User Experience
- **Responsive UI**: Non-blocking progress updates
- **Background Processing**: Long operations don't freeze interface
- **Cancellation Options**: User can interrupt long operations
- **Resource Monitoring**: Memory and performance tracking

## Development Roadmap

### Completed Features

1. **Core XML Parsing Engine** - Multi-format XML processing
2. **GUI Application** - Complete Tkinter interface
3. **Excel Export System** - Multiple export formats with rich formatting
4. **SQLite Database Integration** - Relational database with analytics
5. **Multi-Folder Processing** - Combined output generation
6. **Template Format Export** - Radiologist 1-4 column structure
7. **Quality Validation System** - Comprehensive data quality checks
8. **Progress Tracking** - Real-time processing feedback
9. **Error Handling** - Robust error management and recovery

### Current Development

#### Database GUI Project (In Planning)
A separate application for database analysis and visualization:
- **Database Browser**: Navigate and explore SQLite databases
- **Query Interface**: Visual SQL query builder
- **Analytics Dashboard**: Radiologist agreement analysis
- **Data Visualization**: Charts and graphs for data insights
- **Export Tools**: Advanced export options from database
- **Comparison Tools**: Compare multiple databases

### Future Enhancements

#### Phase 1: Enhanced Analytics
- **Statistical Analysis**: Advanced inter-rater reliability metrics
- **Machine Learning Integration**: Anomaly detection in radiologist readings
- **Predictive Modeling**: Quality prediction based on XML structure
- **Batch Comparison**: Compare processing results across batches

#### Phase 2: Scalability Improvements
- **Parallel Processing**: Multi-core processing for large batches
- **Cloud Integration**: AWS/Azure processing capabilities
- **API Development**: REST API for automated processing
- **Docker Containerization**: Deployment and scaling support

#### Phase 3: Advanced Features
- **DICOM Integration**: Support for DICOM file processing
- **Web Interface**: Browser-based processing interface
- **Real-time Monitoring**: Live processing dashboards
- **Integration APIs**: Connect with hospital information systems

#### Phase 4: AI/ML Features
- **Natural Language Processing**: Extract insights from reason text
- **Computer Vision**: Image coordinate validation
- **Automated Quality Assessment**: AI-powered data quality scoring
- **Predictive Analytics**: Forecast processing outcomes

## Technical Specifications

### System Requirements
- **Python**: 3.8 or higher
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: 1GB+ free space for databases and exports
- **OS**: Windows 10+, macOS 10.14+, Linux (Ubuntu 18.04+)

### Performance Benchmarks
- **Small Dataset** (<1,000 files): ~2-5 minutes
- **Medium Dataset** (1,000-10,000 files): ~10-30 minutes  
- **Large Dataset** (10,000+ files): ~30+ minutes
- **Memory Usage**: ~100-500MB typical, scales with dataset size

### Dependencies
```python
# Core Dependencies
pandas>=1.3.0
openpyxl>=3.0.9
numpy>=1.21.0

# GUI and System
tkinter (built-in)
platform (built-in)
subprocess (built-in)

# Database
sqlite3 (built-in)

# XML Processing
xml.etree.ElementTree (built-in)
```

## Installation & Setup

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd "XML PARSE"

# Install dependencies
pip install pandas openpyxl numpy

# Run the application
python main.py
```

### Development Setup
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install development dependencies
pip install -r requirements.txt

# Run tests (if available)
python -m pytest tests/

# Start development server
python main.py
```

## Usage Examples

### Basic File Processing
1. Launch application: `python main.py`
2. Click "Select XML Files" or "Select Folders"
3. Choose export format (Excel/SQLite/Both)
4. Click "Export to Excel" or "Export to SQLite"
5. Monitor progress and review results

### Multi-Folder Processing
1. Click "Select Folders" → "Multiple Folders"
2. Use Cmd+Click (macOS) to select multiple folders
3. Choose combined export format
4. Process creates single Excel with multiple sheets
5. Single SQLite database contains all folder data

### Template Format Export
1. Select files/folders for processing
2. Choose "Export to Excel"
3. System automatically applies template format
4. Results show Radiologist 1-4 columns with compact ratings

### Database Analysis
1. Export data to SQLite format
2. Use generated analysis Excel for quick insights
3. Query database directly using SQL tools
4. Future: Use Database GUI for advanced analysis

## Known Issues & Limitations

### Current Limitations
- **Single-threaded Processing**: No parallel processing yet
- **Memory Usage**: Large datasets can consume significant RAM
- **XML Format Support**: Limited to known formats (extensible)
- **Error Recovery**: Some XML errors cannot be automatically resolved

### Known Issues
- **Very Large Files**: Files >100MB may process slowly
- **Special Characters**: Some Unicode characters in XML may cause issues
- **Network Drives**: Processing from network locations may be slower
- **macOS Permissions**: May require permissions for file access

### Workarounds
- **Large Datasets**: Process in smaller batches
- **Memory Issues**: Close other applications during processing
- **File Errors**: Check XML validity before processing
- **Performance**: Use local storage for better performance

## Contributing

### Development Guidelines
- Follow PEP 8 Python style guidelines
- Add docstrings to all functions and classes
- Include type hints where appropriate
- Write tests for new features
- Update documentation for changes

### Code Organization
- **main.py**: Entry point only, minimal logic
- **XMLPARSE.py**: Core functionality, well-documented
- **radiology_database.py**: Database operations
- **New features**: Consider separate modules for large features

### Testing
- Test with various XML formats
- Verify export formats work correctly
- Check error handling with malformed data
- Performance test with large datasets

** Testing Documentation:**
- [Testing Guide](docs/TESTING_GUIDE.md) - Comprehensive testing documentation
- [Quick Reference](docs/TEST_QUICKSTART.md) - Quick commands and tips

**Run Tests:**
```bash
# Web tests
cd web/ && npm test

# Python tests  
pytest -v

# Coverage reports
npm run test:coverage  # web
pytest --cov=src --cov-report=html  # python
```

**CI/CD:** Tests run automatically on push/PR via GitHub Actions (`.github/workflows/test.yml`)

## License

**MAPS is proprietary software with dual licensing:**

### 🎓 Academic/Non-Commercial Use (FREE)
- Free for academic research and education
- Must cite in publications
- No commercial use permitted
- See [LICENSE](LICENSE) for full terms

### 💼 Commercial Use (PAID LICENSE REQUIRED)
- Required for any for-profit use
- Includes support and updates
- Custom pricing based on use case
- Contact for commercial licensing

**Copyright (c) 2025 Isa Lucia Schlichting. All Rights Reserved.**

### Citation

If you use MAPS in academic research, please cite:

```bibtex
@software{schlichting2025maps,
  author = {Schlichting, Isa Lucia},
  title = {MAPS: Medical Annotation Processing System},
  year = {2025},
  publisher = {GitHub},
  url = {https://github.com/luvisaisa/MAPS}
}
```

### Licensing Inquiries

For commercial licensing, enterprise support, or questions:
- 📧 Email: isa.lucia.sch@outlook.com
- 📄 Details: [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md)
- 💻 Repository: https://github.com/luvisaisa/MAPS

## Project Links

- **Repository**: NYTXMLPARSE (GitHub)
- **Author**: luvisaisa
- **Created**: 2025
- **Language**: Python

## Support

For issues, questions, or contributions:
- Create an issue in the GitHub repository
- Review existing documentation
- Check known issues section
- Contact development team

---

*Last Updated: August 12, 2025*
*Version: 2.0*
*Status: Active Development*
