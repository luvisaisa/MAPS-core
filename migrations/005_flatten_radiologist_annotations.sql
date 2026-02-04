-- Flatten radiologist annotation JSON into separate columns
-- This creates a view with each characteristic as its own column

DROP VIEW IF EXISTS radiologist_annotations_flat CASCADE;

CREATE VIEW radiologist_annotations_flat AS
SELECT 
    s.segment_id,
    s.file_id,
    f.filename,
    f.file_type,
    s.position_in_file as annotation_number,
    s.extraction_timestamp,
    
    -- Extract numeric values from the content JSON/text
    -- PostgreSQL can parse JSON or use regex for dict strings
    CASE 
        WHEN s.content::text LIKE '%subtlety%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]subtlety[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as subtlety,
    
    CASE 
        WHEN s.content::text LIKE '%internalStructure%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]internalStructure[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as internal_structure,
    
    CASE 
        WHEN s.content::text LIKE '%calcification%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]calcification[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as calcification,
    
    CASE 
        WHEN s.content::text LIKE '%sphericity%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]sphericity[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as sphericity,
    
    CASE 
        WHEN s.content::text LIKE '%margin%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]margin[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as margin,
    
    CASE 
        WHEN s.content::text LIKE '%lobulation%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]lobulation[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as lobulation,
    
    CASE 
        WHEN s.content::text LIKE '%spiculation%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]spiculation[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as spiculation,
    
    CASE 
        WHEN s.content::text LIKE '%texture%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]texture[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as texture,
    
    CASE 
        WHEN s.content::text LIKE '%malignancy%' THEN
            CAST(regexp_replace(
                regexp_replace(s.content::text, '.*[''"]malignancy[''"]:\s*', ''),
                '[,}].*', ''
            ) AS INTEGER)
        ELSE NULL
    END as malignancy
    
FROM unified_segments s
JOIN file_imports f ON s.file_id = f.file_id
WHERE s.segment_type = 'quantitative';

COMMENT ON VIEW radiologist_annotations_flat IS 
'Flattened view of radiologist annotations with each characteristic as a separate column';

-- Create an export-ready table with better column names
DROP MATERIALIZED VIEW IF EXISTS export_radiologist_data CASCADE;

CREATE MATERIALIZED VIEW export_radiologist_data AS
SELECT 
    filename as patient_id,
    annotation_number as radiologist_number,
    subtlety as "Subtlety (1-5)",
    internal_structure as "Internal Structure (1-4)",
    calcification as "Calcification (1-6)",
    sphericity as "Sphericity (1-5)",
    margin as "Margin (1-5)",
    lobulation as "Lobulation (1-5)",
    spiculation as "Spiculation (1-5)",
    texture as "Texture (1-5)",
    malignancy as "Malignancy (1-5)",
    extraction_timestamp as "Import Date"
FROM radiologist_annotations_flat
ORDER BY patient_id, radiologist_number;

CREATE INDEX idx_export_radiologist_patient ON export_radiologist_data(patient_id);
CREATE INDEX idx_export_radiologist_malignancy ON export_radiologist_data("Malignancy (1-5)");

COMMENT ON MATERIALIZED VIEW export_radiologist_data IS 
'Export-ready radiologist annotations with human-readable column names';

-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_radiologist_export()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW export_radiologist_data;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_radiologist_export IS 
'Refresh the export_radiologist_data materialized view with latest data';
