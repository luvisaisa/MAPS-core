-- Enable Row Level Security for read-only access
-- Run this in Supabase SQL Editor

-- Allow anonymous users to read from analysis views
ALTER TABLE master_analysis_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous read access to master_analysis_table"
ON master_analysis_table
FOR SELECT
TO anon
USING (true);

-- Same for export table
ALTER TABLE export_ready_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous read access to export_ready_table"
ON export_ready_table
FOR SELECT
TO anon
USING (true);

-- Optional: Create a public API endpoint
-- Users can access data via:
-- https://YOUR_PROJECT.supabase.co/rest/v1/master_analysis_table
-- Using your anon key in header: apikey: YOUR_ANON_KEY

-- Example curl command for non-technical users:
-- curl "https://YOUR_PROJECT.supabase.co/rest/v1/master_analysis_table?select=*" \
--   -H "apikey: YOUR_ANON_KEY" \
--   -H "Authorization: Bearer YOUR_ANON_KEY"
