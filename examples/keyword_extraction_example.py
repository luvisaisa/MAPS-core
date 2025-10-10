"""
Example: Keyword Extraction from Medical Literature

Demonstrates extracting keywords from PDF research papers and XML files,
with normalization and search capabilities.
"""

from maps import (
    KeywordNormalizer,
    PDFKeywordExtractor,
    KeywordSearchEngine
)


def keyword_normalization_example():
    """Demonstrate keyword normalization"""
    print("=== Keyword Normalization Example ===\n")

    normalizer = KeywordNormalizer()

    keywords = [
        "lung nodule",
        "CT scan",
        "GGO",
        "pulmonary lesion",
        "computed tomography"
    ]

    print("Normalizing medical keywords:")
    for keyword in keywords:
        normalized = normalizer.normalize(keyword)
        print(f"  {keyword:25} → {normalized}")

    print("\n" + "="*50 + "\n")


def synonym_expansion_example():
    """Demonstrate synonym expansion for search"""
    print("=== Synonym Expansion Example ===\n")

    normalizer = KeywordNormalizer()

    search_terms = ["nodule", "pulmonary", "CT"]

    print("Expanding search terms with synonyms:")
    for term in search_terms:
        synonyms = normalizer.get_all_forms(term)
        print(f"  {term}:")
        print(f"    Synonyms: {', '.join(synonyms)}")

    print("\n" + "="*50 + "\n")


def multi_word_detection_example():
    """Demonstrate multi-word term detection"""
    print("=== Multi-Word Term Detection Example ===\n")

    normalizer = KeywordNormalizer()

    text = """
    Patient presents with ground glass opacity in the right upper lobe.
    Computed tomography scan reveals multiple pulmonary nodules.
    Further evaluation recommended.
    """

    print("Detecting multi-word medical terms in text:")
    print(f"Text: {text.strip()}\n")

    multi_word_terms = normalizer.detect_multi_word_terms(text)

    if multi_word_terms:
        print("Detected terms:")
        for term, start, end in multi_word_terms:
            print(f"  - '{term}' at position {start}-{end}")
    else:
        print("  (No multi-word terms detected)")

    print("\n" + "="*50 + "\n")


def pdf_extraction_example():
    """Demonstrate PDF keyword extraction"""
    print("=== PDF Keyword Extraction Example ===\n")

    print("To extract keywords from a PDF:")
    print("""
    from maps import PDFKeywordExtractor

    extractor = PDFKeywordExtractor()

    # Extract from single PDF
    metadata, keywords = extractor.extract_from_pdf("paper.pdf")

    print(f"Title: {metadata.title}")
    print(f"Year: {metadata.year}")
    print(f"Keywords extracted: {len(keywords)}")

    # Show top keywords
    for kw in keywords[:10]:
        print(f"  - {kw.text} ({kw.category}): {kw.frequency} occurrences")
    """)

    print("\n" + "="*50 + "\n")


def search_engine_example():
    """Demonstrate keyword search"""
    print("=== Keyword Search Engine Example ===\n")

    normalizer = KeywordNormalizer()
    search_engine = KeywordSearchEngine(normalizer)

    print("Indexing sample keywords...")
    sample_keywords = [
        ("lung nodule", "body", "patient has lung nodule in RUL"),
        ("ground glass opacity", "abstract", "GGO observed in CT scan"),
        ("pulmonary lesion", "body", "multiple pulmonary lesions detected"),
        ("computed tomography", "metadata", "CT imaging study")
    ]

    search_engine.index_keywords(sample_keywords)

    queries = [
        "nodule",
        "CT",
        "lung AND opacity",
        "pulmonary OR lesion"
    ]

    print("\nPerforming searches:")
    for query in queries:
        print(f"\n  Query: '{query}'")
        response = search_engine.search(query)
        print(f"  Results: {response.total_results}")

        for result in response.results[:3]:
            print(f"    - {result.keyword_text} (relevance: {result.relevance_score:.2f})")

    print("\n" + "="*50 + "\n")


def main():
    """Run all keyword extraction examples"""
    print("\n" + "="*60)
    print("  MAPS Keyword Extraction System Examples")
    print("="*60 + "\n")

    keyword_normalization_example()
    synonym_expansion_example()
    multi_word_detection_example()
    pdf_extraction_example()
    search_engine_example()

    print("Examples complete!")
    print("\nFor more information, see docs/KEYWORD_EXTRACTION.md")


if __name__ == "__main__":
    main()
