"""
Keyword Normalizer

Normalizes medical keywords using synonyms, abbreviations, and medical terminology.
Supports canonical form mapping and synonym expansion for search queries.
"""

import json
import logging
from typing import List, Dict, Set, Optional, Tuple
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class KeywordNormalizer:
    """
    Normalize medical keywords using medical terminology dictionary.

    Features:
    - Synonym mapping (lung → pulmonary)
    - Abbreviation expansion (CT → computed tomography)
    - Multi-word term detection (ground glass opacity)
    - Canonical form mapping for database storage
    - Synonym expansion for search queries
    """

    def __init__(self, medical_terms_path: str = None):
        """
        Initialize keyword normalizer.

        Args:
            medical_terms_path: Path to medical_terms.json (default: data/medical_terms.json)
        """
        if medical_terms_path is None:
            base_dir = Path(__file__).parent.parent.parent
            medical_terms_path = base_dir / "data" / "medical_terms.json"

        self.medical_terms = self._load_medical_terms(medical_terms_path)
        self._build_lookup_maps()

        logger.info(f"KeywordNormalizer initialized with {len(self.synonym_map)} synonym mappings")

    def _load_medical_terms(self, path: str) -> Dict:
        """Load medical terms dictionary from JSON"""
        try:
            with open(path, 'r') as f:
                terms = json.load(f)
            logger.debug(f"Loaded medical terms from {path}")
            return terms
        except FileNotFoundError:
            logger.warning(f"Medical terms file not found: {path}. Using empty dictionary.")
            return {
                'synonyms': {},
                'abbreviations': {},
                'multi_word_terms': [],
                'stopwords': []
            }
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing medical terms JSON: {e}")
            raise

    def _build_lookup_maps(self):
        """Build reverse lookup maps for fast normalization"""
        self.synonym_map = {}

        for canonical, synonyms in self.medical_terms.get('synonyms', {}).items():
            self.synonym_map[canonical.lower()] = canonical.lower()
            for syn in synonyms:
                self.synonym_map[syn.lower()] = canonical.lower()

        self.abbreviation_map = {
            abbr.lower(): full.lower()
            for abbr, full in self.medical_terms.get('abbreviations', {}).items()
        }

        self.multi_word_set = set(
            term.lower() for term in self.medical_terms.get('multi_word_terms', [])
        )

        self.stopwords = set(
            word.lower() for word in self.medical_terms.get('stopwords', [])
        )

        logger.debug(f"Built lookup maps: {len(self.synonym_map)} synonyms, "
                    f"{len(self.abbreviation_map)} abbreviations")

    def normalize(self, keyword: str, expand_abbreviations: bool = True) -> str:
        """
        Normalize a keyword to its canonical form.

        Examples:
            normalize("lung") → "pulmonary"
            normalize("CT") → "computed tomography"
            normalize("GGO") → "ground glass opacity"
        """
        keyword_lower = keyword.lower().strip()

        if expand_abbreviations and keyword_lower in self.abbreviation_map:
            keyword_lower = self.abbreviation_map[keyword_lower]

        if keyword_lower in self.synonym_map:
            return self.synonym_map[keyword_lower]

        return keyword_lower

    def is_stopword(self, word: str) -> bool:
        """Check if a word is a medical stopword"""
        return word.lower() in self.stopwords

    def filter_stopwords(self, tokens: List[str]) -> List[str]:
        """Filter stopwords from a list of tokens"""
        return [token for token in tokens if not self.is_stopword(token)]

    def get_all_forms(self, keyword: str) -> List[str]:
        """
        Get all synonym forms of a keyword (for search expansion).

        Examples:
            get_all_forms("pulmonary") → ["pulmonary", "lung", "pneumonic", "pulmonic"]
            get_all_forms("nodule") → ["nodule", "lesion", "mass", "growth", "tumor"]
        """
        canonical = self.normalize(keyword)
        synonyms = [canonical]

        for canon, syns in self.medical_terms.get('synonyms', {}).items():
            if canon.lower() == canonical:
                synonyms.extend([s.lower() for s in syns])
                break

        return list(set(synonyms))

    def is_multi_word_term(self, text: str) -> bool:
        """Check if text matches a known multi-word medical term"""
        return text.lower() in self.multi_word_set

    def detect_multi_word_terms(self, text: str) -> List[Tuple[str, int, int]]:
        """
        Detect multi-word medical terms in text.

        Returns:
            List of (term, start_pos, end_pos) tuples

        Example:
            detect_multi_word_terms("patient has ground glass opacity")
            → [("ground glass opacity", 12, 32)]
        """
        text_lower = text.lower()
        detected = []

        sorted_terms = sorted(self.multi_word_set, key=len, reverse=True)

        for term in sorted_terms:
            start = 0
            while True:
                pos = text_lower.find(term, start)
                if pos == -1:
                    break

                before_ok = pos == 0 or not text_lower[pos-1].isalnum()
                after_ok = pos + len(term) == len(text_lower) or not text_lower[pos + len(term)].isalnum()

                if before_ok and after_ok:
                    detected.append((term, pos, pos + len(term)))

                start = pos + 1

        detected.sort(key=lambda x: x[1])
        return detected
