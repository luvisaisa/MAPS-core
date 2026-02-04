# MAPS Testing Quick Reference

Quick commands for running tests in the MAPS project.

---

## Web Frontend Tests

```bash
cd web/

# quick test run
npm test

# watch mode (auto-rerun on changes)
npm run test:watch

# with coverage report
npm run test:coverage

# interactive UI
npm run test:ui

# specific file
npm test Dashboard.test.tsx

# pattern matching
npm test -- --grep "upload"
```

**View Coverage:**
```bash
cd web/
npm run test:coverage
open coverage/index.html
```

---

## Python Backend Tests

```bash
# all tests
pytest

# verbose output
pytest -v

# specific file
pytest tests/test_api_comprehensive.py

# specific test class
pytest tests/test_api_comprehensive.py::TestProfileEndpoints

# specific test
pytest tests/test_api_comprehensive.py::TestProfileEndpoints::test_list_profiles

# pattern matching
pytest -k "upload"

# with coverage
pytest --cov=src --cov-report=html --cov-report=term

# stop on first failure
pytest -x

# show print statements
pytest -s

# run last failed
pytest --lf
```

**View Coverage:**
```bash
pytest --cov=src --cov-report=html
open htmlcov/index.html
```

---

## Integration Tests

```bash
# all integration tests
pytest tests/test_integration_workflows.py -v

# specific workflow
pytest tests/test_integration_workflows.py::TestXMLParsingWorkflow -v
```

---

## Run All Tests

```bash
# web tests
cd web/ && npm test && cd ..

# python tests
pytest -v

# or use make (if configured)
make test
```

---

## CI/CD

Tests run automatically on:
- Push to `main` or `develop`
- Pull requests to `main` or `develop`

**Workflow:** `.github/workflows/test.yml`

**Jobs:**
- `web-tests` - Frontend tests with coverage
- `python-tests` - Backend tests on Python 3.11 & 3.12
- `integration-tests` - End-to-end workflows
- `test-report` - Summary and artifacts

---

## Coverage Goals

| Component | Target |
|-----------|--------|
| Web Components | 80% |
| Web Pages | 80% |
| Web Services | 90% |
| Python API | 85% |
| Python Core | 80% |
| Python Exporters | 80% |

---

## Pre-commit Testing

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
cd web && npm run test:run --silent && cd ..
pytest --tb=short -q
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## Troubleshooting

**Tests won't run:**
```bash
# web - reinstall dependencies
cd web/
rm -rf node_modules package-lock.json
npm install

# python - reinstall dependencies
pip install -r requirements.txt
pip install pytest pytest-cov
```

**Import errors:**
```bash
# add src to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)/src"
```

**Timeout errors:**
```typescript
// increase timeout in test
it('slow test', { timeout: 10000 }, async () => {
  // test code
});
```

---

## Useful Commands

```bash
# list all tests without running
pytest --collect-only

# run tests in parallel (requires pytest-xdist)
pytest -n auto

# run with specific marker
pytest -m "integration"

# generate JUnit XML report
pytest --junitxml=report.xml

# web: update snapshots
npm test -- -u

# web: run in different browser
npm test -- --browser=firefox
```

---

## Documentation

- **Full Guide:** [docs/TESTING_GUIDE.md](./TESTING_GUIDE.md)
- **Vitest Docs:** https://vitest.dev/
- **pytest Docs:** https://docs.pytest.org/
- **Testing Library:** https://testing-library.com/

---

## Quick Test Status Check

```bash
# check web test status
cd web/ && npm test -- --reporter=json > test-results.json

# check python test status
pytest --tb=no -q

# check coverage
pytest --cov=src --cov-report=term-missing | grep TOTAL
```
