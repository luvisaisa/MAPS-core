"""Tests for parse case detection."""

import unittest
from src.maps.parser import detect_parse_case, get_expected_attributes_for_case


class TestParseCaseDetection(unittest.TestCase):
    """Test suite for parse case detection."""
    
    def test_get_expected_attributes_complete(self):
        """Test expected attributes for complete parse case."""
        attrs = get_expected_attributes_for_case("Complete_Attributes")
        
        self.assertIn("header", attrs)
        self.assertIn("StudyInstanceUID", attrs["header"])
        self.assertIn("Modality", attrs["header"])
        self.assertEqual(len(attrs["characteristics"]), 9)
    
    def test_get_expected_attributes_lidc(self):
        """Test expected attributes for LIDC parse case."""
        attrs = get_expected_attributes_for_case("LIDC_Multi_Session_4")
        
        self.assertIn("header", attrs)
        self.assertIn("DateService", attrs["header"])
        self.assertIn("subtlety", attrs["characteristics"])
    
    def test_get_expected_attributes_unknown(self):
        """Test default attributes for unknown parse case."""
        attrs = get_expected_attributes_for_case("Unknown_Case")
        
        self.assertIn("header", attrs)
        self.assertEqual(len(attrs["header"]), 2)  # Default minimal header


if __name__ == "__main__":
    unittest.main()
