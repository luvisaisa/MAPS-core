"""Core XML parsing functions for medical annotation data."""

import xml.etree.ElementTree as ET
import re
import pandas as pd
from typing import Tuple, Dict, List
import os


def parse_radiology_sample(file_path: str) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Parse a single radiology XML file and return DataFrames.
    
    Args:
        file_path: Path to the XML file
        
    Returns:
        Tuple of (main_dataframe, unblinded_dataframe)
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
    records = []
    unblinded_reads = root.findall(tag('unblindedReadNodule'))
    
    for nodule_elem in unblinded_reads:
        record = header_values.copy()
        
        # Extract nodule ID
        nodule_id = nodule_elem.find(tag('noduleID'))
        if nodule_id is not None and nodule_id.text:
            record['noduleID'] = nodule_id.text
        
        records.append(record)
    
    # Convert to DataFrame
    main_df = pd.DataFrame(records)
    unblinded_df = pd.DataFrame()  # Placeholder for now
    
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
        subtlety = characteristics.find(tag_func('subtlety'))
        if subtlety is not None and subtlety.text:
            char_data['subtlety'] = subtlety.text
        
        internal_struct = characteristics.find(tag_func('internalStructure'))
        if internal_struct is not None and internal_struct.text:
            char_data['internalStructure'] = internal_struct.text
        
        calcification = characteristics.find(tag_func('calcification'))
        if calcification is not None and calcification.text:
            char_data['calcification'] = calcification.text
        
        sphericity = characteristics.find(tag_func('sphericity'))
        if sphericity is not None and sphericity.text:
            char_data['sphericity'] = sphericity.text
        
        margin = characteristics.find(tag_func('margin'))
        if margin is not None and margin.text:
            char_data['margin'] = margin.text
        
        lobulation = characteristics.find(tag_func('lobulation'))
        if lobulation is not None and lobulation.text:
            char_data['lobulation'] = lobulation.text
        
        spiculation = characteristics.find(tag_func('spiculation'))
        if spiculation is not None and spiculation.text:
            char_data['spiculation'] = spiculation.text
        
        texture = characteristics.find(tag_func('texture'))
        if texture is not None and texture.text:
            char_data['texture'] = texture.text
        
        malignancy = characteristics.find(tag_func('malignancy'))
        if malignancy is not None and malignancy.text:
            char_data['malignancy'] = malignancy.text
    
    return char_data


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
            print(f"✓ Successfully parsed {file_id}")
        except Exception as e:
            print(f"✗ Error parsing {file_path}: {e}")
    
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
    print(f"✓ Exported to {output_path}")
