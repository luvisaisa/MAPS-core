# MAPS Documentation Index

**Last Updated:** 2026-02-03
**Version:** 1.0.1

---

## Quick Navigation

| Document | Description |
|----------|-------------|
| [README](../README.md) | Project overview |
| [CURRENT-STATE](CURRENT-STATE.md) | Feature status, tests, improvements |
| [DEVLOG](DEVLOG.md) | Development history by date |
| [TODO](../TODO.md) | Active tasks and backlog |

---

## Documentation Structure

```
docs/
├── INDEX.md           # This file
├── CURRENT-STATE.md   # Feature checklist, test coverage
├── DEVLOG.md          # Git history by date
├── guides/            # Getting started, developer guides
├── api/               # API reference and endpoints
├── database/          # Database setup and migrations
├── features/          # Feature-specific documentation
├── keywords/          # Keyword extraction system
├── testing/           # Test guides and reports
├── performance/       # Performance optimization
└── archive/           # Historical docs, reviews
```

---

## Guides

Getting started and development guides.

| Document | Description |
|----------|-------------|
| [QUICKSTART](guides/QUICKSTART.md) | Basic setup guide |
| [QUICKSTART_SCHEMA_AGNOSTIC](guides/QUICKSTART_SCHEMA_AGNOSTIC.md) | Schema-agnostic quick start |
| [DEVELOPER_GUIDE](guides/DEVELOPER_GUIDE.md) | Development setup and workflows |
| [EXTENSIBILITY_GUIDE](guides/EXTENSIBILITY_GUIDE.md) | Extending MAPS functionality |
| [INTEGRATION_GUIDE](guides/INTEGRATION_GUIDE.md) | System integration patterns |
| [CONTRIBUTING](guides/CONTRIBUTING.md) | Contribution guidelines |
| [TROUBLESHOOTING](guides/TROUBLESHOOTING.md) | Common issues and solutions |
| [FAQ](guides/FAQ.md) | Frequently asked questions |

---

## API Documentation

REST API reference and integration.

| Document | Description |
|----------|-------------|
| [API_REFERENCE](api/API_REFERENCE.md) | Complete API documentation |
| [API_ENDPOINTS](api/API_ENDPOINTS.md) | Endpoint specifications |
| [API_QUICKSTART](api/API_QUICKSTART.md) | API getting started |
| [API_DEPLOYMENT](api/API_DEPLOYMENT.md) | Deployment guide |
| [API_TEST_RESULTS](api/API_TEST_RESULTS.md) | API test coverage |
| [WEB_API_INTEGRATION](api/WEB_API_INTEGRATION.md) | Web integration guide |

---

## Database

Database setup and migrations.

| Document | Description |
|----------|-------------|
| [DATABASE_SETUP](database/DATABASE_SETUP.md) | PostgreSQL/SQLite configuration |
| [DB_MIGRATION_SUMMARY](database/DB_MIGRATION_SUMMARY.md) | Migration reference |
| [EXCEL_vs_SQLITE_GUIDE](database/EXCEL_vs_SQLITE_GUIDE.md) | Export format comparison |

---

## Features

Feature-specific documentation.

| Document | Description |
|----------|-------------|
| [SCHEMA_AGNOSTIC](features/SCHEMA_AGNOSTIC.md) | Schema-agnostic architecture |
| [SCHEMA_AGNOSTIC_SUMMARY](features/SCHEMA_AGNOSTIC_SUMMARY.md) | Architecture overview |
| [IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC](features/IMPLEMENTATION_GUIDE_SCHEMA_AGNOSTIC.md) | Implementation details |
| [PARSE_CASES](features/PARSE_CASES.md) | Parse case detection |
| [PYLIDC_INTEGRATION_GUIDE](features/PYLIDC_INTEGRATION_GUIDE.md) | LIDC-IDRI integration |
| [CASE_IDENTIFIER_README](features/CASE_IDENTIFIER_README.md) | Unified identifiers |
| [CASE_IDENTIFIER_QUICKSTART](features/CASE_IDENTIFIER_QUICKSTART.md) | Quick start |
| [MULTI_FORMAT_SUPPORT](features/MULTI_FORMAT_SUPPORT.md) | Format support |
| [ANALYSIS_AND_EXPORT_GUIDE](features/ANALYSIS_AND_EXPORT_GUIDE.md) | Export workflows |
| [RA_D_PS_EXPORT_GUIDE](features/RA_D_PS_EXPORT_GUIDE.md) | Export formats |

---

## Keyword Extraction

Keyword extraction and search system.

| Document | Description |
|----------|-------------|
| [KEYWORD_CONSOLIDATED_VIEW](keywords/KEYWORD_CONSOLIDATED_VIEW.md) | System overview |
| [KEYWORD_EXTRACTION](keywords/KEYWORD_EXTRACTION.md) | Extraction details |
| [KEYWORD_NORMALIZATION_SUMMARY](keywords/KEYWORD_NORMALIZATION_SUMMARY.md) | Text processing |
| [PDF_KEYWORD_EXTRACTOR_SUMMARY](keywords/PDF_KEYWORD_EXTRACTOR_SUMMARY.md) | PDF processing |
| [PDF_KEYWORD_EXTRACTOR_QUICK_REF](keywords/PDF_KEYWORD_EXTRACTOR_QUICK_REF.md) | Quick reference |
| [XML_KEYWORD_EXTRACTOR_SUMMARY](keywords/XML_KEYWORD_EXTRACTOR_SUMMARY.md) | XML processing |

---

## Testing

Test guides and coverage reports.

| Document | Description |
|----------|-------------|
| [TESTING_GUIDE](testing/TESTING_GUIDE.md) | How to run tests |
| [TEST_QUICKSTART](testing/TEST_QUICKSTART.md) | Quick start |
| [TEST_COVERAGE_REPORT](testing/TEST_COVERAGE_REPORT.md) | Coverage metrics |
| [TESTING_SUITE_SUMMARY](testing/TESTING_SUITE_SUMMARY.md) | Suite overview |
| [INTEGRATION_TEST_REPORT](testing/INTEGRATION_TEST_REPORT.md) | Integration tests |

---

## Performance

Performance optimization and benchmarks.

| Document | Description |
|----------|-------------|
| [PERFORMANCE](performance/PERFORMANCE.md) | Optimization guide |
| [PERFORMANCE_README](performance/PERFORMANCE_README.md) | Overview |
| [PERFORMANCE_QUICKREF](performance/PERFORMANCE_QUICKREF.md) | Quick reference |
| [PERFORMANCE_OPTIMIZATION_REPORT](performance/PERFORMANCE_OPTIMIZATION_REPORT.md) | Optimization report |
| [PERFORMANCE_DEPLOYMENT_CHECKLIST](performance/PERFORMANCE_DEPLOYMENT_CHECKLIST.md) | Deployment checklist |
| [PERFORMANCE_REVIEW](performance/PERFORMANCE_REVIEW.md) | Review |

---

## Archive

Historical documentation and reviews.

| Document | Description |
|----------|-------------|
| [ROADMAP](archive/ROADMAP.md) | Development roadmap |
| [IMPLEMENTATION_ROADMAP](archive/IMPLEMENTATION_ROADMAP.md) | Implementation plan |
| [COMPREHENSIVE_CODE_REVIEW_SUMMARY](archive/COMPREHENSIVE_CODE_REVIEW_SUMMARY.md) | Code review |
| [TYPE_SAFETY_REVIEW](archive/TYPE_SAFETY_REVIEW.md) | Type safety analysis |
| [SECURITY_AUDIT](archive/SECURITY_AUDIT.md) | Security audit |
| [SECURITY](archive/SECURITY.md) | Security policy |
| [QUICK_REFERENCE_NEW_FEATURES](archive/QUICK_REFERENCE_NEW_FEATURES.md) | New features reference |

---

## By Role

**End Users:**
- Start with [README](../README.md) and [QUICKSTART](guides/QUICKSTART.md)

**Developers:**
- Read [DEVELOPER_GUIDE](guides/DEVELOPER_GUIDE.md) and [API_REFERENCE](api/API_REFERENCE.md)

**System Administrators:**
- See [DATABASE_SETUP](database/DATABASE_SETUP.md) and [API_DEPLOYMENT](api/API_DEPLOYMENT.md)

**Researchers:**
- See [ANALYSIS_AND_EXPORT_GUIDE](features/ANALYSIS_AND_EXPORT_GUIDE.md)

---

## Project Status

| Metric | Value |
|--------|-------|
| Version | 1.0.1 |
| Total Tests | 43 |
| API Endpoints | 8 categories |
| Documentation Files | 52 |

See [CURRENT-STATE](CURRENT-STATE.md) for detailed status.

---

*Last reorganized: 2026-02-03*
