"""Parser endpoints"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from typing import Optional
import tempfile
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/parse/xml")
async def parse_xml_file(
    file: UploadFile = File(...),
    profile_name: Optional[str] = "lidc_idri_standard"
):
    """
    Parse uploaded XML file using specified profile.

    Args:
        file: XML file to parse
        profile_name: Parsing profile to use

    Returns:
        Parsed canonical document
    """
    if not file.filename.endswith('.xml'):
        raise HTTPException(status_code=400, detail="File must be XML format")

    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.xml') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        # Parse using profile
        from maps.parsers.xml_parser import XMLParser
        parser = XMLParser(profile_name=profile_name)
        document = parser.parse(tmp_path)

        # Clean up temp file
        os.unlink(tmp_path)

        return {
            "status": "success",
            "filename": file.filename,
            "profile": profile_name,
            "document": document.model_dump() if document else None
        }

    except Exception as e:
        logger.error(f"Failed to parse XML: {e}")
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise HTTPException(status_code=500, detail=f"Parsing failed: {str(e)}")


@router.post("/parse/batch")
async def parse_xml_batch(
    files: list[UploadFile] = File(...),
    profile_name: Optional[str] = "lidc_idri_standard"
):
    """
    Parse multiple XML files in batch.

    Args:
        files: List of XML files to parse
        profile_name: Parsing profile to use

    Returns:
        Batch parsing results
    """
    results = []
    errors = []

    for file in files:
        if not file.filename.endswith('.xml'):
            errors.append({"filename": file.filename, "error": "Not XML format"})
            continue

        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.xml') as tmp:
                content = await file.read()
                tmp.write(content)
                tmp_path = tmp.name

            from maps.parsers.xml_parser import XMLParser
            parser = XMLParser(profile_name=profile_name)
            document = parser.parse(tmp_path)
            os.unlink(tmp_path)

            results.append({
                "filename": file.filename,
                "status": "success",
                "document": document.model_dump() if document else None
            })

        except Exception as e:
            logger.error(f"Failed to parse {file.filename}: {e}")
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            errors.append({"filename": file.filename, "error": str(e)})

    return {
        "total": len(files),
        "successful": len(results),
        "failed": len(errors),
        "results": results,
        "errors": errors
    }
