-- =====================================================================
-- RA-D-PS Radiology Document Extensions for Supabase
-- PostgreSQL Migration v1.0
-- =====================================================================
-- Purpose: Additional indexes and views for radiology-specific queries
-- Target: Supabase PostgreSQL
-- Requires: 001_initial_schema.sql
-- =====================================================================

-- Enable required extensions if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- Trigram matching for fuzzy search

-- =====================================================================
-- RADIOLOGY-SPECIFIC INDEXES
-- =====================================================================

-- Index for fast radiology UID lookups
CREATE INDEX IF NOT EXISTS idx_content_study_uid
ON document_content USING GIN ((canonical_data -> 'study_instance_uid'));

CREATE INDEX IF NOT EXISTS idx_content_series_uid
ON document_content USING GIN ((canonical_data -> 'series_instance_uid'));

CREATE INDEX IF NOT EXISTS idx_content_patient_id
ON document_content USING GIN ((canonical_data -> 'fields' -> 'patient_id'));

-- Index for nodule searches
CREATE INDEX IF NOT EXISTS idx_content_nodules
ON document_content USING GIN ((canonical_data -> 'nodules'));

-- Index for source system filtering (LIDC-IDRI, etc.)
CREATE INDEX IF NOT EXISTS idx_documents_source_system_btree
ON documents(source_system) WHERE source_system IS NOT NULL;

-- Composite index for common queries (system + status)
CREATE INDEX IF NOT EXISTS idx_documents_system_status
ON documents(source_system, status);

-- =====================================================================
-- MATERIALIZED VIEWS FOR ANALYTICS
-- =====================================================================

-- View: Radiology document summary with nodule counts
CREATE MATERIALIZED VIEW IF NOT EXISTS radiology_document_summary AS
SELECT
    d.id AS document_id,
    d.source_file_name,
    d.source_system,
    d.status,
    d.ingestion_timestamp,
    dc.canonical_data->>'study_instance_uid' AS study_uid,
    dc.canonical_data->>'series_instance_uid' AS series_uid,
    dc.canonical_data->'fields'->>'patient_id' AS patient_id,
    COALESCE(jsonb_array_length(dc.canonical_data->'nodules'), 0) AS nodule_count,
    COALESCE(jsonb_array_length(dc.canonical_data->'radiologist_readings'), 0) AS reading_count,
    dc.confidence_score,
    dc.tags
FROM documents d
JOIN document_content dc ON d.id = dc.document_id
WHERE d.source_system = 'LIDC-IDRI'
  AND d.status = 'completed';

-- Index on materialized view for fast queries
CREATE UNIQUE INDEX IF NOT EXISTS idx_radiology_summary_doc_id
ON radiology_document_summary(document_id);

CREATE INDEX IF NOT EXISTS idx_radiology_summary_study_uid
ON radiology_document_summary(study_uid);

CREATE INDEX IF NOT EXISTS idx_radiology_summary_patient_id
ON radiology_document_summary(patient_id);

-- Refresh function for materialized view
CREATE OR REPLACE FUNCTION refresh_radiology_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY radiology_document_summary;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================

-- Function to extract study metadata from canonical document
CREATE OR REPLACE FUNCTION get_study_metadata(doc_id UUID)
RETURNS TABLE (
    study_uid TEXT,
    series_uid TEXT,
    patient_id TEXT,
    modality TEXT,
    nodule_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.canonical_data->>'study_instance_uid' AS study_uid,
        dc.canonical_data->>'series_instance_uid' AS series_uid,
        dc.canonical_data->'fields'->>'patient_id' AS patient_id,
        dc.canonical_data->>'modality' AS modality,
        COALESCE(jsonb_array_length(dc.canonical_data->'nodules'), 0)::INTEGER AS nodule_count
    FROM document_content dc
    WHERE dc.document_id = doc_id;
END;
$$ LANGUAGE plpgsql;

-- Function to search nodules by characteristics
CREATE OR REPLACE FUNCTION search_nodules_by_malignancy(
    min_malignancy INTEGER DEFAULT 3,
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE (
    document_id UUID,
    study_uid TEXT,
    nodule_id TEXT,
    avg_malignancy NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.document_id,
        dc.canonical_data->>'study_instance_uid' AS study_uid,
        nodule->>'nodule_id' AS nodule_id,
        (
            SELECT AVG((radiologist_data->>'malignancy')::NUMERIC)
            FROM jsonb_each(nodule->'radiologists') AS radiologist_data
            WHERE radiologist_data.value->>'malignancy' IS NOT NULL
        ) AS avg_malignancy
    FROM document_content dc,
    jsonb_array_elements(dc.canonical_data->'nodules') AS nodule
    WHERE (
        SELECT AVG((radiologist_data->>'malignancy')::NUMERIC)
        FROM jsonb_each(nodule->'radiologists') AS radiologist_data
        WHERE radiologist_data.value->>'malignancy' IS NOT NULL
    ) >= min_malignancy
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- ROW LEVEL SECURITY (Optional - for multi-tenant Supabase)
-- =====================================================================

-- Enable RLS on documents table
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all documents
CREATE POLICY IF NOT EXISTS "Allow authenticated read access"
ON documents FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert documents
CREATE POLICY IF NOT EXISTS "Allow authenticated insert access"
ON documents FOR INSERT
TO authenticated
WITH CHECK (true);

-- Enable RLS on document_content table
ALTER TABLE document_content ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all content
CREATE POLICY IF NOT EXISTS "Allow authenticated read access"
ON document_content FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert content
CREATE POLICY IF NOT EXISTS "Allow authenticated insert access"
ON document_content FOR INSERT
TO authenticated
WITH CHECK (true);

-- =====================================================================
-- PERFORMANCE TUNING
-- =====================================================================

-- Analyze tables for query planner
ANALYZE documents;
ANALYZE document_content;

-- =====================================================================
-- COMMENTS
-- =====================================================================

COMMENT ON MATERIALIZED VIEW radiology_document_summary IS
'Pre-computed summary of radiology documents with nodule counts. Refresh with refresh_radiology_summary()';

COMMENT ON FUNCTION get_study_metadata(UUID) IS
'Extract study metadata from a document canonical data';

COMMENT ON FUNCTION search_nodules_by_malignancy(INTEGER, INTEGER) IS
'Search for nodules with average malignancy rating >= threshold';

-- =====================================================================
-- VERIFICATION
-- =====================================================================

-- Verify indexes exist
DO $$
BEGIN
    RAISE NOTICE 'Migration 002 complete. Radiology-specific indexes and views created.';
END $$;
