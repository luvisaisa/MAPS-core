"""Health check endpoints"""

from fastapi import APIRouter
from datetime import datetime

router = APIRouter()


@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "MAPS API",
        "version": "1.0.0"
    }


@router.get("/status")
async def status():
    """Detailed status endpoint"""
    return {
        "status": "operational",
        "components": {
            "parser": "ready",
            "profiles": "ready",
            "keywords": "ready"
        },
        "timestamp": datetime.utcnow().isoformat()
    }
