# MAPS GUI Guide

## Overview

The MAPS GUI provides a user-friendly interface for parsing medical imaging XML files.

## Features

- File selection (individual or batch)
- Folder selection (recursive XML discovery)
- Progress tracking with visual progress bar
- Real-time status logging
- Excel export

## Usage

### Launch GUI

```bash
python scripts/launch_gui.py
```

### Parse Files

1. Select mode: Files or Folder
2. Choose XML files or folder containing XML files
3. Select output folder for results
4. Click "Parse Files"
5. Monitor progress in status log

### Output

Results are exported to Excel in the selected output folder as `parsed_results.xlsx`.

## Requirements

- Python 3.8+
- tkinter (usually included with Python)
- All dependencies from requirements.txt
