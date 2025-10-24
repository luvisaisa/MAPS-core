"""Keywords router for keyword search and extraction"""

from fastapi import APIRouter, HTTPException, Query
from typing import Optional
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/search")
async def search_keywords(
    query: str = Query(..., min_length=1),
    expand_synonyms: bool = True,
    min_relevance: float = 0.0
):
    """
    Search for keywords using boolean query.

    Args:
        query: Search query (supports AND/OR operators)
        expand_synonyms: Whether to expand synonyms
        min_relevance: Minimum relevance score

    Returns:
        Search results with relevance scores
    """
    try:
        from maps.keyword_search import KeywordSearchEngine
        from maps.keyword_normalizer import KeywordNormalizer

        normalizer = KeywordNormalizer()
        search_engine = KeywordSearchEngine(normalizer)

        response = search_engine.search(
            query=query,
            expand_synonyms=expand_synonyms,
            min_relevance=min_relevance
        )

        return {
            "query": response.query,
            "expanded_query": response.expanded_query,
            "total_results": response.total_results,
            "results": [
                {
                    "keyword": r.keyword,
                    "relevance": r.relevance,
                    "matched_terms": r.matched_terms
                } for r in response.results
            ]
        }

    except Exception as e:
        logger.error(f"Keyword search failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/normalize")
async def normalize_keyword(
    keyword: str,
    expand_abbreviations: bool = True
):
    """
    Normalize medical keyword.

    Args:
        keyword: Keyword to normalize
        expand_abbreviations: Whether to expand abbreviations

    Returns:
        Normalized keyword and all forms
    """
    try:
        from maps.keyword_normalizer import KeywordNormalizer

        normalizer = KeywordNormalizer()
        normalized = normalizer.normalize(keyword, expand_abbreviations)
        all_forms = normalizer.get_all_forms(keyword)

        return {
            "original": keyword,
            "normalized": normalized,
            "all_forms": all_forms
        }

    except Exception as e:
        logger.error(f"Normalization failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
