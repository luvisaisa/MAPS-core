"""Example: PYLIDC Integration with LIDC-IDRI Dataset"""

from maps import PyLIDCAdapter, canonical_to_dict


def basic_example():
    """Basic PYLIDC integration"""
    print("=== PYLIDC Integration Example ===\n")

    print("""
# Query and convert LIDC scans to canonical format

import pylidc as pl
from maps import PyLIDCAdapter

# Create adapter
adapter = PyLIDCAdapter()

# Query a scan
scan = pl.query(pl.Scan).first()

# Convert to canonical document
doc = adapter.scan_to_canonical(scan)

print(f"Patient: {doc.fields['patient_id']}")
print(f"Nodules: {len(doc.nodules)}")
print(f"Study UID: {doc.study_instance_uid}")

# Access nodule data
for nodule in doc.nodules:
    print(f"  Nodule {nodule['nodule_id']}: {nodule['num_radiologists']} radiologists")
    if 'consensus' in nodule:
        print(f"    Consensus malignancy: {nodule['consensus'].get('malignancy_mean')}")
    """)


def batch_example():
    """Batch processing example"""
    print("\n=== Batch Processing ===\n")

    print("""
# Process multiple scans

adapter = PyLIDCAdapter()

# Query specific patients
documents = adapter.query_and_convert(
    patient_ids=['LIDC-IDRI-0001', 'LIDC-IDRI-0002'],
    max_scans=10
)

# Get statistics
for doc in documents:
    stats = adapter.get_scan_statistics(doc)
    print(f"{stats['patient_id']}: {stats['num_nodules']} nodules, {stats['total_annotations']} annotations")
    """)


if __name__ == "__main__":
    basic_example()
    batch_example()
    print("\nNote: Requires pylidc installation and LIDC database setup")
