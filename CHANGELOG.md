# Changelog

All notable changes to MAPS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-02-03

### Removed
- Tkinter GUI module (gui.py) - project now API-only
- GUI-related documentation, tests, and examples
- GUI launcher scripts

### Changed
- Refactored parser.py extract_characteristics() to reduce redundancy
- Consolidated LIDC session attribute definitions
- Updated API router imports to use relative paths
- Migrated config to Pydantic v2 SettingsConfigDict pattern

### Fixed
- API keyword router attribute name mismatches
- Removed emojis from parser print statements for cleaner logs

## [0.7.0] - 2025-10-27

### Added
- REST API with FastAPI framework
- Health check and status endpoints
- File upload endpoints for XML and PDF parsing
- Batch processing API endpoints
- Profile management API (list, get, validate)
- Keyword search and normalization endpoints
- Auto-analysis API endpoints
- Parse case detection endpoint
- Export endpoints (Excel, CSV, JSON)
- API middleware for logging and error handling
- Response caching utilities
- System statistics endpoints
- API configuration management
- Comprehensive API documentation

### Changed
- Bumped version to 0.7.0 for REST API release

## [0.6.0] - 2025-10-16

### Added
- PYLIDC adapter for LIDC-IDRI dataset integration
- Scan to canonical document conversion
- Consensus metrics calculation for multi-reader annotations
- Nodule clustering support
- Batch processing for LIDC scans
- PYLIDC integration documentation and examples

## [0.5.0] - 2025-10-13

### Added
- Auto-analysis system for XML files
- XMLKeywordExtractor for automatic keyword extraction
- AutoAnalyzer for canonical document population
- Semantic characteristic mapping (numeric to descriptive)
- Batch analysis with statistics
- Entity extraction metadata tracking

## [0.4.0] - 2025-10-04

### Added
- Keyword extraction system
- KeywordNormalizer with synonym mapping
- Medical terms dictionary (synonyms, abbreviations, multi-word terms)
- PDFKeywordExtractor for research paper processing
- KeywordSearchEngine with boolean query support (AND/OR)
- Synonym expansion for comprehensive search
- Keyword extraction examples and documentation

## [0.3.0] - 2025-09-26

### Added
- Schema-agnostic data ingestion framework
- Profile-based mapping system
- Pydantic v2 canonical schemas (CanonicalDocument, RadiologyCanonicalDocument)
- Entity extraction models (Entity, ExtractedEntities)
- Profile schema with FieldMapping and ValidationRules
- BaseParser interface for extensible parsers
- ProfileManager with CRUD operations
- LIDC-IDRI standard profile
- Profile validation and inheritance
- Comprehensive schema-agnostic documentation

### Changed
- Migrated to Pydantic v2 for schema validation
- Enhanced type safety across models

## [0.2.0] - 2025-09-16

### Added
- GUI application using Tkinter
- File and folder selection dialogs
- Progress bar with real-time updates
- Status logging in GUI
- One-click parsing and export
- GUI documentation and user guide

### Note
- GUI marked as SUSPENDED in favor of future FastAPI + React web interface

## [0.1.1] - 2025-09-06

### Added
- Parse case detection system (7 supported formats)
- StructureDetector for XML analysis
- Parse statistics and reporting
- Expected attributes mapping per case
- Utility functions for logging and formatting
- PARSE_CASES documentation

## [0.1.0] - 2025-08-26

### Added
- Initial XML parsing engine
- Namespace handling for medical XML formats
- Header extraction (StudyUID, SeriesUID, Modality, DateTime)
- Nodule data extraction with 9 characteristics
- ROI coordinate extraction
- Pandas DataFrame conversion
- Batch processing support
- Excel export functionality
- Basic examples and tests
- Project documentation

### Dependencies
- pandas>=1.3.0
- lxml>=4.6.0
- openpyxl>=3.0.7
- python-dateutil>=2.8.0

[0.7.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.7.0
[0.6.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.6.0
[0.5.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.5.0
[0.4.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.4.0
[0.3.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.3.0
[0.2.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.2.0
[0.1.1]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.1.1
[0.1.0]: https://github.com/luvisaisa/MAPS-core/releases/tag/v0.1.0

## [1.0.0] - 2025-11-28

### Release Notes

First stable release of MAPS with complete feature set.

### Features Complete
- XML parsing with parse case detection
- Profile-based schema-agnostic parsing
- Keyword extraction and normalization
- Auto-analysis and entity extraction
- PYLIDC adapter integration  
- REST API with FastAPI
- Comprehensive documentation
- Full test coverage

### Production Ready
- Stable API contract
- Security audit complete
- Performance optimizations applied
- Deployment guides provided
