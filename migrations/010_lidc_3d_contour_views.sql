-- =============================================================================
-- Migration 010: LIDC 3D Contour Views for Spatial Visualization
-- =============================================================================
-- Purpose: Extract and organize 3D contour data for visualization and analysis
-- Compatible with pylidc methods: boolean_mask(), to_volume(), uniform_cubic_resample()
-- =============================================================================

-- =============================================================================
-- VIEW: LIDC 3D Contours (nodule-level spatial data)
-- =============================================================================

CREATE OR REPLACE VIEW lidc_3d_contours AS
WITH lidc_files AS (
    SELECT
        fi.file_id,
        fi.filename,
        fi.metadata->>'case_label' AS patient_id,
        fi.import_timestamp
    FROM file_imports fi
    WHERE fi.metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}'
),
nodule_contours AS (
    SELECT
        lf.patient_id,
        lf.file_id,
        nodule_elem->>'nodule_id' AS nodule_id,

        -- Extract contour data for each radiologist
        radiologist_key.key AS radiologist_id,
        radiologist_key.value AS radiologist_contour_data,

        -- Extract contour coordinates if available
        CASE
            WHEN radiologist_key.value ? 'contours' THEN radiologist_key.value->'contours'
            WHEN radiologist_key.value ? 'contour_data' THEN radiologist_key.value->'contour_data'
            WHEN radiologist_key.value ? 'coordinates' THEN radiologist_key.value->'coordinates'
            ELSE NULL
        END AS contour_coordinates_json,

        -- Extract bounding box if available
        CASE
            WHEN radiologist_key.value ? 'bbox' THEN radiologist_key.value->'bbox'
            WHEN radiologist_key.value ? 'bounding_box' THEN radiologist_key.value->'bounding_box'
            ELSE NULL
        END AS bounding_box_json,

        -- Extract centroid if available
        CASE
            WHEN radiologist_key.value ? 'centroid' THEN radiologist_key.value->'centroid'
            WHEN radiologist_key.value ? 'center' THEN radiologist_key.value->'center'
            ELSE NULL
        END AS centroid_json,

        -- Extract volume if calculated
        (radiologist_key.value->>'volume_mm3')::NUMERIC AS volume_mm3,
        (radiologist_key.value->>'diameter_mm')::NUMERIC AS diameter_mm,

        -- Z-coordinate range (slice positions)
        (radiologist_key.value->>'min_z')::NUMERIC AS min_z,
        (radiologist_key.value->>'max_z')::NUMERIC AS max_z

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
    WHERE radiologist_key.value ? 'contours'
       OR radiologist_key.value ? 'contour_data'
       OR radiologist_key.value ? 'coordinates'
)
SELECT
    -- Identification
    nc.patient_id,
    nc.nodule_id,
    nc.radiologist_id,

    -- Contour coordinates (array of {x, y, z} points)
    nc.contour_coordinates_json AS contour_coordinates,

    -- Bounding box {min_x, max_x, min_y, max_y, min_z, max_z}
    CASE
        WHEN nc.bounding_box_json IS NOT NULL THEN nc.bounding_box_json
        ELSE jsonb_build_object(
            'min_x', NULL,
            'max_x', NULL,
            'min_y', NULL,
            'max_y', NULL,
            'min_z', nc.min_z,
            'max_z', nc.max_z
        )
    END AS bounding_box,

    -- Centroid {x, y, z}
    nc.centroid_json AS centroid,

    -- Volume and diameter
    nc.volume_mm3,
    nc.diameter_mm,

    -- Slice information
    nc.min_z,
    nc.max_z,
    CASE
        WHEN nc.min_z IS NOT NULL AND nc.max_z IS NOT NULL
        THEN (nc.max_z - nc.min_z + 1)::INTEGER
        ELSE NULL
    END AS slice_count,

    -- Metadata for pylidc compatibility
    jsonb_build_object(
        'patient_id', nc.patient_id,
        'nodule_id', nc.nodule_id,
        'radiologist_id', nc.radiologist_id,
        'has_contours', nc.contour_coordinates_json IS NOT NULL,
        'has_bbox', nc.bounding_box_json IS NOT NULL,
        'has_centroid', nc.centroid_json IS NOT NULL,
        'slice_range', ARRAY[nc.min_z, nc.max_z]
    ) AS metadata

FROM nodule_contours nc
WHERE nc.contour_coordinates_json IS NOT NULL
ORDER BY nc.patient_id, nc.nodule_id, nc.radiologist_id;

COMMENT ON VIEW lidc_3d_contours IS '3D contour data per radiologist for visualization and spatial analysis';

-- =============================================================================
-- VIEW: LIDC Contour Slices (per-slice polygon data)
-- =============================================================================

CREATE OR REPLACE VIEW lidc_contour_slices AS
WITH lidc_files AS (
    SELECT
        fi.file_id,
        fi.filename,
        fi.metadata->>'case_label' AS patient_id,
        fi.import_timestamp
    FROM file_imports fi
    WHERE fi.metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}'
),
nodule_contours AS (
    SELECT
        lf.patient_id,
        lf.file_id,
        nodule_elem->>'nodule_id' AS nodule_id,
        nodule_elem->'radiologists' AS radiologists_data,

        -- Extract slice-by-slice contour data if available
        CASE
            WHEN nodule_elem ? 'contour_slices' THEN nodule_elem->'contour_slices'
            WHEN nodule_elem ? 'slices' THEN nodule_elem->'slices'
            ELSE NULL
        END AS slices_data

    FROM lidc_files lf
    JOIN quantitative_segments qs ON lf.file_id = qs.file_id
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE
            WHEN qs.data_structure ? 'nodules' THEN qs.data_structure->'nodules'
            WHEN qs.data_structure ? 'annotations' THEN qs.data_structure->'annotations'
            ELSE '[]'::jsonb
        END
    ) AS nodule_elem
),
slice_expansion AS (
    SELECT
        nc.patient_id,
        nc.nodule_id,
        slice_elem->>'slice_number' AS slice_number,
        (slice_elem->>'z_coordinate')::NUMERIC AS z_coordinate,

        -- Radiologist contours for this slice
        slice_elem->'radiologist_contours' AS radiologist_contours,

        -- Consensus contour (if pre-calculated)
        slice_elem->'consensus_contour' AS consensus_contour,

        -- DICOM image URL (constructed)
        'https://nbia.cancerimagingarchive.net/viewer?patient=' || nc.patient_id ||
        '&slice=' || (slice_elem->>'slice_number') AS dicom_image_url

    FROM nodule_contours nc
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(nc.slices_data, '[]'::jsonb)
    ) AS slice_elem
    WHERE nc.slices_data IS NOT NULL
)
SELECT
    patient_id,
    nodule_id,
    slice_number,
    z_coordinate,

    -- Radiologist contours (array of polygon coordinates per radiologist)
    radiologist_contours,

    -- Consensus contour (averaged/interpolated across radiologists)
    consensus_contour,

    -- DICOM viewer URL for this specific slice
    dicom_image_url,

    -- Metadata
    jsonb_build_object(
        'patient_id', patient_id,
        'nodule_id', nodule_id,
        'slice_number', slice_number,
        'z_coordinate', z_coordinate,
        'has_consensus', consensus_contour IS NOT NULL,
        'radiologist_count', CASE
            WHEN radiologist_contours IS NOT NULL
            THEN jsonb_array_length(radiologist_contours)
            ELSE 0
        END
    ) AS metadata

FROM slice_expansion
ORDER BY patient_id, nodule_id, slice_number;

COMMENT ON VIEW lidc_contour_slices IS 'Per-slice contour data for 3D reconstruction and slice-by-slice visualization';

-- =============================================================================
-- VIEW: Contour Data Availability Summary
-- =============================================================================

CREATE OR REPLACE VIEW lidc_contour_availability AS
SELECT
    patient_id,
    COUNT(DISTINCT nodule_id) AS nodule_count,
    COUNT(DISTINCT radiologist_id) AS radiologist_count,
    COUNT(DISTINCT CASE WHEN contour_coordinates IS NOT NULL THEN nodule_id END) AS nodules_with_contours,
    COUNT(DISTINCT CASE WHEN bounding_box IS NOT NULL THEN nodule_id END) AS nodules_with_bbox,
    COUNT(DISTINCT CASE WHEN centroid IS NOT NULL THEN nodule_id END) AS nodules_with_centroid,
    COUNT(DISTINCT CASE WHEN volume_mm3 IS NOT NULL THEN nodule_id END) AS nodules_with_volume,

    -- Slice range statistics
    MIN(min_z) AS min_z_overall,
    MAX(max_z) AS max_z_overall,
    AVG(slice_count) AS avg_slices_per_nodule,
    MAX(slice_count) AS max_slices_per_nodule,

    -- Volume statistics
    AVG(volume_mm3) AS avg_volume_mm3,
    MIN(volume_mm3) AS min_volume_mm3,
    MAX(volume_mm3) AS max_volume_mm3,

    -- Completeness metrics
    ROUND(
        (COUNT(DISTINCT CASE WHEN contour_coordinates IS NOT NULL THEN nodule_id END)::DECIMAL
        / NULLIF(COUNT(DISTINCT nodule_id), 0)) * 100,
        2
    ) AS contour_completeness_percent

FROM lidc_3d_contours
GROUP BY patient_id
ORDER BY patient_id;

COMMENT ON VIEW lidc_contour_availability IS 'Summary of contour data availability per patient';

-- =============================================================================
-- FUNCTION: Get contour data for specific nodule (JSON export for Python)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_nodule_contour_data(
    p_patient_id TEXT,
    p_nodule_id TEXT
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'patient_id', p_patient_id,
        'nodule_id', p_nodule_id,
        'radiologists', jsonb_agg(
            jsonb_build_object(
                'radiologist_id', radiologist_id,
                'contour_coordinates', contour_coordinates,
                'bounding_box', bounding_box,
                'centroid', centroid,
                'volume_mm3', volume_mm3,
                'diameter_mm', diameter_mm,
                'slice_count', slice_count,
                'min_z', min_z,
                'max_z', max_z
            )
        )
    ) INTO result
    FROM lidc_3d_contours
    WHERE patient_id = p_patient_id
      AND nodule_id = p_nodule_id
    GROUP BY patient_id, nodule_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_nodule_contour_data IS 'Get all contour data for a nodule (all radiologists) as JSON for Python processing';

-- =============================================================================
-- FUNCTION: Get slice data for 3D reconstruction
-- =============================================================================

CREATE OR REPLACE FUNCTION get_nodule_slice_data(
    p_patient_id TEXT,
    p_nodule_id TEXT
)
RETURNS TABLE(
    slice_number TEXT,
    z_coordinate NUMERIC,
    radiologist_contours JSONB,
    consensus_contour JSONB,
    dicom_image_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        lcs.slice_number,
        lcs.z_coordinate,
        lcs.radiologist_contours,
        lcs.consensus_contour,
        lcs.dicom_image_url
    FROM lidc_contour_slices lcs
    WHERE lcs.patient_id = p_patient_id
      AND lcs.nodule_id = p_nodule_id
    ORDER BY lcs.z_coordinate;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_nodule_slice_data IS 'Get slice-by-slice contour data for 3D reconstruction';

-- =============================================================================
-- FUNCTION: Calculate bounding box from contour coordinates
-- =============================================================================

CREATE OR REPLACE FUNCTION calculate_bounding_box_from_contours(contour_coords JSONB)
RETURNS JSONB AS $$
DECLARE
    min_x NUMERIC := 999999;
    max_x NUMERIC := -999999;
    min_y NUMERIC := 999999;
    max_y NUMERIC := -999999;
    min_z NUMERIC := 999999;
    max_z NUMERIC := -999999;
    point JSONB;
    x_val NUMERIC;
    y_val NUMERIC;
    z_val NUMERIC;
BEGIN
    -- If contour_coords is null or empty, return null
    IF contour_coords IS NULL OR jsonb_array_length(contour_coords) = 0 THEN
        RETURN NULL;
    END IF;

    -- Iterate through all points
    FOR point IN SELECT jsonb_array_elements(contour_coords)
    LOOP
        x_val := (point->>'x')::NUMERIC;
        y_val := (point->>'y')::NUMERIC;
        z_val := (point->>'z')::NUMERIC;

        IF x_val < min_x THEN min_x := x_val; END IF;
        IF x_val > max_x THEN max_x := x_val; END IF;
        IF y_val < min_y THEN min_y := y_val; END IF;
        IF y_val > max_y THEN max_y := y_val; END IF;
        IF z_val < min_z THEN min_z := z_val; END IF;
        IF z_val > max_z THEN max_z := z_val; END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'min_x', min_x,
        'max_x', max_x,
        'min_y', min_y,
        'max_y', max_y,
        'min_z', min_z,
        'max_z', max_z,
        'width', max_x - min_x,
        'height', max_y - min_y,
        'depth', max_z - min_z
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_bounding_box_from_contours IS 'Calculate bounding box from contour coordinate array';

-- =============================================================================
-- FUNCTION: Calculate centroid from contour coordinates
-- =============================================================================

CREATE OR REPLACE FUNCTION calculate_centroid_from_contours(contour_coords JSONB)
RETURNS JSONB AS $$
DECLARE
    sum_x NUMERIC := 0;
    sum_y NUMERIC := 0;
    sum_z NUMERIC := 0;
    point_count INTEGER := 0;
    point JSONB;
BEGIN
    -- If contour_coords is null or empty, return null
    IF contour_coords IS NULL OR jsonb_array_length(contour_coords) = 0 THEN
        RETURN NULL;
    END IF;

    -- Sum all coordinates
    FOR point IN SELECT jsonb_array_elements(contour_coords)
    LOOP
        sum_x := sum_x + (point->>'x')::NUMERIC;
        sum_y := sum_y + (point->>'y')::NUMERIC;
        sum_z := sum_z + (point->>'z')::NUMERIC;
        point_count := point_count + 1;
    END LOOP;

    -- Return centroid (average position)
    RETURN jsonb_build_object(
        'x', ROUND(sum_x / point_count, 3),
        'y', ROUND(sum_y / point_count, 3),
        'z', ROUND(sum_z / point_count, 3)
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_centroid_from_contours IS 'Calculate centroid (center point) from contour coordinate array';

-- =============================================================================
-- VIEW: Nodule Spatial Statistics (derived from contours)
-- =============================================================================

CREATE OR REPLACE VIEW lidc_nodule_spatial_stats AS
SELECT
    patient_id,
    nodule_id,
    radiologist_id,

    -- Bounding box dimensions
    (bounding_box->>'width')::NUMERIC AS width_mm,
    (bounding_box->>'height')::NUMERIC AS height_mm,
    (bounding_box->>'depth')::NUMERIC AS depth_mm,

    -- Centroid position
    (centroid->>'x')::NUMERIC AS centroid_x,
    (centroid->>'y')::NUMERIC AS centroid_y,
    (centroid->>'z')::NUMERIC AS centroid_z,

    -- Volume and diameter
    volume_mm3,
    diameter_mm,

    -- Slice extent
    slice_count,
    min_z,
    max_z,

    -- Sphericity estimate (width/height ratio)
    CASE
        WHEN (bounding_box->>'height')::NUMERIC > 0
        THEN ROUND((bounding_box->>'width')::NUMERIC / (bounding_box->>'height')::NUMERIC, 3)
        ELSE NULL
    END AS width_height_ratio,

    -- Aspect ratio (max_dimension / min_dimension)
    CASE
        WHEN LEAST(
            (bounding_box->>'width')::NUMERIC,
            (bounding_box->>'height')::NUMERIC,
            (bounding_box->>'depth')::NUMERIC
        ) > 0
        THEN ROUND(
            GREATEST(
                (bounding_box->>'width')::NUMERIC,
                (bounding_box->>'height')::NUMERIC,
                (bounding_box->>'depth')::NUMERIC
            ) / LEAST(
                (bounding_box->>'width')::NUMERIC,
                (bounding_box->>'height')::NUMERIC,
                (bounding_box->>'depth')::NUMERIC
            ),
            3
        )
        ELSE NULL
    END AS aspect_ratio

FROM lidc_3d_contours
WHERE bounding_box IS NOT NULL
  AND centroid IS NOT NULL
ORDER BY patient_id, nodule_id, radiologist_id;

COMMENT ON VIEW lidc_nodule_spatial_stats IS 'Spatial statistics derived from 3D contour data';

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Index for LIDC patient queries
CREATE INDEX IF NOT EXISTS idx_file_metadata_lidc_patient
ON file_imports USING GIN ((metadata->'case_label'))
WHERE metadata->>'case_label' ~ 'LIDC-IDRI-\d{4}';

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 010: LIDC 3D contour views for spatial visualization installed';
