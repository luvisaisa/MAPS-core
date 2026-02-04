# TODO - Active Development Tasks

Current working tasks with implementation plans. Completed tasks move to [DEVLOG.md](docs/DEVLOG.md).

**Last Code Review:** 2026-02-04 - See [CURRENT-STATE.md](docs/CURRENT-STATE.md) for detailed findings.

---

## 🔴 Critical Priority

### 1. Add PYLIDC Adapter Tests
**Status:** Not Started
**Priority:** Critical
**Effort:** 4-6 hours

**Problem:**
- `pylidc_adapter.py` has 278 lines, 0 tests
- No coverage for scan conversion, consensus metrics, clustering
- Can't safely refactor or modify

**Implementation Plan:**
1. Create `tests/test_pylidc_adapter.py`
2. Mock pylidc.Scan objects for isolation
3. Test `scan_to_canonical()` conversion
4. Test `_cluster_to_nodule()` logic
5. Test `_calculate_consensus()` statistics
6. Test `scans_to_canonical_batch()` batch processing
7. Test error cases (missing data, invalid scans)

**Acceptance Criteria:**
- 80%+ coverage on pylidc_adapter.py
- All public methods have at least one test
- Tests run without external PYLIDC database
- Tests pass with mocked pylidc objects

---

### 2. Add Auto-Analysis Tests
**Status:** Not Started
**Priority:** Critical  
**Effort:** 4-6 hours

**Problem:**
- `auto_analysis.py` has 269 lines, 0 tests
- No coverage for AutoAnalyzer, entity extraction
- Integration with XMLKeywordExtractor untested

**Implementation Plan:**
1. Create `tests/test_auto_analysis.py`
2. Test `AutoAnalyzer.analyze_xml()` with sample XML
3. Test `_extract_entities_from_keywords()` entity mapping
4. Test `_calculate_confidence()` scoring
5. Test `analyze_batch()` with multiple files
6. Test `get_analysis_summary()` statistics
7. Mock filesystem and parser dependencies

**Acceptance Criteria:**
- Coverage for auto_analysis.py (>80%)
- All AutoAnalyzer methods tested
- Entity extraction validated
- Batch analysis validated

---

## 🟡 High Priority

### 3. Implement Proper Caching with Cleanup
**Status:** Not Started
**Priority:** High
**Effort:** 3-4 hours

**Problem:**
- `cache.py` SimpleCache has no cleanup (memory leak)
- No max size limit (unbounded growth)
- TTL exists but expired entries never removed

**Implementation Plan:**
1. Option A: Upgrade to functools.lru_cache with TTL wrapper
2. Option B: Use cachetools library (LRU + TTL)
3. Option C: Add Redis integration for production
4. Add background cleanup task (if not using LRU)
5. Add cache statistics endpoint
6. Add cache clear endpoint for admin
7. Document caching behavior

**Acceptance Criteria:**
- Cache has max size limit
- Expired entries removed automatically
- Memory usage bounded
- Tests verify cleanup works

---

### 4. Add Structured Logging with Request IDs
**Status:** Not Started
**Priority:** High
**Effort:** 4-5 hours

**Problem:**
- Plain string logging only
- No request tracing across services
- Can't correlate logs for single request
- No machine-readable format

**Implementation Plan:**
1. Create `src/maps/api/logging_config.py`
2. Define JSON log format (timestamp, level, message, request_id, etc.)
3. Add request ID middleware (UUID per request)
4. Update LoggingMiddleware to use structured format
5. Add request_id to all log calls
6. Update FastAPI app to use new logging config
7. Document log format in docs/

**Acceptance Criteria:**
- All logs output as JSON
- Each request has unique ID
- Request ID propagates through call chain
- Logs include duration, status, path, method
- Easy to parse for log aggregation tools

---

### 5. Add API Response Pagination
**Status:** Not Started
**Priority:** High
**Effort:** 3-4 hours

**Problem:**
- Search endpoints return unlimited results
- Could cause memory issues with large datasets
- No standard pagination format

**Implementation Plan:**
1. Create pagination models in `src/maps/api/models.py`
2. Add `page` and `per_page` parameters to search endpoints
3. Return pagination metadata (total, page, per_page, has_next)
4. Update keyword search to support pagination
5. Update profile list to support pagination
6. Add tests for pagination logic
7. Document pagination in API docs

**Acceptance Criteria:**
- All list/search endpoints paginated
- Default page size: 20
- Max page size: 100
- Pagination metadata in responses
- Tests verify pagination works

---

### 6. Separate Export Logic from Parser
**Status:** Not Started
**Priority:** High
**Effort:** 2-3 hours

**Problem:**
- `parser.py` has `export_excel()` function (mixed concerns)
- Parsing and exporting should be separate
- Violates single responsibility principle

**Implementation Plan:**
1. Create `src/maps/exporters/` directory
2. Create `src/maps/exporters/excel_exporter.py`
3. Move `export_excel()` to ExcelExporter class
4. Add CSV export support (CSVExporter)
5. Add JSON export support (JSONExporter)
6. Update API export router to use new exporters
7. Remove export function from parser.py
8. Update any imports

**Acceptance Criteria:**
- Export logic in separate module
- Parser.py only does parsing
- Multiple export formats supported
- Tests for each exporter
- No broken imports

---

## 🟢 Medium Priority

### 7. Add Integration Tests
**Status:** Not Started
**Priority:** Medium
**Effort:** 6-8 hours

**Problem:**
- Only unit tests exist
- No end-to-end workflow tests
- API integration with parser untested
- Database integration untested

**Implementation Plan:**
1. Create `tests/integration/` directory
2. Add `test_api_integration.py` - full API workflows
3. Add `test_parser_integration.py` - file parsing end-to-end
4. Add `test_database_integration.py` - if DB tests needed
5. Use TestClient for API tests
6. Use test fixtures for sample files
7. Add integration tests to CI

**Acceptance Criteria:**
- At least 5 integration test scenarios
- Cover upload → parse → store → export workflow
- Tests can run in CI environment
- Tests clean up after themselves

---

### 8. Fix Async/Sync Architecture
**Status:** Not Started
**Priority:** Medium
**Effort:** 3-4 hours

**Problem:**
- API endpoints are async but call sync parser functions
- Blocking I/O in async context (defeats purpose)
- No actual concurrency benefit

**Implementation Plan:**
1. Document decision: keep sync or make async
2. Option A: Use `asyncio.to_thread()` for blocking operations
3. Option B: Document that API is sync-in-async (acceptable)
4. Option C: Refactor parser to be truly async (large effort)
5. Update tests if architecture changes
6. Document threading model in ARCHITECTURE.md

**Decision Needed:**
- Is true async needed for performance?
- Is current sync-in-async acceptable?
- Benchmark to inform decision

---

### 9. Create Router Base Class
**Status:** Not Started
**Priority:** Medium
**Effort:** 3-4 hours

**Problem:**
- Router files have duplicate patterns
- Error handling repeated
- File upload logic duplicated

**Implementation Plan:**
1. Create `src/maps/api/routers/base.py`
2. Define BaseRouter with common methods
3. Add `handle_file_upload()` method
4. Add `handle_error()` method
5. Add `validate_file_extension()` method
6. Refactor existing routers to inherit from BaseRouter
7. Remove duplicated code

**Acceptance Criteria:**
- All routers inherit from BaseRouter
- Common patterns abstracted
- Code duplication reduced by >30%
- Tests still pass

---

### 10. Update Documentation
**Status:** Not Started
**Priority:** Medium
**Effort:** 2-3 hours

**Problem:**
- GUI references still in docs (app removed)
- INDEX.md outdated for new structure
- Some links may be broken

**Implementation Plan:**
1. Search docs/ for "GUI", "Tkinter", "gui.py"
2. Remove or update outdated sections
3. Update INDEX.md with new docs structure
4. Verify all internal links work
5. Add missing sections (caching, logging)
6. Update architecture diagrams if needed

**Acceptance Criteria:**
- Zero GUI references in docs
- INDEX.md reflects current structure
- All links functional
- Architecture docs updated

---

## 🔵 Low Priority / Backlog

### Security Audit
**Priority:** Low
**Effort:** 4-6 hours

**Implementation Plan:**
1. Review authentication/authorization requirements
2. Audit file upload security (path traversal, file types)
3. Check input sanitization across all endpoints
4. Review error messages for information leakage
5. Scan for hardcoded credentials/secrets
6. Check SQL injection risks (if using raw SQL)
7. Review dependency vulnerabilities (pip-audit)
8. Test rate limiting effectiveness
9. Document security posture
10. Create security checklist for future features

**Acceptance Criteria:**
- Security audit report created
- All high-risk issues addressed
- Security best practices documented
- No hardcoded secrets in codebase
- Dependency vulnerabilities resolved

---

### Add API Versioning (v1/ prefix)
**Priority:** Low
**Effort:** 2-3 hours

**Implementation Plan:**
1. Create `/api/v1/` route prefix
2. Move all routes under v1
3. Document versioning strategy
4. Plan for v2 migration

---

### Add Rate Limiting
**Priority:** Low
**Effort:** 2-3 hours

**Implementation Plan:**
1. Add slowapi dependency
2. Configure limits per endpoint
3. Add rate limit headers
4. Document limits

---

### Create Benchmark Suite
**Priority:** Low
**Effort:** 4-6 hours

**Implementation Plan:**
1. Create performance tests
2. Measure parse times
3. Track regression
4. Document baselines

---

### Enhance Keyword Synonym Database
**Priority:** Low
**Effort:** Ongoing

**Implementation Plan:**
1. Research medical terminology sources
2. Expand synonym mappings
3. Add domain-specific terms
4. Test search improvements

---

### Add More Parse Case Formats
**Priority:** Low
**Effort:** Variable

**Implementation Plan:**
1. Research DICOM-SR format
2. Research HL7 FHIR format
3. Create adapters for new formats
4. Add tests for new parsers

---

## Completed

### 2026-02-04 (Phase 1 Progress)
- ✅ **CORS security fixed** - Environment-based configuration with secure localhost default
  - Modified `src/maps/api/app.py` to use settings
  - Updated `.env.example` with documentation and warnings
- ✅ **All print() statements replaced with logging** - 22 instances across 4 files
  - Added module-level loggers to `parser.py`, `profile_manager.py`, `pylidc_adapter.py`, `parsers/base.py`
  - Used appropriate log levels (info/warning/error)
  - All 37 core tests passing after changes
- ✅ **Security audit task added to backlog**
- ✅ **Documentation updated** - DEVLOG.md, CURRENT-STATE.md, TODO.md, IMPLEMENTATION-PLAN.md
- ✅ Full code review completed
- ✅ CURRENT-STATE.md updated with findings
- ✅ TODO.md reorganized by priority
- ✅ GUI references removed from active docs (4 files updated)
- ✅ INDEX.md verified (already current with new structure)

### 2026-02-03
- ✅ Docs subfolder structure created
- ✅ Documentation files reorganized
- ✅ DEVLOG.md created
- ✅ TODO.md updated to new format

---

## Notes

**Task Selection Criteria:**
- Critical: Security issues, correctness bugs, missing tests for core features
- High: Performance issues, maintainability problems, technical debt
- Medium: Code quality, documentation, additional tests
- Low: Nice-to-haves, future enhancements, optimizations

**Estimated Total Effort:**
- Critical: 8-12 hours (2 of 2 tasks complete)
- High: 13-17 hours
- Medium: 14-19 hours
- Low: 8+ hours (backlog)

**Recommended Order:**
1. ✅ ~~Fix CORS security (30 min)~~
2. ✅ ~~Replace print() with logging (2-3 hrs)~~
3. Add PYLIDC adapter tests (4-6 hrs)
4. Add auto-analysis tests (4-6 hrs)
5. Implement proper caching (3-4 hrs)
6. Add structured logging (4-5 hrs)

---

*For implementation details and patterns, see [CLAUDE.md](CLAUDE.md) operating instructions.*
