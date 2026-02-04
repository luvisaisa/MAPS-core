# TODO - Active Development Tasks

Current working tasks with implementation plans. Completed tasks move to [DEVLOG.md](docs/DEVLOG.md).

---

## In Progress

### Documentation Reorganization
**Started:** 2026-02-03

**Implementation Plan:**
1. Create docs subfolder structure
2. Move docs to appropriate subfolders
3. Create CURRENT-STATE.md
4. Create DEVLOG.md
5. Update TODO.md
6. Update INDEX.md

**Status:**
- [x] Create subfolder structure (guides/, api/, database/, features/, keywords/, testing/, performance/, archive/)
- [x] Move 52 documentation files to subfolders
- [x] Create docs/CURRENT-STATE.md
- [x] Create docs/DEVLOG.md
- [x] Update TODO.md format
- [ ] Update docs/INDEX.md for new structure

---

## Pending Tasks

### Add PYLIDC Adapter Tests
**Priority:** High

**Implementation Plan:**
1. Create tests/test_pylidc_adapter.py
2. Add unit tests for scan conversion
3. Add tests for consensus metrics
4. Add tests for nodule clustering
5. Mock PYLIDC dependencies for isolation
6. Verify all adapter methods covered

**Acceptance Criteria:**
- 80%+ coverage on pylidc_adapter.py
- All public methods have at least one test
- Tests run without external PYLIDC database

---

### Add Auto-Analysis Tests
**Priority:** High

**Implementation Plan:**
1. Create tests/test_auto_analysis.py
2. Add tests for XMLKeywordExtractor
3. Add tests for AutoAnalyzer
4. Test semantic mapping functions
5. Test batch analysis with statistics
6. Add edge case tests

**Acceptance Criteria:**
- Coverage for xml_keyword_extractor.py
- Coverage for auto_analysis.py
- All extraction paths tested

---

### Remove GUI References from Docs
**Priority:** Medium

**Implementation Plan:**
1. Search docs for "GUI", "Tkinter", "gui.py" references
2. Remove or update outdated sections
3. Update any screenshots or diagrams
4. Verify all links still work

---

### Add Structured Logging
**Priority:** Medium

**Implementation Plan:**
1. Define JSON log format
2. Create logging configuration module
3. Update middleware to use structured format
4. Add request ID tracking
5. Update existing log statements

---

### API Rate Limiting
**Priority:** Low

**Implementation Plan:**
1. Add slowapi or similar dependency
2. Create rate limit configuration
3. Apply to public endpoints
4. Add rate limit headers to responses
5. Document rate limits in API reference

---

## Backlog

Items for future consideration:

- Add more parse case formats (DICOM-SR, HL7 FHIR)
- Enhance keyword synonym database
- Add API versioning (v1/, v2/)
- Create benchmark suite for performance tracking
- Add WebSocket support for streaming analysis
- Create React admin dashboard

---

## Completed (Move to DEVLOG)

### 2026-02-03
- Docs subfolder structure created
- Documentation files reorganized
- CURRENT-STATE.md created
- DEVLOG.md created
- TODO.md updated to new format

---

*When adding tasks, include an implementation plan using the pydev-feature workflow pattern.*
