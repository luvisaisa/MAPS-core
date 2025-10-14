"""
Example: Auto-Analysis of Radiology XML Files

Demonstrates automatic keyword extraction and entity population
from XML files using the auto-analysis system.
"""

from maps import (
    AutoAnalyzer,
    XMLKeywordExtractor,
    KeywordNormalizer,
    canonical_to_dict
)


def basic_auto_analysis():
    """Demonstrate basic auto-analysis of XML file"""
    print("=== Basic Auto-Analysis Example ===\n")

    analyzer = AutoAnalyzer()

    # Note: Replace with actual XML file path
    xml_file = "data/sample.xml"

    print(f"Analyzing: {xml_file}")
    print("(This would work with actual XML files)\n")

    # Example of what the analysis would produce:
    print("Auto-analysis extracts:")
    print("  - Header information (Study UID, Modality, Date)")
    print("  - Nodule characteristics (subtlety, malignancy, etc.)")
    print("  - Semantic keywords (e.g., 'obvious' from subtlety=5)")
    print("  - Entity extraction (dates, identifiers, medical terms)")
    print("  - Canonical document with full type safety")

    print("\n" + "="*50 + "\n")


def keyword_extraction_from_xml():
    """Demonstrate keyword extraction from XML"""
    print("=== XML Keyword Extraction Example ===\n")

    normalizer = KeywordNormalizer()
    extractor = XMLKeywordExtractor(normalizer)

    print("XML keyword extractor can extract:")
    print("\n1. Header Keywords:")
    print("   - Modality: 'ct'")
    print("   - Study ID: 'study_12345'")

    print("\n2. Characteristic Keywords:")
    print("   - 'subtlety' (from characteristic name)")
    print("   - 'obvious' (semantic descriptor for subtlety=5)")
    print("   - 'malignancy' (from characteristic name)")
    print("   - 'highly_suspicious' (semantic descriptor for malignancy=5)")

    print("\n3. ROI Keywords:")
    print("   - 'roi_size_24_points' (coordinate count)")

    print("\n" + "="*50 + "\n")


def canonical_document_example():
    """Demonstrate canonical document creation"""
    print("=== Canonical Document Creation Example ===\n")

    print("AutoAnalyzer creates RadiologyCanonicalDocument with:\n")

    print("Document Metadata:")
    print("  - title: 'Radiology Scan - 1.2.840...'")
    print("  - date: '2024-01-15'")
    print("  - document_type: 'radiology_report'\n")

    print("Radiology-Specific Fields:")
    print("  - study_instance_uid: '1.2.840.113654.2.55.12345'")
    print("  - series_instance_uid: '1.2.840.113654.2.55.12346'")
    print("  - modality: 'CT'")
    print("  - nodules: [array of nodule data]\n")

    print("Extracted Entities:")
    print("  - dates: [service date]")
    print("  - identifiers: [Study UID, Series UID]")
    print("  - medical_terms: [characteristic keywords]\n")

    print("Extraction Metadata:")
    print("  - extraction_timestamp: datetime.utcnow()")
    print("  - profile_name: 'xml_auto_extraction'")
    print("  - overall_confidence: 0.85")

    print("\n" + "="*50 + "\n")


def batch_analysis_example():
    """Demonstrate batch analysis"""
    print("=== Batch Analysis Example ===\n")

    print("Analyzing multiple XML files:\n")

    print("""
from maps import AutoAnalyzer

analyzer = AutoAnalyzer()

xml_files = [
    'data/scan001.xml',
    'data/scan002.xml',
    'data/scan003.xml'
]

# Analyze all files
documents = analyzer.analyze_batch(
    xml_files,
    progress_callback=lambda i, total, file: print(f"Processing {i}/{total}: {file}")
)

# Get summary statistics
summary = analyzer.get_analysis_summary(documents)

print(f"Analyzed {summary['total_documents']} documents")
print(f"Total nodules: {summary['total_nodules']}")
print(f"Total entities: {summary['total_entities']}")
print(f"Average confidence: {summary['average_confidence']}")
print(f"Modalities: {summary['modalities']}")
    """)

    print("Output:")
    print("  Processing 1/3: data/scan001.xml")
    print("  Processing 2/3: data/scan002.xml")
    print("  Processing 3/3: data/scan003.xml")
    print("  Analyzed 3 documents")
    print("  Total nodules: 8")
    print("  Total entities: 42")
    print("  Average confidence: 0.87")
    print("  Modalities: {'CT': 3}")

    print("\n" + "="*50 + "\n")


def characteristic_semantic_mapping():
    """Demonstrate characteristic-to-semantic mapping"""
    print("=== Characteristic Semantic Mapping Example ===\n")

    print("Automatic semantic keyword generation:\n")

    characteristic_examples = [
        ("subtlety", "1", "extremely_subtle, barely_visible"),
        ("subtlety", "5", "obvious, very_clear"),
        ("malignancy", "1", "highly_unlikely_malignant, benign"),
        ("malignancy", "5", "highly_suspicious, likely_malignant"),
        ("texture", "1", "non_solid, ground_glass"),
        ("texture", "5", "solid, completely_solid"),
        ("sphericity", "1", "linear, elongated"),
        ("sphericity", "5", "round, spherical")
    ]

    print("Characteristic → Value → Semantic Keywords:")
    for char, value, keywords in characteristic_examples:
        print(f"  {char:15} = {value}  →  {keywords}")

    print("\nThese semantic keywords enable:")
    print("  - Natural language search ('highly suspicious nodules')")
    print("  - Medical term standardization")
    print("  - Cross-study comparisons")
    print("  - Machine learning feature extraction")

    print("\n" + "="*50 + "\n")


def integration_with_profiles():
    """Demonstrate integration with profile system"""
    print("=== Integration with Profile System ===\n")

    print("Auto-analysis works seamlessly with profiles:\n")

    print("""
from maps import AutoAnalyzer, get_profile_manager

# Load custom profile
profile_manager = get_profile_manager()
profile = profile_manager.load_profile("custom_radiology_profile")

# Analyze with profile-driven extraction
analyzer = AutoAnalyzer()
doc = analyzer.analyze_xml("scan.xml")

# Document is already in canonical format
# Can be stored, searched, or exported
canonical_dict = canonical_to_dict(doc)
    """)

    print("Benefits:")
    print("  - Profile-based field mapping")
    print("  - Automatic entity extraction")
    print("  - Type-safe canonical output")
    print("  - Ready for database storage")

    print("\n" + "="*50 + "\n")


def main():
    """Run all auto-analysis examples"""
    print("\n" + "="*60)
    print("  MAPS Auto-Analysis System Examples")
    print("="*60 + "\n")

    basic_auto_analysis()
    keyword_extraction_from_xml()
    canonical_document_example()
    batch_analysis_example()
    characteristic_semantic_mapping()
    integration_with_profiles()

    print("Examples complete!")
    print("\nFor more information:")
    print("  - docs/KEYWORD_EXTRACTION.md")
    print("  - docs/SCHEMA_AGNOSTIC.md")


if __name__ == "__main__":
    main()
