"""pytest configuration and shared fixtures."""

import pytest
from datetime import datetime
from unittest.mock import Mock, MagicMock


@pytest.fixture
def mock_annotation():
    """create mock pylidc annotation object."""
    ann = Mock()
    ann.subtlety = 3
    ann.internalStructure = 2
    ann.calcification = 1
    ann.sphericity = 4
    ann.margin = 3
    ann.lobulation = 2
    ann.spiculation = 1
    ann.texture = 3
    ann.malignancy = 2
    ann.diameter = 10.5
    ann.surface_area = 346.36
    ann.volume = 606.13
    ann.centroid = (50.0, 60.0, 70.0)
    ann.bbox = MagicMock(return_value=[
        slice(40, 60),
        slice(50, 70),
        slice(60, 80)
    ])
    return ann


@pytest.fixture
def mock_annotation_partial():
    """create mock annotation with some missing values."""
    ann = Mock()
    ann.subtlety = 3
    ann.internalStructure = None
    ann.calcification = 1
    ann.sphericity = None
    ann.margin = 3
    ann.lobulation = None
    ann.spiculation = 1
    ann.texture = None
    ann.malignancy = 2
    ann.diameter = 8.2
    ann.surface_area = 211.24
    ann.volume = 289.35
    ann.centroid = (45.0, 55.0, 65.0)
    ann.bbox = MagicMock(return_value=[
        slice(35, 55),
        slice(45, 65),
        slice(55, 75)
    ])
    return ann


@pytest.fixture
def mock_annotations_cluster(mock_annotation):
    """create list of mock annotations for clustering."""
    annotations = []
    for i in range(3):
        ann = Mock()
        ann.subtlety = 3 + i
        ann.internalStructure = 2 + i
        ann.calcification = 1 + i
        ann.sphericity = 4 + i
        ann.margin = 3 + i
        ann.lobulation = 2 + i
        ann.spiculation = 1 + i
        ann.texture = 3 + i
        ann.malignancy = 2 + i
        ann.diameter = 10.0 + i
        ann.surface_area = 300.0 + i * 10
        ann.volume = 500.0 + i * 20
        ann.centroid = (50.0 + i, 60.0 + i, 70.0 + i)
        ann.bbox = MagicMock(return_value=[
            slice(40, 60),
            slice(50, 70),
            slice(60, 80)
        ])
        annotations.append(ann)
    return annotations


@pytest.fixture
def mock_scan():
    """create mock pylidc scan object without annotations."""
    scan = Mock()
    scan.series_instance_uid = "1.2.3.4.5.6.7.8.9"
    scan.study_instance_uid = "1.2.3.4.5.6.7.8"
    scan.patient_id = "LIDC-IDRI-0001"
    scan.slice_thickness = 2.5
    scan.pixel_spacing = 0.703125
    scan.contrast_used = False
    scan.slice_zvals = list(range(100))
    scan.annotations = []
    scan.cluster_annotations = MagicMock(return_value=[])
    return scan


@pytest.fixture
def mock_scan_with_annotations(mock_scan, mock_annotations_cluster):
    """create mock scan with annotations."""
    scan = mock_scan
    scan.annotations = mock_annotations_cluster
    scan.cluster_annotations = MagicMock(return_value=[mock_annotations_cluster])
    return scan


@pytest.fixture
def mock_scans_list(mock_scan):
    """create list of mock scans for batch testing."""
    scans = []
    for i in range(3):
        scan = Mock()
        scan.series_instance_uid = f"1.2.3.4.5.6.7.8.{i}"
        scan.study_instance_uid = f"1.2.3.4.5.6.7.{i}"
        scan.patient_id = f"LIDC-IDRI-000{i}"
        scan.slice_thickness = 2.5
        scan.pixel_spacing = 0.703125
        scan.contrast_used = False
        scan.slice_zvals = list(range(100))
        scan.annotations = []
        scan.cluster_annotations = MagicMock(return_value=[])
        scans.append(scan)
    return scans
