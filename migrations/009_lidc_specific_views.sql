-- =============================================================================
-- Migration 009: LIDC-Specific Medical Analysis Views
-- =============================================================================
-- Purpose: Medical views for LIDC-IDRI dataset with TCIA links and consensus metrics
-- Includes patient summaries, nodule analysis, and radiologist agreement statistics
-- =============================================================================

-- =============================================================================
-- VIEW: LIDC Patient Summary (one row per patient)
-- =============================================================================

CREATE OR REPLACE VIEW lidc_patient_summary AS
WITH lidc_files AS (
    -- Identify LIDC files by case label
    SELECT
        fi.file_id,
        fi.filename,
        fi.metadata->>'case_label' AS patient_id,
        fi.import_timestamp
    FROM file_imports fi
    WHERE fi.metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}'
),
nodule_data AS (
    -- Extract nodule information from quantitative segments
    SELECT
        lf.patient_id,
        lf.file_id,
        qs.segment_id,
        qs.data_structure,

        -- Extract nodule array if present
        CASE
            WHEN qs.data_structure ? 'nodules' THEN qs.data_structure->'nodules'
            WHEN qs.data_structure ? 'annotations' THEN qs.data_structure->'annotations'
            ELSE NULL
        END AS nodules_array,

        -- Extract individual nodule elements
        jsonb_array_elements(
            CASE
                WHEN qs.data_structure ? 'nodules' THEN qs.data_structure->'nodules'
                WHEN qs.data_structure ? 'annotations' THEN qs.data_structure->'annotations'
                ELSE '[]'::jsonb
            END
        ) AS nodule
    FROM lidc_files lf
    JOIN quantitative_segments qs ON lf.file_id = qs.file_id
    WHERE qs.data_structure ? 'nodules' OR qs.data_structure ? 'annotations'
),
radiologist_readings AS (
    -- Extract radiologist characteristics from nodules
    SELECT
        nd.patient_id,
        nd.nodule->>'nodule_id' AS nodule_id,

        -- Extract radiologist data (handles both 'radiologists' and 'characteristics' keys)
        COALESCE(
            nd.nodule->'radiologists',
            nd.nodule->'characteristics',
            nd.nodule
        ) AS radiologist_data,

        -- Count radiologists
        CASE
            WHEN nd.nodule ? 'num_radiologists' THEN (nd.nodule->>'num_radiologists')::INTEGER
            WHEN nd.nodule ? 'radiologists' THEN jsonb_object_keys(nd.nodule->'radiologists')::INTEGER
            ELSE 0
        END AS num_radiologists
    FROM nodule_data nd
),
characteristic_stats AS (
    -- Calculate consensus statistics for all 9 characteristics
    SELECT
        rr.patient_id,

        -- Nodule count
        COUNT(DISTINCT rr.nodule_id) AS nodule_count,

        -- Subtlety (1-5)
        AVG((jsonb_each_value.value->>'subtlety')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'subtlety') AS avg_subtlety,
        MIN((jsonb_each_value.value->>'subtlety')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'subtlety') AS min_subtlety,
        MAX((jsonb_each_value.value->>'subtlety')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'subtlety') AS max_subtlety,
        STDDEV((jsonb_each_value.value->>'subtlety')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'subtlety') AS stddev_subtlety,

        -- Internal Structure (1-4)
        AVG((jsonb_each_value.value->>'internal_structure')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'internal_structure') AS avg_internal_structure,
        MIN((jsonb_each_value.value->>'internal_structure')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'internal_structure') AS min_internal_structure,
        MAX((jsonb_each_value.value->>'internal_structure')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'internal_structure') AS max_internal_structure,
        STDDEV((jsonb_each_value.value->>'internal_structure')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'internal_structure') AS stddev_internal_structure,

        -- Calcification (1-6)
        AVG((jsonb_each_value.value->>'calcification')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'calcification') AS avg_calcification,
        MIN((jsonb_each_value.value->>'calcification')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'calcification') AS min_calcification,
        MAX((jsonb_each_value.value->>'calcification')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'calcification') AS max_calcification,
        STDDEV((jsonb_each_value.value->>'calcification')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'calcification') AS stddev_calcification,

        -- Sphericity (1-5)
        AVG((jsonb_each_value.value->>'sphericity')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'sphericity') AS avg_sphericity,
        MIN((jsonb_each_value.value->>'sphericity')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'sphericity') AS min_sphericity,
        MAX((jsonb_each_value.value->>'sphericity')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'sphericity') AS max_sphericity,
        STDDEV((jsonb_each_value.value->>'sphericity')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'sphericity') AS stddev_sphericity,

        -- Margin (1-5)
        AVG((jsonb_each_value.value->>'margin')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'margin') AS avg_margin,
        MIN((jsonb_each_value.value->>'margin')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'margin') AS min_margin,
        MAX((jsonb_each_value.value->>'margin')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'margin') AS max_margin,
        STDDEV((jsonb_each_value.value->>'margin')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'margin') AS stddev_margin,

        -- Lobulation (1-5)
        AVG((jsonb_each_value.value->>'lobulation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'lobulation') AS avg_lobulation,
        MIN((jsonb_each_value.value->>'lobulation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'lobulation') AS min_lobulation,
        MAX((jsonb_each_value.value->>'lobulation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'lobulation') AS max_lobulation,
        STDDEV((jsonb_each_value.value->>'lobulation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'lobulation') AS stddev_lobulation,

        -- Spiculation (1-5)
        AVG((jsonb_each_value.value->>'spiculation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'spiculation') AS avg_spiculation,
        MIN((jsonb_each_value.value->>'spiculation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'spiculation') AS min_spiculation,
        MAX((jsonb_each_value.value->>'spiculation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'spiculation') AS max_spiculation,
        STDDEV((jsonb_each_value.value->>'spiculation')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'spiculation') AS stddev_spiculation,

        -- Texture (1-5)
        AVG((jsonb_each_value.value->>'texture')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'texture') AS avg_texture,
        MIN((jsonb_each_value.value->>'texture')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'texture') AS min_texture,
        MAX((jsonb_each_value.value->>'texture')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'texture') AS max_texture,
        STDDEV((jsonb_each_value.value->>'texture')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'texture') AS stddev_texture,

        -- Malignancy (1-5) - MOST IMPORTANT
        AVG((jsonb_each_value.value->>'malignancy')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'malignancy') AS avg_malignancy,
        MIN((jsonb_each_value.value->>'malignancy')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'malignancy') AS min_malignancy,
        MAX((jsonb_each_value.value->>'malignancy')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'malignancy') AS max_malignancy,
        STDDEV((jsonb_each_value.value->>'malignancy')::NUMERIC) FILTER (WHERE jsonb_each_value.value ? 'malignancy') AS stddev_malignancy,

        -- Contour data availability
        BOOL_OR(jsonb_each_value.value ? 'contours' OR jsonb_each_value.value ? 'contour_data') AS has_contour_data

    FROM radiologist_readings rr
    CROSS JOIN LATERAL jsonb_each(rr.radiologist_data) AS jsonb_each_value
    WHERE jsonb_typeof(rr.radiologist_data) = 'object'
    GROUP BY rr.patient_id
)
SELECT
    -- Patient identification
    cs.patient_id,

    -- TCIA study links
    'https://wiki.cancerimagingarchive.net/display/Public/LIDC-IDRI' AS tcia_study_url,
    'https://nbia.cancerimagingarchive.net' AS tcia_download_url,

    -- Nodule count
    cs.nodule_count,

    -- Subtlety consensus (1-5: 1=extremely subtle, 5=obvious)
    ROUND(cs.avg_subtlety, 2) AS avg_subtlety,
    cs.min_subtlety,
    cs.max_subtlety,
    ROUND(cs.stddev_subtlety, 3) AS stddev_subtlety,

    -- Internal Structure consensus (1-4: 1=soft tissue, 2=fluid, 3=fat, 4=air)
    ROUND(cs.avg_internal_structure, 2) AS avg_internal_structure,
    cs.min_internal_structure,
    cs.max_internal_structure,
    ROUND(cs.stddev_internal_structure, 3) AS stddev_internal_structure,

    -- Calcification consensus (1-6: 1=popcorn, 2=laminated, 3=solid, 4=non-central, 5=central, 6=absent)
    ROUND(cs.avg_calcification, 2) AS avg_calcification,
    cs.min_calcification,
    cs.max_calcification,
    ROUND(cs.stddev_calcification, 3) AS stddev_calcification,

    -- Sphericity consensus (1-5: 1=linear, 3=ovoid, 5=round)
    ROUND(cs.avg_sphericity, 2) AS avg_sphericity,
    cs.min_sphericity,
    cs.max_sphericity,
    ROUND(cs.stddev_sphericity, 3) AS stddev_sphericity,

    -- Margin consensus (1-5: 1=poorly defined, 5=sharp)
    ROUND(cs.avg_margin, 2) AS avg_margin,
    cs.min_margin,
    cs.max_margin,
    ROUND(cs.stddev_margin, 3) AS stddev_margin,

    -- Lobulation consensus (1-5: 1=marked, 5=none)
    ROUND(cs.avg_lobulation, 2) AS avg_lobulation,
    cs.min_lobulation,
    cs.max_lobulation,
    ROUND(cs.stddev_lobulation, 3) AS stddev_lobulation,

    -- Spiculation consensus (1-5: 1=marked, 5=none)
    ROUND(cs.avg_spiculation, 2) AS avg_spiculation,
    cs.min_spiculation,
    cs.max_spiculation,
    ROUND(cs.stddev_spiculation, 3) AS stddev_spiculation,

    -- Texture consensus (1-5: 1=non-solid/ground glass, 5=solid)
    ROUND(cs.avg_texture, 2) AS avg_texture,
    cs.min_texture,
    cs.max_texture,
    ROUND(cs.stddev_texture, 3) AS stddev_texture,

    -- Malignancy consensus (1-5: 1=highly unlikely, 3=indeterminate, 5=highly suspicious)
    ROUND(cs.avg_malignancy, 2) AS avg_malignancy,
    cs.min_malignancy,
    cs.max_malignancy,
    ROUND(cs.stddev_malignancy, 3) AS stddev_malignancy,

    -- Contour availability
    cs.has_contour_data

FROM characteristic_stats cs
ORDER BY cs.patient_id;

COMMENT ON VIEW lidc_patient_summary IS 'LIDC patient-level summary with consensus characteristics and TCIA links';

-- =============================================================================
-- VIEW: LIDC Nodule Analysis (per-nodule with per-radiologist columns)
-- =============================================================================

CREATE OR REPLACE VIEW lidc_nodule_analysis AS
WITH lidc_files AS (
    SELECT
        fi.file_id,
        fi.filename,
        fi.metadata->>'case_label' AS patient_id,
        fi.import_timestamp
    FROM file_imports fi
    WHERE fi.metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}'
),
nodule_data AS (
    SELECT
        lf.patient_id,
        lf.file_id,
        jsonb_array_elements(
            CASE
                WHEN qs.data_structure ? 'nodules' THEN qs.data_structure->'nodules'
                WHEN qs.data_structure ? 'annotations' THEN qs.data_structure->'annotations'
                ELSE '[]'::jsonb
            END
        ) AS nodule
    FROM lidc_files lf
    JOIN quantitative_segments qs ON lf.file_id = qs.file_id
    WHERE qs.data_structure ? 'nodules' OR qs.data_structure ? 'annotations'
),
radiologist_pivot AS (
    SELECT
        nd.patient_id,
        nd.nodule->>'nodule_id' AS nodule_id,

        -- TCIA nodule URL (constructed from patient and nodule ID)
        'https://wiki.cancerimagingarchive.net/display/Public/LIDC-IDRI#nodule-' ||
        nd.patient_id || '-' || (nd.nodule->>'nodule_id') AS tcia_nodule_url,

        -- Extract radiologist data
        COALESCE(nd.nodule->'radiologists', nd.nodule->'characteristics', '{}'::jsonb) AS rad_data,

        -- Radiologist 1
        (nd.nodule->'radiologists'->'1'->>'malignancy')::NUMERIC AS rad1_malignancy,
        (nd.nodule->'radiologists'->'1'->>'subtlety')::NUMERIC AS rad1_subtlety,
        (nd.nodule->'radiologists'->'1'->>'internal_structure')::NUMERIC AS rad1_internal_structure,
        (nd.nodule->'radiologists'->'1'->>'calcification')::NUMERIC AS rad1_calcification,
        (nd.nodule->'radiologists'->'1'->>'sphericity')::NUMERIC AS rad1_sphericity,
        (nd.nodule->'radiologists'->'1'->>'margin')::NUMERIC AS rad1_margin,
        (nd.nodule->'radiologists'->'1'->>'lobulation')::NUMERIC AS rad1_lobulation,
        (nd.nodule->'radiologists'->'1'->>'spiculation')::NUMERIC AS rad1_spiculation,
        (nd.nodule->'radiologists'->'1'->>'texture')::NUMERIC AS rad1_texture,

        -- Radiologist 2
        (nd.nodule->'radiologists'->'2'->>'malignancy')::NUMERIC AS rad2_malignancy,
        (nd.nodule->'radiologists'->'2'->>'subtlety')::NUMERIC AS rad2_subtlety,
        (nd.nodule->'radiologists'->'2'->>'internal_structure')::NUMERIC AS rad2_internal_structure,
        (nd.nodule->'radiologists'->'2'->>'calcification')::NUMERIC AS rad2_calcification,
        (nd.nodule->'radiologists'->'2'->>'sphericity')::NUMERIC AS rad2_sphericity,
        (nd.nodule->'radiologists'->'2'->>'margin')::NUMERIC AS rad2_margin,
        (nd.nodule->'radiologists'->'2'->>'lobulation')::NUMERIC AS rad2_lobulation,
        (nd.nodule->'radiologists'->'2'->>'spiculation')::NUMERIC AS rad2_spiculation,
        (nd.nodule->'radiologists'->'2'->>'texture')::NUMERIC AS rad2_texture,

        -- Radiologist 3
        (nd.nodule->'radiologists'->'3'->>'malignancy')::NUMERIC AS rad3_malignancy,
        (nd.nodule->'radiologists'->'3'->>'subtlety')::NUMERIC AS rad3_subtlety,
        (nd.nodule->'radiologists'->'3'->>'internal_structure')::NUMERIC AS rad3_internal_structure,
        (nd.nodule->'radiologists'->'3'->>'calcification')::NUMERIC AS rad3_calcification,
        (nd.nodule->'radiologists'->'3'->>'sphericity')::NUMERIC AS rad3_sphericity,
        (nd.nodule->'radiologists'->'3'->>'margin')::NUMERIC AS rad3_margin,
        (nd.nodule->'radiologists'->'3'->>'lobulation')::NUMERIC AS rad3_lobulation,
        (nd.nodule->'radiologists'->'3'->>'spiculation')::NUMERIC AS rad3_spiculation,
        (nd.nodule->'radiologists'->'3'->>'texture')::NUMERIC AS rad3_texture,

        -- Radiologist 4
        (nd.nodule->'radiologists'->'4'->>'malignancy')::NUMERIC AS rad4_malignancy,
        (nd.nodule->'radiologists'->'4'->>'subtlety')::NUMERIC AS rad4_subtlety,
        (nd.nodule->'radiologists'->'4'->>'internal_structure')::NUMERIC AS rad4_internal_structure,
        (nd.nodule->'radiologists'->'4'->>'calcification')::NUMERIC AS rad4_calcification,
        (nd.nodule->'radiologists'->'4'->>'sphericity')::NUMERIC AS rad4_sphericity,
        (nd.nodule->'radiologists'->'4'->>'margin')::NUMERIC AS rad4_margin,
        (nd.nodule->'radiologists'->'4'->>'lobulation')::NUMERIC AS rad4_lobulation,
        (nd.nodule->'radiologists'->'4'->>'spiculation')::NUMERIC AS rad4_spiculation,
        (nd.nodule->'radiologists'->'4'->>'texture')::NUMERIC AS rad4_texture,

        -- Contour data
        nd.nodule ? 'contours' OR nd.nodule ? 'contour_data' AS contour_available,

        -- Slice range (for contours)
        (nd.nodule->>'min_z')::NUMERIC AS min_z,
        (nd.nodule->>'max_z')::NUMERIC AS max_z

    FROM nodule_data nd
)
SELECT
    patient_id,
    nodule_id,
    tcia_nodule_url,

    -- Per-radiologist malignancy (most important)
    rad1_malignancy,
    rad2_malignancy,
    rad3_malignancy,
    rad4_malignancy,

    -- Per-radiologist subtlety
    rad1_subtlety,
    rad2_subtlety,
    rad3_subtlety,
    rad4_subtlety,

    -- Per-radiologist internal structure
    rad1_internal_structure,
    rad2_internal_structure,
    rad3_internal_structure,
    rad4_internal_structure,

    -- Per-radiologist calcification
    rad1_calcification,
    rad2_calcification,
    rad3_calcification,
    rad4_calcification,

    -- Per-radiologist sphericity
    rad1_sphericity,
    rad2_sphericity,
    rad3_sphericity,
    rad4_sphericity,

    -- Per-radiologist margin
    rad1_margin,
    rad2_margin,
    rad3_margin,
    rad4_margin,

    -- Per-radiologist lobulation
    rad1_lobulation,
    rad2_lobulation,
    rad3_lobulation,
    rad4_lobulation,

    -- Per-radiologist spiculation
    rad1_spiculation,
    rad2_spiculation,
    rad3_spiculation,
    rad4_spiculation,

    -- Per-radiologist texture
    rad1_texture,
    rad2_texture,
    rad3_texture,
    rad4_texture,

    -- Consensus metrics for malignancy
    ROUND((COALESCE(rad1_malignancy, 0) + COALESCE(rad2_malignancy, 0) +
           COALESCE(rad3_malignancy, 0) + COALESCE(rad4_malignancy, 0))::NUMERIC /
          NULLIF(
              (CASE WHEN rad1_malignancy IS NOT NULL THEN 1 ELSE 0 END +
               CASE WHEN rad2_malignancy IS NOT NULL THEN 1 ELSE 0 END +
               CASE WHEN rad3_malignancy IS NOT NULL THEN 1 ELSE 0 END +
               CASE WHEN rad4_malignancy IS NOT NULL THEN 1 ELSE 0 END), 0
          ), 2) AS mean_malignancy,

    -- Median malignancy (approximate using percentile_cont)
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY val) AS median_malignancy
    FROM (
        SELECT rad1_malignancy AS val WHERE rad1_malignancy IS NOT NULL
        UNION ALL SELECT rad2_malignancy WHERE rad2_malignancy IS NOT NULL
        UNION ALL SELECT rad3_malignancy WHERE rad3_malignancy IS NOT NULL
        UNION ALL SELECT rad4_malignancy WHERE rad4_malignancy IS NOT NULL
    ) malignancy_values,

    -- Standard deviation malignancy
    ROUND(STDDEV(val), 3) AS stddev_malignancy
    FROM (
        SELECT rad1_malignancy AS val WHERE rad1_malignancy IS NOT NULL
        UNION ALL SELECT rad2_malignancy WHERE rad2_malignancy IS NOT NULL
        UNION ALL SELECT rad3_malignancy WHERE rad3_malignancy IS NOT NULL
        UNION ALL SELECT rad4_malignancy WHERE rad4_malignancy IS NOT NULL
    ) malignancy_values,

    -- Contour info
    contour_available,
    CASE
        WHEN min_z IS NOT NULL AND max_z IS NOT NULL
        THEN (max_z - min_z + 1)::INTEGER
        ELSE NULL
    END AS slice_range

FROM radiologist_pivot
ORDER BY patient_id, nodule_id;

COMMENT ON VIEW lidc_nodule_analysis IS 'Per-nodule analysis with per-radiologist columns and consensus metrics';

-- =============================================================================
-- VIEW: LIDC Patient Cases (case-level rollup)
-- =============================================================================

CREATE OR REPLACE VIEW lidc_patient_cases AS
SELECT
    cp.case_id,
    cp.case_label AS patient_id,

    -- TCIA links
    'https://wiki.cancerimagingarchive.net/display/Public/LIDC-IDRI' AS tcia_study_url,
    'https://nbia.cancerimagingarchive.net' AS tcia_download_url,

    -- Case metadata
    cp.detection_method,
    cp.confidence_score,
    cp.cross_type_validated,

    -- Associated data counts
    cp.file_count,
    cp.segment_count,
    cp.keyword_count,

    -- Nodule summary from lidc_patient_summary
    (SELECT nodule_count FROM lidc_patient_summary WHERE patient_id = cp.case_label) AS nodule_count,
    (SELECT avg_malignancy FROM lidc_patient_summary WHERE patient_id = cp.case_label) AS avg_malignancy,
    (SELECT has_contour_data FROM lidc_patient_summary WHERE patient_id = cp.case_label) AS has_contour_data,

    -- Source files
    (
        SELECT jsonb_agg(jsonb_build_object(
            'filename', fi.filename,
            'import_timestamp', fi.import_timestamp
        ) ORDER BY fi.import_timestamp DESC)
        FROM file_imports fi
        WHERE fi.metadata->>'case_label' = cp.case_label
    ) AS source_files,

    -- Timestamps
    cp.detected_timestamp,
    cp.last_updated_timestamp

FROM case_patterns cp
WHERE cp.case_label ~ 'LIDC-IDRI-\d{4}'
ORDER BY cp.case_label;

COMMENT ON VIEW lidc_patient_cases IS 'Case-level rollup for LIDC patients with TCIA links';

-- =============================================================================
-- HELPER FUNCTION: Calculate Fleiss Kappa for inter-rater reliability
-- =============================================================================

CREATE OR REPLACE FUNCTION calculate_fleiss_kappa(ratings NUMERIC[])
RETURNS NUMERIC AS $$
DECLARE
    n INTEGER;  -- Number of subjects (nodules)
    k INTEGER;  -- Number of raters
    categories INTEGER[];  -- Distinct rating categories
    p_j NUMERIC[];  -- Proportion of ratings in each category
    P_i NUMERIC[];  -- Proportion of agreement for each subject
    P_bar NUMERIC;  -- Mean agreement
    P_e_bar NUMERIC;  -- Expected agreement by chance
    kappa NUMERIC;
BEGIN
    -- For now, return NULL - full implementation requires matrix operations
    -- This is a placeholder for the Python implementation in lidc_3d_utils.py
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_fleiss_kappa IS 'Calculate Fleiss kappa for multi-rater agreement (placeholder - use Python implementation)';

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 009: LIDC-specific medical views with TCIA links installed';
