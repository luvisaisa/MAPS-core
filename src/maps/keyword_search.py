"""
Keyword search engine for medical annotation corpus.

Provides search capabilities across keywords with:
- Boolean query parsing (AND/OR operators)
- Synonym expansion using KeywordNormalizer
- Relevance scoring
- Result snippets with highlighting
"""

import re
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Set
from collections import defaultdict

from .keyword_normalizer import KeywordNormalizer


@dataclass
class SearchResult:
    """Single search result with relevance score and context"""
    keyword_text: str
    normalized_form: str
    category: str
    relevance_score: float
    context: str = ""
    matched_query_terms: List[str] = field(default_factory=list)


@dataclass
class SearchResponse:
    """Search response with results and metadata"""
    query: str
    total_results: int
    results: List[SearchResult] = field(default_factory=list)
    expanded_query_terms: List[str] = field(default_factory=list)


class QueryParser:
    """Parse boolean search queries with AND/OR operators"""

    def __init__(self):
        self.and_pattern = re.compile(r'\s+AND\s+', re.IGNORECASE)
        self.or_pattern = re.compile(r'\s+OR\s+', re.IGNORECASE)

    def parse(self, query: str) -> Dict[str, any]:
        """
        Parse query into structured form.

        Returns:
            Dict with 'operator' and 'terms' keys
        """
        query = query.strip()

        if self.and_pattern.search(query):
            terms = self.and_pattern.split(query)
            return {
                'operator': 'AND',
                'terms': [term.strip().lower() for term in terms if term.strip()]
            }

        if self.or_pattern.search(query):
            terms = self.or_pattern.split(query)
            return {
                'operator': 'OR',
                'terms': [term.strip().lower() for term in terms if term.strip()]
            }

        terms = query.split()
        if len(terms) > 1:
            return {
                'operator': 'AND',
                'terms': [term.strip().lower() for term in terms if term.strip()]
            }

        return {
            'operator': 'SINGLE',
            'terms': [query.lower()]
        }


class KeywordSearchEngine:
    """Search engine for keyword corpus with relevance scoring"""

    def __init__(self, normalizer: Optional[KeywordNormalizer] = None):
        """
        Initialize search engine.

        Args:
            normalizer: Optional keyword normalizer for synonym expansion
        """
        self.normalizer = normalizer or KeywordNormalizer()
        self.query_parser = QueryParser()
        self.keyword_index: Dict[str, Set[str]] = defaultdict(set)

    def index_keywords(self, keywords: List[tuple[str, str, str]]):
        """
        Index keywords for searching.

        Args:
            keywords: List of (text, category, context) tuples
        """
        for text, category, context in keywords:
            normalized = self.normalizer.normalize(text)
            self.keyword_index[normalized].add(text)

    def search(
        self,
        query: str,
        expand_synonyms: bool = True,
        min_relevance: float = 0.0
    ) -> SearchResponse:
        """
        Search keyword corpus with query.

        Args:
            query: Search query string (supports AND/OR operators)
            expand_synonyms: Whether to expand query terms with synonyms
            min_relevance: Minimum relevance score threshold

        Returns:
            SearchResponse with results and metadata
        """
        parsed = self.query_parser.parse(query)
        query_terms = parsed['terms']
        operator = parsed['operator']

        expanded_terms = set()
        for term in query_terms:
            expanded_terms.add(term)
            if expand_synonyms:
                synonym_forms = self.normalizer.get_all_forms(term)
                expanded_terms.update(synonym_forms)

        results = []
        for normalized, original_forms in self.keyword_index.items():
            matches = False
            matched_terms = []

            if operator == 'AND':
                if all(term in normalized or any(term in form for form in original_forms) for term in expanded_terms):
                    matches = True
                    matched_terms = list(expanded_terms)
            elif operator == 'OR' or operator == 'SINGLE':
                for term in expanded_terms:
                    if term in normalized or any(term in form for form in original_forms):
                        matches = True
                        matched_terms.append(term)
                        break

            if matches:
                relevance = len(matched_terms) / max(len(expanded_terms), 1)

                if relevance >= min_relevance:
                    for original in original_forms:
                        results.append(SearchResult(
                            keyword_text=original,
                            normalized_form=normalized,
                            category="keyword",
                            relevance_score=relevance,
                            matched_query_terms=matched_terms
                        ))

        results.sort(key=lambda x: x.relevance_score, reverse=True)

        return SearchResponse(
            query=query,
            total_results=len(results),
            results=results,
            expanded_query_terms=list(expanded_terms)
        )
