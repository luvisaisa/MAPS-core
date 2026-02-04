-- =====================================================================
-- RA-D-PS Keyword Enhancements Migration
-- Migration: 002_add_keyword_enhancements
-- Date: 2025-11-22
-- =====================================================================
-- Purpose: Enhance keyword schema to support standardized radiology
--          terminology with source references and create consolidated views
-- =====================================================================

BEGIN;

-- =====================================================================
-- KEYWORD SCHEMA ENHANCEMENTS
-- =====================================================================

-- Add source_refs column to keywords table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'keywords' AND column_name = 'source_refs'
    ) THEN
        ALTER TABLE keywords ADD COLUMN source_refs TEXT;
        COMMENT ON COLUMN keywords.source_refs IS 'Semicolon-separated reference IDs to source papers/documents (e.g., "1;13;25")';
    END IF;
END $$;

-- Add definition column if not already present (rename from description if needed)
DO $$
BEGIN
    -- Check if we need to rename description to definition for clarity
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'keywords' AND column_name = 'description'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'keywords' AND column_name = 'definition'
    ) THEN
        -- Both columns can coexist: description for internal notes, definition for formal definition
        -- For now, just add definition as a new column
        ALTER TABLE keywords ADD COLUMN definition TEXT;
        COMMENT ON COLUMN keywords.definition IS 'Formal definition of the keyword/term from medical literature';
    END IF;

    -- If description doesn't exist but definition does, add description
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'keywords' AND column_name = 'description'
    ) THEN
        COMMENT ON COLUMN keywords.description IS 'Internal description or notes about the keyword';
    END IF;
END $$;

-- Add metadata fields for better keyword management
DO $$
BEGIN
    -- Add is_standard flag to mark keywords from standard vocabularies
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'keywords' AND column_name = 'is_standard'
    ) THEN
        ALTER TABLE keywords ADD COLUMN is_standard BOOLEAN DEFAULT FALSE;
        COMMENT ON COLUMN keywords.is_standard IS 'Indicates if keyword is from a standardized vocabulary (e.g., RadLex, LOINC, Lung-RADS)';
    END IF;

    -- Add vocabulary_source to track which standard the keyword comes from
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'keywords' AND column_name = 'vocabulary_source'
    ) THEN
        ALTER TABLE keywords ADD COLUMN vocabulary_source VARCHAR(100);
        COMMENT ON COLUMN keywords.vocabulary_source IS 'Source vocabulary name (e.g., "RadLex", "LOINC", "Lung-RADS", "custom")';
    END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_keywords_is_standard ON keywords(is_standard) WHERE is_standard = TRUE;
CREATE INDEX IF NOT EXISTS idx_keywords_vocabulary_source ON keywords(vocabulary_source);

-- =====================================================================
-- CONSOLIDATED KEYWORD VIEW
-- =====================================================================

-- Drop existing view if it exists
DROP VIEW IF EXISTS v_keyword_consolidated CASCADE;

-- Create comprehensive keyword view
CREATE OR REPLACE VIEW v_keyword_consolidated AS
SELECT
    k.keyword_id,
    k.keyword_text,
    k.normalized_form,
    k.category,
    COALESCE(k.definition, k.description) AS definition,
    k.source_refs,
    k.is_standard,
    k.vocabulary_source,

    -- Statistics from keyword_statistics table
    ks.total_frequency,
    ks.document_count,
    ks.idf_score,
    ks.avg_tf_idf,
    ks.last_calculated AS stats_last_calculated,

    -- Synonym count
    (SELECT COUNT(*) FROM keyword_synonyms WHERE canonical_keyword_id = k.keyword_id) AS synonym_count,

    -- Source file count by type
    (SELECT COUNT(DISTINCT source_file) FROM keyword_sources WHERE keyword_id = k.keyword_id) AS unique_source_files,
    (SELECT COUNT(*) FROM keyword_sources WHERE keyword_id = k.keyword_id AND source_type = 'xml') AS xml_source_count,
    (SELECT COUNT(*) FROM keyword_sources WHERE keyword_id = k.keyword_id AND source_type = 'pdf') AS pdf_source_count,
    (SELECT COUNT(*) FROM keyword_sources WHERE keyword_id = k.keyword_id AND source_type = 'research_paper') AS paper_source_count,

    -- Timestamps
    k.created_at,
    k.updated_at
FROM keywords k
LEFT JOIN keyword_statistics ks ON k.keyword_id = ks.keyword_id
ORDER BY k.category, k.keyword_text;

COMMENT ON VIEW v_keyword_consolidated IS 'Consolidated view of all keywords with statistics, sources, and metadata for easy querying';

-- =====================================================================
-- CATEGORY-SPECIFIC VIEWS
-- =====================================================================

-- View for standardized reporting keywords
CREATE OR REPLACE VIEW v_keywords_standardization_reporting AS
SELECT * FROM v_keyword_consolidated
WHERE category = 'standardization_and_reporting'
ORDER BY keyword_text;

COMMENT ON VIEW v_keywords_standardization_reporting IS 'Keywords related to standardization and reporting (RADS, RadLex, etc.)';

-- View for radiologist cognition and diagnostic keywords
CREATE OR REPLACE VIEW v_keywords_radiologist_cognition AS
SELECT * FROM v_keyword_consolidated
WHERE category = 'radiologist_cognition_and_diagnostics'
ORDER BY keyword_text;

COMMENT ON VIEW v_keywords_radiologist_cognition AS 'Keywords related to radiologist cognition, errors, and diagnostic patterns';

-- View for imaging biomarkers and computational keywords
CREATE OR REPLACE VIEW v_keywords_imaging_biomarkers AS
SELECT * FROM v_keyword_consolidated
WHERE category = 'imaging_biomarkers_and_computation'
ORDER BY keyword_text;

COMMENT ON VIEW v_keywords_imaging_biomarkers AS 'Keywords related to imaging biomarkers, radiomics, and computational analysis';

-- View for pulmonary nodules and databases
CREATE OR REPLACE VIEW v_keywords_pulmonary_nodules AS
SELECT * FROM v_keyword_consolidated
WHERE category = 'pulmonary_nodules_and_databases'
ORDER BY keyword_text;

COMMENT ON VIEW v_keywords_pulmonary_nodules AS 'Keywords related to pulmonary nodules, lung cancer screening, and databases';

-- View for NER performance metrics
CREATE OR REPLACE VIEW v_keywords_ner_metrics AS
SELECT * FROM v_keyword_consolidated
WHERE category = 'ner_performance_metrics'
ORDER BY keyword_text;

COMMENT ON VIEW v_keywords_ner_metrics IS 'Keywords related to Named Entity Recognition (NER) performance metrics';

-- =====================================================================
-- KEYWORD REFERENCE SOURCES TABLE
-- =====================================================================

-- Create a table to store reference source metadata
CREATE TABLE IF NOT EXISTS keyword_reference_sources (
    source_id INTEGER PRIMARY KEY,
    citation TEXT NOT NULL,
    title TEXT,
    authors TEXT,
    journal TEXT,
    year INTEGER,
    doi TEXT,
    url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE keyword_reference_sources IS 'Stores metadata for source references cited in keywords (source_refs column)';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_keyword_ref_sources_year ON keyword_reference_sources(year DESC);
CREATE INDEX IF NOT EXISTS idx_keyword_ref_sources_journal ON keyword_reference_sources(journal);

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================

-- Function to get all keywords by category
CREATE OR REPLACE FUNCTION get_keywords_by_category(p_category VARCHAR)
RETURNS TABLE (
    keyword_id INTEGER,
    keyword_text VARCHAR,
    definition TEXT,
    source_refs TEXT,
    total_frequency INTEGER,
    document_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.keyword_id,
        v.keyword_text,
        v.definition,
        v.source_refs,
        v.total_frequency,
        v.document_count
    FROM v_keyword_consolidated v
    WHERE v.category = p_category
    ORDER BY v.keyword_text;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_keywords_by_category IS 'Returns all keywords for a specific category with basic statistics';

-- Function to search keywords by text pattern
CREATE OR REPLACE FUNCTION search_keywords_full(p_search_term TEXT)
RETURNS TABLE (
    keyword_id INTEGER,
    keyword_text VARCHAR,
    normalized_form VARCHAR,
    category VARCHAR,
    definition TEXT,
    source_refs TEXT,
    match_type VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        k.keyword_id,
        k.keyword_text,
        k.normalized_form,
        k.category,
        COALESCE(k.definition, k.description) AS definition,
        k.source_refs,
        CASE
            WHEN k.keyword_text ILIKE p_search_term THEN 'exact'
            WHEN k.keyword_text ILIKE '%' || p_search_term || '%' THEN 'partial'
            WHEN k.normalized_form ILIKE '%' || p_search_term || '%' THEN 'normalized'
            WHEN COALESCE(k.definition, k.description) ILIKE '%' || p_search_term || '%' THEN 'definition'
            ELSE 'other'
        END AS match_type
    FROM keywords k
    WHERE
        k.keyword_text ILIKE '%' || p_search_term || '%'
        OR k.normalized_form ILIKE '%' || p_search_term || '%'
        OR COALESCE(k.definition, k.description) ILIKE '%' || p_search_term || '%'
    ORDER BY
        CASE
            WHEN k.keyword_text ILIKE p_search_term THEN 1
            WHEN k.keyword_text ILIKE p_search_term || '%' THEN 2
            WHEN k.keyword_text ILIKE '%' || p_search_term || '%' THEN 3
            ELSE 4
        END,
        k.keyword_text;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION search_keywords_full IS 'Full-text search across keyword text, normalized form, and definition with match type ranking';

-- =====================================================================
-- UPDATE SCHEMA VERSION
-- =====================================================================

-- Insert version record
INSERT INTO schema_versions (version, description)
VALUES (2, 'Add keyword enhancements: source_refs, definition, consolidated views, and helper functions')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- =====================================================================
-- END OF MIGRATION 002
-- =====================================================================
