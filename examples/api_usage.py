"""
Example API usage with requests library
"""

import requests
from pathlib import Path


# Base URL for local development
BASE_URL = "http://localhost:8000/api"


def health_check():
    """Check API health"""
    response = requests.get(f"{BASE_URL}/health")
    print("Health Check:", response.json())


def list_profiles():
    """List available profiles"""
    response = requests.get(f"{BASE_URL}/profiles")
    print("Profiles:", response.json())


def parse_xml_file(file_path: str):
    """Parse XML file"""
    with open(file_path, 'rb') as f:
        files = {'file': f}
        params = {'profile_name': 'lidc_idri_standard'}
        response = requests.post(
            f"{BASE_URL}/parse/parse/xml",
            files=files,
            params=params
        )
        print("Parse Result:", response.json())


def search_keywords(query: str):
    """Search keywords"""
    params = {'query': query, 'expand_synonyms': True}
    response = requests.get(f"{BASE_URL}/keywords/search", params=params)
    print(f"Search Results for '{query}':", response.json())


def normalize_keyword(keyword: str):
    """Normalize medical keyword"""
    params = {'keyword': keyword}
    response = requests.get(f"{BASE_URL}/keywords/normalize", params=params)
    print(f"Normalized '{keyword}':", response.json())


def analyze_xml(file_path: str):
    """Auto-analyze XML file"""
    with open(file_path, 'rb') as f:
        files = {'file': f}
        params = {'populate_entities': True}
        response = requests.post(
            f"{BASE_URL}/analysis/analyze/xml",
            files=files,
            params=params
        )
        result = response.json()
        print("Analysis Results:")
        print(f"  Filename: {result.get('filename')}")
        print(f"  Statistics: {result.get('statistics')}")


def detect_parse_case(file_path: str):
    """Detect XML parse case"""
    with open(file_path, 'rb') as f:
        files = {'file': f}
        response = requests.post(f"{BASE_URL}/detect/detect", files=files)
        print("Detection Result:", response.json())


if __name__ == "__main__":
    print("MAPS API Usage Examples")
    print("=" * 50)

    # Health check
    print("\n1. Health Check")
    health_check()

    # List profiles
    print("\n2. List Profiles")
    list_profiles()

    # Keyword operations
    print("\n3. Normalize Keyword")
    normalize_keyword("GGO")

    print("\n4. Search Keywords")
    search_keywords("lung AND nodule")

    # File operations (uncomment when you have a sample file)
    # print("\n5. Parse XML File")
    # parse_xml_file("data/sample.xml")

    # print("\n6. Analyze XML File")
    # analyze_xml("data/sample.xml")

    # print("\n7. Detect Parse Case")
    # detect_parse_case("data/sample.xml")
