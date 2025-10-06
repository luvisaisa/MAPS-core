"""
PDF keyword extractor for radiology research literature.

Extracts keywords from research papers in PDF format, including:
- Metadata (title, authors, journal, year, DOI)
- Abstract content
- Author-provided keywords
- Body text keywords with page tracking
"""

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Dict, Optional, Set

try:
    import pdfplumber
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False

from .keyword_normalizer import KeywordNormalizer


@dataclass
class PDFMetadata:
    """Metadata extracted from PDF document"""
    title: str = ""
    authors: List[str] = field(default_factory=list)
    journal: str = ""
    year: Optional[int] = None
    doi: str = ""
    abstract: str = ""
    author_keywords: List[str] = field(default_factory=list)


@dataclass
class ExtractedPDFKeyword:
    """Keyword extracted from PDF with context and location"""
    text: str
    category: str  # metadata, abstract, keyword, body
    page_number: int
    context: str = ""
    frequency: int = 1
    normalized_form: Optional[str] = None


class PDFKeywordExtractor:
    """Extract keywords from PDF research papers"""

    def __init__(self, normalizer: Optional[KeywordNormalizer] = None):
        """
        Initialize PDF keyword extractor.

        Args:
            normalizer: Optional keyword normalizer for term standardization
        """
        if not PDF_AVAILABLE:
            raise ImportError("pdfplumber is required for PDF extraction. Install with: pip install pdfplumber")

        self.normalizer = normalizer or KeywordNormalizer()

        self.abstract_patterns = [
            r'\babstract\b',
            r'\bsummary\b',
            r'\bbackground\b'
        ]

        self.keyword_patterns = [
            r'\bkeywords?\b',
            r'\bkey\s+words?\b',
            r'\bindex\s+terms?\b'
        ]

    def extract_from_pdf(
        self,
        pdf_path: str,
        max_pages: Optional[int] = None
    ) -> tuple[PDFMetadata, List[ExtractedPDFKeyword]]:
        """
        Extract keywords from PDF file.

        Args:
            pdf_path: Path to PDF file
            max_pages: Optional maximum number of pages to process

        Returns:
            Tuple of (metadata, list of extracted keywords)
        """
        pdf_path = Path(pdf_path)
        if not pdf_path.exists():
            raise FileNotFoundError(f"PDF not found: {pdf_path}")

        metadata = PDFMetadata()
        all_keywords = []

        with pdfplumber.open(pdf_path) as pdf:
            total_pages = len(pdf.pages)
            pages_to_process = min(max_pages, total_pages) if max_pages else total_pages

            if total_pages > 0:
                first_page_text = pdf.pages[0].extract_text() or ""
                metadata = self._extract_metadata(first_page_text, pdf.metadata or {})

            for page_num, page in enumerate(pdf.pages[:pages_to_process], start=1):
                page_text = page.extract_text() or ""

                if page_num <= 2 and not metadata.abstract:
                    abstract = self._extract_abstract(page_text)
                    if abstract:
                        metadata.abstract = abstract
                        abstract_keywords = self._extract_keywords_from_text(
                            abstract, 'abstract', page_num
                        )
                        all_keywords.extend(abstract_keywords)

                if page_num <= 2 and not metadata.author_keywords:
                    author_kws = self._extract_author_keywords(page_text)
                    if author_kws:
                        metadata.author_keywords = author_kws
                        for kw in author_kws:
                            all_keywords.append(ExtractedPDFKeyword(
                                text=kw,
                                category='keyword',
                                page_number=page_num,
                                frequency=1
                            ))

                body_keywords = self._extract_keywords_from_text(
                    page_text, 'body', page_num
                )
                all_keywords.extend(body_keywords)

        all_keywords = self._consolidate_keywords(all_keywords)

        for keyword in all_keywords:
            normalized = self.normalizer.normalize(keyword.text)
            keyword.normalized_form = normalized

        return metadata, all_keywords

    def _extract_metadata(self, first_page_text: str, pdf_metadata: Dict) -> PDFMetadata:
        """Extract metadata from first page and PDF metadata"""
        metadata = PDFMetadata()

        if 'Title' in pdf_metadata:
            metadata.title = pdf_metadata['Title']
        else:
            lines = [line.strip() for line in first_page_text.split('\n') if line.strip()]
            if lines:
                metadata.title = lines[0]

        year_match = re.search(r'\b(19|20)\d{2}\b', first_page_text)
        if year_match:
            metadata.year = int(year_match.group())

        doi_match = re.search(r'doi:\s*([^\s]+)', first_page_text, re.IGNORECASE)
        if doi_match:
            metadata.doi = doi_match.group(1)

        return metadata

    def _extract_abstract(self, text: str) -> str:
        """Extract abstract section from text"""
        text_lower = text.lower()

        for pattern in self.abstract_patterns:
            match = re.search(pattern, text_lower)
            if match:
                start_pos = match.end()
                end_pos = len(text)

                abstract = text[start_pos:end_pos].strip()
                abstract = re.sub(r'\s+', ' ', abstract)
                return abstract[:2000]

        return ""

    def _extract_author_keywords(self, text: str) -> List[str]:
        """Extract author-provided keywords from text"""
        text_lower = text.lower()
        keywords = []

        for pattern in self.keyword_patterns:
            match = re.search(pattern, text_lower)
            if match:
                start_pos = match.end()
                keyword_text = text[start_pos:start_pos + 200]
                kw_parts = re.split(r'[;,\n]', keyword_text)

                for kw in kw_parts:
                    kw = kw.strip().rstrip('.')
                    if kw and len(kw) > 2 and len(kw) < 50:
                        keywords.append(kw)
                break

        return keywords[:20]

    def _extract_keywords_from_text(
        self,
        text: str,
        category: str,
        page_number: int
    ) -> List[ExtractedPDFKeyword]:
        """Extract keywords from text using multi-word detection and filtering"""
        keywords = []

        multi_word_terms = self.normalizer.detect_multi_word_terms(text)

        for term, start, end in multi_word_terms:
            context_start = max(0, start - 50)
            context_end = min(len(text), end + 50)
            context = text[context_start:context_end].strip()

            keywords.append(ExtractedPDFKeyword(
                text=term,
                category=category,
                page_number=page_number,
                context=context,
                frequency=1
            ))

        return keywords

    def _consolidate_keywords(self, keywords: List[ExtractedPDFKeyword]) -> List[ExtractedPDFKeyword]:
        """Consolidate duplicate keywords by summing frequencies"""
        keyword_map: Dict[tuple, ExtractedPDFKeyword] = {}

        for kw in keywords:
            key = (kw.text.lower(), kw.category)

            if key in keyword_map:
                keyword_map[key].frequency += 1
            else:
                keyword_map[key] = kw

        return list(keyword_map.values())
