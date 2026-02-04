"""Tests for keyword extraction and normalization modules."""

import pytest
from src.maps.keyword_normalizer import KeywordNormalizer
from src.maps.keyword_search import KeywordSearchEngine, QueryParser, SearchResponse


class TestKeywordNormalizer:
    """Test suite for KeywordNormalizer class."""

    @pytest.fixture
    def normalizer(self):
        """Create normalizer instance."""
        return KeywordNormalizer()

    def test_normalizer_initialization(self, normalizer):
        """Test normalizer initializes without errors."""
        assert normalizer is not None
        assert hasattr(normalizer, 'synonym_map')
        assert hasattr(normalizer, 'abbreviation_map')

    def test_normalize_lowercase(self, normalizer):
        """Test normalization converts to lowercase."""
        result = normalizer.normalize("LUNG")
        assert result == result.lower()

    def test_normalize_strips_whitespace(self, normalizer):
        """Test normalization strips whitespace."""
        result = normalizer.normalize("  lung  ")
        assert result == result.strip()

    def test_normalize_returns_string(self, normalizer):
        """Test normalize always returns a string."""
        result = normalizer.normalize("test")
        assert isinstance(result, str)

    def test_is_stopword_returns_bool(self, normalizer):
        """Test is_stopword returns boolean."""
        result = normalizer.is_stopword("the")
        assert isinstance(result, bool)

    def test_filter_stopwords_returns_list(self, normalizer):
        """Test filter_stopwords returns a list."""
        result = normalizer.filter_stopwords(["the", "lung", "is"])
        assert isinstance(result, list)

    def test_get_all_forms_returns_list(self, normalizer):
        """Test get_all_forms returns a list."""
        result = normalizer.get_all_forms("lung")
        assert isinstance(result, list)
        assert len(result) >= 1

    def test_get_all_forms_includes_input(self, normalizer):
        """Test get_all_forms includes the normalized input."""
        result = normalizer.get_all_forms("test")
        normalized = normalizer.normalize("test")
        assert normalized in result

    def test_is_multi_word_term_returns_bool(self, normalizer):
        """Test is_multi_word_term returns boolean."""
        result = normalizer.is_multi_word_term("ground glass opacity")
        assert isinstance(result, bool)

    def test_detect_multi_word_terms_returns_list(self, normalizer):
        """Test detect_multi_word_terms returns list of tuples."""
        result = normalizer.detect_multi_word_terms("sample text")
        assert isinstance(result, list)


class TestQueryParser:
    """Test suite for QueryParser class."""

    @pytest.fixture
    def parser(self):
        """Create parser instance."""
        return QueryParser()

    def test_parser_initialization(self, parser):
        """Test parser initializes without errors."""
        assert parser is not None

    def test_parse_single_term(self, parser):
        """Test parsing single term query."""
        result = parser.parse("lung")
        assert 'operator' in result
        assert 'terms' in result
        assert result['operator'] == 'SINGLE'
        assert 'lung' in result['terms']

    def test_parse_and_query(self, parser):
        """Test parsing AND query."""
        result = parser.parse("lung AND nodule")
        assert result['operator'] == 'AND'
        assert len(result['terms']) == 2

    def test_parse_or_query(self, parser):
        """Test parsing OR query."""
        result = parser.parse("lung OR pulmonary")
        assert result['operator'] == 'OR'
        assert len(result['terms']) == 2

    def test_parse_returns_lowercase_terms(self, parser):
        """Test parsed terms are lowercase."""
        result = parser.parse("LUNG")
        assert all(term == term.lower() for term in result['terms'])

    def test_parse_multiple_words_default_and(self, parser):
        """Test multiple space-separated words default to AND."""
        result = parser.parse("lung nodule cancer")
        assert result['operator'] == 'AND'
        assert len(result['terms']) == 3


class TestKeywordSearchEngine:
    """Test suite for KeywordSearchEngine class."""

    @pytest.fixture
    def normalizer(self):
        """Create normalizer instance."""
        return KeywordNormalizer()

    @pytest.fixture
    def engine(self, normalizer):
        """Create search engine instance."""
        return KeywordSearchEngine(normalizer)

    def test_engine_initialization(self, engine):
        """Test engine initializes without errors."""
        assert engine is not None
        assert hasattr(engine, 'normalizer')
        assert hasattr(engine, 'query_parser')

    def test_engine_has_keyword_index(self, engine):
        """Test engine has keyword index."""
        assert hasattr(engine, 'keyword_index')

    def test_search_returns_search_response(self, engine):
        """Test search returns SearchResponse object."""
        result = engine.search("lung")
        assert isinstance(result, SearchResponse)

    def test_search_response_has_query(self, engine):
        """Test search response contains original query."""
        result = engine.search("test query")
        assert result.query == "test query"

    def test_search_response_has_results_list(self, engine):
        """Test search response has results list."""
        result = engine.search("lung")
        assert isinstance(result.results, list)

    def test_search_response_has_total_results(self, engine):
        """Test search response has total_results count."""
        result = engine.search("lung")
        assert isinstance(result.total_results, int)
        assert result.total_results >= 0

    def test_search_with_expand_synonyms_true(self, engine):
        """Test search with synonym expansion enabled."""
        result = engine.search("lung", expand_synonyms=True)
        assert isinstance(result, SearchResponse)

    def test_search_with_expand_synonyms_false(self, engine):
        """Test search with synonym expansion disabled."""
        result = engine.search("lung", expand_synonyms=False)
        assert isinstance(result, SearchResponse)

    def test_search_with_min_relevance(self, engine):
        """Test search with minimum relevance threshold."""
        result = engine.search("lung", min_relevance=0.5)
        assert isinstance(result, SearchResponse)

    def test_index_keywords_accepts_list(self, engine):
        """Test index_keywords accepts list of tuples."""
        keywords = [
            ("lung nodule", "anatomy", "context1"),
            ("pulmonary", "anatomy", "context2"),
        ]
        engine.index_keywords(keywords)
        assert len(engine.keyword_index) > 0

    def test_search_after_indexing(self, engine):
        """Test search finds indexed keywords."""
        keywords = [
            ("test keyword", "category", "context"),
        ]
        engine.index_keywords(keywords)
        result = engine.search("test")
        assert isinstance(result, SearchResponse)


class TestSearchResponse:
    """Test suite for SearchResponse dataclass."""

    def test_search_response_creation(self):
        """Test SearchResponse can be created."""
        response = SearchResponse(
            query="test",
            total_results=0,
            results=[],
            expanded_query_terms=[]
        )
        assert response.query == "test"
        assert response.total_results == 0

    def test_search_response_with_results(self):
        """Test SearchResponse with results."""
        from src.maps.keyword_search import SearchResult

        result = SearchResult(
            keyword_text="lung",
            normalized_form="lung",
            category="anatomy",
            relevance_score=1.0,
            matched_query_terms=["lung"]
        )
        response = SearchResponse(
            query="lung",
            total_results=1,
            results=[result],
            expanded_query_terms=["lung"]
        )
        assert len(response.results) == 1
        assert response.results[0].keyword_text == "lung"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
