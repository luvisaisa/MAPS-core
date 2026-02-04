-- =============================================================================
-- Migration 008: Universal Views for All Import Types
-- =============================================================================
-- Purpose: Create views that work across all data sources (XML, PDF, LIDC, JSON)
-- Schema-agnostic queries for files, segments, cases, and validation
-- =============================================================================

-- =============================================================================
-- VIEW: File Summary (one row per file)
-- =============================================================================

CREATE OR REPLACE VIEW file_summary AS
SELECT
    -- File identification
    fi.file_id,
    fi.filename,
    fi.extension AS file_type,
    fi.file_size_bytes,
    fi.import_timestamp,
    fi.processing_status,
    fi.metadata,

    -- Segment counts by type
    COUNT(DISTINCT CASE WHEN us.segment_type = 'qualitative' THEN us.segment_id END) AS qualitative_segment_count,
    COUNT(DISTINCT CASE WHEN us.segment_type = 'quantitative' THEN us.segment_id END) AS quantitative_segment_count,
    COUNT(DISTINCT CASE WHEN us.segment_type = 'mixed' THEN us.segment_id END) AS mixed_segment_count,
    COUNT(DISTINCT us.segment_id) AS total_segment_count,

    -- Keyword statistics
    COUNT(DISTINCT ko.keyword_id) AS unique_keyword_count,
    COUNT(ko.occurrence_id) AS total_keyword_occurrences,
    MAX(k.relevance_score) AS max_keyword_relevance,

    -- Case assignment
    fi.metadata->>'assigned_case_id' AS assigned_case_id,
    fi.metadata->>'case_label' AS case_label,
    (fi.metadata->>'case_confidence')::DECIMAL AS case_confidence,

    -- Processing metadata
    fi.metadata->>'detected_case_id' AS detected_case_id,
    fi.metadata->>'case_detection_method' AS detection_method,
    (fi.metadata->>'case_detection_timestamp')::TIMESTAMPTZ AS detection_timestamp,

    -- Quality indicators
    CASE
        WHEN COUNT(DISTINCT us.segment_id) = 0 THEN 'no_segments'
        WHEN fi.metadata->>'assigned_case_id' IS NULL THEN 'no_case_assigned'
        WHEN fi.processing_status = 'failed' THEN 'processing_failed'
        WHEN fi.processing_status = 'complete' THEN 'complete'
        ELSE fi.processing_status
    END AS quality_status

FROM file_imports fi
LEFT JOIN unified_segments us ON fi.file_id = us.file_id
LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
GROUP BY
    fi.file_id, fi.filename, fi.extension, fi.file_size_bytes,
    fi.import_timestamp, fi.processing_status, fi.metadata
ORDER BY fi.import_timestamp DESC;

COMMENT ON VIEW file_summary IS 'One row per file with aggregated segment, keyword, and case statistics';

-- =============================================================================
-- VIEW: Segment Statistics (one row per segment)
-- =============================================================================

CREATE OR REPLACE VIEW segment_statistics AS
SELECT
    -- Segment identification
    us.segment_id,
    us.segment_type,
    us.file_id,
    fi.filename,
    fi.extension AS file_type,

    -- Segment content metrics
    CASE
        WHEN us.segment_type = 'qualitative' THEN
            (SELECT word_count FROM qualitative_segments WHERE segment_id = us.segment_id)
        ELSE NULL
    END AS word_count,

    CASE
        WHEN us.segment_type = 'quantitative' THEN
            (SELECT row_count FROM quantitative_segments WHERE segment_id = us.segment_id)
        ELSE NULL
    END AS numeric_row_count,

    CASE
        WHEN us.segment_type = 'quantitative' THEN
            (SELECT numeric_density FROM quantitative_segments WHERE segment_id = us.segment_id)
        WHEN us.segment_type = 'mixed' THEN
            (SELECT quantitative_ratio FROM mixed_segments WHERE segment_id = us.segment_id)
        ELSE NULL
    END AS numeric_density,

    -- Keyword statistics
    COUNT(DISTINCT ko.keyword_id) AS keyword_count,
    COUNT(ko.occurrence_id) AS keyword_occurrence_count,
    AVG(k.relevance_score) AS avg_keyword_relevance,
    MAX(k.relevance_score) AS max_keyword_relevance,

    -- Numeric associations
    COUNT(CASE WHEN ko.associated_values IS NOT NULL THEN 1 END) AS numeric_association_count,

    -- Content completeness
    CASE
        WHEN us.segment_type = 'qualitative' THEN
            CASE
                WHEN (SELECT word_count FROM qualitative_segments WHERE segment_id = us.segment_id) > 0
                THEN 1.0
                ELSE 0.0
            END
        WHEN us.segment_type = 'quantitative' THEN
            (SELECT COALESCE(numeric_density, 0) FROM quantitative_segments WHERE segment_id = us.segment_id)
        WHEN us.segment_type = 'mixed' THEN
            (SELECT COALESCE(quantitative_ratio, 0) FROM mixed_segments WHERE segment_id = us.segment_id)
    END AS completeness_ratio,

    -- Position and timing
    us.position_in_file,
    us.extraction_timestamp,

    -- Case assignment
    fi.metadata->>'assigned_case_id' AS case_id

FROM unified_segments us
JOIN file_imports fi ON us.file_id = fi.file_id
LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
GROUP BY
    us.segment_id, us.segment_type, us.file_id, fi.filename, fi.extension,
    us.position_in_file, us.extraction_timestamp, fi.metadata
ORDER BY us.extraction_timestamp DESC;

COMMENT ON VIEW segment_statistics IS 'Per-segment metrics: word count, numeric density, keywords, completeness';

-- =============================================================================
-- VIEW: Numeric Data Flat (auto-extract all numeric fields)
-- =============================================================================

CREATE OR REPLACE VIEW numeric_data_flat AS
WITH numeric_extracts AS (
    SELECT
        qs.segment_id,
        qs.file_id,
        fi.filename,
        fi.metadata->>'assigned_case_id' AS case_id,

        -- Extract all key-value pairs from data_structure
        key_value.key AS field_name,
        key_value.value AS field_value,

        -- Try to extract numeric value
        CASE
            WHEN jsonb_typeof(key_value.value) = 'number' THEN
                (key_value.value::TEXT)::NUMERIC
            WHEN jsonb_typeof(key_value.value) = 'string' AND key_value.value::TEXT ~ '^\d+\.?\d*$' THEN
                (key_value.value::TEXT)::NUMERIC
            ELSE NULL
        END AS numeric_value,

        -- Array handling for multi-radiologist data
        CASE
            WHEN jsonb_typeof(key_value.value) = 'array' THEN
                jsonb_array_length(key_value.value)
            ELSE NULL
        END AS array_length,

        qs.extraction_timestamp

    FROM quantitative_segments qs
    JOIN file_imports fi ON qs.file_id = fi.file_id
    CROSS JOIN LATERAL jsonb_each(qs.data_structure) AS key_value

    WHERE key_value.key NOT IN ('metadata', 'position_in_file', 'extraction_timestamp')
)
SELECT
    segment_id,
    file_id,
    filename,
    case_id,
    field_name,
    field_value,
    numeric_value,
    array_length,
    extraction_timestamp,

    -- Aggregated statistics per field
    COUNT(*) OVER (PARTITION BY field_name) AS field_occurrence_count,
    AVG(numeric_value) OVER (PARTITION BY field_name) AS field_avg_value,
    MIN(numeric_value) OVER (PARTITION BY field_name) AS field_min_value,
    MAX(numeric_value) OVER (PARTITION BY field_name) AS field_max_value

FROM numeric_extracts
ORDER BY filename, field_name;

COMMENT ON VIEW numeric_data_flat IS 'Flattened numeric fields from quantitative segments with statistics';

-- =============================================================================
-- VIEW: Cases with Evidence (established cases with linked data)
-- =============================================================================

CREATE OR REPLACE VIEW cases_with_evidence AS
SELECT
    -- Case identification
    cp.case_id,
    cp.case_label,
    cp.pattern_signature,
    cp.detection_method,
    cp.confidence_score,
    cp.cross_type_validated,

    -- Case statistics
    cp.keyword_count,
    cp.segment_count,
    cp.file_count,

    -- Keywords (top 10 by relevance)
    (
        SELECT jsonb_agg(kw ORDER BY (kw->>'relevance')::DECIMAL DESC)
        FROM (
            SELECT jsonb_array_elements(cp.keywords) AS kw
            LIMIT 10
        ) top_keywords
    ) AS top_keywords,

    -- Source files
    (
        SELECT jsonb_agg(DISTINCT jsonb_build_object(
            'file_id', fi.file_id,
            'filename', fi.filename,
            'import_timestamp', fi.import_timestamp
        ) ORDER BY fi.import_timestamp DESC)
        FROM file_imports fi
        WHERE fi.metadata->>'assigned_case_id' = 'CASE-' || cp.case_label
           OR fi.metadata->>'case_label' = cp.case_label
    ) AS source_files,

    -- Segment breakdown
    COUNT(DISTINCT CASE WHEN seg->>'segment_type' = 'qualitative' THEN seg->>'segment_id' END) AS qualitative_segments,
    COUNT(DISTINCT CASE WHEN seg->>'segment_type' = 'quantitative' THEN seg->>'segment_id' END) AS quantitative_segments,
    COUNT(DISTINCT CASE WHEN seg->>'segment_type' = 'mixed' THEN seg->>'segment_id' END) AS mixed_segments,

    -- Version history
    cp.version_history,
    array_length(cp.version_history::jsonb, 1) AS version_count,

    -- Timestamps
    cp.detected_timestamp,
    cp.last_updated_timestamp

FROM case_patterns cp
CROSS JOIN LATERAL jsonb_array_elements(cp.source_segments) AS seg
GROUP BY
    cp.case_id, cp.case_label, cp.pattern_signature, cp.detection_method,
    cp.confidence_score, cp.cross_type_validated, cp.keyword_count,
    cp.segment_count, cp.file_count, cp.keywords, cp.version_history,
    cp.detected_timestamp, cp.last_updated_timestamp
ORDER BY cp.confidence_score DESC, cp.last_updated_timestamp DESC;

COMMENT ON VIEW cases_with_evidence IS 'Established cases with all supporting evidence and metadata';

-- =============================================================================
-- VIEW: Unresolved Segments (no case assignment)
-- =============================================================================

CREATE OR REPLACE VIEW unresolved_segments AS
SELECT
    -- Segment info
    us.segment_id,
    us.segment_type,
    us.file_id,
    fi.filename,
    fi.extension AS file_type,

    -- Content preview
    CASE
        WHEN us.segment_type = 'qualitative' THEN
            LEFT((us.content->>'text_content')::TEXT, 200)
        WHEN us.segment_type = 'quantitative' THEN
            LEFT((us.content)::TEXT, 200)
        WHEN us.segment_type = 'mixed' THEN
            LEFT((us.content->>'text_elements')::TEXT, 200)
    END AS content_preview,

    -- Keywords extracted
    COUNT(DISTINCT ko.keyword_id) AS keyword_count,
    jsonb_agg(DISTINCT jsonb_build_object(
        'term', k.term,
        'relevance', k.relevance_score
    )) FILTER (WHERE k.keyword_id IS NOT NULL) AS keywords,

    -- Pending assignment info
    pca.confidence_score AS suggested_confidence,
    pca.suggested_case_id,
    pca.detection_method AS suggested_detection_method,
    pca.review_status,

    -- Timestamps
    us.extraction_timestamp,
    fi.import_timestamp,

    -- Priority score (for manual review queue)
    CASE
        WHEN pca.confidence_score IS NOT NULL THEN pca.confidence_score
        WHEN COUNT(DISTINCT ko.keyword_id) > 5 THEN 0.6
        WHEN COUNT(DISTINCT ko.keyword_id) > 2 THEN 0.4
        ELSE 0.2
    END AS review_priority

FROM unified_segments us
JOIN file_imports fi ON us.file_id = fi.file_id
LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
LEFT JOIN pending_case_assignment pca ON us.segment_id = pca.segment_id
WHERE
    fi.metadata->>'assigned_case_id' IS NULL  -- No case assigned to file
    OR pca.review_status = 'pending'  -- Explicitly pending review
GROUP BY
    us.segment_id, us.segment_type, us.file_id, fi.filename, fi.extension,
    us.content, us.extraction_timestamp, fi.import_timestamp,
    pca.confidence_score, pca.suggested_case_id, pca.detection_method, pca.review_status
ORDER BY review_priority DESC, fi.import_timestamp DESC;

COMMENT ON VIEW unresolved_segments IS 'Segments without case assignment, prioritized for manual review';

-- =============================================================================
-- VIEW: Case Identifier Validation (completeness metrics)
-- =============================================================================

CREATE OR REPLACE VIEW case_identifier_validation AS
SELECT
    -- File-level aggregation
    fi.file_id,
    fi.filename,
    fi.extension AS file_type,
    fi.import_timestamp,
    fi.processing_status,

    -- Case assignment status
    fi.metadata->>'assigned_case_id' AS assigned_case_id,
    fi.metadata->>'case_label' AS case_label,
    (fi.metadata->>'case_confidence')::DECIMAL AS case_confidence,
    fi.metadata->>'case_detection_method' AS detection_method,

    -- Segment coverage
    COUNT(DISTINCT us.segment_id) AS total_segments,
    COUNT(DISTINCT CASE
        WHEN fi.metadata->>'assigned_case_id' IS NOT NULL THEN us.segment_id
    END) AS segments_with_case,
    COUNT(DISTINCT CASE
        WHEN fi.metadata->>'assigned_case_id' IS NULL THEN us.segment_id
    END) AS segments_without_case,

    -- Completeness percentage
    CASE
        WHEN COUNT(DISTINCT us.segment_id) = 0 THEN 0.0
        ELSE ROUND(
            (COUNT(DISTINCT CASE WHEN fi.metadata->>'assigned_case_id' IS NOT NULL THEN us.segment_id END)::DECIMAL
            / COUNT(DISTINCT us.segment_id)::DECIMAL) * 100,
            2
        )
    END AS case_completeness_percent,

    -- Pending review count
    COUNT(DISTINCT pca.pending_id) AS pending_review_count,

    -- Quality flags
    CASE
        WHEN fi.metadata->>'assigned_case_id' IS NULL THEN 'NO_CASE_ASSIGNED'
        WHEN COUNT(DISTINCT pca.pending_id) > 0 THEN 'PENDING_REVIEW'
        WHEN COUNT(DISTINCT us.segment_id) = COUNT(DISTINCT CASE WHEN fi.metadata->>'assigned_case_id' IS NOT NULL THEN us.segment_id END)
            THEN 'COMPLETE'
        ELSE 'PARTIAL_ASSIGNMENT'
    END AS validation_status,

    -- Recommendations
    CASE
        WHEN fi.metadata->>'assigned_case_id' IS NULL AND COUNT(DISTINCT us.segment_id) > 0
            THEN 'Run case detection: SELECT process_case_assignment(''' || fi.file_id || '''::UUID)'
        WHEN COUNT(DISTINCT pca.pending_id) > 0
            THEN 'Review pending assignments for this file'
        WHEN COUNT(DISTINCT us.segment_id) = 0
            THEN 'No segments found - check parsing'
        ELSE 'Case assignment complete'
    END AS recommendation

FROM file_imports fi
LEFT JOIN unified_segments us ON fi.file_id = us.file_id
LEFT JOIN pending_case_assignment pca ON us.segment_id = pca.segment_id AND pca.review_status = 'pending'
GROUP BY
    fi.file_id, fi.filename, fi.extension, fi.import_timestamp,
    fi.processing_status, fi.metadata
ORDER BY
    CASE
        WHEN fi.metadata->>'assigned_case_id' IS NULL THEN 1
        WHEN COUNT(DISTINCT pca.pending_id) > 0 THEN 2
        ELSE 3
    END,
    fi.import_timestamp DESC;

COMMENT ON VIEW case_identifier_validation IS 'Validation metrics for case assignment completeness per file';

-- =============================================================================
-- HELPER VIEW: Cross-Type Keyword Evidence
-- =============================================================================

CREATE OR REPLACE VIEW cross_type_keyword_evidence AS
SELECT
    k.keyword_id,
    k.term,
    k.normalized_term,
    k.relevance_score,

    -- Occurrence counts by type
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.segment_id END) AS qualitative_occurrences,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.segment_id END) AS quantitative_occurrences,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'mixed' THEN ko.segment_id END) AS mixed_occurrences,

    -- Cross-validation flag
    (COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.segment_id END) > 0
     AND COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.segment_id END) > 0) AS is_cross_validated,

    -- File and case distribution
    COUNT(DISTINCT ko.file_id) AS file_count,
    COUNT(DISTINCT fi.metadata->>'assigned_case_id') FILTER (WHERE fi.metadata->>'assigned_case_id' IS NOT NULL) AS case_count,

    -- Numeric associations
    COUNT(ko.occurrence_id) FILTER (WHERE ko.associated_values IS NOT NULL) AS numeric_association_count,

    -- Example contexts (first 3)
    (
        SELECT jsonb_agg(jsonb_build_object(
            'segment_type', ko2.segment_type,
            'context', LEFT(ko2.surrounding_context, 100),
            'filename', fi2.filename
        ) ORDER BY ko2.occurrence_timestamp DESC)
        FROM keyword_occurrences ko2
        JOIN file_imports fi2 ON ko2.file_id = fi2.file_id
        WHERE ko2.keyword_id = k.keyword_id
        LIMIT 3
    ) AS example_contexts

FROM extracted_keywords k
JOIN keyword_occurrences ko ON k.keyword_id = ko.keyword_id
JOIN file_imports fi ON ko.file_id = fi.file_id
GROUP BY k.keyword_id, k.term, k.normalized_term, k.relevance_score
HAVING COUNT(DISTINCT ko.segment_type) > 1  -- Only keywords appearing in multiple types
ORDER BY k.relevance_score DESC, file_count DESC;

COMMENT ON VIEW cross_type_keyword_evidence IS 'Keywords appearing across multiple segment types (high signal for case detection)';

-- =============================================================================
-- INDEXES FOR VIEW PERFORMANCE
-- =============================================================================

-- Index for case assignment lookups on file metadata
CREATE INDEX IF NOT EXISTS idx_file_metadata_case_id ON file_imports USING GIN ((metadata->'assigned_case_id'));
CREATE INDEX IF NOT EXISTS idx_file_metadata_case_label ON file_imports USING GIN ((metadata->'case_label'));

-- Index for pending case assignment queries
CREATE INDEX IF NOT EXISTS idx_pending_review_status_created ON pending_case_assignment(review_status, created_at DESC);

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 008: Universal views for all import types installed';
