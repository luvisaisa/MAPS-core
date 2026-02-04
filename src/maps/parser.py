"""Core XML parsing functions for medical annotation data."""

import logging
import xml.etree.ElementTree as ET
import re
import pandas as pd
from typing import Tuple, Dict, List, Any, Optional
import os

logger = logging.getLogger(__name__)


def parse_radiology_sample(file_path: str) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Parse a single radiology XML file and return DataFrames.
    
    Args:
        file_path: Path to the XML file
        
    Returns:
        Tuple of (main_dataframe, unblinded_dataframe)
        
    Raises:
        FileNotFoundError: If file does not exist
        ET.ParseError: If XML is malformed
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")
    
    logger.info(f"Parsing XML file: {os.path.basename(file_path)}")
    
    # Detect parse case first
    parse_case = detect_parse_case(file_path)
    logger.info(f"Parse case: {parse_case}")
    
    expected_attrs = get_expected_attributes_for_case(parse_case)
    
    try:
        # Load XML file
        tree = ET.parse(file_path)
        root = tree.getroot()
    except ET.ParseError as e:
        raise ET.ParseError(f"Malformed XML in {file_path}: {e}")
    
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
        for field in expected_attrs["header"]:
            elem = header.find(tag(field))
            if elem is not None and elem.text:
                header_values[field] = elem.text
            else:
                header_values[field] = "MISSING"
                logger.warning(f"Expected field missing: {field}")
    
    # Extract nodule data with characteristics
    records = []
    unblinded_reads = root.findall(tag('unblindedReadNodule'))
    
    for nodule_elem in unblinded_reads:
        record = header_values.copy()
        
        # Extract nodule ID
        nodule_id = nodule_elem.find(tag('noduleID'))
        if nodule_id is not None and nodule_id.text:
            record['noduleID'] = nodule_id.text
        
        # Extract characteristics
        char_data = extract_characteristics(nodule_elem, tag)
        record.update(char_data)
        
        # Extract ROI data (count of ROIs)
        rois = extract_roi_data(nodule_elem, tag)
        record['roi_count'] = len(rois)
        
        records.append(record)
    
    # Convert to DataFrame
    main_df = pd.DataFrame(records) if records else pd.DataFrame()
    unblinded_df = pd.DataFrame()  # Placeholder for now
    
    logger.info(f"Parsed {len(records)} nodule records")
    
    return main_df, unblinded_df


def extract_roi_data(nodule_elem, tag_func):
    """Extract ROI (Region of Interest) data from a nodule element."""
    roi_list = []
    rois = nodule_elem.findall(tag_func('roi'))
    
    for roi in rois:
        roi_data = {}
        
        image_sop = roi.find(tag_func('imageSOP_UID'))
        if image_sop is not None and image_sop.text:
            roi_data['imageSOP_UID'] = image_sop.text
        
        x_coord = roi.find(tag_func('xCoord'))
        if x_coord is not None and x_coord.text:
            roi_data['xCoord'] = x_coord.text
            
        y_coord = roi.find(tag_func('yCoord'))
        if y_coord is not None and y_coord.text:
            roi_data['yCoord'] = y_coord.text
        
        roi_list.append(roi_data)
    
    return roi_list


def extract_characteristics(nodule_elem, tag_func):
    """Extract nodule characteristic data."""
    char_data = {}
    characteristics = nodule_elem.find(tag_func('characteristics'))

    if characteristics is not None:
        char_fields = [
            'subtlety', 'internalStructure', 'calcification', 'sphericity',
            'margin', 'lobulation', 'spiculation', 'texture', 'malignancy'
        ]
        for field in char_fields:
            elem = characteristics.find(tag_func(field))
            if elem is not None and elem.text:
                char_data[field] = elem.text

    return char_data


def extract_reading_sessions(root, tag_func):
    """
    Extract reading session data from XML.
    
    Args:
        root: XML root element
        tag_func: Function to build namespaced tags
        
    Returns:
        List of reading session dictionaries
    """
    sessions = []
    reading_sessions = root.findall(tag_func('readingSession'))
    
    for session in reading_sessions:
        session_data = {}
        
        # Extract radiologist ID
        rad_id = session.find(tag_func('servicingRadiologistID'))
        if rad_id is not None and rad_id.text:
            session_data['radiologist_id'] = rad_id.text
        
        # Extract annotation version
        annotation_version = session.find(tag_func('annotationVersion'))
        if annotation_version is not None and annotation_version.text:
            session_data['annotation_version'] = annotation_version.text
        
        sessions.append(session_data)
    
    return sessions


def detect_parse_case(file_path: str) -> str:
    """
    Detect the parse case (XML structure type) of a file.
    
    Args:
        file_path: Path to XML file
        
    Returns:
        Parse case identifier string
    """
    tree = ET.parse(file_path)
    root = tree.getroot()
    
    # Extract namespace
    namespace_match = re.match(r'\{(.*)\}', root.tag)
    ns_uri = namespace_match.group(1) if namespace_match else ''
    
    def tag(name):
        return f"{{{ns_uri}}}{name}" if ns_uri else name
    
    # Check for LIDC format
    root_tag = root.tag.split('}')[-1] if '}' in root.tag else root.tag
    is_lidc = root_tag == 'LidcReadMessage'
    
    # Count reading sessions
    reading_sessions = root.findall(tag('readingSession'))
    session_count = len(reading_sessions)
    
    if is_lidc:
        if session_count == 1:
            return "LIDC_Single_Session"
        elif session_count == 2:
            return "LIDC_Multi_Session_2"
        elif session_count == 3:
            return "LIDC_Multi_Session_3"
        elif session_count == 4:
            return "LIDC_Multi_Session_4"
        else:
            return f"LIDC_Multi_Session_{session_count}"
    
    # Non-LIDC format detection
    header = root.find(tag('ResponseHeader'))
    if header is None:
        return "Unknown"
    
    # Check for complete attributes
    has_modality = header.find(tag('Modality')) is not None
    has_date = header.find(tag('DateService')) is not None
    
    if has_modality and has_date:
        return "Complete_Attributes"
    elif has_date:
        return "Core_Attributes_Only"
    else:
        return "With_Reason_Partial"


def get_expected_attributes_for_case(parse_case: str) -> Dict[str, List[str]]:
    """
    Get expected XML attributes for a given parse case.

    Args:
        parse_case: Parse case identifier

    Returns:
        Dictionary mapping attribute categories to expected field lists
    """
    # LIDC sessions share the same structure
    lidc_session_attrs = {
        "header": ["StudyInstanceUID", "SeriesInstanceUID", "DateService", "TimeService"],
        "characteristics": ["subtlety"],
        "roi": ["imageSOP_UID", "xCoord", "yCoord"],
        "nodule": ["noduleID"]
    }

    expected_attrs = {
        "Complete_Attributes": {
            "header": ["StudyInstanceUID", "SeriesInstanceUID", "Modality", "DateService", "TimeService"],
            "characteristics": ["subtlety", "internalStructure", "calcification", "sphericity",
                              "margin", "lobulation", "spiculation", "texture", "malignancy"],
            "roi": ["imageSOP_UID", "xCoord", "yCoord"],
            "nodule": ["noduleID"]
        },
        "Core_Attributes_Only": {
            "header": ["StudyInstanceUID", "SeriesInstanceUID", "DateService"],
            "characteristics": ["subtlety", "malignancy"],
            "roi": ["imageSOP_UID", "xCoord", "yCoord"],
            "nodule": ["noduleID"]
        },
        "With_Reason_Partial": {
            "header": ["StudyInstanceUID", "SeriesInstanceUID"],
            "characteristics": ["subtlety"],
            "roi": ["imageSOP_UID"],
            "nodule": ["noduleID"]
        },
        "LIDC_Single_Session": lidc_session_attrs,
    }

    # Default structure for unknown cases
    default_expected = {
        "header": ["StudyInstanceUID", "SeriesInstanceUID"],
        "characteristics": [],
        "roi": ["imageSOP_UID"],
        "nodule": ["noduleID"]
    }

    # Handle LIDC multi-session cases dynamically
    if parse_case.startswith("LIDC_Multi_Session_"):
        return lidc_session_attrs

    return expected_attrs.get(parse_case, default_expected)


def parse_multiple(files: List[str]) -> Tuple[Dict[str, pd.DataFrame], Dict[str, pd.DataFrame]]:
    """
    Parse multiple XML files.
    
    Args:
        files: List of file paths to parse
        
    Returns:
        Tuple of (main_dataframes_dict, unblinded_dataframes_dict)
    """
    main_dfs = {}
    unblinded_dfs = {}
    
    for file_path in files:
        try:
            main_df, unblinded_df = parse_radiology_sample(file_path)
            file_id = os.path.basename(file_path).split('.')[0]
            main_dfs[file_id] = main_df
            unblinded_dfs[file_id] = unblinded_df
            logger.info(f"Successfully parsed {file_id}")
        except Exception as e:
            logger.error(f"Error parsing {file_path}: {e}")
    
    return main_dfs, unblinded_dfs


def export_excel(df: pd.DataFrame, output_path: str) -> None:
    """
    Export DataFrame to Excel file.
    
    Args:
        df: DataFrame to export
        output_path: Path to save Excel file
    """
    from openpyxl import Workbook
    from openpyxl.utils.dataframe import dataframe_to_rows
    
    wb = Workbook()
    ws = wb.active
    ws.title = "Radiology Data"
    
    # Write DataFrame to worksheet
    for r in dataframe_to_rows(df, index=False, header=True):
        ws.append(r)
    
    wb.save(output_path)
    logger.info(f"Exported to {output_path}")


def get_parse_statistics(main_dfs: Dict[str, pd.DataFrame]) -> Dict[str, Any]:
    """
    Calculate statistics from parsed dataframes.
    
    Args:
        main_dfs: Dictionary of dataframes by file ID
        
    Returns:
        Dictionary containing parse statistics
    """
    stats = {
        'total_files': len(main_dfs),
        'total_records': sum(len(df) for df in main_dfs.values()),
        'records_per_file': {},
        'empty_files': []
    }
    
    for file_id, df in main_dfs.items():
        record_count = len(df)
        stats['records_per_file'][file_id] = record_count
        if record_count == 0:
            stats['empty_files'].append(file_id)
    
    return stats
