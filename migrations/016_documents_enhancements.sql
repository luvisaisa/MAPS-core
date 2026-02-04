-- =====================================================================
-- Migration 016: Documents Table Enhancements
-- =====================================================================
-- Purpose: Add fields to documents table for better management,
--          including parse case tracking, keyword counts, and metadata
-- Date: November 24, 2025
-- =====================================================================

-- ---------------------------------------------------------------------
-- Add new columns to documents table
-- ---------------------------------------------------------------------
ALTER TABLE documents
    ADD COLUMN IF NOT EXISTS parse_case VARCHAR(255),
    ADD COLUMN IF NOT EXISTS detection_confidence DECIMAL(5, 4) CHECK (detection_confidence >= 0 AND detection_confidence <= 1),
    ADD COLUMN IF NOT EXISTS keywords_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS parsed_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS parsed_content_preview TEXT,
    ADD COLUMN IF NOT EXISTS document_title VARCHAR(500),
    ADD COLUMN IF NOT EXISTS document_date DATE,
    ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64);  -- Hash of parsed content for change detection

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_documents_parse_case ON documents(parse_case);
CREATE INDEX IF NOT EXISTS idx_documents_detection_confidence ON documents(detection_confidence);
CREATE INDEX IF NOT EXISTS idx_documents_keywords_count ON documents(keywords_count);
CREATE INDEX IF NOT EXISTS idx_documents_parsed_at ON documents(parsed_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_document_date ON documents(document_date DESC);
CREATE INDEX IF NOT EXISTS idx_documents_content_hash ON documents(content_hash);

-- Add comments for new columns
COMMENT ON COLUMN documents.parse_case IS 'Detected or assigned parse case (e.g., LIDC_Single_Session, Complete_Attributes)';
COMMENT ON COLUMN documents.detection_confidence IS 'Confidence score from structure detector (0-1)';
COMMENT ON COLUMN documents.keywords_count IS 'Number of keywords extracted from document';
COMMENT ON COLUMN documents.parsed_at IS 'Timestamp when document was successfully parsed';
COMMENT ON COLUMN documents.parsed_content_preview IS 'Plain text preview of parsed content (first 500 chars)';
COMMENT ON COLUMN documents.document_title IS 'Title extracted from document content';
COMMENT ON COLUMN documents.document_date IS 'Date extracted from document content (study date, report date, etc.)';
COMMENT ON COLUMN documents.content_hash IS 'SHA-256 hash of parsed content for detecting changes';

-- ---------------------------------------------------------------------
-- Enhanced view: v_document_list (for Documents page)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_document_list AS
SELECT
    d.id,
    d.source_file_name AS filename,
    d.document_title,
    d.parse_case,
    d.detection_confidence AS confidence,
    d.file_type,
    d.file_size_bytes,
    d.keywords_count,
    d.status,
    d.ingestion_timestamp AS uploaded_at,
    d.parsed_at,
    d.document_date,
    d.uploaded_by,
    d.error_message,
    -- Content preview
    COALESCE(d.parsed_content_preview, LEFT(c.searchable_text, 500)) AS content_preview,
    -- Tags from document_content
    c.tags,
    -- Profile info
    p.profile_name,
    -- Detection details (if available)
    dd.match_percentage,
    dd.total_expected,
    dd.total_detected,
    -- Calculated fields
    CASE
        WHEN d.status = 'completed' THEN 'success'
        WHEN d.status = 'failed' THEN 'error'
        WHEN d.status = 'processing' THEN 'processing'
        ELSE 'pending'
    END AS status_category
FROM documents d
LEFT JOIN document_content c ON d.id = c.document_id
LEFT JOIN profiles p ON d.profile_id = p.id
LEFT JOIN detection_details dd ON d.id = dd.document_id
WHERE d.status != 'archived'
ORDER BY d.ingestion_timestamp DESC;

COMMENT ON VIEW v_document_list IS 'Comprehensive document listing view for UI with all relevant metadata';

-- ---------------------------------------------------------------------
-- View: v_document_detail (for Document Detail Modal)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_document_detail AS
SELECT
    d.id,
    d.source_file_name,
    d.source_file_path,
    d.document_title,
    d.file_type,
    d.file_size_bytes,
    d.file_hash,
    d.parse_case,
    d.detection_confidence,
    d.keywords_count,
    d.status,
    d.error_message,
    d.processing_duration_ms,
    d.ingestion_timestamp,
    d.parsed_at,
    d.document_date,
    d.uploaded_by,
    d.created_at,
    d.updated_at,
    -- Profile info
    p.profile_name,
    p.description AS profile_description,
    -- Full content
    c.canonical_data,
    c.searchable_text,
    c.extracted_entities,
    c.tags,
    c.confidence_score AS content_confidence,
    c.schema_version,
    -- Detection details
    dd.expected_attributes,
    dd.detected_attributes,
    dd.missing_attributes,
    dd.match_percentage,
    dd.field_analysis,
    dd.detector_type,
    dd.detected_at,
    -- Statistics
    (SELECT COUNT(*) FROM ingestion_logs WHERE document_id = d.id) AS log_count,
    (SELECT COUNT(*) FROM ingestion_logs WHERE document_id = d.id AND log_level = 'ERROR') AS error_count
FROM documents d
LEFT JOIN document_content c ON d.id = c.document_id
LEFT JOIN profiles p ON d.profile_id = p.id
LEFT JOIN detection_details dd ON d.id = dd.document_id;

COMMENT ON VIEW v_document_detail IS 'Complete document details including content, detection analysis, and statistics';

-- ---------------------------------------------------------------------
-- View: v_documents_by_parse_case (statistics for UI)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_documents_by_parse_case AS
SELECT
    parse_case,
    COUNT(*) AS total_documents,
    AVG(detection_confidence) AS avg_confidence,
    MIN(detection_confidence) AS min_confidence,
    MAX(detection_confidence) AS max_confidence,
    SUM(keywords_count) AS total_keywords,
    AVG(keywords_count) AS avg_keywords_per_doc,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count,
    MAX(parsed_at) AS last_parsed_at
FROM documents
WHERE parse_case IS NOT NULL
GROUP BY parse_case
ORDER BY total_documents DESC;

COMMENT ON VIEW v_documents_by_parse_case IS 'Statistics grouped by parse case for analytics dashboard';

-- ---------------------------------------------------------------------
-- Function: Update parsed_at timestamp when document completes
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_parsed_at()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'completed' THEN
        NEW.parsed_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_update_parsed_at BEFORE UPDATE OF status ON documents
    FOR EACH ROW EXECUTE FUNCTION update_parsed_at();

COMMENT ON FUNCTION update_parsed_at() IS 'Automatically set parsed_at timestamp when document status changes to completed';

-- ---------------------------------------------------------------------
-- Function: Search documents by keyword (full-text search)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_documents(
    search_query TEXT,
    parse_case_filter VARCHAR DEFAULT NULL,
    status_filter VARCHAR DEFAULT NULL,
    limit_results INTEGER DEFAULT 100
)
RETURNS TABLE (
    document_id UUID,
    filename VARCHAR,
    parse_case VARCHAR,
    confidence DECIMAL,
    status VARCHAR,
    relevance REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id AS document_id,
        d.source_file_name AS filename,
        d.parse_case,
        d.detection_confidence AS confidence,
        d.status,
        ts_rank(to_tsvector('english', c.searchable_text), plainto_tsquery('english', search_query)) AS relevance
    FROM documents d
    LEFT JOIN document_content c ON d.id = c.document_id
    WHERE
        (parse_case_filter IS NULL OR d.parse_case = parse_case_filter)
        AND (status_filter IS NULL OR d.status = status_filter)
        AND to_tsvector('english', c.searchable_text) @@ plainto_tsquery('english', search_query)
    ORDER BY relevance DESC, d.ingestion_timestamp DESC
    LIMIT limit_results;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION search_documents IS 'Full-text search across documents with optional filters and relevance ranking';

-- =====================================================================
-- Update schema version
-- =====================================================================
INSERT INTO schema_versions (version, description)
VALUES (16, 'Enhance documents table with parse case tracking, keywords, and metadata')
ON CONFLICT (version) DO NOTHING;

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
