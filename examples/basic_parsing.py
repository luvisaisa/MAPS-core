"""Basic XML parsing example."""

from src.maps.parser import parse_radiology_sample, export_excel
import os

# Example usage
if __name__ == "__main__":
    # Parse a single XML file
    xml_file = "data/sample.xml"
    
    if os.path.exists(xml_file):
        print(f"Parsing {xml_file}...")
        main_df, unblinded_df = parse_radiology_sample(xml_file)
        
        print(f"\nParsed {len(main_df)} records")
        print("\nFirst few rows:")
        print(main_df.head())
        
        # Export to Excel
        output_path = "output/parsed_data.xlsx"
        os.makedirs("output", exist_ok=True)
        export_excel(main_df, output_path)
    else:
        print(f"File not found: {xml_file}")
