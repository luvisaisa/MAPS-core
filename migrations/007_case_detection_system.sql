-- =============================================================================
-- Migration 007: Hybrid Case Detection System with Confidence Threshold
-- =============================================================================
-- Purpose: Detect cases using filename patterns (primary) + keyword signatures (fallback)
-- Confidence-based auto-assignment vs manual review
-- =============================================================================

-- =============================================================================
-- TABLE: Pending Case Assignment (for manual review)
-- =============================================================================

CREATE TABLE IF NOT EXISTS pending_case_assignment (
    pending_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES file_imports(file_id) ON DELETE CASCADE,
    segment_id UUID NOT NULL,
    segment_type segment_type_enum NOT NULL,

    -- Detection metadata
    suggested_case_id TEXT,
    detection_method TEXT, -- 'filename_regex', 'keyword_signature', 'hybrid'
    confidence_score DECIMAL(5,4) NOT NULL CHECK (confidence_score >= 0 AND confidence_score <= 1),

    -- Supporting evidence
    keyword_signature TEXT,
    keyword_ids UUID[],
    pattern_match_details JSONB,

    -- Review tracking
    review_status TEXT DEFAULT 'pending' CHECK (review_status IN ('pending', 'assigned', 'rejected', 'merged')),
    assigned_case_id TEXT,
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_file FOREIGN KEY (file_id) REFERENCES file_imports(file_id) ON DELETE CASCADE
);

CREATE INDEX idx_pending_confidence ON pending_case_assignment(confidence_score DESC);
CREATE INDEX idx_pending_status ON pending_case_assignment(review_status);
CREATE INDEX idx_pending_file ON pending_case_assignment(file_id);
CREATE INDEX idx_pending_created ON pending_case_assignment(created_at DESC);

COMMENT ON TABLE pending_case_assignment IS 'Cases with confidence < 0.8 awaiting manual review and assignment';
COMMENT ON COLUMN pending_case_assignment.confidence_score IS 'Calculated confidence: 0.0-0.79 = manual review, 0.8-1.0 = auto-assigned';

-- =============================================================================
-- ENHANCED CASE PATTERNS TABLE (add case_label and metadata)
-- =============================================================================

-- Add columns if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'case_patterns' AND column_name = 'case_label') THEN
        ALTER TABLE case_patterns ADD COLUMN case_label TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'case_patterns' AND column_name = 'detection_method') THEN
        ALTER TABLE case_patterns ADD COLUMN detection_method TEXT DEFAULT 'keyword_signature';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'case_patterns' AND column_name = 'version_history') THEN
        ALTER TABLE case_patterns ADD COLUMN version_history JSONB DEFAULT '[]'::JSONB;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_case_label ON case_patterns(case_label);
CREATE INDEX IF NOT EXISTS idx_case_detection_method ON case_patterns(detection_method);

COMMENT ON COLUMN case_patterns.case_label IS 'Human-readable case identifier (e.g., LIDC-IDRI-0001, Study-12345)';
COMMENT ON COLUMN case_patterns.detection_method IS 'How case was detected: filename_regex, keyword_signature, manual, hybrid';
COMMENT ON COLUMN case_patterns.version_history IS 'Array of import events: [{version, file_id, timestamp, segment_count}]';

-- =============================================================================
-- FUNCTION: Calculate confidence score for case detection
-- =============================================================================

CREATE OR REPLACE FUNCTION calculate_case_confidence(
    p_keyword_count INTEGER,
    p_segment_count INTEGER,
    p_has_quantitative BOOLEAN,
    p_has_qualitative BOOLEAN,
    p_high_relevance_keywords INTEGER DEFAULT 0
)
RETURNS DECIMAL AS $$
DECLARE
    base_score DECIMAL;
    cross_type_bonus DECIMAL;
    relevance_bonus DECIMAL;
    final_score DECIMAL;
BEGIN
    -- Base score from keyword and segment counts
    -- More keywords + more segments = higher confidence
    base_score := LEAST(
        (p_keyword_count::DECIMAL / (p_segment_count + 1)::DECIMAL),
        0.70  -- Cap base at 0.70
    );

    -- Cross-type validation bonus: +0.20 if appears in both quan and qual
    cross_type_bonus := CASE
        WHEN p_has_quantitative AND p_has_qualitative THEN 0.20
        ELSE 0.0
    END;

    -- High-relevance keywords bonus: +0.10 for significant medical terms
    relevance_bonus := CASE
        WHEN p_high_relevance_keywords > 0 THEN LEAST(p_high_relevance_keywords::DECIMAL * 0.02, 0.10)
        ELSE 0.0
    END;

    -- Final score (capped at 1.0)
    final_score := LEAST(base_score + cross_type_bonus + relevance_bonus, 1.0);

    RETURN final_score;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_case_confidence IS 'Calculate confidence score: base + cross_type_bonus + relevance_bonus';

-- =============================================================================
-- FUNCTION: Detect case from file using hybrid strategy
-- =============================================================================

CREATE OR REPLACE FUNCTION detect_case_from_file(p_file_id UUID)
RETURNS TABLE(
    case_id TEXT,
    case_label TEXT,
    detection_method TEXT,
    confidence_score DECIMAL,
    keyword_signature TEXT,
    should_auto_assign BOOLEAN
) AS $$
DECLARE
    v_filename TEXT;
    v_metadata JSONB;
    v_pattern_match TEXT;
    v_keyword_ids UUID[];
    v_keyword_count INTEGER;
    v_segment_count INTEGER;
    v_has_quan BOOLEAN;
    v_has_qual BOOLEAN;
    v_high_rel_count INTEGER;
    v_signature TEXT;
    v_confidence DECIMAL;
BEGIN
    -- Get file info
    SELECT fi.filename, fi.metadata
    INTO v_filename, v_metadata
    FROM file_imports fi
    WHERE fi.file_id = p_file_id;

    -- PRIMARY STRATEGY: Filename pattern matching (confidence = 1.0)
    -- LIDC-IDRI-XXXX pattern
    v_pattern_match := (regexp_matches(v_filename, '(LIDC-IDRI-\d{4})', 'i'))[1];
    IF v_pattern_match IS NOT NULL THEN
        RETURN QUERY SELECT
            'CASE-' || UPPER(v_pattern_match) AS case_id,
            UPPER(v_pattern_match) AS case_label,
            'filename_regex'::TEXT AS detection_method,
            1.0::DECIMAL AS confidence_score,
            NULL::TEXT AS keyword_signature,
            TRUE AS should_auto_assign;
        RETURN;
    END IF;

    -- Study-XXXXX pattern
    v_pattern_match := (regexp_matches(v_filename, '(Study-\d+)', 'i'))[1];
    IF v_pattern_match IS NOT NULL THEN
        RETURN QUERY SELECT
            'CASE-' || UPPER(v_pattern_match) AS case_id,
            UPPER(v_pattern_match) AS case_label,
            'filename_regex'::TEXT AS detection_method,
            1.0::DECIMAL AS confidence_score,
            NULL::TEXT AS keyword_signature,
            TRUE AS should_auto_assign;
        RETURN;
    END IF;

    -- Patient-XXX pattern
    v_pattern_match := (regexp_matches(v_filename, '(Patient-[A-Z0-9]+)', 'i'))[1];
    IF v_pattern_match IS NOT NULL THEN
        RETURN QUERY SELECT
            'CASE-' || UPPER(v_pattern_match) AS case_id,
            UPPER(v_pattern_match) AS case_label,
            'filename_regex'::TEXT AS detection_method,
            1.0::DECIMAL AS confidence_score,
            NULL::TEXT AS keyword_signature,
            TRUE AS should_auto_assign;
        RETURN;
    END IF;

    -- Check metadata for existing case_id
    IF v_metadata ? 'detected_case_id' THEN
        RETURN QUERY SELECT
            'CASE-' || (v_metadata->>'detected_case_id')::TEXT AS case_id,
            (v_metadata->>'detected_case_id')::TEXT AS case_label,
            'metadata_lookup'::TEXT AS detection_method,
            1.0::DECIMAL AS confidence_score,
            NULL::TEXT AS keyword_signature,
            TRUE AS should_auto_assign;
        RETURN;
    END IF;

    -- FALLBACK STRATEGY: Keyword signature hashing
    -- Collect all keywords from this file's segments
    SELECT
        array_agg(DISTINCT ko.keyword_id ORDER BY ko.keyword_id),
        COUNT(DISTINCT ko.keyword_id),
        COUNT(DISTINCT ko.segment_id),
        bool_or(ko.segment_type = 'quantitative'),
        bool_or(ko.segment_type = 'qualitative'),
        COUNT(DISTINCT CASE WHEN k.relevance_score > 0.5 THEN k.keyword_id END)
    INTO
        v_keyword_ids,
        v_keyword_count,
        v_segment_count,
        v_has_quan,
        v_has_qual,
        v_high_rel_count
    FROM keyword_occurrences ko
    JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
    WHERE ko.file_id = p_file_id;

    -- If no keywords found, return NULL case
    IF v_keyword_ids IS NULL OR array_length(v_keyword_ids, 1) = 0 THEN
        RETURN QUERY SELECT
            NULL::TEXT AS case_id,
            NULL::TEXT AS case_label,
            'no_keywords'::TEXT AS detection_method,
            0.0::DECIMAL AS confidence_score,
            NULL::TEXT AS keyword_signature,
            FALSE AS should_auto_assign;
        RETURN;
    END IF;

    -- Generate keyword signature
    v_signature := generate_keyword_signature(v_keyword_ids);

    -- Calculate confidence
    v_confidence := calculate_case_confidence(
        v_keyword_count,
        v_segment_count,
        v_has_quan,
        v_has_qual,
        v_high_rel_count
    );

    -- Return keyword-based case
    RETURN QUERY SELECT
        'CASE-' || v_signature AS case_id,
        'KW-' || v_signature AS case_label,
        'keyword_signature'::TEXT AS detection_method,
        v_confidence AS confidence_score,
        v_signature AS keyword_signature,
        (v_confidence >= 0.80) AS should_auto_assign;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION detect_case_from_file IS 'Hybrid case detection: filename regex (primary) or keyword signature (fallback)';

-- =============================================================================
-- FUNCTION: Auto-assign or flag case for review
-- =============================================================================

CREATE OR REPLACE FUNCTION process_case_assignment(p_file_id UUID)
RETURNS TABLE(
    case_assigned BOOLEAN,
    case_id TEXT,
    confidence DECIMAL,
    action TEXT
) AS $$
DECLARE
    v_case_record RECORD;
    v_existing_case_id UUID;
    v_segment_records RECORD;
    v_version_entry JSONB;
BEGIN
    -- Detect case
    SELECT * INTO v_case_record
    FROM detect_case_from_file(p_file_id)
    LIMIT 1;

    -- If no case detected
    IF v_case_record.case_id IS NULL THEN
        -- Flag all segments for manual review
        FOR v_segment_records IN
            SELECT segment_id, segment_type
            FROM (
                SELECT segment_id, 'qualitative'::segment_type_enum AS segment_type
                FROM qualitative_segments WHERE file_id = p_file_id
                UNION ALL
                SELECT segment_id, 'quantitative'::segment_type_enum
                FROM quantitative_segments WHERE file_id = p_file_id
                UNION ALL
                SELECT segment_id, 'mixed'::segment_type_enum
                FROM mixed_segments WHERE file_id = p_file_id
            ) all_segments
        LOOP
            INSERT INTO pending_case_assignment (
                file_id, segment_id, segment_type,
                suggested_case_id, detection_method, confidence_score,
                review_status
            ) VALUES (
                p_file_id,
                v_segment_records.segment_id,
                v_segment_records.segment_type,
                NULL,
                'no_detection',
                0.0,
                'pending'
            );
        END LOOP;

        RETURN QUERY SELECT FALSE, NULL::TEXT, 0.0::DECIMAL, 'flagged_for_review'::TEXT;
        RETURN;
    END IF;

    -- If confidence >= 0.8: auto-assign
    IF v_case_record.should_auto_assign THEN
        -- Check if case pattern already exists
        SELECT case_id INTO v_existing_case_id
        FROM case_patterns
        WHERE pattern_signature = COALESCE(v_case_record.keyword_signature, v_case_record.case_label);

        IF v_existing_case_id IS NULL THEN
            -- Create new case pattern
            INSERT INTO case_patterns (
                pattern_signature,
                case_label,
                detection_method,
                keywords,
                source_segments,
                confidence_score,
                cross_type_validated,
                keyword_count,
                segment_count,
                file_count,
                version_history
            )
            SELECT
                COALESCE(v_case_record.keyword_signature, v_case_record.case_label),
                v_case_record.case_label,
                v_case_record.detection_method,
                jsonb_agg(DISTINCT jsonb_build_object(
                    'keyword_id', k.keyword_id,
                    'term', k.term,
                    'frequency', k.total_frequency
                )),
                jsonb_agg(DISTINCT jsonb_build_object(
                    'segment_id', us.segment_id,
                    'segment_type', us.segment_type,
                    'file_id', us.file_id
                )),
                v_case_record.confidence_score,
                bool_or(us.segment_type = 'quantitative') AND bool_or(us.segment_type = 'qualitative'),
                COUNT(DISTINCT k.keyword_id),
                COUNT(DISTINCT us.segment_id),
                1,  -- file_count
                jsonb_build_array(
                    jsonb_build_object(
                        'version', 1,
                        'file_id', p_file_id,
                        'timestamp', NOW(),
                        'segment_count', COUNT(DISTINCT us.segment_id)
                    )
                )
            FROM unified_segments us
            LEFT JOIN keyword_occurrences ko ON us.segment_id = ko.segment_id
            LEFT JOIN extracted_keywords k ON ko.keyword_id = k.keyword_id
            WHERE us.file_id = p_file_id
            RETURNING case_id INTO v_existing_case_id;
        ELSE
            -- Update existing case pattern (accumulate segments)
            UPDATE case_patterns
            SET
                source_segments = source_segments || (
                    SELECT jsonb_agg(DISTINCT jsonb_build_object(
                        'segment_id', segment_id,
                        'segment_type', segment_type,
                        'file_id', file_id
                    ))
                    FROM unified_segments
                    WHERE file_id = p_file_id
                ),
                segment_count = segment_count + (
                    SELECT COUNT(*) FROM unified_segments WHERE file_id = p_file_id
                ),
                file_count = file_count + 1,
                version_history = version_history || jsonb_build_object(
                    'version', array_length(version_history::jsonb, 1) + 1,
                    'file_id', p_file_id,
                    'timestamp', NOW(),
                    'segment_count', (SELECT COUNT(*) FROM unified_segments WHERE file_id = p_file_id)
                ),
                last_updated_timestamp = NOW()
            WHERE case_id = v_existing_case_id;
        END IF;

        -- Update file metadata with assigned case
        UPDATE file_imports
        SET metadata = COALESCE(metadata, '{}'::JSONB) || jsonb_build_object(
            'assigned_case_id', v_case_record.case_id,
            'case_label', v_case_record.case_label,
            'case_confidence', v_case_record.confidence_score,
            'case_assignment_timestamp', NOW()
        )
        WHERE file_id = p_file_id;

        RETURN QUERY SELECT TRUE, v_case_record.case_id, v_case_record.confidence_score, 'auto_assigned'::TEXT;
        RETURN;
    ELSE
        -- Confidence < 0.8: flag for manual review
        FOR v_segment_records IN
            SELECT segment_id, segment_type
            FROM (
                SELECT segment_id, 'qualitative'::segment_type_enum AS segment_type
                FROM qualitative_segments WHERE file_id = p_file_id
                UNION ALL
                SELECT segment_id, 'quantitative'::segment_type_enum
                FROM quantitative_segments WHERE file_id = p_file_id
                UNION ALL
                SELECT segment_id, 'mixed'::segment_type_enum
                FROM mixed_segments WHERE file_id = p_file_id
            ) all_segments
        LOOP
            INSERT INTO pending_case_assignment (
                file_id, segment_id, segment_type,
                suggested_case_id, detection_method, confidence_score,
                keyword_signature, review_status
            ) VALUES (
                p_file_id,
                v_segment_records.segment_id,
                v_segment_records.segment_type,
                v_case_record.case_id,
                v_case_record.detection_method,
                v_case_record.confidence_score,
                v_case_record.keyword_signature,
                'pending'
            );
        END LOOP;

        RETURN QUERY SELECT FALSE, v_case_record.case_id, v_case_record.confidence_score, 'pending_review'::TEXT;
        RETURN;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION process_case_assignment IS 'Auto-assign high-confidence cases or flag low-confidence for manual review';

-- =============================================================================
-- FUNCTION: Manual case assignment (for UI)
-- =============================================================================

CREATE OR REPLACE FUNCTION assign_case_manually(
    p_pending_id UUID,
    p_case_label TEXT,
    p_create_new_case BOOLEAN DEFAULT FALSE,
    p_reviewed_by TEXT DEFAULT 'manual'
)
RETURNS TABLE(
    success BOOLEAN,
    case_id UUID,
    message TEXT
) AS $$
DECLARE
    v_pending_record RECORD;
    v_case_id UUID;
    v_existing_case UUID;
BEGIN
    -- Get pending assignment
    SELECT * INTO v_pending_record
    FROM pending_case_assignment
    WHERE pending_id = p_pending_id;

    IF v_pending_record IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, 'Pending assignment not found'::TEXT;
        RETURN;
    END IF;

    -- Check if case exists
    IF p_create_new_case THEN
        -- Create new case pattern
        INSERT INTO case_patterns (
            pattern_signature,
            case_label,
            detection_method,
            keywords,
            source_segments,
            confidence_score,
            cross_type_validated,
            keyword_count,
            segment_count,
            file_count
        ) VALUES (
            'MANUAL-' || gen_random_uuid()::TEXT,
            p_case_label,
            'manual',
            '[]'::JSONB,
            jsonb_build_array(jsonb_build_object(
                'segment_id', v_pending_record.segment_id,
                'segment_type', v_pending_record.segment_type,
                'file_id', v_pending_record.file_id
            )),
            1.0,  -- Manual assignment has perfect confidence
            FALSE,
            0,
            1,
            1
        )
        RETURNING case_id INTO v_case_id;
    ELSE
        -- Find existing case by label
        SELECT case_id INTO v_existing_case
        FROM case_patterns
        WHERE case_label = p_case_label
        LIMIT 1;

        IF v_existing_case IS NULL THEN
            RETURN QUERY SELECT FALSE, NULL::UUID, 'Case not found. Use create_new_case=TRUE to create.'::TEXT;
            RETURN;
        END IF;

        -- Update existing case
        UPDATE case_patterns
        SET
            source_segments = source_segments || jsonb_build_object(
                'segment_id', v_pending_record.segment_id,
                'segment_type', v_pending_record.segment_type,
                'file_id', v_pending_record.file_id
            ),
            segment_count = segment_count + 1,
            last_updated_timestamp = NOW()
        WHERE case_id = v_existing_case;

        v_case_id := v_existing_case;
    END IF;

    -- Update pending assignment
    UPDATE pending_case_assignment
    SET
        review_status = 'assigned',
        assigned_case_id = p_case_label,
        reviewed_by = p_reviewed_by,
        reviewed_at = NOW(),
        updated_at = NOW()
    WHERE pending_id = p_pending_id;

    RETURN QUERY SELECT TRUE, v_case_id, 'Case assigned successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION assign_case_manually IS 'Manually assign a pending case to existing or new case pattern';

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 007: Hybrid case detection with confidence threshold installed';
