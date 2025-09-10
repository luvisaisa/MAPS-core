"""Examples of parsing different XML format types."""

from src.maps.parser import parse_radiology_sample, detect_parse_case
import os


def demonstrate_parse_cases():
    """Demonstrate parsing files with different parse cases."""
    
    # Example files (would need actual data)
    example_files = {
        "complete.xml": "Complete_Attributes",
        "lidc_single.xml": "LIDC_Single_Session",
        "lidc_multi_4.xml": "LIDC_Multi_Session_4",
        "partial.xml": "With_Reason_Partial"
    }
    
    for filename, expected_case in example_files.items():
        filepath = f"data/examples/{filename}"
        
        if os.path.exists(filepath):
            print(f"\nAnalyzing: {filename}")
            print(f"Expected case: {expected_case}")
            
            # Detect parse case
            detected_case = detect_parse_case(filepath)
            print(f"Detected case: {detected_case}")
            
            # Parse file
            main_df, unblinded_df = parse_radiology_sample(filepath)
            print(f"Extracted {len(main_df)} records")
        else:
            print(f"\nSkipping {filename} (not found)")


if __name__ == "__main__":
    demonstrate_parse_cases()
