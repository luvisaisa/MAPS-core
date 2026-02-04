-- =============================================================================
-- Migration 006: Automatic Keyword Extraction and Case Detection Triggers
-- =============================================================================
-- Purpose: Automatically extract keywords and detect cases on every import
-- Triggers fire on INSERT to segment tables → populate keywords → detect cases
-- =============================================================================

-- =============================================================================
-- HELPER FUNCTIONS FOR KEYWORD EXTRACTION
-- =============================================================================

-- Function: Normalize text for keyword extraction
CREATE OR REPLACE FUNCTION normalize_keyword_text(raw_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN LOWER(TRIM(regexp_replace(raw_text, '\s+', ' ', 'g')));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION normalize_keyword_text IS 'Normalize text: lowercase, trim, collapse whitespace';

-- Function: Extract keywords from text (qualitative content)
CREATE OR REPLACE FUNCTION extract_keywords_from_text(
    text_content TEXT,
    min_word_length INTEGER DEFAULT 3,
    max_keywords INTEGER DEFAULT 50
)
RETURNS TABLE(term TEXT, frequency INTEGER) AS $$
BEGIN
    RETURN QUERY
    WITH words AS (
        SELECT
            normalize_keyword_text(word) AS normalized_word,
            word AS original_word
        FROM regexp_split_to_table(text_content, '\s+') AS word
        WHERE LENGTH(word) >= min_word_length
            AND word !~ '^\d+$'  -- Exclude pure numbers
    ),
    filtered_words AS (
        SELECT w.original_word, w.normalized_word
        FROM words w
        LEFT JOIN stop_words sw ON w.normalized_word = sw.normalized_term AND sw.active = TRUE
        WHERE sw.stop_word_id IS NULL  -- Exclude stop words
    ),
    word_counts AS (
        SELECT
            original_word AS term,
            COUNT(*)::INTEGER AS frequency
        FROM filtered_words
        GROUP BY original_word
        ORDER BY frequency DESC, original_word
        LIMIT max_keywords
    )
    SELECT wc.term, wc.frequency FROM word_counts wc;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION extract_keywords_from_text IS 'Extract keywords from text with stop word filtering';

-- Function: Extract keywords from JSONB (quantitative content)
CREATE OR REPLACE FUNCTION extract_keywords_from_jsonb(
    jsonb_content JSONB,
    max_keywords INTEGER DEFAULT 30
)
RETURNS TABLE(term TEXT, associated_value NUMERIC) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE json_keys AS (
        -- Extract all keys from JSONB structure
        SELECT
            key AS term,
            value
        FROM jsonb_each(jsonb_content)
        UNION ALL
        SELECT
            jk.term || '.' || je.key AS term,
            je.value
        FROM json_keys jk,
        LATERAL jsonb_each(jk.value) je
        WHERE jsonb_typeof(jk.value) = 'object'
    ),
    numeric_associations AS (
        SELECT
            normalize_keyword_text(term) AS normalized_term,
            term,
            CASE
                WHEN jsonb_typeof(value) = 'number' THEN (value::TEXT)::NUMERIC
                ELSE NULL
            END AS numeric_value
        FROM json_keys
        WHERE term NOT IN ('data_structure', 'metadata', 'position_in_file')
    )
    SELECT
        na.term,
        na.numeric_value
    FROM numeric_associations na
    WHERE na.term IS NOT NULL
        AND LENGTH(na.term) >= 3
    ORDER BY na.term
    LIMIT max_keywords;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION extract_keywords_from_jsonb IS 'Extract field names and numeric values from JSONB structure';

-- Function: Calculate TF-IDF relevance score
CREATE OR REPLACE FUNCTION calculate_tfidf_score(
    term_frequency INTEGER,
    document_frequency INTEGER,
    total_documents INTEGER,
    position_weight DECIMAL DEFAULT 1.0
)
RETURNS DECIMAL AS $$
DECLARE
    tf DECIMAL;
    idf DECIMAL;
BEGIN
    IF document_frequency = 0 OR total_documents = 0 THEN
        RETURN 0;
    END IF;

    -- TF: normalized frequency
    tf := term_frequency::DECIMAL;

    -- IDF: log(total_docs / doc_freq)
    idf := LOG(total_documents::DECIMAL / document_frequency::DECIMAL);

    -- TF-IDF with position weight
    RETURN (tf * idf * position_weight);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_tfidf_score IS 'Calculate TF-IDF relevance score with position weighting';

-- =============================================================================
-- HELPER FUNCTIONS FOR CASE DETECTION
-- =============================================================================

-- Function: Detect LIDC patient ID from filename or content
CREATE OR REPLACE FUNCTION detect_lidc_patient_id(
    filename TEXT,
    content_jsonb JSONB DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    patient_id TEXT;
BEGIN
    -- Try filename pattern: LIDC-IDRI-XXXX
    patient_id := (regexp_matches(filename, 'LIDC-IDRI-(\d{4})', 'i'))[1];
    IF patient_id IS NOT NULL THEN
        RETURN 'LIDC-IDRI-' || patient_id;
    END IF;

    -- Try content if provided
    IF content_jsonb IS NOT NULL THEN
        -- Check for patient_id field
        IF content_jsonb ? 'patient_id' THEN
            patient_id := content_jsonb->>'patient_id';
            IF patient_id ~ 'LIDC-IDRI-\d{4}' THEN
                RETURN patient_id;
            END IF;
        END IF;

        -- Check for StudyInstanceUID pattern
        IF content_jsonb ? 'study_instance_uid' THEN
            patient_id := (regexp_matches(content_jsonb->>'study_instance_uid', 'LIDC-IDRI-(\d{4})', 'i'))[1];
            IF patient_id IS NOT NULL THEN
                RETURN 'LIDC-IDRI-' || patient_id;
            END IF;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION detect_lidc_patient_id IS 'Detect LIDC-IDRI patient ID from filename or content';

-- Function: Generate keyword signature hash for case detection
CREATE OR REPLACE FUNCTION generate_keyword_signature(keyword_ids UUID[])
RETURNS TEXT AS $$
DECLARE
    sorted_ids TEXT[];
    signature TEXT;
BEGIN
    -- Sort keyword IDs to ensure consistent hash
    sorted_ids := ARRAY(SELECT unnest(keyword_ids) ORDER BY 1);

    -- Generate SHA-256 hash
    signature := encode(digest(array_to_string(sorted_ids, ','), 'sha256'), 'hex');

    RETURN substring(signature from 1 for 16);  -- Use first 16 chars
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION generate_keyword_signature IS 'Generate consistent hash from sorted keyword IDs for case detection';

-- =============================================================================
-- TRIGGER FUNCTION: Auto-extract keywords from qualitative segments
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_extract_keywords_qualitative()
RETURNS TRIGGER AS $$
DECLARE
    v_total_docs INTEGER;
    v_keyword_record RECORD;
    v_keyword_id UUID;
    v_doc_freq INTEGER;
    v_relevance DECIMAL;
BEGIN
    -- Get total documents for IDF calculation
    SELECT COUNT(DISTINCT file_id) INTO v_total_docs
    FROM file_imports
    WHERE processing_status = 'complete';

    IF v_total_docs = 0 THEN
        v_total_docs := 1;  -- Avoid division by zero
    END IF;

    -- Extract keywords from text content
    FOR v_keyword_record IN
        SELECT * FROM extract_keywords_from_text(NEW.text_content)
    LOOP
        -- Upsert into extracted_keywords
        INSERT INTO extracted_keywords (term, normalized_term, is_phrase, total_frequency, document_frequency, first_seen_timestamp, last_seen_timestamp)
        VALUES (
            v_keyword_record.term,
            normalize_keyword_text(v_keyword_record.term),
            (v_keyword_record.term LIKE '% %'),  -- is_phrase if contains space
            v_keyword_record.frequency,
            1,  -- document_frequency = 1 for new keyword
            NOW(),
            NOW()
        )
        ON CONFLICT (normalized_term) DO UPDATE SET
            total_frequency = extracted_keywords.total_frequency + v_keyword_record.frequency,
            document_frequency = extracted_keywords.document_frequency + 1,
            last_seen_timestamp = NOW()
        RETURNING keyword_id, document_frequency INTO v_keyword_id, v_doc_freq;

        -- Calculate relevance score
        v_relevance := calculate_tfidf_score(
            v_keyword_record.frequency,
            v_doc_freq,
            v_total_docs,
            CASE WHEN NEW.segment_subtype IN ('header', 'title', 'abstract') THEN 1.5 ELSE 1.0 END
        );

        -- Update relevance score
        UPDATE extracted_keywords
        SET relevance_score = v_relevance
        WHERE keyword_id = v_keyword_id;

        -- Insert occurrence
        INSERT INTO keyword_occurrences (
            keyword_id,
            segment_id,
            segment_type,
            file_id,
            surrounding_context,
            position_weight,
            occurrence_timestamp
        ) VALUES (
            v_keyword_id,
            NEW.segment_id,
            'qualitative',
            NEW.file_id,
            LEFT(NEW.text_content, 500),  -- Context preview
            CASE WHEN NEW.segment_subtype IN ('header', 'title', 'abstract') THEN 1.5 ELSE 1.0 END,
            NOW()
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_extract_keywords_qualitative IS 'Automatically extract keywords from qualitative segments on INSERT';

-- =============================================================================
-- TRIGGER FUNCTION: Auto-extract keywords from quantitative segments
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_extract_keywords_quantitative()
RETURNS TRIGGER AS $$
DECLARE
    v_total_docs INTEGER;
    v_keyword_record RECORD;
    v_keyword_id UUID;
    v_doc_freq INTEGER;
    v_relevance DECIMAL;
BEGIN
    -- Get total documents for IDF calculation
    SELECT COUNT(DISTINCT file_id) INTO v_total_docs
    FROM file_imports
    WHERE processing_status = 'complete';

    IF v_total_docs = 0 THEN
        v_total_docs := 1;
    END IF;

    -- Extract keywords from JSONB structure
    FOR v_keyword_record IN
        SELECT * FROM extract_keywords_from_jsonb(NEW.data_structure)
    LOOP
        -- Upsert into extracted_keywords
        INSERT INTO extracted_keywords (term, normalized_term, is_phrase, total_frequency, document_frequency, first_seen_timestamp, last_seen_timestamp)
        VALUES (
            v_keyword_record.term,
            normalize_keyword_text(v_keyword_record.term),
            FALSE,  -- Field names are not phrases
            1,
            1,
            NOW(),
            NOW()
        )
        ON CONFLICT (normalized_term) DO UPDATE SET
            total_frequency = extracted_keywords.total_frequency + 1,
            document_frequency = extracted_keywords.document_frequency + 1,
            last_seen_timestamp = NOW()
        RETURNING keyword_id, document_frequency INTO v_keyword_id, v_doc_freq;

        -- Calculate relevance score
        v_relevance := calculate_tfidf_score(1, v_doc_freq, v_total_docs, 1.0);

        -- Update relevance score
        UPDATE extracted_keywords
        SET relevance_score = v_relevance
        WHERE keyword_id = v_keyword_id;

        -- Insert occurrence with numeric association
        INSERT INTO keyword_occurrences (
            keyword_id,
            segment_id,
            segment_type,
            file_id,
            associated_values,
            position_weight,
            occurrence_timestamp
        ) VALUES (
            v_keyword_id,
            NEW.segment_id,
            'quantitative',
            NEW.file_id,
            CASE
                WHEN v_keyword_record.associated_value IS NOT NULL
                THEN jsonb_build_object('value', v_keyword_record.associated_value)
                ELSE NULL
            END,
            1.0,
            NOW()
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_extract_keywords_quantitative IS 'Automatically extract keywords from quantitative segments on INSERT';

-- =============================================================================
-- TRIGGER FUNCTION: Auto-extract keywords from mixed segments
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_extract_keywords_mixed()
RETURNS TRIGGER AS $$
DECLARE
    v_total_docs INTEGER;
    v_text_content TEXT;
BEGIN
    -- Get total documents
    SELECT COUNT(DISTINCT file_id) INTO v_total_docs
    FROM file_imports
    WHERE processing_status = 'complete';

    IF v_total_docs = 0 THEN
        v_total_docs := 1;
    END IF;

    -- Extract text from text_elements if available
    IF NEW.text_elements IS NOT NULL THEN
        v_text_content := NEW.text_elements::TEXT;

        -- Process as qualitative (reuse logic by creating temp record)
        -- Note: For mixed segments, we extract from both text and numeric elements
        PERFORM extract_keywords_from_text(v_text_content);
    END IF;

    -- Extract from numeric elements
    IF NEW.numeric_elements IS NOT NULL THEN
        PERFORM extract_keywords_from_jsonb(NEW.numeric_elements);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_extract_keywords_mixed IS 'Automatically extract keywords from mixed segments on INSERT';

-- =============================================================================
-- TRIGGER FUNCTION: Detect and update case information
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_detect_case_info()
RETURNS TRIGGER AS $$
DECLARE
    v_filename TEXT;
    v_patient_id TEXT;
    v_metadata JSONB;
BEGIN
    -- Get filename from file_imports
    SELECT filename, metadata INTO v_filename, v_metadata
    FROM file_imports
    WHERE file_id = NEW.file_id;

    -- Try to detect LIDC patient ID
    v_patient_id := detect_lidc_patient_id(v_filename, NEW.content);

    -- If detected, update file_imports metadata
    IF v_patient_id IS NOT NULL THEN
        UPDATE file_imports
        SET metadata = COALESCE(metadata, '{}'::JSONB) || jsonb_build_object(
            'detected_case_id', v_patient_id,
            'case_detection_method', 'regex_pattern',
            'case_detection_timestamp', NOW()
        )
        WHERE file_id = NEW.file_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_detect_case_info IS 'Detect case information (e.g., LIDC patient ID) from content';

-- =============================================================================
-- CREATE TRIGGERS
-- =============================================================================

-- Trigger on qualitative_segments
DROP TRIGGER IF EXISTS extract_keywords_qualitative ON qualitative_segments;
CREATE TRIGGER extract_keywords_qualitative
    AFTER INSERT ON qualitative_segments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_extract_keywords_qualitative();

-- Trigger on quantitative_segments
DROP TRIGGER IF EXISTS extract_keywords_quantitative ON quantitative_segments;
CREATE TRIGGER extract_keywords_quantitative
    AFTER INSERT ON quantitative_segments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_extract_keywords_quantitative();

-- Trigger on mixed_segments
DROP TRIGGER IF EXISTS extract_keywords_mixed ON mixed_segments;
CREATE TRIGGER extract_keywords_mixed
    AFTER INSERT ON mixed_segments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_extract_keywords_mixed();

-- Note: We need to trigger on the unified_segments view, but triggers can't be directly on views
-- Instead, we create triggers on each underlying table

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Index for faster keyword normalization lookups
CREATE INDEX IF NOT EXISTS idx_keywords_normalized_lower ON extracted_keywords(LOWER(normalized_term));

-- Index for TF-IDF calculations
CREATE INDEX IF NOT EXISTS idx_keywords_total_freq ON extracted_keywords(total_frequency DESC);

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 006: Automatic keyword extraction and case detection triggers installed';
