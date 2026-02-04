-- =====================================================================
-- Migration 015: Detection Details Table
-- =====================================================================
-- Purpose: Store detailed parse case detection information including
--          expected attributes, detected attributes, and match analysis
-- Date: November 24, 2025
-- =====================================================================

-- ---------------------------------------------------------------------
-- detection_details: Store parse case detection analysis
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detection_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Reference to queue item or document
    queue_item_id VARCHAR(50),  -- Reference to approval queue item
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,

    -- Detection results
    parse_case VARCHAR(255) NOT NULL,
    confidence DECIMAL(5, 4) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),

    -- Attribute analysis (JSONB for flexibility)
    expected_attributes JSONB NOT NULL DEFAULT '[]'::jsonb,
    detected_attributes JSONB NOT NULL DEFAULT '[]'::jsonb,
    missing_attributes JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- Match metrics
    match_percentage DECIMAL(5, 2) NOT NULL,  -- 0.00 to 100.00
    total_expected INTEGER NOT NULL DEFAULT 0,
    total_detected INTEGER NOT NULL DEFAULT 0,

    -- Field-by-field analysis
    field_analysis JSONB DEFAULT '[]'::jsonb,

    -- Detection metadata
    detector_type VARCHAR(100) DEFAULT 'XMLStructureDetector',
    detector_version VARCHAR(50) DEFAULT '1.0.0',
    detection_method VARCHAR(255),  -- e.g., "keyword_matching", "structure_analysis"

    -- Confidence breakdown (optional detailed scoring)
    confidence_breakdown JSONB DEFAULT '{}'::jsonb,

    -- Timestamps
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for detection_details
CREATE INDEX idx_detection_queue_item ON detection_details(queue_item_id);
CREATE INDEX idx_detection_document ON detection_details(document_id);
CREATE INDEX idx_detection_parse_case ON detection_details(parse_case);
CREATE INDEX idx_detection_confidence ON detection_details(confidence);
CREATE INDEX idx_detection_match_percentage ON detection_details(match_percentage);
CREATE INDEX idx_detection_detected_at ON detection_details(detected_at DESC);
CREATE INDEX idx_detection_expected_attrs_gin ON detection_details USING GIN (expected_attributes);
CREATE INDEX idx_detection_detected_attrs_gin ON detection_details USING GIN (detected_attributes);
CREATE INDEX idx_detection_field_analysis_gin ON detection_details USING GIN (field_analysis);

-- Comment documentation
COMMENT ON TABLE detection_details IS 'Detailed parse case detection analysis including attribute matching and confidence scoring';
COMMENT ON COLUMN detection_details.queue_item_id IS 'Reference to approval queue item if detection triggered review';
COMMENT ON COLUMN detection_details.expected_attributes IS 'JSON array of attributes expected for the detected parse case';
COMMENT ON COLUMN detection_details.detected_attributes IS 'JSON array of attributes found in the source document';
COMMENT ON COLUMN detection_details.missing_attributes IS 'JSON array of expected attributes not found in document';
COMMENT ON COLUMN detection_details.match_percentage IS 'Percentage of expected attributes found (0-100)';
COMMENT ON COLUMN detection_details.field_analysis IS 'JSON array with detailed field-by-field analysis (path, found, value_sample)';
COMMENT ON COLUMN detection_details.confidence_breakdown IS 'JSON object with detailed confidence scoring factors';

-- Trigger: Update updated_at timestamp
CREATE TRIGGER detection_details_updated_at BEFORE UPDATE ON detection_details
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ---------------------------------------------------------------------
-- View: Detection Summary (for UI display)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_detection_summary AS
SELECT
    dd.id,
    dd.queue_item_id,
    dd.document_id,
    dd.parse_case,
    dd.confidence,
    dd.match_percentage,
    dd.total_expected,
    dd.total_detected,
    dd.total_expected - dd.total_detected AS total_missing,
    dd.detector_type,
    dd.detected_at,
    -- Extract attribute names for easy display
    (SELECT JSONB_AGG(attr->>'name') FROM JSONB_ARRAY_ELEMENTS(dd.expected_attributes) attr) AS expected_attr_names,
    (SELECT JSONB_AGG(attr->>'name') FROM JSONB_ARRAY_ELEMENTS(dd.detected_attributes) attr) AS detected_attr_names,
    (SELECT JSONB_AGG(attr->>'name') FROM JSONB_ARRAY_ELEMENTS(dd.missing_attributes) attr) AS missing_attr_names,
    -- Document info (if linked)
    d.source_file_name,
    d.file_type,
    d.status AS document_status
FROM detection_details dd
LEFT JOIN documents d ON dd.document_id = d.id;

COMMENT ON VIEW v_detection_summary IS 'Denormalized view of detection details for UI display';

-- ---------------------------------------------------------------------
-- Example data structure documentation
-- ---------------------------------------------------------------------
COMMENT ON COLUMN detection_details.expected_attributes IS
'JSON array format: [{"name": "study_instance_uid", "xpath": "/root/study", "data_type": "string", "required": true}]';

COMMENT ON COLUMN detection_details.detected_attributes IS
'JSON array format: [{"name": "study_instance_uid", "xpath": "/root/study", "value": "1.2.3.4", "found": true}]';

COMMENT ON COLUMN detection_details.field_analysis IS
'JSON array format: [{"field": "study_instance_uid", "expected": true, "found": true, "confidence": 1.0, "xpath": "/root/study", "value_sample": "1.2.3.4"}]';

-- =====================================================================
-- Update schema version
-- =====================================================================
INSERT INTO schema_versions (version, description)
VALUES (15, 'Add detection_details table for parse case identification analysis')
ON CONFLICT (version) DO NOTHING;

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
