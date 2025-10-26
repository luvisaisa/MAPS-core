#!/usr/bin/env python3
"""
MAPS API Server

Launch the FastAPI server for MAPS REST API.
"""

import uvicorn
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


def main():
    """Run the FastAPI server"""
    uvicorn.run(
        "maps.api.app:create_app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        factory=True
    )


if __name__ == "__main__":
    main()
