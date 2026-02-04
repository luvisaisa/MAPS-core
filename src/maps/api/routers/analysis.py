"""Auto-analysis endpoints"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from typing import Optional
import tempfile
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/analyze/xml")
async def analyze_xml_file(
    file: UploadFile = File(...),
    populate_entities: bool = True
):
    """
    Auto-analyze XML file and extract entities.

    Args:
        file: XML file to analyze
        populate_entities: Whether to populate entities in canonical document

    Returns:
        Canonical document with extracted entities and keywords
    """
    if not file.filename.endswith('.xml'):
        raise HTTPException(status_code=400, detail="File must be XML format")

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.xml') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        from ...auto_analysis import AutoAnalyzer
        analyzer = AutoAnalyzer()
        document = analyzer.analyze_xml(tmp_path, populate_entities=populate_entities)

        os.unlink(tmp_path)

        return {
            "status": "success",
            "filename": file.filename,
            "document": document.model_dump() if document else None,
            "statistics": {
                "total_entities": len(document.entities.medical_terms) if document else 0,
                "nodules": len(document.nodules) if document else 0,
                "confidence": document.extraction_metadata.overall_confidence if document else 0.0
            }
        }

    except Exception as e:
        logger.error(f"Auto-analysis failed: {e}")
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")
