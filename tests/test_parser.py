"""Basic tests for XML parser."""

import unittest
import os
from src.maps.parser import parse_radiology_sample


class TestParser(unittest.TestCase):
    """Test suite for XML parser."""
    
    def test_parse_nonexistent_file(self):
        """Test parsing nonexistent file raises FileNotFoundError."""
        with self.assertRaises(FileNotFoundError):
            parse_radiology_sample("nonexistent.xml")
    
    def test_parse_returns_dataframes(self):
        """Test parse returns tuple of dataframes."""
        # This would need actual test data
        pass


if __name__ == "__main__":
    unittest.main()
