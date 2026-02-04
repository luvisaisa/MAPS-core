# Test Coverage Report

**Date:** November 24, 2025
**Version:** 1.0.0
**Test Runner:** pytest with pytest-cov

## Summary

Test coverage analysis completed. Overall coverage is **40%** with significant gaps in utility modules and extractors.

## Test Suite Statistics

- **Total Tests:** 169 collected (1 broken test excluded)
- **Test Execution:** 75 passed, 23 failed, 14 skipped
- **Coverage:** 40% overall (4,682 of 7,807 lines)
- **Broken Test:** `tests/test_database.py` (collection error)

## Coverage by Module Category

### ✅ Excellent Coverage (>80%)

| Module | Coverage | Lines | Missing |
|--------|----------|-------|---------|
| schemas/profile.py | 93% | 145 | 10 |
| exporters/base.py | 91% | 32 | 3 |
| exporters/excel_exporter.py | 91% | 183 | 16 |
| gui.py | 87% | 23 | 3 |
| schemas/canonical.py | 82% | 166 | 30 |

**Assessment:** Schema and export layers well-tested.

### ⚠️ Good Coverage (60-80%)

| Module | Coverage | Lines | Missing |
|--------|----------|-------|---------|
| keyword_normalizer.py | 72% | 134 | 37 |
| xml_keyword_extractor.py | 66% | 168 | 57 |
| detectors/parse_case_schemas.py | 61% | 28 | 11 |
| pdf_keyword_extractor.py | 60% | 197 | 79 |

**Assessment:** Keyword extraction reasonably tested.

### ⚠️ Moderate Coverage (40-60%)

| Module | Coverage | Lines | Missing |
|--------|----------|-------|---------|
| parsers/base.py | 54% | 41 | 19 |
| profile_manager.py | 54% | 211 | 98 |
| keyword_search_engine.py | 48% | 158 | 82 |
| parser.py | 48% | 515 | 269 |
| profiles/lidc_idri_profile.py | 48% | 27 | 14 |

**Assessment:** Core parsing logic needs more test coverage.

### ❌ Poor Coverage (<40%)

| Module | Coverage | Lines | Missing |
|--------|----------|-------|---------|
| structure_detector.py | 21% | 261 | 205 |
| parsers/legacy_radiology.py | 15% | 91 | 77 |
| detectors/xml_structure_detector.py | 14% | 321 | 275 |
| sqlite_database.py | 13% | 144 | 125 |
| parsers/xml_parser.py | 12% | 261 | 229 |

**Assessment:** Structure detection and legacy code critically under-tested.

### ❌ No Coverage (0%)

| Module | Lines |
|--------|-------|
| extractors/base.py | 34 |
| extractors/factory.py | 40 |
| extractors/pdf_keyword_extractor.py | 211 |
| extractors/xml_keyword_extractor.py | 167 |
| lidc_3d_utils.py | 194 |
| pylidc_supabase_bridge.py | 136 |
| radiologist_exporter.py | 117 |
| supabase.py | 37 |
| utils.py | 22 |

**Assessment:** Utility modules and extractors completely untested.

## Test Failures Analysis

### API Tests (23 failures)

**Module:** `tests/test_api_comprehensive.py`

**Failure Categories:**
1. Health check tests (1 failure)
2. Profile endpoint tests (3 failures)
3. File upload tests (7 failures)
4. Job management tests (4 failures)
5. Export tests (4 failures)
6. Analytics tests (4 failures)
7. Keyword tests (3 failures)

**Root Cause:** Most failures appear to be integration test issues, likely:
- Database connection not configured for tests
- Missing test fixtures
- API dependencies not mocked

## Critical Coverage Gaps

### 1. Database Layer (13% coverage)

**Impact:** HIGH
**Files:**
- `sqlite_database.py` - 13%
- Test database connections, CRUD operations, migrations

**Recommendation:**
- Add unit tests with in-memory SQLite
- Test all public methods
- Test error handling

### 2. XML Parsers (12-15% coverage)

**Impact:** HIGH
**Files:**
- `parsers/xml_parser.py` - 12%
- `parsers/legacy_radiology.py` - 15%

**Recommendation:**
- Test with various XML formats
- Test error conditions (malformed XML)
- Test all parse cases

### 3. Extractors (0% coverage)

**Impact:** MEDIUM
**Files:**
- All extractor modules completely untested
- PDF and XML keyword extraction

**Recommendation:**
- Add integration tests with sample files
- Test keyword normalization
- Test edge cases (empty files, special characters)

### 4. Utility Modules (0% coverage)

**Impact:** LOW
**Files:**
- `utils.py`, `supabase.py`, `lidc_3d_utils.py`

**Recommendation:**
- Add unit tests for utility functions
- Test 3D visualization utilities
- Test Supabase integration

## Recommendations

### High Priority (Before Production)

1. **Fix test_database.py Collection Error**
   - AttributeError blocking test execution
   - Debug and fix immediately

2. **Increase Core Parser Coverage to >70%**
   - Focus on `parser.py` (currently 48%)
   - Focus on `xml_parser.py` (currently 12%)
   - Add tests for all parse cases

3. **Add Database Layer Tests**
   - Target: 60%+ coverage
   - Test CRUD operations
   - Test connection pooling
   - Test error handling

### Medium Priority

4. **Add Extractor Tests**
   - Target: 50%+ coverage
   - Test PDF and XML keyword extraction
   - Test with sample documents

5. **Fix API Integration Tests**
   - Investigate 23 API test failures
   - Add proper test fixtures
   - Mock external dependencies

6. **Increase Structure Detector Coverage**
   - Target: 50%+ coverage
   - Test XML structure detection
   - Test parse case identification

### Low Priority

7. **Add Utility Tests**
   - Target: 60%+ coverage
   - Test 3D utilities
   - Test Supabase integration

8. **Improve Profile Manager Tests**
   - Current: 54%, Target: 70%+
   - Test profile validation
   - Test profile import/export

## Testing Best Practices

### Unit Test Guidelines

1. **Use pytest fixtures**
   ```python
   @pytest.fixture
   def sample_xml():
       return """<?xml version="1.0"?>
       <root><data>test</data></root>"""
   ```

2. **Mock external dependencies**
   ```python
   @patch('maps.database.models.Session')
   def test_with_mocked_db(mock_session):
       pass
   ```

3. **Test edge cases**
   - Empty inputs
   - Invalid inputs
   - Boundary conditions
   - Error conditions

### Integration Test Guidelines

1. **Use test databases**
   - In-memory SQLite for fast tests
   - Test PostgreSQL instance for integration

2. **Clean up after tests**
   - Use fixtures with teardown
   - Rollback database transactions

3. **Test real workflows**
   - End-to-end parsing
   - Database persistence
   - Export generation

## Coverage Goals

### Short Term (1 Month)

- Overall: 40% → 60%
- Core parsers: 48% → 70%
- Database: 13% → 60%
- Extractors: 0% → 40%

### Long Term (3 Months)

- Overall: 60% → 80%
- All core modules: >70%
- Utilities: >60%
- Critical paths: 100%

## CI/CD Integration

### GitHub Actions

Add coverage checks to CI:
```yaml
- name: Run tests with coverage
  run: |
    pytest --cov=src/maps --cov-report=xml --cov-fail-under=60

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
```

### Pre-commit Hooks

Require minimum coverage for changed files:
```bash
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: pytest-cov
      name: pytest coverage check
      entry: pytest --cov=src/maps --cov-fail-under=40
```

## Conclusion

Test coverage is **insufficient** for production deployment:

**Strengths:**
- Schemas well-tested (82-93%)
- Exporters well-tested (91%)
- Test suite exists and runs

**Critical Gaps:**
- Core parsers under-tested (12-48%)
- Database layer critically low (13%)
- Extractors completely untested (0%)
- 23 API tests failing

**Action Required:**
Before production, achieve:
- 60%+ overall coverage
- 70%+ on core parsing
- 60%+ on database operations
- Fix all broken tests

Current coverage makes regression detection difficult and increases bug risk in production.

---

**Next Steps:**
1. Fix `test_database.py` collection error
2. Add tests for high-priority modules
3. Reach 60% overall coverage milestone

**Last Updated:** November 24, 2025
