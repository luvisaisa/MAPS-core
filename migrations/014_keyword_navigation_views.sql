-- =============================================================================
-- Migration 014: Keyword Navigation Views (EXTENSION)
-- =============================================================================
-- Purpose: Create keyword-centered navigation views that link canonical keywords
-- to files, segments, and cases for bidirectional discovery
-- Integrates with Migration 013 (canonical keyword semantics)
-- =============================================================================

-- =============================================================================
-- VIEW: Keyword Directory (canonical keyword catalog)
-- =============================================================================

CREATE OR REPLACE VIEW keyword_directory AS
SELECT
    -- Canonical keyword info
    ck.id AS canonical_keyword_id,
    ck.keyword AS canonical_keyword,
    ck.display_name,
    ck.short_definition,
    ck.subject_category,
    ck.topic_tags,

    -- Citation info (joined)
    c.ama_citation,
    c.url AS citation_url,
    c.citation_key,

    -- Usage statistics (from extracted_keywords)
    COUNT(DISTINCT ek.keyword_id) AS extracted_variant_count,
    SUM(ek.total_frequency) AS total_occurrences,
    SUM(ek.document_frequency) AS total_document_frequency,
    AVG(ek.relevance_score) AS avg_relevance_score,

    -- Occurrence statistics (from keyword_occurrences)
    COUNT(DISTINCT ko.occurrence_id) AS total_occurrence_records,
    COUNT(DISTINCT ko.file_id) AS file_count,
    COUNT(DISTINCT ko.segment_id) AS segment_count,

    -- Case statistics
    COUNT(DISTINCT fi.metadata->>'assigned_case_id') FILTER (
        WHERE fi.metadata->>'assigned_case_id' IS NOT NULL
    ) AS case_count,

    -- Segment type breakdown
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.occurrence_id END) AS qualitative_occurrences,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.occurrence_id END) AS quantitative_occurrences,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'mixed' THEN ko.occurrence_id END) AS mixed_occurrences,

    -- Cross-validation flag
    (COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.occurrence_id END) > 0
     AND COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.occurrence_id END) > 0) AS is_cross_validated,

    -- Status
    ck.is_active,
    ck.created_at,
    ck.updated_at

FROM canonical_keywords ck
LEFT JOIN citations c ON ck.citation_key = c.citation_key
LEFT JOIN extracted_keywords ek ON ek.canonical_keyword_id = ck.id
LEFT JOIN keyword_occurrences ko ON ko.keyword_id = ek.keyword_id
LEFT JOIN file_imports fi ON ko.file_id = fi.file_id
WHERE ck.is_active = TRUE
GROUP BY
    ck.id, ck.keyword, ck.display_name, ck.short_definition,
    ck.subject_category, ck.topic_tags, ck.is_active,
    ck.created_at, ck.updated_at,
    c.ama_citation, c.url, c.citation_key
ORDER BY total_occurrences DESC NULLS LAST, ck.display_name;

CREATE INDEX IF NOT EXISTS idx_keyword_directory_category ON canonical_keywords(subject_category);
CREATE INDEX IF NOT EXISTS idx_keyword_directory_tags ON canonical_keywords USING GIN(topic_tags);

COMMENT ON VIEW keyword_directory IS 'Comprehensive catalog of canonical keywords with usage statistics, citations, and cross-references';

-- =============================================================================
-- VIEW: Keyword Occurrence Map (where keywords appear - segment level)
-- =============================================================================

CREATE OR REPLACE VIEW keyword_occurrence_map AS
SELECT
    -- Canonical keyword info
    ck.id AS canonical_keyword_id,
    ck.keyword AS canonical_keyword,
    ck.display_name AS keyword_display_name,
    ck.subject_category,
    ck.topic_tags,

    -- Extracted keyword variant
    ek.term AS extracted_variant,
    ek.normalized_term AS normalized_variant,

    -- File information
    fi.file_id,
    fi.filename AS file_name,
    fi.extension AS file_type,
    fi.metadata->>'case_label' AS case_id,
    fi.import_timestamp,

    -- Segment information
    ko.segment_id,
    ko.segment_type,

    -- Occurrence details
    ko.occurrence_id,
    ko.surrounding_context AS occurrence_context,
    ko.position_weight,
    ko.associated_values AS numeric_associations,
    ko.occurrence_timestamp AS first_seen_at,

    -- Relevance
    ek.relevance_score

FROM canonical_keywords ck
JOIN extracted_keywords ek ON ek.canonical_keyword_id = ck.id
JOIN keyword_occurrences ko ON ko.keyword_id = ek.keyword_id
JOIN file_imports fi ON ko.file_id = fi.file_id
WHERE ck.is_active = TRUE
ORDER BY ck.display_name, fi.import_timestamp DESC, ko.occurrence_timestamp DESC;

CREATE INDEX IF NOT EXISTS idx_occurrence_map_canonical_id
    ON extracted_keywords(canonical_keyword_id)
    WHERE canonical_keyword_id IS NOT NULL;

COMMENT ON VIEW keyword_occurrence_map IS 'Segment-level occurrences for each canonical keyword (where-used detail view)';

-- =============================================================================
-- VIEW: File Keyword Summary (keywords per file)
-- =============================================================================

CREATE OR REPLACE VIEW file_keyword_summary AS
SELECT
    -- File identification
    fi.file_id,
    fi.filename AS file_name,
    fi.extension AS file_type,
    fi.metadata->>'case_label' AS case_id,
    fi.import_timestamp,
    fi.processing_status,

    -- Keyword aggregations
    COUNT(DISTINCT ck.id) AS distinct_canonical_keyword_count,
    COUNT(DISTINCT ek.keyword_id) AS distinct_extracted_keyword_count,
    COUNT(ko.occurrence_id) AS total_keyword_occurrences,

    -- Arrays of canonical keywords (for display)
    array_agg(DISTINCT ck.display_name ORDER BY ck.display_name) FILTER (WHERE ck.id IS NOT NULL) AS canonical_keywords,

    -- Arrays of subject categories
    array_agg(DISTINCT ck.subject_category ORDER BY ck.subject_category) FILTER (WHERE ck.subject_category IS NOT NULL) AS subject_categories,

    -- Arrays of topic tags (flattened)
    array_agg(DISTINCT unnest_tags.tag ORDER BY unnest_tags.tag) FILTER (WHERE unnest_tags.tag IS NOT NULL) AS topic_tags,

    -- Top keywords by relevance (as JSONB for structure)
    jsonb_agg(
        DISTINCT jsonb_build_object(
            'display_name', ck.display_name,
            'canonical_keyword', ck.keyword,
            'subject_category', ck.subject_category,
            'occurrence_count', COUNT(ko.occurrence_id) OVER (PARTITION BY ck.id, fi.file_id)
        ) ORDER BY COUNT(ko.occurrence_id) OVER (PARTITION BY ck.id, fi.file_id) DESC
    ) FILTER (WHERE ck.id IS NOT NULL) AS top_keywords_detail

FROM file_imports fi
LEFT JOIN keyword_occurrences ko ON ko.file_id = fi.file_id
LEFT JOIN extracted_keywords ek ON ko.keyword_id = ek.keyword_id
LEFT JOIN canonical_keywords ck ON ek.canonical_keyword_id = ck.id AND ck.is_active = TRUE
LEFT JOIN LATERAL unnest(ck.topic_tags) AS unnest_tags(tag) ON TRUE
GROUP BY fi.file_id, fi.filename, fi.extension, fi.metadata, fi.import_timestamp, fi.processing_status
ORDER BY fi.import_timestamp DESC;

COMMENT ON VIEW file_keyword_summary IS 'Per-file keyword summary with canonical keywords, categories, and tags';

-- =============================================================================
-- VIEW: Case Keyword Summary (keywords per case)
-- =============================================================================

CREATE OR REPLACE VIEW case_keyword_summary AS
SELECT
    -- Case identification
    cp.case_id,
    cp.case_label,
    cp.detection_method,
    cp.confidence_score,

    -- Keyword aggregations
    COUNT(DISTINCT ck.id) AS distinct_canonical_keyword_count,
    COUNT(DISTINCT ek.keyword_id) AS distinct_extracted_keyword_count,
    COUNT(DISTINCT ko.occurrence_id) AS total_keyword_occurrences,

    -- Arrays of canonical keywords
    array_agg(DISTINCT ck.display_name ORDER BY ck.display_name) FILTER (WHERE ck.id IS NOT NULL) AS canonical_keywords,

    -- Arrays of subject categories
    array_agg(DISTINCT ck.subject_category ORDER BY ck.subject_category) FILTER (WHERE ck.subject_category IS NOT NULL) AS subject_categories,

    -- Arrays of topic tags
    array_agg(DISTINCT unnest_tags.tag ORDER BY unnest_tags.tag) FILTER (WHERE unnest_tags.tag IS NOT NULL) AS topic_tags,

    -- High-value keywords (by relevance and frequency)
    jsonb_agg(
        DISTINCT jsonb_build_object(
            'display_name', ck.display_name,
            'canonical_keyword', ck.keyword,
            'subject_category', ck.subject_category,
            'topic_tags', ck.topic_tags,
            'occurrence_count', COUNT(ko.occurrence_id) OVER (PARTITION BY ck.id, cp.case_id),
            'avg_relevance', AVG(ek.relevance_score) OVER (PARTITION BY ck.id, cp.case_id)
        ) ORDER BY
            COUNT(ko.occurrence_id) OVER (PARTITION BY ck.id, cp.case_id) DESC,
            AVG(ek.relevance_score) OVER (PARTITION BY ck.id, cp.case_id) DESC
    ) FILTER (WHERE ck.id IS NOT NULL) AS high_value_keywords,

    -- Case metadata
    cp.file_count,
    cp.segment_count,
    cp.detected_timestamp,
    cp.last_updated_timestamp

FROM case_patterns cp
LEFT JOIN file_imports fi ON fi.metadata->>'case_label' = cp.case_label
LEFT JOIN keyword_occurrences ko ON ko.file_id = fi.file_id
LEFT JOIN extracted_keywords ek ON ko.keyword_id = ek.keyword_id
LEFT JOIN canonical_keywords ck ON ek.canonical_keyword_id = ck.id AND ck.is_active = TRUE
LEFT JOIN LATERAL unnest(ck.topic_tags) AS unnest_tags(tag) ON TRUE
GROUP BY
    cp.case_id, cp.case_label, cp.detection_method, cp.confidence_score,
    cp.file_count, cp.segment_count, cp.detected_timestamp, cp.last_updated_timestamp
ORDER BY cp.confidence_score DESC, total_keyword_occurrences DESC;

COMMENT ON VIEW case_keyword_summary IS 'Per-case keyword summary with canonical keywords and high-value terms';

-- =============================================================================
-- VIEW: Keyword Subject Category Summary (rollup by category)
-- =============================================================================

CREATE OR REPLACE VIEW keyword_subject_category_summary AS
SELECT
    subject_category,
    COUNT(DISTINCT id) AS keyword_count,
    array_agg(DISTINCT display_name ORDER BY display_name) AS keywords_in_category,

    -- Usage statistics
    SUM((
        SELECT COUNT(DISTINCT ko.occurrence_id)
        FROM extracted_keywords ek
        JOIN keyword_occurrences ko ON ko.keyword_id = ek.keyword_id
        WHERE ek.canonical_keyword_id = ck.id
    )) AS total_occurrences_in_category,

    -- Example keywords (top 5 by occurrence)
    (
        SELECT jsonb_agg(
            jsonb_build_object(
                'display_name', display_name,
                'keyword', keyword,
                'occurrence_count', occurrence_count
            ) ORDER BY occurrence_count DESC
        )
        FROM (
            SELECT
                ck2.display_name,
                ck2.keyword,
                (
                    SELECT COUNT(DISTINCT ko.occurrence_id)
                    FROM extracted_keywords ek
                    JOIN keyword_occurrences ko ON ko.keyword_id = ek.keyword_id
                    WHERE ek.canonical_keyword_id = ck2.id
                ) AS occurrence_count
            FROM canonical_keywords ck2
            WHERE ck2.subject_category = ck.subject_category
              AND ck2.is_active = TRUE
            ORDER BY occurrence_count DESC
            LIMIT 5
        ) top_keywords
    ) AS top_keywords_in_category

FROM canonical_keywords ck
WHERE is_active = TRUE
  AND subject_category IS NOT NULL
GROUP BY subject_category
ORDER BY total_occurrences_in_category DESC NULLS LAST, keyword_count DESC;

COMMENT ON VIEW keyword_subject_category_summary IS 'Summary of keywords grouped by subject category';

-- =============================================================================
-- VIEW: Keyword Topic Tag Summary (rollup by tag)
-- =============================================================================

CREATE OR REPLACE VIEW keyword_topic_tag_summary AS
SELECT
    unnest_tags.tag AS topic_tag,
    COUNT(DISTINCT ck.id) AS keyword_count,
    array_agg(DISTINCT ck.display_name ORDER BY ck.display_name) AS keywords_with_tag,

    -- Subject categories using this tag
    array_agg(DISTINCT ck.subject_category ORDER BY ck.subject_category) FILTER (WHERE ck.subject_category IS NOT NULL) AS subject_categories,

    -- Usage statistics
    SUM((
        SELECT COUNT(DISTINCT ko.occurrence_id)
        FROM extracted_keywords ek
        JOIN keyword_occurrences ko ON ko.keyword_id = ek.keyword_id
        WHERE ek.canonical_keyword_id = ck.id
    )) AS total_occurrences_with_tag

FROM canonical_keywords ck
CROSS JOIN LATERAL unnest(ck.topic_tags) AS unnest_tags(tag)
WHERE ck.is_active = TRUE
GROUP BY unnest_tags.tag
ORDER BY total_occurrences_with_tag DESC NULLS LAST, keyword_count DESC;

COMMENT ON VIEW keyword_topic_tag_summary IS 'Summary of keywords grouped by topic tag';

-- =============================================================================
-- FUNCTION: Get all occurrences for a canonical keyword
-- =============================================================================

CREATE OR REPLACE FUNCTION get_canonical_keyword_occurrences(p_canonical_keyword TEXT)
RETURNS TABLE(
    occurrence_id UUID,
    file_name TEXT,
    case_id TEXT,
    segment_type segment_type_enum,
    occurrence_context TEXT,
    extracted_variant TEXT,
    relevance_score DECIMAL,
    occurrence_timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        kom.occurrence_id,
        kom.file_name,
        kom.case_id,
        kom.segment_type,
        kom.occurrence_context,
        kom.extracted_variant,
        kom.relevance_score,
        kom.first_seen_at AS occurrence_timestamp
    FROM keyword_occurrence_map kom
    WHERE kom.canonical_keyword = p_canonical_keyword
    ORDER BY kom.first_seen_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_canonical_keyword_occurrences IS 'Get all occurrences for a canonical keyword (for drill-down from keyword directory)';

-- =============================================================================
-- FUNCTION: Get canonical keywords for a file
-- =============================================================================

CREATE OR REPLACE FUNCTION get_file_canonical_keywords(p_file_id UUID)
RETURNS TABLE(
    canonical_keyword_id UUID,
    display_name TEXT,
    canonical_keyword TEXT,
    subject_category TEXT,
    topic_tags TEXT[],
    occurrence_count BIGINT,
    avg_relevance DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ck.id AS canonical_keyword_id,
        ck.display_name,
        ck.keyword AS canonical_keyword,
        ck.subject_category,
        ck.topic_tags,
        COUNT(ko.occurrence_id) AS occurrence_count,
        AVG(ek.relevance_score) AS avg_relevance
    FROM canonical_keywords ck
    JOIN extracted_keywords ek ON ek.canonical_keyword_id = ck.id
    JOIN keyword_occurrences ko ON ko.keyword_id = ek.keyword_id
    WHERE ko.file_id = p_file_id
      AND ck.is_active = TRUE
    GROUP BY ck.id, ck.display_name, ck.keyword, ck.subject_category, ck.topic_tags
    ORDER BY occurrence_count DESC, avg_relevance DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_file_canonical_keywords IS 'Get all canonical keywords for a specific file with occurrence counts';

-- =============================================================================
-- FUNCTION: Search canonical keywords by topic tag
-- =============================================================================

CREATE OR REPLACE FUNCTION search_keywords_by_tag(p_tag TEXT)
RETURNS TABLE(
    canonical_keyword_id UUID,
    display_name TEXT,
    canonical_keyword TEXT,
    subject_category TEXT,
    short_definition TEXT,
    occurrence_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        kd.canonical_keyword_id,
        kd.display_name,
        kd.canonical_keyword,
        kd.subject_category,
        kd.short_definition,
        kd.total_occurrences AS occurrence_count
    FROM keyword_directory kd
    WHERE p_tag = ANY(kd.topic_tags)
    ORDER BY kd.total_occurrences DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search_keywords_by_tag IS 'Search canonical keywords by topic tag (e.g., "LIDC", "Radiomics", "NLP")';

-- =============================================================================
-- GRANT PUBLIC ACCESS TO KEYWORD NAVIGATION VIEWS
-- =============================================================================

-- Grant SELECT to anonymous users for keyword navigation
GRANT SELECT ON keyword_directory TO anon;
GRANT SELECT ON keyword_occurrence_map TO anon;
GRANT SELECT ON file_keyword_summary TO anon;
GRANT SELECT ON case_keyword_summary TO anon;
GRANT SELECT ON keyword_subject_category_summary TO anon;
GRANT SELECT ON keyword_topic_tag_summary TO anon;

-- Grant EXECUTE on helper functions
GRANT EXECUTE ON FUNCTION get_canonical_keyword_occurrences(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_file_canonical_keywords(UUID) TO anon;
GRANT EXECUTE ON FUNCTION search_keywords_by_tag(TEXT) TO anon;

-- Also grant to authenticated users
GRANT SELECT ON keyword_directory TO authenticated;
GRANT SELECT ON keyword_occurrence_map TO authenticated;
GRANT SELECT ON file_keyword_summary TO authenticated;
GRANT SELECT ON case_keyword_summary TO authenticated;
GRANT SELECT ON keyword_subject_category_summary TO authenticated;
GRANT SELECT ON keyword_topic_tag_summary TO authenticated;

GRANT EXECUTE ON FUNCTION get_canonical_keyword_occurrences(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_file_canonical_keywords(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION search_keywords_by_tag(TEXT) TO authenticated;

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 014: Keyword navigation views for bidirectional discovery installed';
