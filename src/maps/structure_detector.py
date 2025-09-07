"""XML structure detection and analysis."""

import xml.etree.ElementTree as ET
import re
from typing import Dict, Any


def analyze_xml_structure(file_path: str) -> Dict[str, Any]:
    """
    Analyze XML file structure and return metadata.
    
    Args:
        file_path: Path to XML file
        
    Returns:
        Dictionary containing structure analysis
    """
    tree = ET.parse(file_path)
    root = tree.getroot()
    
    # Extract root tag information
    namespace_match = re.match(r'\{(.*)\}', root.tag)
    namespace = namespace_match.group(1) if namespace_match else None
    root_tag = root.tag.split('}')[-1] if '}' in root.tag else root.tag
    
    # Count elements
    all_elements = list(root.iter())
    element_counts = {}
    for elem in all_elements:
        tag_name = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
        element_counts[tag_name] = element_counts.get(tag_name, 0) + 1
    
    # Detect key structures
    has_response_header = root.find('.//*[local-name()="ResponseHeader"]') is not None
    has_reading_session = root.find('.//*[local-name()="readingSession"]') is not None
    has_unblinded_read = root.find('.//*[local-name()="unblindedReadNodule"]') is not None
    
    return {
        'root_tag': root_tag,
        'namespace': namespace,
        'total_elements': len(all_elements),
        'element_counts': element_counts,
        'has_response_header': has_response_header,
        'has_reading_session': has_reading_session,
        'has_unblinded_read': has_unblinded_read,
        'is_lidc_format': root_tag == 'LidcReadMessage'
    }
