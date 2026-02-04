-- =============================================================================
-- Migration 012: Public Access Policies (Row-Level Security)
-- =============================================================================
-- Purpose: Enable anonymous read-only access to export views and public data
-- Restrict access to internal processing tables
-- =============================================================================

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY ON EXPORT VIEWS
-- =============================================================================

-- Note: Materialized views in PostgreSQL don't support RLS directly
-- We need to create security barrier views on top of materialized views

-- Create security barrier views for public access
CREATE OR REPLACE VIEW public_export_universal_wide
WITH (security_barrier) AS
SELECT * FROM export_universal_wide;

CREATE OR REPLACE VIEW public_export_lidc_analysis_ready
WITH (security_barrier) AS
SELECT * FROM export_lidc_analysis_ready;

CREATE OR REPLACE VIEW public_export_lidc_with_links
WITH (security_barrier) AS
SELECT * FROM export_lidc_with_links;

CREATE OR REPLACE VIEW public_export_radiologist_data
WITH (security_barrier) AS
SELECT * FROM export_radiologist_data;

CREATE OR REPLACE VIEW public_export_top_keywords
WITH (security_barrier) AS
SELECT * FROM export_top_keywords;

-- Grant SELECT to anonymous role (anon is Supabase's anonymous role)
GRANT SELECT ON public_export_universal_wide TO anon;
GRANT SELECT ON public_export_lidc_analysis_ready TO anon;
GRANT SELECT ON public_export_lidc_with_links TO anon;
GRANT SELECT ON public_export_radiologist_data TO anon;
GRANT SELECT ON public_export_top_keywords TO anon;

COMMENT ON VIEW public_export_universal_wide IS 'Public read-only access to universal export';
COMMENT ON VIEW public_export_lidc_analysis_ready IS 'Public read-only access to LIDC analysis data';
COMMENT ON VIEW public_export_lidc_with_links IS 'Public read-only access to LIDC with TCIA links';
COMMENT ON VIEW public_export_radiologist_data IS 'Public read-only access to radiologist statistics';
COMMENT ON VIEW public_export_top_keywords IS 'Public read-only access to top keywords';

-- =============================================================================
-- GRANT SELECT ON LIDC-SPECIFIC VIEWS (anonymous access)
-- =============================================================================

-- LIDC patient summary
GRANT SELECT ON lidc_patient_summary TO anon;
GRANT SELECT ON lidc_nodule_analysis TO anon;
GRANT SELECT ON lidc_patient_cases TO anon;

-- LIDC contour views
GRANT SELECT ON lidc_3d_contours TO anon;
GRANT SELECT ON lidc_contour_slices TO anon;
GRANT SELECT ON lidc_contour_availability TO anon;
GRANT SELECT ON lidc_nodule_spatial_stats TO anon;

COMMENT ON VIEW lidc_patient_summary IS 'Public access: LIDC patient summaries';
COMMENT ON VIEW lidc_nodule_analysis IS 'Public access: Per-nodule analysis with radiologist ratings';
COMMENT ON VIEW lidc_3d_contours IS 'Public access: 3D contour data for visualization';

-- =============================================================================
-- GRANT SELECT ON UNIVERSAL VIEWS (anonymous access)
-- =============================================================================

-- Universal analysis views
GRANT SELECT ON file_summary TO anon;
GRANT SELECT ON segment_statistics TO anon;
GRANT SELECT ON numeric_data_flat TO anon;

-- Case-related views
GRANT SELECT ON cases_with_evidence TO anon;

-- Validation views (but NOT pending assignments)
GRANT SELECT ON case_identifier_validation TO anon;
GRANT SELECT ON unresolved_segments TO anon;

-- Keyword views
GRANT SELECT ON cross_type_keyword_evidence TO anon;

COMMENT ON VIEW file_summary IS 'Public access: File-level statistics';
COMMENT ON VIEW cases_with_evidence IS 'Public access: Established cases only';

-- =============================================================================
-- RESTRICT ACCESS TO INTERNAL PROCESSING TABLES
-- =============================================================================

-- These tables should ONLY be accessible to authenticated users

-- Ensure RLS is enabled on core tables (already done in migration 002, but re-confirm)
ALTER TABLE file_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE quantitative_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE qualitative_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE mixed_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE extracted_keywords ENABLE ROW LEVEL SECURITY;
ALTER TABLE keyword_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE stop_words ENABLE ROW LEVEL SECURITY;

-- Pending case assignments - ONLY authenticated users
ALTER TABLE pending_case_assignment ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies and recreate
DROP POLICY IF EXISTS "Allow all for authenticated users" ON file_imports;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON quantitative_segments;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON qualitative_segments;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON mixed_segments;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON extracted_keywords;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON keyword_occurrences;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON case_patterns;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON stop_words;

-- Allow authenticated users full access to core tables
CREATE POLICY "Authenticated users full access" ON file_imports
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users full access" ON quantitative_segments
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users full access" ON qualitative_segments
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users full access" ON mixed_segments
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users full access" ON extracted_keywords
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users full access" ON keyword_occurrences
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users full access" ON stop_words
    FOR ALL USING (auth.role() = 'authenticated');

-- Case patterns - authenticated can read/write, anon can read established cases only
CREATE POLICY "Authenticated users full access" ON case_patterns
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Anonymous read established cases" ON case_patterns
    FOR SELECT USING (
        auth.role() = 'anon' AND confidence_score >= 0.8
    );

-- Pending case assignments - ONLY authenticated users (contains uncertain data)
CREATE POLICY "Only authenticated users" ON pending_case_assignment
    FOR ALL USING (auth.role() = 'authenticated');

COMMENT ON TABLE pending_case_assignment IS 'RESTRICTED: Only authenticated users can access pending assignments';

-- =============================================================================
-- GRANT EXECUTE ON PUBLIC HELPER FUNCTIONS
-- =============================================================================

-- Allow anonymous users to execute read-only helper functions
GRANT EXECUTE ON FUNCTION get_keyword_contexts(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION find_files_with_keywords(TEXT[]) TO anon;
GRANT EXECUTE ON FUNCTION get_nodule_contour_data(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_nodule_slice_data(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION calculate_bounding_box_from_contours(JSONB) TO anon;
GRANT EXECUTE ON FUNCTION calculate_centroid_from_contours(JSONB) TO anon;

-- Restrict write/admin functions to authenticated users only
REVOKE EXECUTE ON FUNCTION process_case_assignment(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION assign_case_manually(UUID, TEXT, BOOLEAN, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION refresh_all_export_views() FROM anon;
REVOKE EXECUTE ON FUNCTION refresh_export_table() FROM anon;

GRANT EXECUTE ON FUNCTION process_case_assignment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION assign_case_manually(UUID, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_all_export_views() TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_export_table() TO authenticated;

-- =============================================================================
-- CREATE USAGE STATISTICS VIEW (public)
-- =============================================================================

CREATE OR REPLACE VIEW public_database_statistics AS
SELECT
    'Total Files Imported' AS metric,
    COUNT(*)::TEXT AS value
FROM file_imports
UNION ALL
SELECT
    'Total Segments',
    COUNT(*)::TEXT
FROM (
    SELECT segment_id FROM qualitative_segments
    UNION ALL
    SELECT segment_id FROM quantitative_segments
    UNION ALL
    SELECT segment_id FROM mixed_segments
) all_segments
UNION ALL
SELECT
    'Unique Keywords Extracted',
    COUNT(*)::TEXT
FROM extracted_keywords
UNION ALL
SELECT
    'Established Cases',
    COUNT(*)::TEXT
FROM case_patterns
WHERE confidence_score >= 0.8
UNION ALL
SELECT
    'LIDC Patients',
    COUNT(DISTINCT patient_id)::TEXT
FROM lidc_patient_summary
UNION ALL
SELECT
    'LIDC Nodules',
    SUM(nodule_count)::TEXT
FROM lidc_patient_summary
UNION ALL
SELECT
    'Last Data Import',
    TO_CHAR(MAX(import_timestamp), 'YYYY-MM-DD HH24:MI:SS')
FROM file_imports
UNION ALL
SELECT
    'Database Version',
    '1.0.0 (Migrations 001-012)';

GRANT SELECT ON public_database_statistics TO anon;

COMMENT ON VIEW public_database_statistics IS 'Public database statistics (no sensitive data)';

-- =============================================================================
-- CREATE API ACCESS GUIDE VIEW
-- =============================================================================

CREATE OR REPLACE VIEW api_access_guide AS
SELECT
    'Public Export Views' AS category,
    'public_export_universal_wide' AS view_name,
    'All data types - CSV ready' AS description,
    'SELECT * FROM public_export_universal_wide LIMIT 100' AS example_query
UNION ALL
SELECT
    'Public Export Views',
    'public_export_lidc_analysis_ready',
    'LIDC ratings - SPSS/R format',
    'SELECT * FROM public_export_lidc_analysis_ready WHERE "Malignancy (1-5)" >= 4'
UNION ALL
SELECT
    'Public Export Views',
    'public_export_lidc_with_links',
    'LIDC patients with TCIA links',
    'SELECT * FROM public_export_lidc_with_links ORDER BY "Avg Malignancy" DESC'
UNION ALL
SELECT
    'LIDC Medical Views',
    'lidc_patient_summary',
    'Patient-level consensus statistics',
    'SELECT * FROM lidc_patient_summary WHERE avg_malignancy > 3.5'
UNION ALL
SELECT
    'LIDC Medical Views',
    'lidc_nodule_analysis',
    'Per-nodule with radiologist columns',
    'SELECT * FROM lidc_nodule_analysis WHERE mean_malignancy >= 4'
UNION ALL
SELECT
    'LIDC 3D Views',
    'lidc_3d_contours',
    '3D contour data for visualization',
    'SELECT * FROM lidc_3d_contours WHERE volume_mm3 > 100'
UNION ALL
SELECT
    'Universal Views',
    'file_summary',
    'File-level statistics',
    'SELECT * FROM file_summary WHERE "Case ID" != ''Not Assigned'''
UNION ALL
SELECT
    'Universal Views',
    'cases_with_evidence',
    'Established cases only',
    'SELECT * FROM cases_with_evidence WHERE confidence_score >= 0.9'
UNION ALL
SELECT
    'Helper Functions',
    'get_keyword_contexts(keyword)',
    'Get all contexts for a keyword',
    'SELECT * FROM get_keyword_contexts(''malignancy'')'
UNION ALL
SELECT
    'Helper Functions',
    'get_nodule_contour_data(patient_id, nodule_id)',
    'Get contour JSON for Python',
    'SELECT get_nodule_contour_data(''LIDC-IDRI-0001'', ''1'')'
UNION ALL
SELECT
    'Statistics',
    'public_database_statistics',
    'Database usage statistics',
    'SELECT * FROM public_database_statistics';

GRANT SELECT ON api_access_guide TO anon;

COMMENT ON VIEW api_access_guide IS 'API access guide for public users (lists available views and example queries)';

-- =============================================================================
-- SECURITY NOTES AND WARNINGS
-- =============================================================================

-- Create a view documenting the security model
CREATE OR REPLACE VIEW security_model_documentation AS
SELECT
    'ANONYMOUS (anon role)' AS user_type,
    'Read-only access to:' AS access_level,
    string_agg(table_name, ', ' ORDER BY table_name) AS accessible_objects
FROM (
    SELECT 'Export views' AS table_name
    UNION ALL SELECT 'LIDC medical views'
    UNION ALL SELECT 'Universal analysis views'
    UNION ALL SELECT 'Established cases (confidence >= 0.8)'
    UNION ALL SELECT 'Public helper functions'
    UNION ALL SELECT 'Database statistics'
) objects
GROUP BY user_type, access_level
UNION ALL
SELECT
    'AUTHENTICATED (authenticated role)',
    'Full access to:',
    'All tables, views, and functions (read/write/execute)'
UNION ALL
SELECT
    'RESTRICTED (no access)',
    'Private tables:',
    'pending_case_assignment, internal processing tables (raw segments, keywords, occurrences)';

GRANT SELECT ON security_model_documentation TO anon;

COMMENT ON VIEW security_model_documentation IS 'Documentation of database security model and access levels';

-- =============================================================================
-- REFRESH MATERIALIZED VIEWS (initial population)
-- =============================================================================

-- Refresh all export views to ensure they're populated
-- Comment out if running on empty database
-- SELECT * FROM refresh_all_export_views();

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 012: Public access policies (RLS) for anonymous read-only access installed';

-- =============================================================================
-- SUMMARY OF ACCESS CONTROL
-- =============================================================================

/*
SUMMARY:

ANONYMOUS USERS (anon role) CAN:
✓ Read all export views (via public_export_* security barrier views)
✓ Read LIDC medical views (patient summary, nodule analysis, contours)
✓ Read universal analysis views (file summary, segment statistics)
✓ Read established cases (confidence >= 0.8)
✓ Execute read-only helper functions
✓ View database statistics

ANONYMOUS USERS CANNOT:
✗ Access raw file_imports table
✗ Access segment tables (qualitative, quantitative, mixed)
✗ Access keyword extraction internals
✗ Access pending_case_assignment (uncertain data)
✗ Execute admin functions (case assignment, refresh views)
✗ Write/modify any data

AUTHENTICATED USERS (authenticated role) CAN:
✓ Everything anonymous users can do
✓ Full read/write access to all tables
✓ Execute admin functions
✓ Assign cases manually
✓ Refresh materialized views
✓ Import new data

SECURITY BEST PRACTICES:
- LIDC data is de-identified (LIDC-IDRI-XXXX patient IDs)
- No PHI (Protected Health Information) in public views
- Pending/uncertain data restricted to authenticated users
- Internal processing tables hidden from public
- All export views are read-only for anonymous users
*/
