"""Parse case detection endpoints"""

from fastapi import APIRouter, UploadFile, File, HTTPException
import tempfile
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/detect")
async def detect_parse_case(file: UploadFile = File(...)):
    """
    Detect XML parse case without full parsing.

    Args:
        file: XML file to analyze

    Returns:
        Parse case and structure information
    """
    if not file.filename.endswith('.xml'):
        raise HTTPException(status_code=400, detail="File must be XML format")

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.xml') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        from ...structure_detector import analyze_xml_structure
        structure = analyze_xml_structure(tmp_path)

        os.unlink(tmp_path)

        return {
            "status": "success",
            "filename": file.filename,
            "structure": structure
        }

    except Exception as e:
        logger.error(f"Detection failed: {e}")
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise HTTPException(status_code=500, detail=f"Detection failed: {str(e)}")
