"""Statistics endpoints for API usage and system metrics"""

from fastapi import APIRouter
import logging
import psutil
import platform

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/system")
async def get_system_stats():
    """
    Get system resource statistics.

    Returns:
        System CPU, memory, and disk usage
    """
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        return {
            "system": {
                "platform": platform.system(),
                "python_version": platform.python_version(),
            },
            "cpu": {
                "percent": cpu_percent,
                "count": psutil.cpu_count()
            },
            "memory": {
                "total": memory.total,
                "available": memory.available,
                "percent": memory.percent,
                "used": memory.used
            },
            "disk": {
                "total": disk.total,
                "used": disk.used,
                "free": disk.free,
                "percent": disk.percent
            }
        }

    except Exception as e:
        logger.error(f"Failed to get system stats: {e}")
        return {"error": str(e)}


@router.get("/api")
async def get_api_stats():
    """
    Get API usage statistics.

    Returns:
        API endpoint usage metrics
    """
    # Placeholder for future implementation with database tracking
    return {
        "total_requests": 0,
        "endpoints": {},
        "average_response_time": 0.0,
        "error_rate": 0.0
    }
