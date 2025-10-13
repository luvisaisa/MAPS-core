"""
XML keyword extractor for radiology annotation data.

Automatically extracts medical keywords from parsed XML files,
including characteristics, ROI data, and radiologist annotations.
"""

import logging
from typing import List, Dict, Optional, Set, Tuple
from dataclasses import dataclass, field
import pandas as pd

from .keyword_normalizer import KeywordNormalizer
from .parser import parse_radiology_sample, detect_parse_case

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class XMLExtractedKeyword:
    """Keyword extracted from XML with source tracking"""
    text: str
    category: str  # characteristic, roi, header, session
    source_file: str
    nodule_id: Optional[str] = None
    context: str = ""
    frequency: int = 1
    normalized_form: Optional[str] = None
    metadata: Dict = field(default_factory=dict)


class XMLKeywordExtractor:
    """
    Extract keywords from radiology XML files.

    Extracts keywords from:
    - Header fields (StudyUID, Modality, DateTime)
    - Nodule characteristics (subtlety, malignancy, etc.)
    - ROI coordinate data
    - Reading session metadata
    """

    def __init__(self, normalizer: Optional[KeywordNormalizer] = None):
        """
        Initialize XML keyword extractor.

        Args:
            normalizer: Optional keyword normalizer for term standardization
        """
        self.normalizer = normalizer or KeywordNormalizer()

        # Characteristic value mappings for semantic keywords
        self.characteristic_descriptors = {
            'subtlety': {
                '1': ['extremely_subtle', 'barely_visible'],
                '2': ['moderately_subtle', 'faint'],
                '3': ['fairly_subtle', 'visible'],
                '4': ['moderately_obvious', 'clear'],
                '5': ['obvious', 'very_clear']
            },
            'malignancy': {
                '1': ['highly_unlikely_malignant', 'benign'],
                '2': ['moderately_unlikely_malignant', 'probably_benign'],
                '3': ['indeterminate', 'uncertain'],
                '4': ['moderately_suspicious', 'possibly_malignant'],
                '5': ['highly_suspicious', 'likely_malignant']
            },
            'calcification': {
                '1': ['popcorn', 'benign_calcification'],
                '2': ['laminated', 'concentric'],
                '3': ['solid', 'dense'],
                '4': ['non_central', 'eccentric'],
                '5': ['central', 'centrally_located'],
                '6': ['absent', 'no_calcification']
            },
            'sphericity': {
                '1': ['linear', 'elongated'],
                '3': ['ovoid', 'oval'],
                '5': ['round', 'spherical']
            },
            'margin': {
                '1': ['poorly_defined', 'indistinct'],
                '2': ['near_poorly_defined', 'somewhat_indistinct'],
                '3': ['medium_margin', 'moderate'],
                '4': ['near_sharp', 'relatively_sharp'],
                '5': ['sharp', 'well_defined']
            },
            'lobulation': {
                '1': ['marked_lobulation', 'highly_lobulated'],
                '2': ['near_marked', 'moderately_lobulated'],
                '3': ['medium_lobulation', 'some_lobulation'],
                '4': ['near_none', 'minimal_lobulation'],
                '5': ['no_lobulation', 'smooth']
            },
            'spiculation': {
                '1': ['marked_spiculation', 'highly_spiculated'],
                '2': ['near_marked', 'moderately_spiculated'],
                '3': ['medium_spiculation', 'some_spiculation'],
                '4': ['near_none', 'minimal_spiculation'],
                '5': ['no_spiculation', 'smooth_border']
            },
            'texture': {
                '1': ['non_solid', 'ground_glass'],
                '2': ['near_non_solid', 'mostly_ground_glass'],
                '3': ['part_solid', 'mixed'],
                '4': ['near_solid', 'mostly_solid'],
                '5': ['solid', 'completely_solid']
            }
        }

    def extract_from_xml(
        self,
        xml_file: str,
        extract_characteristics: bool = True,
        extract_header: bool = True,
        extract_roi: bool = False
    ) -> List[XMLExtractedKeyword]:
        """
        Extract keywords from XML file.

        Args:
            xml_file: Path to XML file
            extract_characteristics: Extract from nodule characteristics
            extract_header: Extract from header fields
            extract_roi: Extract from ROI coordinate data

        Returns:
            List of extracted keywords
        """
        keywords = []

        try:
            # Parse the XML file
            main_df, unblinded_df = parse_radiology_sample(xml_file)

            if main_df.empty:
                logger.warning(f"No data extracted from {xml_file}")
                return keywords

            # Detect parse case for context
            parse_case = detect_parse_case(xml_file)

            # Extract header keywords
            if extract_header and 'StudyInstanceUID' in main_df.columns:
                header_keywords = self._extract_header_keywords(
                    main_df, xml_file
                )
                keywords.extend(header_keywords)

            # Extract characteristic keywords
            if extract_characteristics and 'Characteristics' in main_df.columns:
                char_keywords = self._extract_characteristic_keywords(
                    main_df, xml_file, parse_case
                )
                keywords.extend(char_keywords)

            # Extract ROI keywords
            if extract_roi and 'ROI_Coords' in main_df.columns:
                roi_keywords = self._extract_roi_keywords(
                    main_df, xml_file
                )
                keywords.extend(roi_keywords)

            # Normalize all keywords
            for keyword in keywords:
                keyword.normalized_form = self.normalizer.normalize(keyword.text)

            logger.info(f"Extracted {len(keywords)} keywords from {xml_file}")

        except Exception as e:
            logger.error(f"Error extracting keywords from {xml_file}: {e}")

        return keywords

    def _extract_header_keywords(
        self,
        df: pd.DataFrame,
        source_file: str
    ) -> List[XMLExtractedKeyword]:
        """Extract keywords from header fields"""
        keywords = []

        if not df.empty:
            row = df.iloc[0]

            # Modality
            if 'Modality' in df.columns and pd.notna(row['Modality']):
                keywords.append(XMLExtractedKeyword(
                    text=str(row['Modality']).lower(),
                    category='header',
                    source_file=source_file,
                    context='imaging_modality',
                    metadata={'field': 'Modality'}
                ))

            # Study UID (truncated for keyword)
            if 'StudyInstanceUID' in df.columns and pd.notna(row['StudyInstanceUID']):
                uid_parts = str(row['StudyInstanceUID']).split('.')
                if uid_parts:
                    keywords.append(XMLExtractedKeyword(
                        text=f"study_{uid_parts[-1]}",
                        category='header',
                        source_file=source_file,
                        context='study_identifier',
                        metadata={'field': 'StudyInstanceUID'}
                    ))

        return keywords

    def _extract_characteristic_keywords(
        self,
        df: pd.DataFrame,
        source_file: str,
        parse_case: str
    ) -> List[XMLExtractedKeyword]:
        """Extract keywords from nodule characteristics"""
        keywords = []

        for idx, row in df.iterrows():
            if 'Characteristics' not in df.columns:
                continue

            characteristics = row.get('Characteristics', {})
            if not isinstance(characteristics, dict):
                continue

            nodule_id = row.get('NoduleID', str(idx))

            for char_name, char_value in characteristics.items():
                if pd.isna(char_value):
                    continue

                # Create keyword for characteristic name
                keywords.append(XMLExtractedKeyword(
                    text=char_name.lower(),
                    category='characteristic',
                    source_file=source_file,
                    nodule_id=nodule_id,
                    context=f"{char_name}={char_value}",
                    metadata={'characteristic': char_name, 'value': char_value}
                ))

                # Create semantic keywords from descriptors
                if char_name.lower() in self.characteristic_descriptors:
                    value_str = str(char_value)
                    descriptors = self.characteristic_descriptors[char_name.lower()].get(
                        value_str, []
                    )

                    for descriptor in descriptors:
                        keywords.append(XMLExtractedKeyword(
                            text=descriptor,
                            category='characteristic_semantic',
                            source_file=source_file,
                            nodule_id=nodule_id,
                            context=f"{char_name}={char_value}",
                            metadata={
                                'characteristic': char_name,
                                'value': char_value,
                                'descriptor': descriptor
                            }
                        ))

        return keywords

    def _extract_roi_keywords(
        self,
        df: pd.DataFrame,
        source_file: str
    ) -> List[XMLExtractedKeyword]:
        """Extract keywords from ROI coordinate data"""
        keywords = []

        for idx, row in df.iterrows():
            if 'ROI_Coords' not in df.columns:
                continue

            roi_coords = row.get('ROI_Coords', [])
            if not roi_coords:
                continue

            nodule_id = row.get('NoduleID', str(idx))

            # Extract ROI size information
            num_coords = len(roi_coords)
            keywords.append(XMLExtractedKeyword(
                text=f"roi_size_{num_coords}_points",
                category='roi',
                source_file=source_file,
                nodule_id=nodule_id,
                context=f"ROI with {num_coords} coordinate points",
                metadata={'roi_point_count': num_coords}
            ))

        return keywords

    def extract_from_multiple(
        self,
        xml_files: List[str],
        progress_callback: Optional[callable] = None
    ) -> Dict[str, List[XMLExtractedKeyword]]:
        """
        Extract keywords from multiple XML files.

        Args:
            xml_files: List of XML file paths
            progress_callback: Optional callback(current, total, filename)

        Returns:
            Dictionary mapping file path to keywords
        """
        results = {}
        total = len(xml_files)

        for i, xml_file in enumerate(xml_files, start=1):
            if progress_callback:
                progress_callback(i, total, xml_file)

            keywords = self.extract_from_xml(xml_file)
            results[xml_file] = keywords

        return results

    def get_keyword_statistics(
        self,
        keywords: List[XMLExtractedKeyword]
    ) -> Dict[str, any]:
        """Get statistics about extracted keywords"""
        stats = {
            'total_keywords': len(keywords),
            'unique_keywords': len(set(kw.text for kw in keywords)),
            'by_category': {},
            'top_keywords': []
        }

        # Count by category
        for kw in keywords:
            stats['by_category'][kw.category] = stats['by_category'].get(kw.category, 0) + 1

        # Count frequencies
        keyword_counts = {}
        for kw in keywords:
            keyword_counts[kw.text] = keyword_counts.get(kw.text, 0) + 1

        # Top 10 keywords
        sorted_keywords = sorted(keyword_counts.items(), key=lambda x: x[1], reverse=True)
        stats['top_keywords'] = sorted_keywords[:10]

        return stats
