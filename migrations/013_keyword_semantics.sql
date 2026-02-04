-- =============================================================================
-- Migration 013: Canonical Keyword Semantics (EXTENSION)
-- =============================================================================
-- Purpose: Add canonical radiology keyword dictionary with definitions,
-- categories, tags, and AMA citations for curated medical concepts
-- =============================================================================

-- =============================================================================
-- TABLE: Citations (AMA-style references)
-- =============================================================================

CREATE TABLE IF NOT EXISTS citations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    citation_key TEXT UNIQUE NOT NULL,  -- e.g., "ACR_LUNG_RADS", "TSUJI_2021_JMIR"
    ama_citation TEXT NOT NULL,  -- Full AMA-formatted citation
    url TEXT,  -- Link to source
    notes TEXT,  -- Additional context
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_citations_key ON citations(citation_key);

COMMENT ON TABLE citations IS 'AMA-style citations for canonical keywords';
COMMENT ON COLUMN citations.citation_key IS 'Short reference key for linking to canonical keywords';
COMMENT ON COLUMN citations.ama_citation IS 'Full AMA-formatted citation text';

-- =============================================================================
-- TABLE: Canonical Keywords (curated radiology concepts)
-- =============================================================================

CREATE TABLE IF NOT EXISTS canonical_keywords (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    keyword TEXT UNIQUE NOT NULL,  -- Canonical lowercase form (e.g., "lung-rads")
    display_name TEXT NOT NULL,  -- Display form (e.g., "Lung-RADS®")
    short_definition TEXT,  -- 1-3 sentence definition

    -- Categorization
    subject_category TEXT,  -- e.g., "Standardization and Reporting Systems"
    topic_tags TEXT[],  -- e.g., {"Radiomics", "NLP", "LIDC", "TCIA"}

    -- Citation reference
    citation_key TEXT REFERENCES citations(citation_key),

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT keyword_lowercase CHECK (keyword = LOWER(keyword))
);

CREATE INDEX idx_canonical_keyword ON canonical_keywords(keyword);
CREATE INDEX idx_canonical_display_name ON canonical_keywords(display_name);
CREATE INDEX idx_canonical_subject_category ON canonical_keywords(subject_category);
CREATE INDEX idx_canonical_topic_tags ON canonical_keywords USING GIN (topic_tags);
CREATE INDEX idx_canonical_citation_key ON canonical_keywords(citation_key);
CREATE INDEX idx_canonical_active ON canonical_keywords(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE canonical_keywords IS 'Curated radiology concepts with definitions, categories, and citations';
COMMENT ON COLUMN canonical_keywords.keyword IS 'Canonical normalized form (lowercase, consistent punctuation)';
COMMENT ON COLUMN canonical_keywords.display_name IS 'Human-readable display form with proper capitalization';
COMMENT ON COLUMN canonical_keywords.subject_category IS 'Main subject area (e.g., Standardization and Reporting Systems, Radiologist Perceptive and Diagnostic Concepts)';
COMMENT ON COLUMN canonical_keywords.topic_tags IS 'Additional topic tags for filtering (e.g., Radiomics, NLP, LIDC, TCIA, Reporting, Errors, Biomarkers)';

-- =============================================================================
-- TABLE: Canonical Keyword Aliases (mapping variants to canonical)
-- =============================================================================

CREATE TABLE IF NOT EXISTS canonical_keyword_aliases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    canonical_keyword_id UUID NOT NULL REFERENCES canonical_keywords(id) ON DELETE CASCADE,
    alias TEXT UNIQUE NOT NULL,  -- Normalized variant (e.g., "lungrads", "lung rads")
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT alias_lowercase CHECK (alias = LOWER(alias))
);

CREATE INDEX idx_alias_canonical_id ON canonical_keyword_aliases(canonical_keyword_id);
CREATE INDEX idx_alias_text ON canonical_keyword_aliases(alias);

COMMENT ON TABLE canonical_keyword_aliases IS 'Mapping of keyword variants to canonical forms';
COMMENT ON COLUMN canonical_keyword_aliases.alias IS 'Normalized variant form (e.g., "lungrads", "lung-rads", "lung rads" all map to canonical "lung-rads")';

-- =============================================================================
-- ALTER: Add canonical_keyword_id to extracted_keywords
-- =============================================================================

-- Add foreign key to link extracted keywords to canonical entries
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'extracted_keywords'
                   AND column_name = 'canonical_keyword_id') THEN
        ALTER TABLE extracted_keywords
        ADD COLUMN canonical_keyword_id UUID REFERENCES canonical_keywords(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'extracted_keywords'
                   AND column_name = 'raw_keyword') THEN
        ALTER TABLE extracted_keywords
        ADD COLUMN raw_keyword TEXT;
    END IF;
END $$;

-- Create index for linking
CREATE INDEX IF NOT EXISTS idx_extracted_canonical_id ON extracted_keywords(canonical_keyword_id);

-- Update raw_keyword for existing records (copy from term if not set)
UPDATE extracted_keywords
SET raw_keyword = term
WHERE raw_keyword IS NULL;

COMMENT ON COLUMN extracted_keywords.canonical_keyword_id IS 'Link to canonical keyword entry (NULL if no match found)';
COMMENT ON COLUMN extracted_keywords.raw_keyword IS 'Original extracted keyword before normalization';

-- =============================================================================
-- FUNCTION: Normalize keyword for canonical matching
-- =============================================================================

CREATE OR REPLACE FUNCTION normalize_for_canonical(raw_text TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Lowercase
    raw_text := LOWER(raw_text);

    -- Trim whitespace
    raw_text := TRIM(raw_text);

    -- Remove common punctuation variations (but preserve hyphens in most cases)
    raw_text := regexp_replace(raw_text, '®|™|©', '', 'g');

    -- Collapse multiple spaces to single space
    raw_text := regexp_replace(raw_text, '\s+', ' ', 'g');

    -- Remove trailing/leading punctuation
    raw_text := regexp_replace(raw_text, '^[^\w]+|[^\w]+$', '', 'g');

    RETURN raw_text;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION normalize_for_canonical IS 'Normalize text for canonical keyword matching (lowercase, trim, remove symbols)';

-- =============================================================================
-- FUNCTION: Get canonical keyword ID from raw keyword
-- =============================================================================

CREATE OR REPLACE FUNCTION get_canonical_keyword_id(raw_keyword_text TEXT)
RETURNS UUID AS $$
DECLARE
    normalized_text TEXT;
    canonical_id UUID;
BEGIN
    -- Normalize the input
    normalized_text := normalize_for_canonical(raw_keyword_text);

    -- Try exact match on canonical keyword
    SELECT id INTO canonical_id
    FROM canonical_keywords
    WHERE keyword = normalized_text
      AND is_active = TRUE
    LIMIT 1;

    IF canonical_id IS NOT NULL THEN
        RETURN canonical_id;
    END IF;

    -- Try alias match
    SELECT canonical_keyword_id INTO canonical_id
    FROM canonical_keyword_aliases
    WHERE alias = normalized_text
    LIMIT 1;

    RETURN canonical_id;  -- Returns NULL if no match
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_canonical_keyword_id IS 'Lookup canonical keyword ID from raw keyword text (checks canonical + aliases)';

-- =============================================================================
-- FUNCTION: Backfill canonical keyword IDs for existing extracted keywords
-- =============================================================================

CREATE OR REPLACE FUNCTION backfill_canonical_keyword_ids()
RETURNS TABLE(
    updated_count BIGINT,
    matched_count BIGINT,
    unmatched_count BIGINT
) AS $$
DECLARE
    v_updated BIGINT := 0;
    v_matched BIGINT := 0;
    v_unmatched BIGINT;
BEGIN
    -- Update extracted_keywords with canonical IDs where possible
    UPDATE extracted_keywords ek
    SET canonical_keyword_id = get_canonical_keyword_id(ek.normalized_term)
    WHERE ek.canonical_keyword_id IS NULL;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    -- Count how many now have canonical IDs
    SELECT COUNT(*) INTO v_matched
    FROM extracted_keywords
    WHERE canonical_keyword_id IS NOT NULL;

    -- Count how many still don't have canonical IDs
    SELECT COUNT(*) INTO v_unmatched
    FROM extracted_keywords
    WHERE canonical_keyword_id IS NULL;

    RETURN QUERY SELECT v_updated, v_matched, v_unmatched;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION backfill_canonical_keyword_ids IS 'Update existing extracted_keywords with canonical_keyword_id where matches exist';

-- =============================================================================
-- TRIGGER: Auto-link new extracted keywords to canonical on INSERT
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_link_canonical_keyword()
RETURNS TRIGGER AS $$
BEGIN
    -- Try to link to canonical keyword
    NEW.canonical_keyword_id := get_canonical_keyword_id(NEW.normalized_term);

    -- Store raw keyword if not already set
    IF NEW.raw_keyword IS NULL THEN
        NEW.raw_keyword := NEW.term;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS link_canonical_keyword ON extracted_keywords;
CREATE TRIGGER link_canonical_keyword
    BEFORE INSERT OR UPDATE ON extracted_keywords
    FOR EACH ROW
    EXECUTE FUNCTION trigger_link_canonical_keyword();

COMMENT ON FUNCTION trigger_link_canonical_keyword IS 'Automatically link extracted keywords to canonical entries on INSERT/UPDATE';

-- =============================================================================
-- SEED DATA: Sample Canonical Keywords and Citations
-- =============================================================================

-- Insert sample citations
INSERT INTO citations (citation_key, ama_citation, url, notes) VALUES
(
    'ACR_LUNG_RADS',
    'American College of Radiology. Lung-RADS® Assessment Categories Version 1.1. Published 2019. Accessed November 21, 2025. https://www.acr.org/Clinical-Resources/Reporting-and-Data-Systems/Lung-Rads',
    'https://www.acr.org/Clinical-Resources/Reporting-and-Data-Systems/Lung-Rads',
    'Official ACR Lung-RADS standardized reporting system'
),
(
    'RSNA_RADLEX',
    'Langlotz CP. RadLex: a new method for indexing online educational materials. RadioGraphics. 2006;26(6):1595-1597. doi:10.1148/rg.266065168',
    'https://www.rsna.org/practice-tools/data-tools-and-standards/radlex',
    'RadLex radiology lexicon from RSNA'
),
(
    'LIDC_IDRI_TCIA',
    'Armato SG 3rd, McLennan G, Bidaut L, et al. The Lung Image Database Consortium (LIDC) and Image Database Resource Initiative (IDRI): a completed reference database of lung nodules on CT scans. Med Phys. 2011;38(2):915-931. doi:10.1118/1.3528204',
    'https://wiki.cancerimagingarchive.net/display/Public/LIDC-IDRI',
    'Original LIDC-IDRI dataset publication'
),
(
    'TCIA_OVERVIEW',
    'Clark K, Vendt B, Smith K, et al. The Cancer Imaging Archive (TCIA): maintaining and operating a public information repository. J Digit Imaging. 2013;26(6):1045-1057. doi:10.1007/s10278-013-9622-7',
    'https://www.cancerimagingarchive.net',
    'TCIA repository overview'
),
(
    'RADIOMICS_PRIMER',
    'Gillies RJ, Kinahan PE, Hricak H. Radiomics: Images Are More than Pictures, They Are Data. Radiology. 2016;278(2):563-577. doi:10.1148/radiol.2015151169',
    'https://pubs.rsna.org/doi/10.1148/radiol.2015151169',
    'Foundational radiomics paper'
),
(
    'CTAKES_NLP',
    'Savova GK, Masanz JJ, Ogren PV, et al. Mayo clinical Text Analysis and Knowledge Extraction System (cTAKES): architecture, component evaluation and applications. J Am Med Inform Assoc. 2010;17(5):507-513. doi:10.1136/jamia.2009.001560',
    'https://ctakes.apache.org',
    'cTAKES NLP system for clinical text'
)
ON CONFLICT (citation_key) DO NOTHING;

-- Insert sample canonical keywords
INSERT INTO canonical_keywords (keyword, display_name, short_definition, subject_category, topic_tags, citation_key) VALUES
-- Standardization and Reporting Systems
(
    'lung-rads',
    'Lung-RADS®',
    'Lung CT Screening Reporting & Data System developed by the American College of Radiology for standardized assessment and management recommendations for lung nodules detected on CT screening.',
    'Standardization and Reporting Systems',
    ARRAY['Reporting', 'Standardization', 'Screening'],
    'ACR_LUNG_RADS'
),
(
    'radlex',
    'RadLex',
    'A comprehensive lexicon of radiology terms developed by the Radiological Society of North America (RSNA) for standardized indexing and retrieval of radiology information.',
    'Standardization and Reporting Systems',
    ARRAY['Terminology', 'Standardization', 'Ontology'],
    'RSNA_RADLEX'
),
(
    'rads',
    'RADS',
    'Reporting and Data Systems - standardized lexicons for structured radiology reporting across various organ systems (e.g., Lung-RADS, BI-RADS, LI-RADS, TI-RADS).',
    'Standardization and Reporting Systems',
    ARRAY['Reporting', 'Standardization'],
    NULL
),

-- Radiologist Perceptive and Diagnostic Concepts
(
    'malignancy',
    'Malignancy',
    'The degree to which a nodule appears cancerous on imaging, typically rated on a scale (e.g., 1-5 in LIDC-IDRI, where 1=highly unlikely malignant, 5=highly suspicious for malignancy).',
    'Radiologist Perceptive and Diagnostic Concepts',
    ARRAY['LIDC', 'Diagnosis', 'Nodule Characteristics'],
    'LIDC_IDRI_TCIA'
),
(
    'spiculation',
    'Spiculation',
    'The presence of linear strands radiating from the margin of a nodule, often indicating malignancy. Rated 1-5 in LIDC-IDRI (1=marked spiculation, 5=no spiculation).',
    'Radiologist Perceptive and Diagnostic Concepts',
    ARRAY['LIDC', 'Nodule Characteristics', 'Morphology'],
    'LIDC_IDRI_TCIA'
),
(
    'subtlety',
    'Subtlety',
    'The difficulty in detecting a nodule on CT imaging, rated 1-5 in LIDC-IDRI (1=extremely subtle, 5=obvious).',
    'Radiologist Perceptive and Diagnostic Concepts',
    ARRAY['LIDC', 'Nodule Characteristics'],
    'LIDC_IDRI_TCIA'
),
(
    'lobulation',
    'Lobulation',
    'Undulations or irregular contours along the nodule margin. Rated 1-5 in LIDC-IDRI (1=marked lobulation, 5=no lobulation).',
    'Radiologist Perceptive and Diagnostic Concepts',
    ARRAY['LIDC', 'Nodule Characteristics', 'Morphology'],
    'LIDC_IDRI_TCIA'
),

-- Imaging Biomarkers and Computational Analysis
(
    'radiomics',
    'Radiomics',
    'High-throughput extraction of quantitative features from medical images for predictive modeling and decision support. Converts images into mineable data.',
    'Imaging Biomarkers and Computational Analysis',
    ARRAY['Radiomics', 'Biomarkers', 'Machine Learning'],
    'RADIOMICS_PRIMER'
),
(
    'texture',
    'Texture',
    'The internal attenuation pattern of a nodule (solid, ground-glass, or mixed). Rated 1-5 in LIDC-IDRI (1=non-solid/ground glass, 5=solid).',
    'Imaging Biomarkers and Computational Analysis',
    ARRAY['LIDC', 'Nodule Characteristics', 'Radiomics'],
    'LIDC_IDRI_TCIA'
),
(
    'qib',
    'QIB',
    'Quantitative Imaging Biomarker - an objectively measured characteristic derived from medical images used as an indicator of biological processes or responses to therapeutic intervention.',
    'Imaging Biomarkers and Computational Analysis',
    ARRAY['Biomarkers', 'Quantitative Imaging'],
    NULL
),

-- Pulmonary Nodule Terminology and Databases
(
    'lidc',
    'LIDC',
    'Lung Image Database Consortium - a collaborative effort to develop a large database of thoracic CT scans with radiologist annotations for lung nodule detection and classification research.',
    'Pulmonary Nodule Terminology and Databases',
    ARRAY['LIDC', 'TCIA', 'Database'],
    'LIDC_IDRI_TCIA'
),
(
    'lidc-idri',
    'LIDC-IDRI',
    'Lung Image Database Consortium - Image Database Resource Initiative dataset containing 1,018 cases with CT scans and radiologist annotations available through TCIA.',
    'Pulmonary Nodule Terminology and Databases',
    ARRAY['LIDC', 'TCIA', 'Database'],
    'LIDC_IDRI_TCIA'
),
(
    'tcia',
    'TCIA',
    'The Cancer Imaging Archive - a service which de-identifies and hosts a large archive of medical images of cancer accessible for public download.',
    'Pulmonary Nodule Terminology and Databases',
    ARRAY['TCIA', 'Database', 'Repository'],
    'TCIA_OVERVIEW'
),

-- NLP and Information Extraction
(
    'ner',
    'NER',
    'Named Entity Recognition - NLP task of identifying and classifying named entities (e.g., anatomical terms, disease mentions) in unstructured text.',
    'NLP and Information Extraction',
    ARRAY['NLP', 'Information Extraction'],
    NULL
),
(
    'ctakes',
    'cTAKES',
    'Clinical Text Analysis and Knowledge Extraction System - Apache open-source NLP system for extracting clinical information from electronic health record text.',
    'NLP and Information Extraction',
    ARRAY['NLP', 'Information Extraction', 'Clinical Text'],
    'CTAKES_NLP'
),

-- Performance Metrics
(
    'precision',
    'Precision',
    'In NER and classification tasks, the proportion of predicted positive cases that are truly positive (TP / (TP + FP)). Also called positive predictive value.',
    'Performance Metrics (NER)',
    ARRAY['NLP', 'Metrics', 'Evaluation'],
    NULL
),
(
    'recall',
    'Recall',
    'In NER and classification tasks, the proportion of actual positive cases that are correctly identified (TP / (TP + FN)). Also called sensitivity.',
    'Performance Metrics (NER)',
    ARRAY['NLP', 'Metrics', 'Evaluation'],
    NULL
),
(
    'f-measure',
    'F-measure',
    'Harmonic mean of precision and recall, providing a single metric that balances both. F1 = 2 * (precision * recall) / (precision + recall).',
    'Performance Metrics (NER)',
    ARRAY['NLP', 'Metrics', 'Evaluation'],
    NULL
)
ON CONFLICT (keyword) DO NOTHING;

-- Insert aliases for common variations
INSERT INTO canonical_keyword_aliases (canonical_keyword_id, alias)
SELECT ck.id, unnest(ARRAY[
    -- Lung-RADS variations
    'lungrads', 'lung rads', 'lung-rad', 'lungrad',
    -- RadLex variations
    'rad-lex', 'rad lex',
    -- LIDC variations
    'lidc idri', 'lidcidri',
    -- TCIA variations
    'cancer imaging archive',
    -- Radiomics variations
    'radiomic', 'radiomics analysis',
    -- NER variations
    'named entity recognition', 'entity recognition',
    -- cTAKES variations
    'ctakes', 'clinical takes',
    -- F-measure variations
    'f1', 'f-score', 'f1-score', 'fscore', 'f measure'
]) AS alias
FROM canonical_keywords ck
WHERE ck.keyword IN ('lung-rads', 'radlex', 'lidc-idri', 'tcia', 'radiomics', 'ner', 'ctakes', 'f-measure')
ON CONFLICT (alias) DO NOTHING;

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

COMMENT ON SCHEMA public IS 'Migration 013: Canonical keyword semantics with citations and categories installed';
