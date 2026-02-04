# Contributing to MAPS

Thank you for your interest in contributing to MAPS!

## Development Setup

1. Fork the repository
2. Clone your fork:
```bash
git clone https://github.com/YOUR_USERNAME/MAPS-core.git
cd MAPS-core
```

3. Create virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate
```

4. Install in development mode:
```bash
pip install -e .
pip install pytest pytest-cov black flake8 mypy
```

## Code Style

We follow PEP 8 with some modifications:

- Line length: 100 characters (flexible)
- Use Black for formatting
- Type hints required for public APIs
- Docstrings: Google style

### Formatting

```bash
# Format code
black src/ tests/ --line-length 100

# Check style
flake8 src/ tests/ --max-line-length 100

# Type checking
mypy src/maps/
```

## Testing

### Running Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=src/maps --cov-report=html

# Specific test file
pytest tests/test_parser.py

# Specific test
pytest tests/test_parser.py::test_parse_radiology_sample
```

### Writing Tests

```python
import pytest
from maps import parse_radiology_sample

def test_parse_valid_xml():
    """Test parsing valid XML file"""
    result = parse_radiology_sample('tests/data/valid.xml')
    assert result is not None
    assert len(result) > 0

@pytest.fixture
def sample_xml_path():
    """Fixture providing sample XML path"""
    return 'tests/data/sample.xml'

def test_with_fixture(sample_xml_path):
    """Test using fixture"""
    result = parse_radiology_sample(sample_xml_path)
    assert result is not None
```

## Pull Request Process

1. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes
3. Add tests for new functionality
4. Run tests and linters:
```bash
pytest
black src/ tests/
flake8 src/ tests/
```

5. Commit your changes:
```bash
git add .
git commit -m "description of changes"
```

6. Push to your fork:
```bash
git push origin feature/your-feature-name
```

7. Create Pull Request on GitHub

### PR Guidelines

- Clear description of changes
- Reference any related issues
- Include tests for new features
- Update documentation as needed
- Ensure all tests pass
- Follow code style guidelines

## Project Structure

```
MAPS-core/
├── src/maps/           # Main package
│   ├── parser.py       # Core parsing
│   ├── schemas/        # Pydantic models
│   ├── parsers/        # Parser implementations
│   ├── api/            # REST API
│   └── adapters/       # External integrations
├── tests/              # Test suite
├── docs/               # Documentation
├── examples/           # Usage examples
└── scripts/            # Utility scripts
```

## Adding Features

### New Parser

1. Implement `BaseParser` interface
2. Add to `src/maps/parsers/`
3. Write tests in `tests/`
4. Add example to `examples/`
5. Update documentation

### New Profile

1. Create profile JSON in `profiles/`
2. Test with sample data
3. Validate with ProfileManager
4. Add to documentation

### New API Endpoint

1. Add router in `src/maps/api/routers/`
2. Register in `app.py`
3. Add tests in `tests/test_api.py`
4. Update `docs/API_ENDPOINTS.md`

## Documentation

### Docstring Format

```python
def parse_radiology_sample(file_path: str) -> pd.DataFrame:
    """Parse radiology XML file.

    Args:
        file_path: Path to XML file

    Returns:
        DataFrame containing parsed data

    Raises:
        FileNotFoundError: If file doesn't exist
        ParsingError: If XML is invalid

    Examples:
        >>> df = parse_radiology_sample('data/sample.xml')
        >>> len(df)
        5
    """
    pass
```

### Updating Docs

- Keep README.md current
- Update relevant guides in `docs/`
- Add examples for new features
- Update API documentation

## Bug Reports

When reporting bugs, include:

1. MAPS version
2. Python version
3. Operating system
4. Steps to reproduce
5. Expected vs actual behavior
6. Error messages/stack traces
7. Sample data (if possible)

## Feature Requests

When requesting features:

1. Clear description of feature
2. Use case and motivation
3. Proposed implementation (optional)
4. Examples of similar features

## Code Review

All submissions require review. We look for:

- Code quality and style
- Test coverage
- Documentation
- Performance impact
- Backward compatibility
- Security considerations

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
