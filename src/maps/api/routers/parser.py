"""Parser endpoints"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from typing import Optional, List
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
        from ...parsers.xml_parser import XMLParser
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

            from ...parsers.xml_parser import XMLParser
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


@router.post("/parse/pdf")
async def parse_pdf_file(file: UploadFile = File(...)):
    """
    Extract keywords from PDF file.

    Args:
        file: PDF file to parse

    Returns:
        PDF metadata and extracted keywords
    """
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="File must be PDF format")

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        from ...pdf_keyword_extractor import PDFKeywordExtractor
        extractor = PDFKeywordExtractor()
        metadata, keywords = extractor.extract_from_pdf(tmp_path)

        os.unlink(tmp_path)

        return {
            "status": "success",
            "filename": file.filename,
            "metadata": {
                "title": metadata.title,
                "authors": metadata.authors,
                "abstract": metadata.abstract,
                "page_count": metadata.page_count
            },
            "keywords": [
                {
                    "keyword": kw.keyword,
                    "frequency": kw.frequency,
                    "normalized_form": kw.normalized_form,
                    "category": kw.category
                } for kw in keywords
            ]
        }

    except Exception as e:
        logger.error(f"Failed to parse PDF: {e}")
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise HTTPException(status_code=500, detail=f"PDF parsing failed: {str(e)}")
