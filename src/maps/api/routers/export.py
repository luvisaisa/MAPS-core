"""Export endpoints for converting parsed data to various formats"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from typing import Optional
import io
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/excel")
async def export_to_excel(
    data: dict,
    format: str = "standard"
):
    """
    Export parsed data to Excel format.

    Args:
        data: Parsed document data
        format: Export format (standard, template, multi-folder)

    Returns:
        Excel file stream
    """
    try:
        import pandas as pd
        from maps import export_excel

        # Convert data to DataFrame
        df = pd.DataFrame([data])

        # Create Excel file in memory
        output = io.BytesIO()
        export_excel(df, output, format=format)
        output.seek(0)

        return StreamingResponse(
            output,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": "attachment; filename=export.xlsx"}
        )

    except Exception as e:
        logger.error(f"Excel export failed: {e}")
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")


@router.post("/csv")
async def export_to_csv(data: dict):
    """
    Export parsed data to CSV format.

    Args:
        data: Parsed document data

    Returns:
        CSV file stream
    """
    try:
        import pandas as pd

        df = pd.DataFrame([data])
        output = io.StringIO()
        df.to_csv(output, index=False)
        output.seek(0)

        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=export.csv"}
        )

    except Exception as e:
        logger.error(f"CSV export failed: {e}")
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")


@router.post("/json")
async def export_to_json(data: dict, pretty: bool = True):
    """
    Export parsed data to JSON format.

    Args:
        data: Parsed document data
        pretty: Pretty print JSON

    Returns:
        JSON file stream
    """
    try:
        import json

        json_str = json.dumps(data, indent=2 if pretty else None)

        return StreamingResponse(
            iter([json_str]),
            media_type="application/json",
            headers={"Content-Disposition": "attachment; filename=export.json"}
        )

    except Exception as e:
        logger.error(f"JSON export failed: {e}")
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")
