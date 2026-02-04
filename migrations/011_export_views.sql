-- =============================================================================
-- Migration 011: Export Views for Non-Technical Users
-- =============================================================================
-- Purpose: Materialized views in CSV-ready format for Excel, R, SPSS, Stata
-- Human-readable column names, no UUIDs, flattened structures
-- =============================================================================

-- =============================================================================
-- MATERIALIZED VIEW: Universal Wide Export (all data types)
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS export_universal_wide CASCADE;
CREATE MATERIALIZED VIEW export_universal_wide AS
SELECT
    -- File identification (human-readable)
    fi.filename AS "File Name",
    fi.extension AS "File Type",
    TO_CHAR(fi.import_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS "Import Date",
    fi.processing_status AS "Processing Status",

    -- Case assignment
    COALESCE(fi.metadata->>'case_label', 'Not Assigned') AS "Case ID",
    COALESCE((fi.metadata->>'case_confidence')::TEXT, 'N/A') AS "Case Confidence",
    COALESCE(fi.metadata->>'case_detection_method', 'N/A') AS "Detection Method",

    -- Segment information
    us.segment_type::TEXT AS "Segment Type",

    -- Content preview
    CASE
        WHEN us.segment_type = 'qualitative' THEN LEFT((us.content->>'text_content')::TEXT, 500)
        WHEN us.segment_type = 'quantitative' THEN 'Numeric data - see numeric columns'
        WHEN us.segment_type = 'mixed' THEN LEFT((us.content->>'text_elements')::TEXT, 500)
        ELSE NULL
    END AS "Content Preview",

    -- Keyword information
    COUNT(DISTINCT ko.keyword_id) AS "Keyword Count",
    STRING_AGG(DISTINCT k.term, '; ' ORDER BY k.term) AS "Keywords",
    MAX(k.relevance_score) AS "Max Keyword Relevance",

    -- Numeric field extraction (for quantitative segments)
    CASE
        WHEN us.segment_type = 'quantitative' THEN
            (us.content->>'row_count')::TEXT
        ELSE NULL
    END AS "Numeric Row Count",

    CASE
        WHEN us.segment_type = 'quantitative' THEN
            (us.content->>'numeric_density')::TEXT
        ELSE NULL
    END AS "Numeric Density",

    -- Quality metrics
    CASE
        WHEN us.segment_type = 'qualitative' THEN
            (SELECT word_count FROM qualitative_segments WHERE segment_id = us.segment_id)
        ELSE NULL
    END AS "Word Count",

    CASE
        WHEN us.segment_type = 'qualitative' THEN
            (SELECT sentence_count FROM qualitative_segments WHERE segment_id = us.segment_id)
        ELSE NULL
    END AS "Sentence Count",

    -- File metadata (flattened)
    fi.file_size_bytes AS "File Size (Bytes)",

    -- Timestamps
    TO_CHAR(us.extraction_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS "Extraction Date"

FROM file_imports fi
LEFT JOIN unified_segments us ON fi.file_id = us.file_id
LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
GROUP BY
    fi.file_id, fi.filename, fi.extension, fi.import_timestamp,
    fi.processing_status, fi.metadata, fi.file_size_bytes,
    us.segment_id, us.segment_type, us.content, us.extraction_timestamp
ORDER BY fi.import_timestamp DESC, us.extraction_timestamp DESC;

-- Create indexes on materialized view
CREATE INDEX idx_export_universal_file_name ON export_universal_wide("File Name");
CREATE INDEX idx_export_universal_case_id ON export_universal_wide("Case ID");
CREATE INDEX idx_export_universal_import_date ON export_universal_wide("Import Date");
CREATE INDEX idx_export_universal_segment_type ON export_universal_wide("Segment Type");

COMMENT ON MATERIALIZED VIEW export_universal_wide IS 'CSV-ready universal export - refresh with: REFRESH MATERIALIZED VIEW export_universal_wide';

-- =============================================================================
-- MATERIALIZED VIEW: LIDC Analysis Ready (statistical software format)
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS export_lidc_analysis_ready CASCADE;
CREATE MATERIALIZED VIEW export_lidc_analysis_ready AS
WITH lidc_files AS (
    SELECT
        fi.file_id,
        fi.filename,
        fi.metadata->>'case_label' AS patient_id,
        fi.import_timestamp
    FROM file_imports fi
    WHERE fi.metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}'
),
nodule_radiologist_ratings AS (
    SELECT
        lf.patient_id,
        nodule_elem->>'nodule_id' AS nodule_id,
        radiologist_key.key AS radiologist_num,
        radiologist_key.value AS ratings
    FROM lidc_files lf
    JOIN quantitative_segments qs ON lf.file_id = qs.file_id
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE
            WHEN qs.data_structure ? 'nodules' THEN qs.data_structure->'nodules'
            WHEN qs.data_structure ? 'annotations' THEN qs.data_structure->'annotations'
            ELSE '[]'::jsonb
        END
    ) AS nodule_elem
    CROSS JOIN LATERAL jsonb_each(
        COALESCE(nodule_elem->'radiologists', nodule_elem->'characteristics', '{}'::jsonb)
    ) AS radiologist_key
)
SELECT
    -- Patient and nodule identification
    patient_id AS "Patient ID",
    nodule_id AS "Nodule Number",
    radiologist_num AS "Radiologist",

    -- All 9 characteristics with human-readable column names

    -- Subtlety (1-5: 1=extremely subtle, 5=obvious)
    (ratings->>'subtlety')::INTEGER AS "Subtlety (1-5)",

    -- Internal Structure (1-4: 1=soft tissue, 2=fluid, 3=fat, 4=air)
    (ratings->>'internal_structure')::INTEGER AS "Internal Structure (1-4)",

    -- Calcification (1-6: 1=popcorn, 2=laminated, 3=solid, 4=non-central, 5=central, 6=absent)
    (ratings->>'calcification')::INTEGER AS "Calcification (1-6)",

    -- Sphericity (1-5: 1=linear, 3=ovoid, 5=round)
    (ratings->>'sphericity')::INTEGER AS "Sphericity (1-5)",

    -- Margin (1-5: 1=poorly defined, 5=sharp)
    (ratings->>'margin')::INTEGER AS "Margin (1-5)",

    -- Lobulation (1-5: 1=marked, 5=none)
    (ratings->>'lobulation')::INTEGER AS "Lobulation (1-5)",

    -- Spiculation (1-5: 1=marked, 5=none)
    (ratings->>'spiculation')::INTEGER AS "Spiculation (1-5)",

    -- Texture (1-5: 1=non-solid/ground glass, 5=solid)
    (ratings->>'texture')::INTEGER AS "Texture (1-5)",

    -- Malignancy (1-5: 1=highly unlikely, 3=indeterminate, 5=highly suspicious)
    (ratings->>'malignancy')::INTEGER AS "Malignancy (1-5)",

    -- Additional metadata for filtering
    (SELECT TO_CHAR(import_timestamp, 'YYYY-MM-DD') FROM lidc_files WHERE patient_id = nrr.patient_id LIMIT 1) AS "Import Date"

FROM nodule_radiologist_ratings nrr
ORDER BY patient_id, nodule_id, radiologist_num;

-- Create indexes
CREATE INDEX idx_export_lidc_patient ON export_lidc_analysis_ready("Patient ID");
CREATE INDEX idx_export_lidc_nodule ON export_lidc_analysis_ready("Nodule Number");
CREATE INDEX idx_export_lidc_malignancy ON export_lidc_analysis_ready("Malignancy (1-5)");

COMMENT ON MATERIALIZED VIEW export_lidc_analysis_ready IS 'LIDC radiologist ratings - one row per radiologist per nodule - perfect for SPSS/R/Stata';

-- =============================================================================
-- MATERIALIZED VIEW: LIDC With Links (for sharing with collaborators)
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS export_lidc_with_links CASCADE;
CREATE MATERIALIZED VIEW export_lidc_with_links AS
SELECT
    -- Patient identification
    lps.patient_id AS "Patient ID",

    -- TCIA links (clickable in Excel when saved as XLSX with hyperlinks)
    lps.tcia_study_url AS "TCIA Study Link",
    lps.tcia_download_url AS "TCIA Download Link",

    -- Nodule summary
    lps.nodule_count AS "Nodule Count",

    -- Consensus characteristics (averages across all radiologists)
    lps.avg_subtlety AS "Avg Subtlety",
    lps.avg_internal_structure AS "Avg Internal Structure",
    lps.avg_calcification AS "Avg Calcification",
    lps.avg_sphericity AS "Avg Sphericity",
    lps.avg_margin AS "Avg Margin",
    lps.avg_lobulation AS "Avg Lobulation",
    lps.avg_spiculation AS "Avg Spiculation",
    lps.avg_texture AS "Avg Texture",
    lps.avg_malignancy AS "Avg Malignancy",

    -- Variability metrics (stddev indicates inter-radiologist disagreement)
    lps.stddev_subtlety AS "StdDev Subtlety",
    lps.stddev_malignancy AS "StdDev Malignancy",

    -- Contour data availability
    CASE
        WHEN lps.has_contour_data THEN 'Yes'
        ELSE 'No'
    END AS "Contour Data Available",

    -- Download instructions
    'Visit NBIA Data Portal at ' || lps.tcia_download_url ||
    ' and search for patient ID: ' || lps.patient_id AS "Download Instructions"

FROM lidc_patient_summary lps
ORDER BY lps.patient_id;

-- Create indexes
CREATE INDEX idx_export_lidc_links_patient ON export_lidc_with_links("Patient ID");
CREATE INDEX idx_export_lidc_links_malignancy ON export_lidc_with_links("Avg Malignancy");
CREATE INDEX idx_export_lidc_links_nodule_count ON export_lidc_with_links("Nodule Count");

COMMENT ON MATERIALIZED VIEW export_lidc_with_links IS 'Patient-level LIDC summary with TCIA links - perfect for sharing';

-- =============================================================================
-- MATERIALIZED VIEW: Radiologist-Specific Export
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS export_radiologist_data CASCADE;
CREATE MATERIALIZED VIEW export_radiologist_data AS
WITH lidc_files AS (
    SELECT
        fi.file_id,
        fi.metadata->>'case_label' AS patient_id,
        fi.import_timestamp
    FROM file_imports fi
    WHERE fi.metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}'
),
radiologist_counts AS (
    SELECT
        lf.patient_id,
        radiologist_key.key AS radiologist_id,
        COUNT(DISTINCT nodule_elem->>'nodule_id') AS nodule_count,

        -- Average ratings per radiologist
        AVG((radiologist_key.value->>'malignancy')::NUMERIC) AS avg_malignancy,
        AVG((radiologist_key.value->>'subtlety')::NUMERIC) AS avg_subtlety,
        AVG((radiologist_key.value->>'spiculation')::NUMERIC) AS avg_spiculation,

        -- Contour contribution
        COUNT(*) FILTER (WHERE radiologist_key.value ? 'contours' OR radiologist_key.value ? 'contour_data') AS contours_provided

    FROM lidc_files lf
    JOIN quantitative_segments qs ON lf.file_id = qs.file_id
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE
            WHEN qs.data_structure ? 'nodules' THEN qs.data_structure->'nodules'
            WHEN qs.data_structure ? 'annotations' THEN qs.data_structure->'annotations'
            ELSE '[]'::jsonb
        END
    ) AS nodule_elem
    CROSS JOIN LATERAL jsonb_each(
        COALESCE(nodule_elem->'radiologists', nodule_elem->'characteristics', '{}'::jsonb)
    ) AS radiologist_key
    GROUP BY lf.patient_id, radiologist_key.key
)
SELECT
    patient_id AS "Patient ID",
    radiologist_id AS "Radiologist Number",
    nodule_count AS "Nodules Annotated",
    ROUND(avg_malignancy, 2) AS "Avg Malignancy Rating",
    ROUND(avg_subtlety, 2) AS "Avg Subtlety Rating",
    ROUND(avg_spiculation, 2) AS "Avg Spiculation Rating",
    contours_provided AS "Contours Provided"
FROM radiologist_counts
ORDER BY patient_id, radiologist_id;

-- Create indexes
CREATE INDEX idx_export_radiologist_patient ON export_radiologist_data("Patient ID");
CREATE INDEX idx_export_radiologist_num ON export_radiologist_data("Radiologist Number");

COMMENT ON MATERIALIZED VIEW export_radiologist_data IS 'Radiologist-level statistics for inter-rater analysis';

-- =============================================================================
-- MATERIALIZED VIEW: Keyword Export (top keywords by relevance)
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS export_top_keywords CASCADE;
CREATE MATERIALIZED VIEW export_top_keywords AS
SELECT
    k.term AS "Keyword",
    k.total_frequency AS "Total Occurrences",
    k.document_frequency AS "Document Count",
    ROUND(k.relevance_score, 4) AS "Relevance Score",

    -- Segment type breakdown
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.segment_id END) AS "Qualitative Occurrences",
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.segment_id END) AS "Quantitative Occurrences",
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'mixed' THEN ko.segment_id END) AS "Mixed Occurrences",

    -- Cross-validation flag
    CASE
        WHEN COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.segment_id END) > 0
         AND COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.segment_id END) > 0
        THEN 'Yes'
        ELSE 'No'
    END AS "Cross-Type Validated",

    -- File distribution
    COUNT(DISTINCT ko.file_id) AS "File Count",

    -- Timestamps
    TO_CHAR(k.first_seen_timestamp, 'YYYY-MM-DD') AS "First Seen",
    TO_CHAR(k.last_seen_timestamp, 'YYYY-MM-DD') AS "Last Seen"

FROM extracted_keywords k
LEFT JOIN keyword_occurrences ko ON k.keyword_id = ko.keyword_id
GROUP BY k.keyword_id, k.term, k.total_frequency, k.document_frequency,
         k.relevance_score, k.first_seen_timestamp, k.last_seen_timestamp
HAVING k.total_frequency >= 3  -- Only keywords appearing 3+ times
ORDER BY k.relevance_score DESC, k.total_frequency DESC
LIMIT 1000;  -- Top 1000 keywords

-- Create indexes
CREATE INDEX idx_export_keywords_term ON export_top_keywords("Keyword");
CREATE INDEX idx_export_keywords_relevance ON export_top_keywords("Relevance Score" DESC);

COMMENT ON MATERIALIZED VIEW export_top_keywords IS 'Top 1000 keywords by relevance for keyword analysis';

-- =============================================================================
-- FUNCTION: Refresh all export views
-- =============================================================================

CREATE OR REPLACE FUNCTION refresh_all_export_views()
RETURNS TABLE(
    view_name TEXT,
    row_count BIGINT,
    refresh_duration INTERVAL
) AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_count BIGINT;
BEGIN
    -- Refresh export_universal_wide
    v_start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW export_universal_wide;
    v_end_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM export_universal_wide;
    RETURN QUERY SELECT 'export_universal_wide'::TEXT, v_count, v_end_time - v_start_time;

    -- Refresh export_lidc_analysis_ready
    v_start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW export_lidc_analysis_ready;
    v_end_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM export_lidc_analysis_ready;
    RETURN QUERY SELECT 'export_lidc_analysis_ready'::TEXT, v_count, v_end_time - v_start_time;

    -- Refresh export_lidc_with_links
    v_start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW export_lidc_with_links;
    v_end_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM export_lidc_with_links;
    RETURN QUERY SELECT 'export_lidc_with_links'::TEXT, v_count, v_end_time - v_start_time;

    -- Refresh export_radiologist_data
    v_start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW export_radiologist_data;
    v_end_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM export_radiologist_data;
    RETURN QUERY SELECT 'export_radiologist_data'::TEXT, v_count, v_end_time - v_start_time;

    -- Refresh export_top_keywords
    v_start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW export_top_keywords;
    v_end_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM export_top_keywords;
    RETURN QUERY SELECT 'export_top_keywords'::TEXT, v_count, v_end_time - v_start_time;

    -- Also refresh the original export_ready_table if it exists
    BEGIN
        v_start_time := clock_timestamp();
        REFRESH MATERIALIZED VIEW export_ready_table;
        v_end_time := clock_timestamp();
        SELECT COUNT(*) INTO v_count FROM export_ready_table;
        RETURN QUERY SELECT 'export_ready_table'::TEXT, v_count, v_end_time - v_start_time;
    EXCEPTION
        WHEN undefined_table THEN
            -- Skip if export_ready_table doesn't exist
            NULL;
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_all_export_views IS 'Refresh all materialized export views and return statistics';

-- =============================================================================
-- VIEW: Export View Status (check freshness)
-- =============================================================================

CREATE OR REPLACE VIEW export_view_status AS
SELECT
    'export_universal_wide' AS view_name,
    (SELECT COUNT(*) FROM export_universal_wide) AS row_count,
    'CSV-ready universal export' AS description
UNION ALL
SELECT
    'export_lidc_analysis_ready',
    (SELECT COUNT(*) FROM export_lidc_analysis_ready),
    'LIDC radiologist ratings (SPSS/R format)'
UNION ALL
SELECT
    'export_lidc_with_links',
    (SELECT COUNT(*) FROM export_lidc_with_links),
    'LIDC patient summary with TCIA links'
UNION ALL
SELECT
    'export_radiologist_data',
    (SELECT COUNT(*) FROM export_radiologist_data),
    'Radiologist-level statistics'
UNION ALL
SELECT
    'export_top_keywords',
    (SELECT COUNT(*) FROM export_top_keywords),
    'Top 1000 keywords by relevance';

COMMENT ON VIEW export_view_status IS 'Check row counts for all export views';

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 011: Export views for non-technical users installed';
