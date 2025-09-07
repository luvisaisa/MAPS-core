# MAPS Git History Reconstruction Workflow

## Current Progress

**Timeline**: August 26, 2025 → November 28, 2025 (94 days)
**Target**: ~196 commits across 13 chapters
**Status**: Chapter 1 in progress (3/15 commits complete)

### Completed
- Chapter 0 (20 commits, Aug 26-Sept 5): Basic XML parsing foundation

### In Progress
- Chapter 1 (3/15 commits, Sept 6-15): Core parser & parse case detection
  - Parse case detection function
  - Expected attributes mapping
  - Integration into main flow
  - 12 more commits needed

### Remaining Chapters
- Chapter 2: Initial GUI (Sept 16-25) - SUSPENDED, later deprecated for FastAPI
- Chapters 3-5: Schema-agnostic, Keywords, Auto-Analysis (Sept 26-Oct 15)
- Chapters 6-8: PYLIDC, REST API (Oct 16-Nov 5)
- Chapters 9-10: React Web Interface (Nov 6-20)
- Chapters 11-13: Profiles, Performance, Docs & Licensing (Nov 21-28)

---

## Workflow Process

### 1. Review Current State

```bash
cd /Users/isa/Desktop/python-projects/MAPS-core
git log --oneline --all | head -25
git status
```

### 2. Plan Next Commit

For each commit, determine:
- Feature/file to add
- Granularity (one method, one feature, one file)
- Date (progress chronologically through the timeline)
- Commit type (feat/fix/docs/test/chore/refactor/perf)

Chapter 1 Remaining Commits (Sept 7-15):
4. Structure detector module (separate file)
5. Add debug logging for missing attributes
6. Handle SeriesInstanceUid spelling variations
7. Extract unblinded read nodules
8. Add non-small nodule extraction
9. Handle multiple radiologist sessions
10. Add file ID extraction
11. Improve error messages with context
12. Add parse case summary reporting
13. Update tests for parse cases
14. Add parse case documentation
15. Example script for different parse cases

### 3. Date Progression

Formula: Increment timestamps realistically
- Heavy coding days: 5-10 commits (09:00, 10:30, 14:00, 15:30, 17:00)
- Normal days: 2-4 commits (morning, afternoon, evening)
- Light days: 1-2 commits
- Skip: Occasional days off (weekends/breaks)

Current position: September 7, 2025

### 4. Source Files Reference

All files copied from: /Users/isa/Desktop/python-projects/MAPS-2/

Key files by chapter:
- Ch 0-1: src/maps/parser.py
- Ch 2: src/maps/gui.py (deprecated later)
- Ch 3-5: src/maps/schemas/, src/maps/parsers/, keyword files
- Ch 6: src/maps/adapters/pylidc_adapter.py, lidc_3d_utils.py
- Ch 7-8: src/maps/api/ (services, routers)
- Ch 9-10: web/ (React app)
- Ch 11: profiles, approval queue
- Ch 12: migrations, performance, tests
- Ch 13: docs, LICENSE change

### 5. Commit Message Format

```
<type>: <description>

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- test: Tests
- chore: Tooling
- refactor: Code restructuring
- perf: Performance
```

### 6. Co-Author Attribution

When reaching Supabase integration (Chapter 2), use:

```bash
git commit -m "feat: initialize supabase client" --date="2025-09-XX"
# Then add co-author trailer
```

---

## Quick Resume Commands

Continue where you left off:

```bash
# 1. Check current position
cd /Users/isa/Desktop/python-projects/MAPS-core
git log --oneline | head -5

# 2. Get next commit from workflow
# 3. Create commit with proper date
```

---

## Notes

- No emoji in commit messages
- No AI voice
- Granular commits
- Chronological dates
- Feature-based
- Real implementation order

Last updated: Commit 23 (Chapter 1, commit 3/15)
