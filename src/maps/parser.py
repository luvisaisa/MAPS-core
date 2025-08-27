"""Core XML parsing functions for medical annotation data."""

import xml.etree.ElementTree as ET
import re
from typing import Tuple, Dict
import os


def parse_radiology_sample(file_path: str) -> Tuple[Dict, Dict]:
    """
    Parse a single radiology XML file.
    
    Args:
        file_path: Path to the XML file
        
    Returns:
        Tuple of (main_data, unblinded_data) dictionaries
    """
    print(f"Parsing XML file: {os.path.basename(file_path)}")
    
    # Load XML file
    tree = ET.parse(file_path)
    root = tree.getroot()
    
    # Extract namespace from root tag
    namespace_match = re.match(r'\{(.*)\}', root.tag)
    ns_uri = namespace_match.group(1) if namespace_match else ''
    
    def tag(name):
        """Helper to build tag with namespace if present."""
        return f"{{{ns_uri}}}{name}" if ns_uri else name
    
    # Extract header information
    header_values = {}
    header = root.find(tag('ResponseHeader'))
    
    if header is not None:
        # Extract study identifiers
        study_uid = header.find(tag('StudyInstanceUID'))
        if study_uid is not None and study_uid.text:
            header_values['StudyInstanceUID'] = study_uid.text
            
        series_uid = header.find(tag('SeriesInstanceUID'))
        if series_uid is not None and series_uid.text:
            header_values['SeriesInstanceUID'] = series_uid.text
    
    # Placeholder for extracted data
    main_data = {'header': header_values}
    unblinded_data = {}
    
    return main_data, unblinded_data
