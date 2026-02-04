-- =============================================================================
-- Analysis and Export Views for Easy Data Collection
-- Run this in Supabase SQL Editor to add comprehensive analysis capabilities
-- =============================================================================

-- View: Master analysis table - comprehensive flattened view for easy filtering and export
CREATE OR REPLACE VIEW master_analysis_table AS
SELECT 
    -- File information
    fi.file_id,
    fi.filename,
    fi.extension AS file_type,
    fi.file_size_bytes,
    fi.import_timestamp,
    fi.processing_status,
    fi.metadata AS file_metadata,
    
    -- Segment information
    us.segment_type,
    us.segment_id,
    us.extraction_timestamp AS segment_timestamp,
    us.position_in_file,
    
    -- Content preview
    CASE 
        WHEN us.segment_type = 'qualitative' THEN LEFT((us.content->>'text_content')::TEXT, 200)
        WHEN us.segment_type = 'quantitative' THEN (us.content->>'data_structure')::TEXT
        WHEN us.segment_type = 'mixed' THEN LEFT((us.content->>'text_elements')::TEXT, 200)
    END AS content_preview,
    
    -- Keyword aggregations
    COUNT(DISTINCT ko.keyword_id) AS keyword_count,
    jsonb_agg(DISTINCT jsonb_build_object(
        'term', k.term,
        'relevance', k.relevance_score,
        'occurrences', k.total_frequency
    )) FILTER (WHERE k.keyword_id IS NOT NULL) AS keywords,
    
    -- Numeric data indicators
    CASE 
        WHEN us.segment_type = 'quantitative' THEN TRUE
        WHEN us.segment_type = 'mixed' THEN TRUE
        ELSE FALSE
    END AS has_numeric_data,
    
    -- Text data indicators
    CASE 
        WHEN us.segment_type = 'qualitative' THEN TRUE
        WHEN us.segment_type = 'mixed' THEN TRUE
        ELSE FALSE
    END AS has_text_data,
    
    -- Associated case patterns
    COUNT(DISTINCT cp.case_id) FILTER (WHERE cp.case_id IS NOT NULL) AS case_pattern_count,
    jsonb_agg(DISTINCT jsonb_build_object(
        'case_id', cp.case_id,
        'confidence', cp.confidence_score,
        'cross_validated', cp.cross_type_validated
    )) FILTER (WHERE cp.case_id IS NOT NULL) AS associated_cases

FROM file_imports fi
LEFT JOIN unified_segments us ON fi.file_id = us.file_id
LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
LEFT JOIN case_patterns cp ON (cp.source_segments @> jsonb_build_array(jsonb_build_object('segment_id', us.segment_id::TEXT)))
GROUP BY 
    fi.file_id, fi.filename, fi.extension, fi.file_size_bytes, 
    fi.import_timestamp, fi.processing_status, fi.metadata,
    us.segment_type, us.segment_id, us.extraction_timestamp, 
    us.position_in_file, us.content
ORDER BY fi.import_timestamp DESC, us.extraction_timestamp DESC;

COMMENT ON VIEW master_analysis_table IS 'Comprehensive flattened view for filtering, analysis, and export - one row per segment with aggregated metadata';

-- Materialized view: Fast export table (refresh periodically for performance)
DROP MATERIALIZED VIEW IF EXISTS export_ready_table CASCADE;
CREATE MATERIALIZED VIEW export_ready_table AS
SELECT 
    -- Core identifiers
    fi.file_id,
    fi.filename,
    fi.extension AS file_type,
    TO_CHAR(fi.import_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS import_date,
    fi.processing_status,
    
    -- Content classification
    us.segment_type,
    us.segment_id,
    
    -- Text content (qualitative)
    CASE 
        WHEN us.segment_type = 'qualitative' THEN (us.content->>'text_content')::TEXT
        WHEN us.segment_type = 'mixed' THEN (us.content->'text_elements')::TEXT
        ELSE NULL
    END AS text_content,
    
    -- Numeric content (quantitative)
    CASE 
        WHEN us.segment_type = 'quantitative' THEN us.content
        WHEN us.segment_type = 'mixed' THEN us.content->'numeric_elements'
        ELSE NULL
    END AS numeric_content,
    
    -- Keywords (comma-separated for Excel)
    STRING_AGG(DISTINCT k.term, ', ' ORDER BY k.term) AS keywords_list,
    
    -- Keyword count
    COUNT(DISTINCT k.keyword_id) AS keyword_count,
    
    -- Top relevance score
    MAX(k.relevance_score) AS max_relevance_score,
    
    -- Has numeric associations
    BOOL_OR(ko.associated_values IS NOT NULL) AS has_numeric_associations,
    
    -- Case pattern membership
    COUNT(DISTINCT cp.case_id) AS case_pattern_count,
    
    -- Source file metadata (JSON flattened to key=value pairs)
    STRING_AGG(DISTINCT 
        jsonb_each.key || '=' || jsonb_each.value::TEXT, 
        '; ' 
    ) AS metadata_flat

FROM file_imports fi
LEFT JOIN unified_segments us ON fi.file_id = us.file_id
LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
LEFT JOIN case_patterns cp ON (cp.source_segments @> jsonb_build_array(jsonb_build_object('segment_id', us.segment_id::TEXT)))
LEFT JOIN LATERAL jsonb_each(fi.metadata) AS jsonb_each ON TRUE
GROUP BY 
    fi.file_id, fi.filename, fi.extension, fi.import_timestamp, 
    fi.processing_status, us.segment_type, us.segment_id, us.content
ORDER BY fi.import_timestamp DESC;

COMMENT ON MATERIALIZED VIEW export_ready_table IS 'Pre-computed export format - refresh with: REFRESH MATERIALIZED VIEW export_ready_table';

-- Index on materialized view for fast filtering
CREATE INDEX idx_export_file_id ON export_ready_table(file_id);
CREATE INDEX idx_export_segment_type ON export_ready_table(segment_type);
CREATE INDEX idx_export_import_date ON export_ready_table(import_date);
CREATE INDEX idx_export_processing_status ON export_ready_table(processing_status);

-- Function: Filter master table by criteria (for exports)
CREATE OR REPLACE FUNCTION filter_analysis_table(
    p_file_types TEXT[] DEFAULT NULL,
    p_segment_types segment_type_enum[] DEFAULT NULL,
    p_min_keyword_count INTEGER DEFAULT 0,
    p_has_case_patterns BOOLEAN DEFAULT NULL,
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL,
    p_keyword_search TEXT DEFAULT NULL
)
RETURNS TABLE (
    file_id UUID,
    filename TEXT,
    file_type TEXT,
    segment_type segment_type_enum,
    segment_id UUID,
    content_preview TEXT,
    keyword_count BIGINT,
    keywords JSONB,
    case_pattern_count BIGINT,
    import_timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mat.file_id,
        mat.filename,
        mat.file_type,
        mat.segment_type,
        mat.segment_id,
        mat.content_preview,
        mat.keyword_count,
        mat.keywords,
        mat.case_pattern_count,
        mat.import_timestamp
    FROM master_analysis_table mat
    WHERE 
        (p_file_types IS NULL OR mat.file_type = ANY(p_file_types))
        AND (p_segment_types IS NULL OR mat.segment_type = ANY(p_segment_types))
        AND mat.keyword_count >= p_min_keyword_count
        AND (p_has_case_patterns IS NULL OR (mat.case_pattern_count > 0) = p_has_case_patterns)
        AND (p_date_from IS NULL OR mat.import_timestamp >= p_date_from)
        AND (p_date_to IS NULL OR mat.import_timestamp <= p_date_to)
        AND (p_keyword_search IS NULL OR mat.keywords::TEXT ILIKE '%' || p_keyword_search || '%')
    ORDER BY mat.import_timestamp DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION filter_analysis_table IS 'Filter master analysis table with common criteria - use for custom exports';

-- Function: Refresh export table and return stats
CREATE OR REPLACE FUNCTION refresh_export_table()
RETURNS TABLE (
    total_rows BIGINT,
    refresh_duration INTERVAL,
    refresh_timestamp TIMESTAMPTZ
) AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_row_count BIGINT;
BEGIN
    v_start_time := NOW();
    
    REFRESH MATERIALIZED VIEW export_ready_table;
    
    v_end_time := NOW();
    
    SELECT COUNT(*) INTO v_row_count FROM export_ready_table;
    
    RETURN QUERY
    SELECT 
        v_row_count,
        v_end_time - v_start_time,
        v_end_time;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_export_table IS 'Refresh materialized export table and return performance stats';

-- =============================================================================
-- COMPLETE - Views and functions ready for use
-- =============================================================================
