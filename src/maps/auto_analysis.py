"""
Auto-analysis module for automatic keyword and entity extraction.

Integrates keyword extraction with canonical schema entity models,
enabling automatic population of ExtractedEntities during parsing.
"""

import logging
from typing import List, Dict, Optional
from datetime import datetime
import re

from .schemas.canonical import (
    CanonicalDocument,
    RadiologyCanonicalDocument,
    Entity,
    ExtractedEntities,
    EntityType,
    ExtractionMetadata
)
from .keyword_normalizer import KeywordNormalizer
from .xml_keyword_extractor import XMLKeywordExtractor, XMLExtractedKeyword

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AutoAnalyzer:
    """
    Automatic analyzer for populating canonical document entities.

    Extracts entities from parsed data and populates:
    - Dates (service dates, study dates)
    - Identifiers (Study UID, Series UID)
    - Medical terms (characteristics, findings)
    - Measurements (ROI sizes, nodule counts)
    """

    def __init__(
        self,
        normalizer: Optional[KeywordNormalizer] = None,
        xml_extractor: Optional[XMLKeywordExtractor] = None
    ):
        """
        Initialize auto analyzer.

        Args:
            normalizer: Keyword normalizer instance
            xml_extractor: XML keyword extractor instance
        """
        self.normalizer = normalizer or KeywordNormalizer()
        self.xml_extractor = xml_extractor or XMLKeywordExtractor(self.normalizer)

    def analyze_xml(
        self,
        xml_file: str,
        populate_entities: bool = True
    ) -> RadiologyCanonicalDocument:
        """
        Analyze XML file and create canonical document with entities.

        Args:
            xml_file: Path to XML file
            populate_entities: Whether to auto-populate entities

        Returns:
            RadiologyCanonicalDocument with extracted entities
        """
        from .parser import parse_radiology_sample, detect_parse_case

        # Parse XML
        main_df, unblinded_df = parse_radiology_sample(xml_file)

        if main_df.empty:
            raise ValueError(f"No data extracted from {xml_file}")

        # Get first row for metadata
        row = main_df.iloc[0]

        # Create canonical document
        doc = RadiologyCanonicalDocument(
            document_metadata={
                'document_type': 'radiology_report',
                'date': row.get('DateService'),
                'title': f"Radiology Scan - {row.get('StudyInstanceUID', 'Unknown')[:20]}..."
            },
            study_instance_uid=row.get('StudyInstanceUID'),
            series_instance_uid=row.get('SeriesInstanceUID'),
            modality=row.get('Modality'),
            nodules=[],
            radiologist_readings=[]
        )

        # Extract keywords
        keywords = self.xml_extractor.extract_from_xml(xml_file)

        # Populate entities if requested
        if populate_entities:
            doc.entities = self._extract_entities_from_keywords(keywords, row)

        # Populate extraction metadata
        parse_case = detect_parse_case(xml_file)
        doc.extraction_metadata = ExtractionMetadata(
            extraction_timestamp=datetime.utcnow(),
            profile_name='xml_auto_extraction',
            parser_version='0.5.0',
            overall_confidence=self._calculate_confidence(keywords)
        )

        # Add nodule data
        for idx, nodule_row in main_df.iterrows():
            nodule_data = {
                'nodule_id': nodule_row.get('NoduleID', str(idx)),
                'characteristics': nodule_row.get('Characteristics', {}),
                'roi_coords': nodule_row.get('ROI_Coords', [])
            }
            doc.nodules.append(nodule_data)

        logger.info(f"Auto-analyzed {xml_file}: {len(keywords)} keywords, "
                   f"{len(doc.nodules)} nodules")

        return doc

    def _extract_entities_from_keywords(
        self,
        keywords: List[XMLExtractedKeyword],
        metadata_row
    ) -> ExtractedEntities:
        """Extract entities from keywords and metadata"""
        entities = ExtractedEntities()

        # Extract dates
        if metadata_row.get('DateService'):
            entities.dates.append(Entity(
                entity_type=EntityType.DATE,
                value=str(metadata_row['DateService']),
                normalized_value=str(metadata_row['DateService']),
                confidence=0.99,
                source_field='DateService'
            ))

        # Extract identifiers
        if metadata_row.get('StudyInstanceUID'):
            entities.identifiers.append(Entity(
                entity_type=EntityType.IDENTIFIER,
                value=str(metadata_row['StudyInstanceUID']),
                normalized_value='study_uid',
                confidence=1.0,
                source_field='StudyInstanceUID',
                metadata={'type': 'DICOM_StudyUID'}
            ))

        if metadata_row.get('SeriesInstanceUID'):
            entities.identifiers.append(Entity(
                entity_type=EntityType.IDENTIFIER,
                value=str(metadata_row['SeriesInstanceUID']),
                normalized_value='series_uid',
                confidence=1.0,
                source_field='SeriesInstanceUID',
                metadata={'type': 'DICOM_SeriesUID'}
            ))

        # Extract medical terms from keywords
        for kw in keywords:
            if kw.category in ['characteristic', 'characteristic_semantic']:
                entities.medical_terms.append(Entity(
                    entity_type=EntityType.MEDICAL_TERM,
                    value=kw.text,
                    normalized_value=kw.normalized_form or kw.text,
                    confidence=0.85,
                    source_field='characteristics',
                    metadata={
                        'category': kw.category,
                        'nodule_id': kw.nodule_id,
                        **kw.metadata
                    }
                ))

        return entities

    def _calculate_confidence(self, keywords: List[XMLExtractedKeyword]) -> float:
        """Calculate overall extraction confidence based on keywords"""
        if not keywords:
            return 0.5

        # Higher confidence if we have multiple categories
        categories = set(kw.category for kw in keywords)
        category_score = min(len(categories) / 5.0, 1.0)

        # Higher confidence if we have normalized forms
        normalized_count = sum(1 for kw in keywords if kw.normalized_form)
        normalization_score = normalized_count / len(keywords)

        # Combine scores
        confidence = (category_score * 0.4) + (normalization_score * 0.6)

        return round(confidence, 2)

    def analyze_batch(
        self,
        xml_files: List[str],
        progress_callback: Optional[callable] = None
    ) -> List[RadiologyCanonicalDocument]:
        """
        Analyze multiple XML files in batch.

        Args:
            xml_files: List of XML file paths
            progress_callback: Optional progress callback

        Returns:
            List of canonical documents
        """
        documents = []
        total = len(xml_files)

        for i, xml_file in enumerate(xml_files, start=1):
            if progress_callback:
                progress_callback(i, total, xml_file)

            try:
                doc = self.analyze_xml(xml_file)
                documents.append(doc)
            except Exception as e:
                logger.error(f"Error analyzing {xml_file}: {e}")
                continue

        return documents

    def get_analysis_summary(
        self,
        documents: List[RadiologyCanonicalDocument]
    ) -> Dict:
        """Get summary statistics from analyzed documents"""
        summary = {
            'total_documents': len(documents),
            'total_nodules': sum(len(doc.nodules) for doc in documents),
            'total_entities': 0,
            'entities_by_type': {},
            'modalities': {},
            'average_confidence': 0.0
        }

        for doc in documents:
            # Count entities
            for entity_list_name in ['dates', 'identifiers', 'medical_terms', 'people', 'organizations']:
                entity_list = getattr(doc.entities, entity_list_name, [])
                count = len(entity_list)
                summary['total_entities'] += count

                if count > 0:
                    summary['entities_by_type'][entity_list_name] = \
                        summary['entities_by_type'].get(entity_list_name, 0) + count

            # Count modalities
            if doc.modality:
                summary['modalities'][doc.modality] = \
                    summary['modalities'].get(doc.modality, 0) + 1

        # Calculate average confidence
        confidences = [
            doc.extraction_metadata.overall_confidence
            for doc in documents
            if doc.extraction_metadata.overall_confidence is not None
        ]
        if confidences:
            summary['average_confidence'] = round(sum(confidences) / len(confidences), 2)

        return summary
