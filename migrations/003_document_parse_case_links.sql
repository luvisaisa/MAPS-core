-- =====================================================================
-- Document-ParseCase Integration for Schema-Agnostic System
-- PostgreSQL Migration v1.0
-- =====================================================================
-- Purpose: Link documents to parse cases for schema tracking
-- Adds foreign keys and indexes to track which parse case was used
-- =====================================================================

-- Add parse_case_id foreign key to documents table
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS parse_case_id UUID REFERENCES parse_cases(id) ON DELETE SET NULL;

-- Add index for fast parse case lookups
CREATE INDEX IF NOT EXISTS idx_documents_parse_case_id
ON documents(parse_case_id);

-- Add composite index for source_system + parse_case queries
CREATE INDEX IF NOT EXISTS idx_documents_system_parse_case
ON documents(source_system, parse_case_id)
WHERE parse_case_id IS NOT NULL;

-- =====================================================================
-- VIEWS FOR SCHEMA TRACKING
-- =====================================================================

-- View: Document schema distribution
CREATE OR REPLACE VIEW document_schema_distribution AS
SELECT
    pc.name AS parse_case_name,
    pc.format_type,
    d.source_system,
    COUNT(*) AS document_count,
    MIN(d.ingestion_timestamp) AS first_ingested,
    MAX(d.ingestion_timestamp) AS last_ingested
FROM documents d
LEFT JOIN parse_cases pc ON d.parse_case_id = pc.id
WHERE d.status = 'completed'
GROUP BY pc.name, pc.format_type, d.source_system
ORDER BY document_count DESC;

-- View: Parse case usage statistics
CREATE OR REPLACE VIEW parse_case_usage_stats AS
SELECT
    pc.id AS parse_case_id,
    pc.name AS parse_case_name,
    pc.format_type,
    pc.version,
    COUNT(d.id) AS total_documents,
    COUNT(CASE WHEN d.status = 'completed' THEN 1 END) AS completed_documents,
    COUNT(CASE WHEN d.status = 'failed' THEN 1 END) AS failed_documents,
    AVG(d.processing_duration_ms) AS avg_processing_ms,
    MIN(d.ingestion_timestamp) AS first_used,
    MAX(d.ingestion_timestamp) AS last_used
FROM parse_cases pc
LEFT JOIN documents d ON pc.id = d.parse_case_id
GROUP BY pc.id, pc.name, pc.format_type, pc.version
ORDER BY total_documents DESC;

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================

-- Function to get documents by parse case
CREATE OR REPLACE FUNCTION get_documents_by_parse_case(
    parse_case_name_param TEXT,
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE (
    document_id UUID,
    source_file_name TEXT,
    source_file_path TEXT,
    source_system TEXT,
    ingestion_timestamp TIMESTAMPTZ,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id,
        d.source_file_name,
        d.source_file_path,
        d.source_system,
        d.ingestion_timestamp,
        d.status
    FROM documents d
    JOIN parse_cases pc ON d.parse_case_id = pc.id
    WHERE pc.name = parse_case_name_param
    ORDER BY d.ingestion_timestamp DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function to detect parse case drift (documents with mismatched parse case)
CREATE OR REPLACE FUNCTION detect_parse_case_drift()
RETURNS TABLE (
    document_id UUID,
    source_file TEXT,
    assigned_parse_case TEXT,
    detected_parse_case TEXT,
    confidence_score NUMERIC
) AS $$
BEGIN
    -- This is a placeholder - actual implementation would use
    -- detection history to compare assigned vs. detected parse cases
    RETURN QUERY
    SELECT
        d.id,
        d.source_file_path,
        pc.name,
        pch.parse_case_name,
        dc.confidence_score
    FROM documents d
    JOIN parse_cases pc ON d.parse_case_id = pc.id
    JOIN parse_case_detection_history pch ON d.source_file_path = pch.file_path
    JOIN document_content dc ON d.id = dc.document_id
    WHERE pc.name != pch.parse_case_name
    AND d.status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- KEYWORD-DOCUMENT LINKS
-- =====================================================================

-- Create junction table linking keywords to documents
CREATE TABLE IF NOT EXISTS document_keywords (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    keyword_id INTEGER NOT NULL,  -- References keywords.keyword_id
    frequency INTEGER DEFAULT 1,
    tf_idf_score REAL DEFAULT 0.0,
    extracted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Unique constraint: one keyword per document
    UNIQUE(document_id, keyword_id)
);

-- Indexes for document_keywords
CREATE INDEX IF NOT EXISTS idx_document_keywords_doc_id
ON document_keywords(document_id);

CREATE INDEX IF NOT EXISTS idx_document_keywords_keyword_id
ON document_keywords(keyword_id);

CREATE INDEX IF NOT EXISTS idx_document_keywords_tfidf
ON document_keywords(tf_idf_score DESC);

-- View: Document keyword summary
CREATE OR REPLACE VIEW document_keyword_summary AS
SELECT
    d.id AS document_id,
    d.source_file_name,
    d.source_system,
    COUNT(dk.keyword_id) AS total_keywords,
    AVG(dk.tf_idf_score) AS avg_tfidf_score,
    ARRAY_AGG(dk.keyword_id ORDER BY dk.tf_idf_score DESC)[:10] AS top_keyword_ids
FROM documents d
LEFT JOIN document_keywords dk ON d.id = dk.document_id
WHERE d.status = 'completed'
GROUP BY d.id, d.source_file_name, d.source_system
ORDER BY total_keywords DESC;

-- =====================================================================
-- TRIGGERS FOR AUTOMATIC TRACKING
-- =====================================================================

-- Trigger function to update parse case statistics
CREATE OR REPLACE FUNCTION update_parse_case_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update statistics when document status changes to 'completed'
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        INSERT INTO parse_case_statistics (parse_case_id, date, detection_count, success_count)
        VALUES (NEW.parse_case_id, CURRENT_DATE, 0, 1)
        ON CONFLICT (parse_case_id, date)
        DO UPDATE SET
            success_count = parse_case_statistics.success_count + 1,
            updated_at = NOW();

    -- Update statistics when document status changes to 'failed'
    ELSIF NEW.status = 'failed' AND OLD.status != 'failed' THEN
        INSERT INTO parse_case_statistics (parse_case_id, date, detection_count, failure_count)
        VALUES (NEW.parse_case_id, CURRENT_DATE, 0, 1)
        ON CONFLICT (parse_case_id, date)
        DO UPDATE SET
            failure_count = parse_case_statistics.failure_count + 1,
            updated_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_update_parse_case_stats ON documents;
CREATE TRIGGER trg_update_parse_case_stats
    AFTER UPDATE OF status ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_parse_case_stats();

-- =====================================================================
-- COMMENTS
-- =====================================================================

COMMENT ON COLUMN documents.parse_case_id IS
'Foreign key to parse_cases table - tracks which schema/structure was used to parse this document';

COMMENT ON TABLE document_keywords IS
'Junction table linking documents to extracted keywords for full-text search and analytics';

COMMENT ON VIEW document_schema_distribution IS
'Shows distribution of documents across different parse cases (schemas)';

COMMENT ON VIEW parse_case_usage_stats IS
'Statistics on parse case usage including success rates and processing times';

COMMENT ON FUNCTION get_documents_by_parse_case(TEXT, INTEGER) IS
'Retrieve documents that were parsed using a specific parse case';

COMMENT ON FUNCTION detect_parse_case_drift() IS
'Detect documents where assigned parse case differs from detected parse case';

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE 'Migration 003 complete. Document-ParseCase integration ready.';
    RAISE NOTICE 'New features:';
    RAISE NOTICE '  - documents.parse_case_id foreign key';
    RAISE NOTICE '  - document_keywords junction table';
    RAISE NOTICE '  - Schema tracking views';
    RAISE NOTICE '  - Automatic statistics updates';
END $$;
