# MAPS Implementation Plan - Code Quality Improvements

**Created:** 2026-02-04
**Based on:** Full code review of MAPS-core v1.0.1

---

## Executive Summary

After comprehensive code review of 4,571 lines of Python source code:

**Overall Assessment:** ✅ Good
- Architecture: Clean, well-organized
- Test Status: 43 tests passing, but gaps exist
- Code Quality: High - good patterns, type hints, no major issues
- Security: Minor issues (CORS configuration)
- Performance: Acceptable, some optimization opportunities

**Critical Issues Found:** 3
**High Priority Issues:** 5
**Medium Priority Issues:** 4
**Low Priority Enhancements:** 5

**Estimated Total Effort:** 46-58 hours

---

## Phase 1: Critical Fixes (11-15 hours)

### Week 1 Focus: Security & Core Stability

#### Task 1.1: Fix CORS Security (30 min) ✅ COMPLETED
**Risk Level:** High - Security vulnerability
**Impact:** High - Production security
**Status:** Complete - 2026-02-04

**Why Critical:**
- Current `allow_origins=["*"]` allows any domain
- Exposes API to CSRF attacks
- Easy fix with high security impact

**Implementation:**
```python
# config.py
cors_origins: List[str] = Field(
    default_factory=lambda: os.getenv("CORS_ORIGINS", "").split(",")
)

# app.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,  # Not ["*"]
    ...
)
```

**Files Modified:**
- `src/maps/api/config.py` - Already had cors_origins in config
- `src/maps/api/app.py` - Changed to use settings.cors_origins
- `.env.example` - Updated with secure default and warnings

**Result:** CORS now configurable via environment, defaults to localhost only

---

#### Task 1.2: Replace print() with Logging (2-3 hours) ✅ COMPLETED
**Risk Level:** Medium - Production observability
**Impact:** High - Log aggregation, debugging
**Status:** Complete - 2026-02-04

**Why Critical:**
- 22 print statements bypass logging infrastructure
- No log levels, no timestamps, goes to stdout
- Can't filter, aggregate, or analyze in production

**Implementation:**
```python
# Before
print(f"Parsing XML file: {filename}")
print(f"  Warning: {field} expected but MISSING")

# After
logger.info(f"Parsing XML file: {filename}")
logger.warning(f"Expected field missing: {field}")
```

**Files Modified:**
- `src/maps/parser.py` - 6 print statements replaced
- `src/maps/profile_manager.py` - 12 print statements replaced
- `src/maps/adapters/pylidc_adapter.py` - 1 print statement replaced
- `src/maps/parsers/base.py` - 1 print statement replaced

**Verification:**
```bash
# Returns 0 - all print statements removed
grep -r "print(" src/maps --include="*.py" | wc -l
```

**Result:** All 22 print statements replaced with appropriate logging levels (info, warning, error)

---

#### Task 1.3: Add PYLIDC Adapter Tests (4-6 hours) ✅ COMPLETED
**Risk Level:** High - Untested integration code
**Impact:** High - Data integrity, refactoring safety
**Status:** Complete - 2026-02-04

**Why Critical:**
- 278 lines of adapter code, 0 tests
- Handles critical scan conversion and consensus calculations
- Can't safely modify or refactor

**Test Structure:**
```python
# tests/test_pylidc_adapter.py

class TestPyLIDCAdapter:
    def test_scan_to_canonical_basic(self, mock_scan):
        """Test basic scan conversion"""
        
    def test_scan_to_canonical_with_annotations(self, mock_scan):
        """Test scan with annotation data"""
        
    def test_cluster_to_nodule(self, mock_annotations):
        """Test annotation clustering"""
        
    def test_calculate_consensus(self, mock_annotations):
        """Test consensus metric calculation"""
        
    def test_batch_conversion(self, mock_scans):
        """Test batch scan processing"""
        
    def test_error_handling(self, invalid_scan):
        """Test error cases"""
```

**Coverage Goal:** >80%

**Implementation:**
- Created `tests/conftest.py` with comprehensive pylidc mock fixtures
- Created `tests/test_pylidc_adapter.py` with 16 test cases
- All test methods cover:
  - Initialization with/without pylidc
  - Basic scan conversion
  - Annotation handling with/without clustering
  - Consensus calculation with complete/partial data
  - Batch processing with progress callbacks
  - Error handling in batch operations
  - Statistics extraction

**Files Created:**
- `tests/conftest.py` - Pytest fixtures for mock pylidc objects
- `tests/test_pylidc_adapter.py` - 16 comprehensive tests

**Verification:**
```bash
# All tests pass
pytest tests/test_pylidc_adapter.py -v
# => 16 passed, 1 skipped
```

**Result:** PyLIDC adapter now has comprehensive test coverage for all public methods and error paths

---

#### Task 1.4: Add Auto-Analysis Tests (4-6 hours) 🔴
**Risk Level:** High - Untested feature module
**Impact:** High - Entity extraction accuracy

**Why Critical:**
- 269 lines of analysis code, 0 tests
- Handles automatic entity extraction (core feature)
- Integration with keyword extractor untested

**Test Structure:**
```python
# tests/test_auto_analysis.py

class TestAutoAnalyzer:
    def test_analyze_xml_basic(self, sample_xml):
        """Test basic XML analysis"""
        
    def test_extract_entities_from_keywords(self):
        """Test entity extraction logic"""
        
    def test_calculate_confidence(self):
        """Test confidence scoring"""
        
    def test_analyze_batch(self, sample_xml_files):
        """Test batch analysis"""
        
    def test_get_analysis_summary(self, analyzed_docs):
        """Test summary statistics"""
```

**Coverage Goal:** >80%

---

## Phase 2: High Priority (13-17 hours)

### Week 2-3 Focus: Performance & Maintainability

#### Task 2.1: Implement Proper Caching (3-4 hours) 🟡
**Risk Level:** Medium - Memory leak potential
**Impact:** Medium - Production stability

**Problem:**
- Current SimpleCache has no cleanup
- Expired entries never removed (memory leak)
- No max size limit (unbounded growth)

**Solution Options:**

**Option A: functools.lru_cache + TTL wrapper (Recommended)**
```python
from functools import lru_cache
from cachetools import TTLCache

# Simple, built-in, no dependencies
cache = TTLCache(maxsize=1000, ttl=300)
```

**Option B: Redis (Production-grade)**
```python
import redis
from redis.client import Redis

redis_client = Redis.from_url(settings.redis_url)
```

**Recommendation:** Start with Option A, migrate to Redis if needed.

---

#### Task 2.2: Add Structured Logging (4-5 hours) 🟡
**Risk Level:** Medium - Observability gap
**Impact:** High - Production debugging

**Implementation:**
```python
# logging_config.py
import structlog

structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)

# middleware.py
import uuid

class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        
        logger.info("request_started",
                   request_id=request_id,
                   method=request.method,
                   path=request.url.path)
        
        # ... rest of middleware
```

**Output Format:**
```json
{
  "timestamp": "2026-02-04T10:15:30.123Z",
  "level": "info",
  "event": "request_started",
  "request_id": "a1b2c3d4-...",
  "method": "POST",
  "path": "/api/parse/xml",
  "duration_ms": 234
}
```

---

#### Task 2.3: Add API Pagination (3-4 hours) 🟡
**Risk Level:** Medium - Performance issue
**Impact:** Medium - API usability

**Implementation:**
```python
# models.py
class PaginationParams(BaseModel):
    page: int = Field(default=1, ge=1)
    per_page: int = Field(default=20, ge=1, le=100)

class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    per_page: int
    has_next: bool
    has_prev: bool

# router example
@router.get("/keywords/search")
async def search_keywords(
    query: str,
    pagination: PaginationParams = Depends()
):
    offset = (pagination.page - 1) * pagination.per_page
    results = search_engine.search(
        query, 
        limit=pagination.per_page,
        offset=offset
    )
    return PaginatedResponse(...)
```

**Affected Endpoints:**
- `/api/keywords/search`
- `/api/profiles` (list)
- `/api/analysis/batch` (results)

---

#### Task 2.4: Separate Export Logic (2-3 hours) 🟡
**Risk Level:** Low - Architecture issue
**Impact:** Medium - Code maintainability

**Current Problem:**
```python
# parser.py (mixed concerns)
def parse_radiology_sample(...):
    # Parsing logic
    
def export_excel(...):  # ❌ Export in parser module
    # Export logic
```

**Solution:**
```python
# exporters/excel_exporter.py
class ExcelExporter:
    def export(self, df: pd.DataFrame, output_path: str):
        # Export logic
        
# exporters/csv_exporter.py
class CSVExporter:
    def export(self, df: pd.DataFrame, output_path: str):
        # Export logic
        
# exporters/json_exporter.py
class JSONExporter:
    def export(self, data: dict, output_path: str):
        # Export logic
```

**Files to Create:**
- `src/maps/exporters/__init__.py`
- `src/maps/exporters/base.py`
- `src/maps/exporters/excel_exporter.py`
- `src/maps/exporters/csv_exporter.py`
- `src/maps/exporters/json_exporter.py`

---

## Phase 3: Medium Priority (14-19 hours)

### Week 4-5 Focus: Code Quality & Coverage

#### Task 3.1: Add Integration Tests (6-8 hours) 🟢
**Coverage:** End-to-end workflows

**Test Scenarios:**
1. **Upload → Parse → Store → Export Workflow**
   ```python
   def test_full_parse_workflow():
       # Upload XML file
       response = client.post("/api/parse/xml", files=...)
       # Verify parse success
       assert response.status_code == 200
       # Export to Excel
       response = client.post("/api/export/excel", ...)
       # Verify export
   ```

2. **Batch Processing Workflow**
3. **Keyword Search → Analysis Workflow**
4. **Profile CRUD Workflow**
5. **Error Handling Workflow**

---

#### Task 3.2: Fix Async/Sync Architecture (3-4 hours) 🟢
**Decision Required:** Document current approach or refactor

**Option A: Document Sync-in-Async (Quick)**
```python
# Document that blocking I/O is acceptable
# Add comment to routers:
# Note: Parser operations are CPU-bound, not I/O-bound
# Async here provides API consistency, not concurrency
```

**Option B: Use run_in_executor (Better)**
```python
import asyncio

@router.post("/parse/xml")
async def parse_xml_file(file: UploadFile):
    loop = asyncio.get_event_loop()
    document = await loop.run_in_executor(
        None,  # Use default executor
        parser.parse,
        tmp_path
    )
```

**Recommendation:** Start with Option A (document), evaluate Option B if load testing shows bottlenecks.

---

#### Task 3.3: Create Router Base Class (3-4 hours) 🟢
**Goal:** Reduce duplication in routers

**Base Class:**
```python
# routers/base.py
class BaseRouter:
    """Base router with common patterns"""
    
    @staticmethod
    async def handle_file_upload(
        file: UploadFile,
        allowed_extensions: List[str]
    ) -> str:
        """Handle file upload and return temp path"""
        if not any(file.filename.endswith(ext) for ext in allowed_extensions):
            raise HTTPException(400, "Invalid file type")
            
        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            content = await file.read()
            tmp.write(content)
            return tmp.name
    
    @staticmethod
    def handle_error(e: Exception, tmp_path: str = None):
        """Standard error handling with cleanup"""
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise HTTPException(500, f"Operation failed: {str(e)}")
```

**Usage:**
```python
# routers/parser.py
class ParserRouter(BaseRouter):
    @router.post("/parse/xml")
    async def parse_xml_file(self, file: UploadFile):
        tmp_path = await self.handle_file_upload(file, ['.xml'])
        try:
            # Parse logic
        except Exception as e:
            self.handle_error(e, tmp_path)
```

---

#### Task 3.4: Update Documentation (2-3 hours) 🟢
**Goal:** Remove stale references, update structure

**Tasks:**
1. Search and remove GUI references
   ```bash
   grep -r "GUI\|Tkinter\|gui.py" docs/ -l
   ```
2. Update INDEX.md with new structure
3. Add caching documentation
4. Add logging documentation
5. Verify all internal links

---

## Phase 4: Low Priority / Backlog (8+ hours)

#### Task 4.1: Add API Versioning (2-3 hours) 🔵
**When:** Before v2 breaking changes

**Implementation:**
```python
# app.py
app.include_router(health.router, prefix="/api/v1", tags=["health"])
app.include_router(parser.router, prefix="/api/v1/parse", tags=["parser"])
# ...
```

---

#### Task 4.2: Add Rate Limiting (2-3 hours) 🔵
**When:** Public API deployment

**Implementation:**
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@router.post("/parse/xml")
@limiter.limit("10/minute")
async def parse_xml_file(...):
    ...
```

---

#### Task 4.3: Create Benchmark Suite (4-6 hours) 🔵
**When:** Performance optimization needed

**Tests:**
- Parse 100 XML files, measure time
- Parse 1000 nodule records, measure time
- Keyword search 10,000 terms, measure time
- Track regression over releases

---

## Implementation Timeline

### Sprint 1 (Week 1): Critical Security & Stability
- Day 1: Fix CORS (30 min) + Replace print() (2-3 hrs)
- Day 2-3: Add PYLIDC adapter tests (4-6 hrs)
- Day 4-5: Add auto-analysis tests (4-6 hrs)

**Deliverables:**
- ✅ CORS secured
- ✅ Logging standardized
- ✅ Core adapters tested

---

### Sprint 2 (Week 2): Performance & Observability
- Day 1-2: Implement proper caching (3-4 hrs)
- Day 3-4: Add structured logging (4-5 hrs)
- Day 5: Add API pagination (3-4 hrs)

**Deliverables:**
- ✅ Cache memory leak fixed
- ✅ JSON logging implemented
- ✅ API pagination added

---

### Sprint 3 (Week 3): Code Quality
- Day 1: Separate export logic (2-3 hrs)
- Day 2-4: Add integration tests (6-8 hrs)
- Day 5: Buffer/planning

**Deliverables:**
- ✅ Export logic modularized
- ✅ Integration tests added

---

### Sprint 4 (Week 4): Architecture & Docs
- Day 1-2: Fix async architecture (3-4 hrs)
- Day 3-4: Create router base class (3-4 hrs)
- Day 5: Update documentation (2-3 hrs)

**Deliverables:**
- ✅ Async pattern documented/fixed
- ✅ Router duplication reduced
- ✅ Docs updated

---

## Success Metrics

### Code Quality
- [x] Zero print() statements in src/
- [ ] Test coverage >80% overall
- [ ] All critical modules have tests
- [ ] No bare except clauses
- [ ] No wildcard imports

### Security
- [x] CORS properly configured
- [ ] No hardcoded secrets
- [ ] File upload validation
- [ ] Input sanitization

### Performance
- [ ] Cache with cleanup
- [ ] API response times <500ms
- [ ] Memory usage stable
- [ ] Pagination on all list endpoints

### Observability
- [ ] JSON structured logging
- [ ] Request ID tracking
- [ ] Error categorization
- [ ] Log aggregation ready

---

## Risk Assessment

### High Risk Items
1. **PYLIDC Adapter Tests** - Complex mocking required
2. **Structured Logging** - May break existing log parsing
3. **Integration Tests** - May expose hidden bugs

### Mitigation
- Test in staging first
- Feature flags for new logging
- Comprehensive test coverage before deploy

---

## Decision Log

| Decision | Rationale | Date |
|----------|-----------|------|
| Start with lru_cache, not Redis | Simpler, sufficient for current scale | 2026-02-04 |
| Document async, don't refactor | Not a bottleneck, bigger refactor later | 2026-02-04 |
| Prioritize tests over features | Safety > new functionality | 2026-02-04 |

---

## Next Steps

1. **Review this plan with team**
2. **Approve sprint 1 scope**
3. **Create feature branches:**
   - `fix/cors-security`
   - `fix/replace-print-statements`
   - `test/pylidc-adapter`
   - `test/auto-analysis`
4. **Start Sprint 1 Day 1**

---

**Questions? See:**
- [CURRENT-STATE.md](../../../docs/CURRENT-STATE.md) - Detailed code review
- [TODO.md](../../../TODO.md) - Task list with acceptance criteria
- [CLAUDE.md](../../../CLAUDE.md) - Development patterns and conventions
