"""Batch processing example for multiple XML files."""

from src.maps.parser import parse_multiple, export_excel
import pandas as pd
import os
from glob import glob


def process_directory(xml_dir: str, output_dir: str):
    """Process all XML files in a directory."""
    # Find all XML files
    xml_files = glob(os.path.join(xml_dir, "*.xml"))
    
    if not xml_files:
        print(f"No XML files found in {xml_dir}")
        return
    
    print(f"Found {len(xml_files)} XML files")
    
    # Parse all files
    main_dfs, unblinded_dfs = parse_multiple(xml_files)
    
    # Combine all main dataframes
    if main_dfs:
        combined_df = pd.concat(main_dfs.values(), ignore_keys=True)
        
        # Create output directory
        os.makedirs(output_dir, exist_ok=True)
        
        # Export combined data
        output_path = os.path.join(output_dir, "combined_results.xlsx")
        export_excel(combined_df, output_path)
        
        print(f"\nProcessed {len(main_dfs)} files")
        print(f"Total records: {len(combined_df)}")
    else:
        print("No data parsed")


if __name__ == "__main__":
    # Example usage
    xml_directory = "data/xml_files"
    output_directory = "output"
    
    process_directory(xml_directory, output_directory)
