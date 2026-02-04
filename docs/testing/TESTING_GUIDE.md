# MAPS Testing Suite Documentation

**Last Updated:** November 23, 2025  
**Coverage Goal:** 80%+ for all components

---

## Table of Contents

1. [Overview](#overview)
2. [Web Application Tests](#web-application-tests)
3. [Python Backend Tests](#python-backend-tests)
4. [Running Tests](#running-tests)
5. [Test Coverage](#test-coverage)
6. [Writing New Tests](#writing-new-tests)
7. [CI/CD Integration](#cicd-integration)

---

## Overview

The MAPS testing suite provides comprehensive coverage for both the web frontend (React/TypeScript) and Python backend (FastAPI/Flask). Tests are organized by component type and include unit tests, integration tests, and end-to-end tests.

### Test Stack

**Web Frontend:**
- **Framework:** Vitest + React Testing Library
- **Mocking:** Vitest mock functions
- **Coverage:** V8 code coverage
- **Location:** `web/src/**/*.test.{ts,tsx}`

**Python Backend:**
- **Framework:** pytest
- **Client:** FastAPI TestClient
- **Coverage:** pytest-cov
- **Location:** `tests/test_*.py`

---

## Web Application Tests

### Test Structure

```
web/src/
 components/
    FileUploader/
       FileUploader.tsx
       FileUploader.test.tsx
    BatchProcessor/
       BatchProcessor.test.tsx
    Layout/
        Header.test.tsx
 pages/
    Dashboard.test.tsx
    Upload.test.tsx
    History.test.tsx
    Profiles.test.tsx
 services/
    api.test.ts
 test/
     setup.ts           # Test setup and mocks
     test-utils.tsx     # Testing utilities and helpers
```

### Running Web Tests

```bash
cd web/

# run all tests
npm test

# run tests in watch mode
npm run test:watch

# run tests with coverage
npm run test:coverage

# run tests with UI
npm run test:ui

# run specific test file
npm test Dashboard.test.tsx

# run tests matching pattern
npm test -- --grep "Upload"
```

### Test Utilities

The `test-utils.tsx` file provides:

- `renderWithProviders()` - Render components with React Query + Router
- `createTestQueryClient()` - Create test query client
- `createMockFile()` - Generate mock files for upload tests
- `waitForLoadingToFinish()` - Wait for async operations

**Example Usage:**

```typescript
import { renderWithProviders, screen, waitFor } from '../../test/test-utils';

test('renders dashboard stats', async () => {
  renderWithProviders(<Dashboard />);
  
  await waitFor(() => {
    expect(screen.getByText('150')).toBeInTheDocument();
  });
});
```

### Mocking API Calls

```typescript
import { vi } from 'vitest';
import { apiClient } from '../../services/api';

vi.mock('../../services/api');

beforeEach(() => {
  vi.mocked(apiClient.getDashboardStats).mockResolvedValue({
    total_documents: 150,
    total_jobs: 25,
    // ...
  });
});
```

### Test Categories

**Component Tests:**
- Render correctly with props
- Handle user interactions
- Display error states
- Show loading states
- Validate accessibility

**Page Tests:**
- Load data from API
- Handle navigation
- Submit forms correctly
- Display proper content
- Handle errors gracefully

**Service Tests:**
- API client methods
- Request/response handling
- Error handling
- Data transformation

---

## Python Backend Tests

### Test Structure

```
tests/
 test_api_comprehensive.py      # All API endpoints
 test_integration_workflows.py  # End-to-end workflows
 test_document_repository.py    # Database operations
 test_excel_export.py           # Excel export functionality
 test_pylidc_adapter.py         # PYLIDC integration
 test_foundation_validation.py  # Core validation logic
 test_xml_comp.py               # XML parsing
```

### Running Python Tests

```bash
# run all tests
pytest

# run with verbose output
pytest -v

# run specific test file
pytest tests/test_api_comprehensive.py

# run specific test class
pytest tests/test_api_comprehensive.py::TestProfileEndpoints

# run specific test method
pytest tests/test_api_comprehensive.py::TestProfileEndpoints::test_list_profiles

# run with coverage
pytest --cov=src --cov-report=html --cov-report=term

# run tests matching pattern
pytest -k "test_upload"

# run tests with markers
pytest -m "integration"

# show print statements
pytest -s

# stop on first failure
pytest -x

# run last failed tests
pytest --lf
```

### Test Organization

**test_api_comprehensive.py:**
- Health check endpoints
- Profile CRUD operations
- File upload endpoints
- Job management
- Export functionality
- Analytics endpoints
- Keyword operations

**test_integration_workflows.py:**
- XML parsing → DataFrame workflow
- XML → Excel export workflow
- Database create/read/update/delete
- Keyword extraction → storage
- Multi-format export
- API upload → process → export

### Writing Backend Tests

**Example Test:**

```python
import pytest
from fastapi.testclient import TestClient
from start_api import app

client = TestClient(app)

class TestMyFeature:
    def test_feature_success(self):
        """Test successful feature execution"""
        response = client.get("/api/v1/feature")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
    
    def test_feature_error_handling(self):
        """Test feature error handling"""
        response = client.get("/api/v1/feature?invalid=param")
        assert response.status_code == 400
        
    @pytest.fixture
    def sample_data(self):
        """Fixture for test data"""
        return {"field": "value"}
```

### Fixtures and Helpers

**Common Fixtures:**

```python
@pytest.fixture
def sample_xml_file():
    """Create temporary XML file"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
        f.write(xml_content)
        yield f.name
    Path(f.name).unlink(missing_ok=True)

@pytest.fixture
def test_profile():
    """Create test profile"""
    return {
        "profile_name": "test",
        "file_type": "xml",
        "mappings": [],
        "validation_rules": {"required_fields": []},
    }
```

---

## Test Coverage

### Current Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| Web Components | 80% | TBD |
| Web Pages | 80% | TBD |
| Web Services | 90% | TBD |
| Python API | 85% | TBD |
| Python Core | 80% | TBD |
| Python Exporters | 80% | TBD |

### Generating Coverage Reports

**Web Coverage:**

```bash
cd web/
npm run test:coverage

# view HTML report
open coverage/index.html
```

**Python Coverage:**

```bash
pytest --cov=src --cov-report=html --cov-report=term

# view HTML report
open htmlcov/index.html
```

### Coverage Configuration

**Web (vitest.config.ts):**

```typescript
coverage: {
  provider: 'v8',
  reporter: ['text', 'json', 'html', 'lcov'],
  lines: 80,
  functions: 80,
  branches: 80,
  statements: 80,
}
```

**Python (pytest.ini or pyproject.toml):**

```ini
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*

[coverage:run]
source = src
omit = 
    */test/*
    */tests/*
    */__pycache__/*
    */venv/*

[coverage:report]
precision = 2
show_missing = True
skip_covered = False
```

---

## Writing New Tests

### Web Component Test Template

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderWithProviders, screen, waitFor } from '../../test/test-utils';
import { MyComponent } from './MyComponent';

describe('MyComponent', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders correctly with props', () => {
    renderWithProviders(<MyComponent prop="value" />);
    expect(screen.getByText('Expected Text')).toBeInTheDocument();
  });

  it('handles user interaction', async () => {
    const mockCallback = vi.fn();
    renderWithProviders(<MyComponent onAction={mockCallback} />);
    
    const button = screen.getByRole('button', { name: /action/i });
    await userEvent.click(button);
    
    expect(mockCallback).toHaveBeenCalledTimes(1);
  });

  it('displays loading state', () => {
    renderWithProviders(<MyComponent loading={true} />);
    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });

  it('handles errors gracefully', () => {
    renderWithProviders(<MyComponent error="Error message" />);
    expect(screen.getByText(/error message/i)).toBeInTheDocument();
  });
});
```

### Python Backend Test Template

```python
import pytest
from fastapi.testclient import TestClient

class TestMyEndpoint:
    """Test MyEndpoint functionality"""

    def test_success_case(self, client):
        """Test successful request"""
        response = client.get("/api/v1/endpoint")
        assert response.status_code == 200
        data = response.json()
        assert "expected_field" in data

    def test_validation_error(self, client):
        """Test request validation"""
        response = client.post("/api/v1/endpoint", json={})
        assert response.status_code == 422

    def test_not_found(self, client):
        """Test 404 response"""
        response = client.get("/api/v1/endpoint/nonexistent")
        assert response.status_code == 404

    @pytest.fixture
    def sample_data(self):
        """Fixture providing test data"""
        return {"field": "value"}
```

### Testing Best Practices

1. **Follow AAA Pattern:** Arrange, Act, Assert
2. **One Assertion Per Test:** Focus each test on one behavior
3. **Clear Test Names:** Use descriptive names that explain what's being tested
4. **Mock External Dependencies:** Isolate the code under test
5. **Test Edge Cases:** Don't test happy paths
6. **Use Fixtures:** Reuse common setup code
7. **Keep Tests Fast:** Avoid slow operations like file I/O when possible
8. **Test Error Paths:** Verify error handling
9. **Maintain Test Data:** Use realistic but small test datasets
10. **Clean Up:** Always clean up test artifacts

---

## CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/test.yml`:

```yaml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  web-tests:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./web
    
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: web/package-lock.json
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linter
        run: npm run lint
      
      - name: Run tests
        run: npm run test:run
      
      - name: Generate coverage
        run: npm run test:coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./web/coverage/lcov.info
          flags: web

  python-tests:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest pytest-cov
      
      - name: Run tests
        run: pytest --cov=src --cov-report=xml --cov-report=term
      
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.xml
          flags: python
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running pre-commit tests..."

# run web tests
cd web
npm run test:run --silent
WEB_EXIT=$?

# run python tests
cd ..
pytest --tb=short -q
PYTHON_EXIT=$?

# check results
if [ $WEB_EXIT -ne 0 ] || [ $PYTHON_EXIT -ne 0 ]; then
    echo " Tests failed. Commit aborted."
    exit 1
fi

echo " All tests passed!"
exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

---

## Troubleshooting

### Common Issues

**Web Tests:**

1. **"Cannot find module" errors:**
   - Check import paths
   - Verify `tsconfig.json` paths configuration
   - Ensure `vitest.config.ts` resolve aliases are correct

2. **Tests timeout:**
   - Increase timeout in test: `it('test', { timeout: 10000 }, async () => {})`
   - Check for unmocked API calls
   - Verify async operations complete

3. **Mocking not working:**
   - Use `vi.mock()` before imports
   - Clear mocks in `beforeEach()`
   - Verify mock implementation

**Python Tests:**

1. **Import errors:**
   - Verify `PYTHONPATH` includes `src/`
   - Check for circular imports
   - Ensure `__init__.py` files exist

2. **Database connection errors:**
   - Use test database or mocks
   - Check environment variables
   - Verify database migrations

3. **Fixture errors:**
   - Check fixture scope
   - Verify fixture dependencies
   - Use `pytest --fixtures` to list available fixtures

---

## Additional Resources

- [Vitest Documentation](https://vitest.dev/)
- [React Testing Library](https://testing-library.com/react)
- [pytest Documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)

---

## Maintaining Tests

### Review Checklist

- [ ] All new features have tests
- [ ] Tests cover happy path and edge cases
- [ ] Error handling is tested
- [ ] Coverage meets minimum thresholds
- [ ] Tests run successfully in CI
- [ ] No flaky tests
- [ ] Test names are descriptive
- [ ] Tests are independent
- [ ] Mocks are properly cleaned up
- [ ] Documentation is updated

### Regular Maintenance

- Review and update tests when features change
- Remove tests for deprecated features
- Refactor tests when patterns improve
- Keep test data realistic and current
- Monitor test execution time
- Fix flaky tests immediately
- Update dependencies regularly
