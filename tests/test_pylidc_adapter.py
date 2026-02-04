"""tests for pylidc adapter module."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

from src.maps.adapters.pylidc_adapter import PyLIDCAdapter, PYLIDC_AVAILABLE
from src.maps.schemas.canonical import RadiologyCanonicalDocument


class TestPyLIDCAdapter:
    """test suite for pylidc adapter."""

    def test_init_without_pylidc(self, monkeypatch):
        """test initialization fails when pylidc not available."""
        monkeypatch.setattr('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', False)
        
        with pytest.raises(ImportError, match="pylidc library is not installed"):
            PyLIDCAdapter()

    @pytest.mark.skipif(not PYLIDC_AVAILABLE, reason="pylidc not installed")
    def test_init_with_pylidc(self):
        """test successful initialization when pylidc available."""
        adapter = PyLIDCAdapter()
        assert adapter is not None

    def test_scan_to_canonical_basic(self, mock_scan):
        """test basic scan conversion without annotations."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            doc = adapter.scan_to_canonical(mock_scan, include_annotations=False)
            
            assert isinstance(doc, RadiologyCanonicalDocument)
            assert doc.document_metadata.document_id == mock_scan.series_instance_uid
            assert doc.series_instance_uid == mock_scan.series_instance_uid
            assert doc.study_instance_uid == mock_scan.study_instance_uid
            assert doc.modality == "CT"
            assert doc.fields["patient_id"] == mock_scan.patient_id
            assert doc.fields["slice_thickness"] == float(mock_scan.slice_thickness)
            assert doc.fields["pixel_spacing"] == float(mock_scan.pixel_spacing)
            assert doc.fields["num_slices"] == len(mock_scan.slice_zvals)
            assert len(doc.nodules) == 0
            assert len(doc.radiologist_readings) == 0

    def test_scan_to_canonical_with_annotations(self, mock_scan_with_annotations):
        """test scan conversion with annotation clustering."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            doc = adapter.scan_to_canonical(
                mock_scan_with_annotations,
                include_annotations=True,
                cluster_nodules=True
            )
            
            assert isinstance(doc, RadiologyCanonicalDocument)
            assert len(doc.nodules) == 1
            assert doc.nodules[0]["nodule_id"] == "1"
            assert doc.nodules[0]["num_radiologists"] == 3
            assert "consensus" in doc.nodules[0]
            assert len(doc.radiologist_readings) == 0

    def test_scan_to_canonical_without_clustering(self, mock_scan_with_annotations):
        """test scan conversion without clustering annotations."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            doc = adapter.scan_to_canonical(
                mock_scan_with_annotations,
                include_annotations=True,
                cluster_nodules=False
            )
            
            assert isinstance(doc, RadiologyCanonicalDocument)
            assert len(doc.nodules) == 0
            assert len(doc.radiologist_readings) == 3

    def test_annotation_to_dict(self, mock_annotation):
        """test annotation object to dictionary conversion."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            ann_dict = adapter._annotation_to_dict(mock_annotation)
            
            assert ann_dict["subtlety"] == 3
            assert ann_dict["internalStructure"] == 2
            assert ann_dict["calcification"] == 1
            assert ann_dict["sphericity"] == 4
            assert ann_dict["margin"] == 3
            assert ann_dict["lobulation"] == 2
            assert ann_dict["spiculation"] == 1
            assert ann_dict["texture"] == 3
            assert ann_dict["malignancy"] == 2
            assert ann_dict["diameter"] == 10.5
            assert ann_dict["surface_area"] == 346.36
            assert ann_dict["volume"] == 606.13
            assert ann_dict["centroid"]["x"] == 50.0
            assert ann_dict["centroid"]["y"] == 60.0
            assert ann_dict["centroid"]["z"] == 70.0
            assert ann_dict["bbox"]["xmin"] == 40.0
            assert ann_dict["bbox"]["xmax"] == 60.0

    def test_annotation_to_dict_with_none_values(self, mock_annotation_partial):
        """test annotation conversion with missing values."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            ann_dict = adapter._annotation_to_dict(mock_annotation_partial)
            
            assert ann_dict["subtlety"] == 3
            assert ann_dict["internalStructure"] is None
            assert ann_dict["calcification"] == 1
            assert ann_dict["sphericity"] is None
            assert ann_dict["malignancy"] == 2
            assert ann_dict["diameter"] == 8.2

    def test_cluster_to_nodule_single(self, mock_annotation):
        """test nodule creation from single annotation."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            nodule = adapter._cluster_to_nodule(1, [mock_annotation])
            
            assert nodule["nodule_id"] == "1"
            assert nodule["num_radiologists"] == 1
            assert "1" in nodule["radiologists"]
            assert "consensus" not in nodule

    def test_cluster_to_nodule_multiple(self, mock_annotations_cluster):
        """test nodule creation from multiple annotations with consensus."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            nodule = adapter._cluster_to_nodule(2, mock_annotations_cluster)
            
            assert nodule["nodule_id"] == "2"
            assert nodule["num_radiologists"] == 3
            assert "1" in nodule["radiologists"]
            assert "2" in nodule["radiologists"]
            assert "3" in nodule["radiologists"]
            assert "consensus" in nodule

    def test_calculate_consensus_basic(self, mock_annotations_cluster):
        """test consensus calculation with complete data."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            consensus = adapter._calculate_consensus(mock_annotations_cluster)
            
            assert "subtlety_mean" in consensus
            assert "subtlety_median" in consensus
            assert "subtlety_stdev" in consensus
            assert consensus["subtlety_mean"] == 4.0
            assert consensus["subtlety_median"] == 4
            assert "diameter_mean" in consensus
            assert consensus["diameter_mean"] == 11.0

    def test_calculate_consensus_with_missing_values(self, mock_annotation, mock_annotation_partial):
        """test consensus calculation with some missing values."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            annotations = [mock_annotation, mock_annotation_partial]
            consensus = adapter._calculate_consensus(annotations)
            
            # should handle missing values gracefully
            assert "subtlety_mean" in consensus
            assert consensus["subtlety_mean"] == 3.0
            # fields with all none should not appear or handle correctly
            assert "diameter_mean" in consensus

    def test_scans_to_canonical_batch(self, mock_scans_list):
        """test batch conversion of multiple scans."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            docs = adapter.scans_to_canonical_batch(mock_scans_list)
            
            assert len(docs) == 3
            assert all(isinstance(doc, RadiologyCanonicalDocument) for doc in docs)
            assert docs[0].fields["patient_id"] == "LIDC-IDRI-0000"
            assert docs[1].fields["patient_id"] == "LIDC-IDRI-0001"
            assert docs[2].fields["patient_id"] == "LIDC-IDRI-0002"

    def test_scans_to_canonical_batch_with_callback(self, mock_scans_list):
        """test batch conversion with progress callback."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            callback_calls = []
            
            def progress_callback(current, total, scan_id):
                callback_calls.append((current, total, scan_id))
            
            docs = adapter.scans_to_canonical_batch(
                mock_scans_list,
                progress_callback=progress_callback
            )
            
            assert len(docs) == 3
            assert len(callback_calls) == 3
            assert callback_calls[0] == (1, 3, "LIDC-IDRI-0000")
            assert callback_calls[1] == (2, 3, "LIDC-IDRI-0001")
            assert callback_calls[2] == (3, 3, "LIDC-IDRI-0002")

    def test_scans_to_canonical_batch_with_errors(self, mock_scans_list):
        """test batch conversion continues on individual scan errors."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            
            # make second scan raise error when accessing slice_thickness
            def raise_error():
                raise AttributeError("test error")
            type(mock_scans_list[1]).slice_thickness = property(lambda self: raise_error())
            
            docs = adapter.scans_to_canonical_batch(mock_scans_list)
            
            # should still process the other scans
            assert len(docs) == 2

    def test_get_scan_statistics_basic(self, mock_scan):
        """test statistics extraction from basic scan."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            doc = adapter.scan_to_canonical(mock_scan)
            stats = adapter.get_scan_statistics(doc)
            
            assert stats["patient_id"] == "LIDC-IDRI-0001"
            assert stats["num_nodules"] == 0
            assert stats["num_readings"] == 0
            assert stats["modality"] == "CT"
            assert stats["slice_thickness"] == 2.5
            assert stats["has_contrast"] is False

    def test_get_scan_statistics_with_nodules(self, mock_scan_with_annotations):
        """test statistics extraction from scan with nodules."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', True):
            adapter = PyLIDCAdapter()
            doc = adapter.scan_to_canonical(mock_scan_with_annotations)
            stats = adapter.get_scan_statistics(doc)
            
            assert stats["num_nodules"] == 1
            assert stats["total_annotations"] == 3

    @pytest.mark.skipif(PYLIDC_AVAILABLE, reason="test requires pylidc not installed")
    def test_query_and_convert_without_pylidc(self):
        """test query_and_convert fails when pylidc not available."""
        with patch('src.maps.adapters.pylidc_adapter.PYLIDC_AVAILABLE', False):
            adapter = Mock()
            adapter.query_and_convert = PyLIDCAdapter.query_and_convert.__get__(adapter, PyLIDCAdapter)
            
            with pytest.raises(ImportError, match="pylidc not available"):
                adapter.query_and_convert()
