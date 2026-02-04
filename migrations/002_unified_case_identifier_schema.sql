-- =============================================================================
-- Unified Schema-Agnostic Case Identifier System
-- PostgreSQL/Supabase Schema
-- =============================================================================
-- Core principle: Content types, not file types
-- All files go through: Parse → Analyze → Classify → Extract
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- Trigram matching for fuzzy search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- GIN indexes on multiple column types

-- =============================================================================
-- ENUMS: Content classification types
-- =============================================================================

CREATE TYPE segment_type_enum AS ENUM ('quantitative', 'qualitative', 'mixed');
CREATE TYPE processing_status_enum AS ENUM ('pending', 'parsing', 'analyzing', 'extracting', 'complete', 'failed');
CREATE TYPE stop_word_category_enum AS ENUM ('common_english', 'academic', 'structural', 'domain_specific', 'custom');

-- =============================================================================
-- SOURCE TRACKING: All imported files (any format)
-- =============================================================================

CREATE TABLE file_imports (
    file_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filename TEXT NOT NULL,
    extension TEXT NOT NULL, -- csv, json, xml, pdf, docx, xlsx, txt
    file_size_bytes BIGINT,
    import_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_content_hash TEXT NOT NULL, -- SHA-256 of file content for deduplication
    processing_status processing_status_enum NOT NULL DEFAULT 'pending',
    processing_error TEXT,
    metadata JSONB DEFAULT '{}', -- Flexible storage for format-specific metadata
    CONSTRAINT unique_content_hash UNIQUE (raw_content_hash)
);

COMMENT ON TABLE file_imports IS 'All imported files regardless of format - unified entry point';
COMMENT ON COLUMN file_imports.raw_content_hash IS 'Ensures idempotent imports - reimporting same file updates existing record';

-- =============================================================================
-- CONTENT SEGMENTS: Classified content extracted from ANY file
-- =============================================================================

-- Quantitative segments: Numerical data, tables, structured values
CREATE TABLE quantitative_segments (
    segment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES file_imports(file_id) ON DELETE CASCADE,
    data_structure JSONB NOT NULL, -- Actual tabular/structured data
    column_mappings JSONB, -- {column_name: data_type, ...}
    row_count INTEGER,
    detected_schema JSONB, -- Inferred schema information
    numeric_density DECIMAL(5,4), -- 0.0000-1.0000, ratio of numeric to total content
    position_in_file JSONB, -- {start_line, end_line, page, sheet_name, xpath, etc.}
    extraction_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_file FOREIGN KEY (file_id) REFERENCES file_imports(file_id) ON DELETE CASCADE
);

CREATE INDEX idx_quant_file_id ON quantitative_segments(file_id);
CREATE INDEX idx_quant_data_gin ON quantitative_segments USING GIN (data_structure);
CREATE INDEX idx_quant_schema_gin ON quantitative_segments USING GIN (detected_schema);

COMMENT ON TABLE quantitative_segments IS 'Segments with >70% numeric content from any source file';

-- Qualitative segments: Text passages, narratives, descriptions
CREATE TABLE qualitative_segments (
    segment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES file_imports(file_id) ON DELETE CASCADE,
    text_content TEXT NOT NULL,
    segment_subtype TEXT, -- abstract, body, caption, annotation, header, footer, etc.
    language_code TEXT DEFAULT 'en', -- ISO 639-1 language code
    word_count INTEGER,
    sentence_count INTEGER,
    position_in_file JSONB, -- {paragraph_index, page, section, xpath, etc.}
    extraction_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    text_vector tsvector, -- For full-text search
    CONSTRAINT fk_file FOREIGN KEY (file_id) REFERENCES file_imports(file_id) ON DELETE CASCADE
);

CREATE INDEX idx_qual_file_id ON qualitative_segments(file_id);
CREATE INDEX idx_qual_text_fts ON qualitative_segments USING GIN (text_vector);
CREATE INDEX idx_qual_subtype ON qualitative_segments(segment_subtype);

COMMENT ON TABLE qualitative_segments IS 'Segments with >70% text/prose content from any source file';

-- Auto-generate text_vector for full-text search
CREATE OR REPLACE FUNCTION qualitative_segments_text_vector_trigger() RETURNS trigger AS $$
BEGIN
    NEW.text_vector := to_tsvector('english', COALESCE(NEW.text_content, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_qualitative_text_vector 
    BEFORE INSERT OR UPDATE ON qualitative_segments
    FOR EACH ROW EXECUTE FUNCTION qualitative_segments_text_vector_trigger();

-- Mixed segments: Interleaved quantitative and qualitative content
CREATE TABLE mixed_segments (
    segment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES file_imports(file_id) ON DELETE CASCADE,
    structure JSONB NOT NULL, -- Full structure preserving both text and numbers
    text_elements JSONB, -- Extracted text components
    numeric_elements JSONB, -- Extracted numeric components
    quantitative_ratio DECIMAL(5,4), -- 0.3000-0.7000, ratio for "mixed" classification
    position_in_file JSONB,
    extraction_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_file FOREIGN KEY (file_id) REFERENCES file_imports(file_id) ON DELETE CASCADE,
    CONSTRAINT check_mixed_ratio CHECK (quantitative_ratio >= 0.30 AND quantitative_ratio <= 0.70)
);

CREATE INDEX idx_mixed_file_id ON mixed_segments(file_id);
CREATE INDEX idx_mixed_structure_gin ON mixed_segments USING GIN (structure);
CREATE INDEX idx_mixed_text_gin ON mixed_segments USING GIN (text_elements);
CREATE INDEX idx_mixed_numeric_gin ON mixed_segments USING GIN (numeric_elements);

COMMENT ON TABLE mixed_segments IS 'Segments with 30-70% quantitative content - blended data types';

-- =============================================================================
-- KEYWORD SYSTEM: Stop words, extraction, occurrences
-- =============================================================================

-- Stop words: Configurable exclusion list
CREATE TABLE stop_words (
    stop_word_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    term TEXT NOT NULL UNIQUE,
    normalized_term TEXT NOT NULL, -- lowercase, trimmed
    category stop_word_category_enum NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    added_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE INDEX idx_stopwords_normalized ON stop_words(normalized_term) WHERE active = TRUE;

COMMENT ON TABLE stop_words IS 'Configurable terms to exclude from keyword extraction';

-- Extracted keywords: Unique terms with aggregated statistics
CREATE TABLE extracted_keywords (
    keyword_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    term TEXT NOT NULL,
    normalized_term TEXT NOT NULL, -- lowercase, trimmed for matching
    is_phrase BOOLEAN NOT NULL DEFAULT FALSE, -- Single word vs multi-word phrase
    total_frequency INTEGER NOT NULL DEFAULT 0, -- Total occurrences across all documents
    document_frequency INTEGER NOT NULL DEFAULT 0, -- Number of documents containing this term
    relevance_score DECIMAL(10,6), -- Multi-factor relevance score
    first_seen_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_normalized_term UNIQUE (normalized_term)
);

CREATE INDEX idx_keywords_normalized ON extracted_keywords(normalized_term);
CREATE INDEX idx_keywords_relevance ON extracted_keywords(relevance_score DESC);
CREATE INDEX idx_keywords_doc_freq ON extracted_keywords(document_frequency DESC);

COMMENT ON TABLE extracted_keywords IS 'All unique keywords extracted across all content types';
COMMENT ON COLUMN extracted_keywords.relevance_score IS 'TF-IDF * position_weight * cross_type_bonus * numeric_association_weight';

-- Keyword occurrences: Each instance with full context (polymorphic)
CREATE TABLE keyword_occurrences (
    occurrence_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    keyword_id UUID NOT NULL REFERENCES extracted_keywords(keyword_id) ON DELETE CASCADE,
    
    -- Polymorphic reference to any segment type
    segment_id UUID NOT NULL,
    segment_type segment_type_enum NOT NULL,
    
    file_id UUID NOT NULL REFERENCES file_imports(file_id) ON DELETE CASCADE,
    
    surrounding_context TEXT, -- Text window around the keyword
    associated_values JSONB, -- Numeric values near this keyword occurrence
    position_metadata JSONB, -- Exact location within segment
    position_weight DECIMAL(5,4) DEFAULT 1.0, -- Higher for headers, titles, etc.
    
    occurrence_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT fk_keyword FOREIGN KEY (keyword_id) REFERENCES extracted_keywords(keyword_id) ON DELETE CASCADE,
    CONSTRAINT fk_file FOREIGN KEY (file_id) REFERENCES file_imports(file_id) ON DELETE CASCADE
);

CREATE INDEX idx_occur_keyword ON keyword_occurrences(keyword_id);
CREATE INDEX idx_occur_segment ON keyword_occurrences(segment_id, segment_type);
CREATE INDEX idx_occur_file ON keyword_occurrences(file_id);
CREATE INDEX idx_occur_values_gin ON keyword_occurrences USING GIN (associated_values);

COMMENT ON TABLE keyword_occurrences IS 'Every keyword instance with context - links to any segment type';
COMMENT ON COLUMN keyword_occurrences.segment_id IS 'References segment_id from quantitative_segments, qualitative_segments, or mixed_segments based on segment_type';

-- =============================================================================
-- CASE PATTERNS: Detected clusters based on keyword co-occurrence
-- =============================================================================

CREATE TABLE case_patterns (
    case_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pattern_signature TEXT NOT NULL UNIQUE, -- Hash of sorted keyword_ids for deduplication
    keywords JSONB NOT NULL, -- Array of {keyword_id, term, frequency}
    source_segments JSONB NOT NULL, -- Array of {segment_id, segment_type, file_id}
    confidence_score DECIMAL(10,6) NOT NULL,
    cross_type_validated BOOLEAN DEFAULT FALSE, -- TRUE if pattern appears in both quan and qual
    keyword_count INTEGER NOT NULL,
    segment_count INTEGER NOT NULL,
    file_count INTEGER NOT NULL,
    detected_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_updated_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_case_confidence ON case_patterns(confidence_score DESC);
CREATE INDEX idx_case_cross_validated ON case_patterns(cross_type_validated) WHERE cross_type_validated = TRUE;
CREATE INDEX idx_case_keywords_gin ON case_patterns USING GIN (keywords);

COMMENT ON TABLE case_patterns IS 'Detected cases based on keyword clustering across content types';
COMMENT ON COLUMN case_patterns.cross_type_validated IS 'High signal: pattern appears in BOTH quantitative and qualitative content';

-- =============================================================================
-- UTILITY VIEWS: Unified queries across segment types
-- =============================================================================

-- View: All segments unified (for cross-type queries)
CREATE OR REPLACE VIEW unified_segments AS
SELECT 
    'quantitative'::segment_type_enum AS segment_type,
    segment_id,
    file_id,
    data_structure AS content,
    position_in_file,
    extraction_timestamp
FROM quantitative_segments
UNION ALL
SELECT 
    'qualitative'::segment_type_enum,
    segment_id,
    file_id,
    jsonb_build_object('text_content', text_content, 'segment_subtype', segment_subtype) AS content,
    position_in_file,
    extraction_timestamp
FROM qualitative_segments
UNION ALL
SELECT 
    'mixed'::segment_type_enum,
    segment_id,
    file_id,
    structure AS content,
    position_in_file,
    extraction_timestamp
FROM mixed_segments;

COMMENT ON VIEW unified_segments IS 'All segments across all types - enables cross-type queries';

-- View: Keywords appearing in both quantitative and qualitative contexts
CREATE OR REPLACE VIEW cross_type_keywords AS
SELECT 
    k.keyword_id,
    k.term,
    k.normalized_term,
    k.relevance_score,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.segment_id END) AS quantitative_occurrences,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.segment_id END) AS qualitative_occurrences,
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'mixed' THEN ko.segment_id END) AS mixed_occurrences,
    COUNT(DISTINCT ko.file_id) AS file_count
FROM extracted_keywords k
JOIN keyword_occurrences ko ON k.keyword_id = ko.keyword_id
GROUP BY k.keyword_id, k.term, k.normalized_term, k.relevance_score
HAVING 
    COUNT(DISTINCT CASE WHEN ko.segment_type = 'quantitative' THEN ko.segment_id END) > 0
    AND COUNT(DISTINCT CASE WHEN ko.segment_type = 'qualitative' THEN ko.segment_id END) > 0
ORDER BY k.relevance_score DESC;

COMMENT ON VIEW cross_type_keywords IS 'High-signal keywords appearing in BOTH quantitative and qualitative content';

-- View: Keyword with all numeric associations
CREATE OR REPLACE VIEW keyword_numeric_associations AS
SELECT 
    k.keyword_id,
    k.term,
    ko.occurrence_id,
    ko.file_id,
    fi.filename,
    ko.segment_type,
    ko.associated_values,
    ko.surrounding_context,
    ko.occurrence_timestamp
FROM extracted_keywords k
JOIN keyword_occurrences ko ON k.keyword_id = ko.keyword_id
JOIN file_imports fi ON ko.file_id = fi.file_id
WHERE ko.associated_values IS NOT NULL
ORDER BY k.term, ko.occurrence_timestamp DESC;

COMMENT ON VIEW keyword_numeric_associations IS 'All numeric values associated with each keyword across all contexts';

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

-- =============================================================================
-- FUNCTIONS: Helper functions for queries and processing
-- =============================================================================

-- Function: Get all contexts for a specific keyword
CREATE OR REPLACE FUNCTION get_keyword_contexts(keyword_term TEXT)
RETURNS TABLE (
    occurrence_id UUID,
    segment_type segment_type_enum,
    file_name TEXT,
    context TEXT,
    numeric_values JSONB,
    position_info JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ko.occurrence_id,
        ko.segment_type,
        fi.filename,
        ko.surrounding_context,
        ko.associated_values,
        ko.position_metadata
    FROM keyword_occurrences ko
    JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
    JOIN file_imports fi ON ko.file_id = fi.file_id
    WHERE k.normalized_term = LOWER(TRIM(keyword_term))
    ORDER BY ko.occurrence_timestamp DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_keyword_contexts IS 'Retrieve all contexts for a keyword regardless of segment type';

-- Function: Find files containing specific keyword pattern
CREATE OR REPLACE FUNCTION find_files_with_keywords(keyword_terms TEXT[])
RETURNS TABLE (
    file_id UUID,
    filename TEXT,
    match_count INTEGER,
    matched_keywords JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fi.file_id,
        fi.filename,
        COUNT(DISTINCT k.keyword_id)::INTEGER AS match_count,
        jsonb_agg(DISTINCT jsonb_build_object('term', k.term, 'relevance', k.relevance_score)) AS matched_keywords
    FROM file_imports fi
    JOIN keyword_occurrences ko ON fi.file_id = ko.file_id
    JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
    WHERE k.normalized_term = ANY(
        SELECT LOWER(TRIM(unnest(keyword_terms)))
    )
    GROUP BY fi.file_id, fi.filename
    HAVING COUNT(DISTINCT k.keyword_id) >= ARRAY_LENGTH(keyword_terms, 1)
    ORDER BY match_count DESC, fi.import_timestamp DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_files_with_keywords IS 'Find files containing all specified keywords';

-- Function: Calculate IDF for keyword relevance scoring
CREATE OR REPLACE FUNCTION calculate_idf(keyword_term TEXT)
RETURNS DECIMAL AS $$
DECLARE
    total_docs INTEGER;
    docs_with_term INTEGER;
BEGIN
    SELECT COUNT(DISTINCT file_id) INTO total_docs FROM file_imports WHERE processing_status = 'complete';
    SELECT document_frequency INTO docs_with_term FROM extracted_keywords WHERE normalized_term = LOWER(TRIM(keyword_term));
    
    IF docs_with_term = 0 OR total_docs = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN LOG(total_docs::DECIMAL / docs_with_term::DECIMAL);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_idf IS 'Calculate inverse document frequency for TF-IDF relevance scoring';

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
-- INITIAL DATA: Common English stop words
-- =============================================================================

INSERT INTO stop_words (term, normalized_term, category) VALUES
-- Articles
('a', 'a', 'common_english'),
('an', 'an', 'common_english'),
('the', 'the', 'common_english'),
-- Pronouns
('i', 'i', 'common_english'),
('you', 'you', 'common_english'),
('he', 'he', 'common_english'),
('she', 'she', 'common_english'),
('it', 'it', 'common_english'),
('we', 'we', 'common_english'),
('they', 'they', 'common_english'),
-- Prepositions
('in', 'in', 'common_english'),
('on', 'on', 'common_english'),
('at', 'at', 'common_english'),
('to', 'to', 'common_english'),
('for', 'for', 'common_english'),
('of', 'of', 'common_english'),
('with', 'with', 'common_english'),
('from', 'from', 'common_english'),
('by', 'by', 'common_english'),
-- Conjunctions
('and', 'and', 'common_english'),
('or', 'or', 'common_english'),
('but', 'but', 'common_english'),
-- Common verbs
('is', 'is', 'common_english'),
('are', 'are', 'common_english'),
('was', 'was', 'common_english'),
('were', 'were', 'common_english'),
('be', 'be', 'common_english'),
('been', 'been', 'common_english'),
('has', 'has', 'common_english'),
('have', 'have', 'common_english'),
('had', 'had', 'common_english'),
-- Academic phrases
('et al', 'et al', 'academic'),
('ibid', 'ibid', 'academic'),
('figure', 'figure', 'academic'),
('table', 'table', 'academic'),
('et al.', 'et al.', 'academic'),
-- Structural noise
('null', 'null', 'structural'),
('undefined', 'undefined', 'structural'),
('n/a', 'n/a', 'structural'),
('true', 'true', 'structural'),
('false', 'false', 'structural'),
('none', 'none', 'structural')
ON CONFLICT (term) DO NOTHING;

-- =============================================================================
-- PERFORMANCE INDEXES: Additional indexes for common query patterns
-- =============================================================================

-- Composite index for keyword occurrence queries by file and type
CREATE INDEX idx_occur_file_type ON keyword_occurrences(file_id, segment_type);

-- Index for case pattern confidence queries
CREATE INDEX idx_case_validated_confidence ON case_patterns(cross_type_validated, confidence_score DESC);

-- Index for file processing status queries
CREATE INDEX idx_file_status ON file_imports(processing_status, import_timestamp DESC);

-- =============================================================================
-- GRANTS: Supabase RLS policies (example - adjust based on auth requirements)
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE file_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE quantitative_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE qualitative_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE mixed_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE extracted_keywords ENABLE ROW LEVEL SECURITY;
ALTER TABLE keyword_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE stop_words ENABLE ROW LEVEL SECURITY;

-- Example policy: Allow all operations for authenticated users
-- Adjust based on your authentication requirements
CREATE POLICY "Allow all for authenticated users" ON file_imports
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON quantitative_segments
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON qualitative_segments
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON mixed_segments
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON extracted_keywords
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON keyword_occurrences
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON case_patterns
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all for authenticated users" ON stop_words
    FOR ALL USING (auth.role() = 'authenticated');

-- =============================================================================
-- SCHEMA COMPLETE
-- =============================================================================
