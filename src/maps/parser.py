"""Core XML parsing functions for medical annotation data."""

import xml.etree.ElementTree as ET
import re
from typing import Tuple, Dict, List
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
        study_uid = header.find(tag('StudyInstanceUID'))
        if study_uid is not None and study_uid.text:
            header_values['StudyInstanceUID'] = study_uid.text
            
        series_uid = header.find(tag('SeriesInstanceUID'))
        if series_uid is not None and series_uid.text:
            header_values['SeriesInstanceUID'] = series_uid.text
            
        modality = header.find(tag('Modality'))
        if modality is not None and modality.text:
            header_values['Modality'] = modality.text
            
        date_service = header.find(tag('DateService'))
        if date_service is not None and date_service.text:
            header_values['DateService'] = date_service.text
            
        time_service = header.find(tag('TimeService'))
        if time_service is not None and time_service.text:
            header_values['TimeService'] = time_service.text
    
    # Extract nodule data
    nodules = []
    unblinded_reads = root.findall(tag('unblindedReadNodule'))
    
    for nodule_elem in unblinded_reads:
        nodule_data = {}
        
        # Extract nodule ID
        nodule_id = nodule_elem.find(tag('noduleID'))
        if nodule_id is not None and nodule_id.text:
            nodule_data['noduleID'] = nodule_id.text
        
        nodules.append(nodule_data)
    
    main_data = {
        'header': header_values,
        'nodules': nodules
    }
    unblinded_data = {}
    
    return main_data, unblinded_data
