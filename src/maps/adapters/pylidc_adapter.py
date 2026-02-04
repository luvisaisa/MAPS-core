"""
PyLIDC Adapter for MAPS Schema-Agnostic System

Converts pylidc Scan and Annotation objects into canonical schema format.
Supports direct integration with the pylidc library for LIDC-IDRI dataset processing.

Usage:
    import pylidc as pl
    from maps.adapters import PyLIDCAdapter

    scan = pl.query(pl.Scan).first()
    adapter = PyLIDCAdapter()
    canonical_doc = adapter.scan_to_canonical(scan)
"""

import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
from decimal import Decimal

try:
    import pylidc as pl
    PYLIDC_AVAILABLE = True
except ImportError:
    PYLIDC_AVAILABLE = False
    pl = None

from ..schemas.canonical import (
    RadiologyCanonicalDocument,
    DocumentMetadata,
    ExtractionMetadata
)

logger = logging.getLogger(__name__)


class PyLIDCAdapter:
    """
    Adapter to convert pylidc Scan and Annotation objects to canonical schema.

    The pylidc library provides an ORM interface to the LIDC-IDRI dataset.
    This adapter bridges pylidc's object model with our canonical schema.
    """

    def __init__(self):
        """Initialize the PyLIDC adapter"""
        if not PYLIDC_AVAILABLE:
            raise ImportError(
                "pylidc library is not installed. "
                "Install it with: pip install pylidc"
            )

    def scan_to_canonical(
        self,
        scan,
        include_annotations: bool = True,
        cluster_nodules: bool = True
    ) -> RadiologyCanonicalDocument:
        """
        Convert a pylidc Scan object to RadiologyCanonicalDocument.

        Args:
            scan: pylidc.Scan object
            include_annotations: Whether to include annotation data
            cluster_nodules: Whether to cluster annotations into nodules

        Returns:
            RadiologyCanonicalDocument with scan and annotation data
        """
        metadata = DocumentMetadata(
            document_id=scan.series_instance_uid,
            document_type="radiology_report",
            title=f"LIDC Scan: {scan.patient_id}",
            date=datetime.utcnow()
        )

        nodules_data = []
        radiologist_readings = []

        if include_annotations:
            if cluster_nodules:
                nodule_clusters = scan.cluster_annotations()
                for nodule_idx, annotations in enumerate(nodule_clusters):
                    nodule_data = self._cluster_to_nodule(
                        nodule_idx + 1,
                        annotations
                    )
                    nodules_data.append(nodule_data)
            else:
                for ann in scan.annotations:
                    ann_data = self._annotation_to_dict(ann)
                    radiologist_readings.append(ann_data)

        extraction_meta = ExtractionMetadata(
            profile_id="pylidc-adapter",
            profile_name="PyLIDC Direct Adapter",
            parser_version="1.0.0"
        )

        doc = RadiologyCanonicalDocument(
            document_metadata=metadata,
            study_instance_uid=scan.study_instance_uid,
            series_instance_uid=scan.series_instance_uid,
            modality="CT",
            nodules=nodules_data,
            radiologist_readings=radiologist_readings,
            fields={
                "patient_id": scan.patient_id,
                "slice_thickness": float(scan.slice_thickness),
                "pixel_spacing": float(scan.pixel_spacing),
                "contrast_used": scan.contrast_used,
                "num_slices": len(scan.slice_zvals)
            },
            extraction_metadata=extraction_meta
        )

        return doc

    def _cluster_to_nodule(
        self,
        nodule_id: int,
        annotations: List
    ) -> Dict[str, Any]:
        """Convert a cluster of annotations to nodule dict"""
        nodule_data = {
            "nodule_id": str(nodule_id),
            "num_radiologists": len(annotations),
            "radiologists": {}
        }

        for rad_idx, ann in enumerate(annotations):
            rad_id = str(rad_idx + 1)
            nodule_data["radiologists"][rad_id] = self._annotation_to_dict(ann)

        if len(annotations) > 1:
            nodule_data["consensus"] = self._calculate_consensus(annotations)

        return nodule_data

    def _annotation_to_dict(self, ann) -> Dict[str, Any]:
        """Convert a pylidc Annotation object to dictionary"""
        centroid = ann.centroid

        return {
            "subtlety": int(ann.subtlety) if ann.subtlety else None,
            "internalStructure": int(ann.internalStructure) if ann.internalStructure else None,
            "calcification": int(ann.calcification) if ann.calcification else None,
            "sphericity": int(ann.sphericity) if ann.sphericity else None,
            "margin": int(ann.margin) if ann.margin else None,
            "lobulation": int(ann.lobulation) if ann.lobulation else None,
            "spiculation": int(ann.spiculation) if ann.spiculation else None,
            "texture": int(ann.texture) if ann.texture else None,
            "malignancy": int(ann.malignancy) if ann.malignancy else None,
            "diameter": float(ann.diameter),
            "surface_area": float(ann.surface_area),
            "volume": float(ann.volume),
            "centroid": {
                "x": float(centroid[0]),
                "y": float(centroid[1]),
                "z": float(centroid[2])
            },
            "bbox": {
                "xmin": float(ann.bbox()[0].start),
                "xmax": float(ann.bbox()[0].stop),
                "ymin": float(ann.bbox()[1].start),
                "ymax": float(ann.bbox()[1].stop),
                "zmin": float(ann.bbox()[2].start),
                "zmax": float(ann.bbox()[2].stop)
            }
        }

    def _calculate_consensus(self, annotations: List) -> Dict[str, Any]:
        """Calculate consensus metrics from multiple annotations"""
        import statistics

        consensus = {}

        characteristics = [
            'subtlety', 'internalStructure', 'calcification',
            'sphericity', 'margin', 'lobulation', 'spiculation',
            'texture', 'malignancy'
        ]

        for char in characteristics:
            values = [getattr(ann, char) for ann in annotations if getattr(ann, char) is not None]
            if values:
                consensus[f"{char}_mean"] = round(statistics.mean(values), 2)
                consensus[f"{char}_median"] = statistics.median(values)
                if len(values) > 1:
                    consensus[f"{char}_stdev"] = round(statistics.stdev(values), 2)

        diameters = [ann.diameter for ann in annotations]
        consensus["diameter_mean"] = round(statistics.mean(diameters), 2)

        return consensus

    def scans_to_canonical_batch(
        self,
        scans: List,
        include_annotations: bool = True,
        progress_callback: Optional[callable] = None
    ) -> List[RadiologyCanonicalDocument]:
        """
        Convert multiple scans to canonical documents in batch.

        Args:
            scans: List of pylidc.Scan objects
            include_annotations: Whether to include annotation data
            progress_callback: Optional callback(current, total, scan_id)

        Returns:
            List of RadiologyCanonicalDocument objects
        """
        documents = []
        total = len(scans)

        for i, scan in enumerate(scans, start=1):
            if progress_callback:
                progress_callback(i, total, scan.patient_id)

            try:
                doc = self.scan_to_canonical(
                    scan,
                    include_annotations=include_annotations
                )
                documents.append(doc)
            except Exception as e:
                logger.error(f"Error converting scan {scan.patient_id}: {e}")
                continue

        return documents

    def query_and_convert(
        self,
        patient_ids: Optional[List[str]] = None,
        max_scans: Optional[int] = None
    ) -> List[RadiologyCanonicalDocument]:
        """
        Query LIDC database and convert scans to canonical format.

        Args:
            patient_ids: Optional list of patient IDs to query
            max_scans: Optional maximum number of scans to process

        Returns:
            List of RadiologyCanonicalDocument objects
        """
        if not PYLIDC_AVAILABLE:
            raise ImportError("pylidc not available")

        query = pl.query(pl.Scan)

        if patient_ids:
            query = query.filter(pl.Scan.patient_id.in_(patient_ids))

        if max_scans:
            scans = query.limit(max_scans).all()
        else:
            scans = query.all()

        return self.scans_to_canonical_batch(scans)

    def get_scan_statistics(self, doc: RadiologyCanonicalDocument) -> Dict[str, Any]:
        """Get statistics from converted canonical document"""
        stats = {
            'patient_id': doc.fields.get('patient_id'),
            'num_nodules': len(doc.nodules),
            'num_readings': len(doc.radiologist_readings),
            'modality': doc.modality,
            'slice_thickness': doc.fields.get('slice_thickness'),
            'has_contrast': doc.fields.get('contrast_used', False)
        }

        if doc.nodules:
            total_radiologists = sum(
                nodule.get('num_radiologists', 0)
                for nodule in doc.nodules
            )
            stats['total_annotations'] = total_radiologists

        return stats
