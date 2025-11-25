# Quick Start: Schema-Agnostic Case Identifier

## Setup (5 minutes)

### 1. Create Supabase Project
```bash
# Go to https://supabase.com and create a new project
# Note your project URL and anon key
```

### 2. Run Database Migration
```bash
# In Supabase SQL Editor, paste and run:
migrations/002_unified_case_identifier_schema.sql
```

### 3. Install Dependencies
```bash
npm install @supabase/supabase-js xml2js pdf-parse mammoth xlsx
```

### 4. Set Environment Variables
```bash
# .env
SUPABASE_URL=https://yourproject.supabase.co
SUPABASE_KEY=your_anon_key
```

## Minimal Working Example

```typescript
import { createClient } from '@supabase/supabase-js';
import {
  UnifiedFileProcessor,
  FormatParserFactory,
  ContentAnalyzer,
  SegmentClassifier,
  KeywordExtractor,
  KeywordProcessor
} from './case_identifier';

// Initialize
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_KEY!
);

const processor = new UnifiedFileProcessor(
  new FormatParserFactory(),
  new ContentAnalyzer(),
  new SegmentClassifier(),
  new KeywordExtractor(
    supabase,
    await KeywordProcessor.create(supabase)
  ),
  supabase
);

// Process any file
await processor.processFile('./data.csv', 'data.csv');
await processor.processFile('./notes.pdf', 'notes.pdf');
await processor.processFile('./results.xlsx', 'results.xlsx');

// Query
const { CrossContentQueryBuilder } = await import('./query-interface');
const query = new CrossContentQueryBuilder(supabase);

// Find keywords in both data and text
const keywords = await query.findCrossTypeKeywords({ limit: 10 });
console.log(keywords);
```

## Common Workflows

### Workflow 1: Process Directory of Mixed Files

```typescript
import { readdir } from 'fs/promises';

const files = await readdir('./data');
for (const filename of files) {
  await processor.processFile(`./data/${filename}`, filename);
}
```

### Workflow 2: Find Files Mentioning Specific Topics

```typescript
const files = await query.findFilesWithKeywords([
  'patient',
  'treatment',
  'outcome'
]);

console.log(`Found ${files.length} relevant files`);
```

### Workflow 3: Extract Measurements from Any Source

```typescript
const measurements = await query.getKeywordNumericAssociations('dosage');
const values = measurements.map(m => m.associated_values);
```

### Workflow 4: Detect Research Themes

```typescript
import { CasePatternDetector } from './case-detector';

const detector = new CasePatternDetector(supabase);
const themes = await detector.detectPatterns({
  minKeywordCount: 4,
  minConfidenceScore: 0.7,
  requireCrossTypeValidation: true
});

for (const theme of themes) {
  console.log(`Theme: ${theme.keywords.map(k => k.term).join(', ')}`);
}
```

## What the System Does

1. **Parse**: Reads ANY file format into unified structure
2. **Analyze**: Calculates numeric vs text density
3. **Classify**: Segments into quantitative/qualitative/mixed
4. **Extract**: Finds keywords with context + numeric associations
5. **Store**: Saves to Supabase with full relational structure
6. **Query**: Cross-content searches across all types
7. **Detect**: Identifies keyword clusters as "cases"

## Key Insights

 **No file type assumptions**: CSV may have narrative notes, PDF may have data tables  
 **Content-based classification**: System analyzes actual content, not file extension  
 **Cross-type keywords are high signal**: Terms appearing in BOTH data and narrative are most important  
 **Numeric associations**: Track which values relate to which concepts  
 **Case patterns emerge automatically**: System finds themes you didn't explicitly search for  

## Troubleshooting

**Problem**: File processing fails  
**Solution**: Check file encoding (UTF-8 required), verify file isn't corrupted

**Problem**: No keywords extracted  
**Solution**: Check stop word configuration, verify content isn't all filtered out

**Problem**: Low relevance scores  
**Solution**: Run `keywordProcessor.updateRelevanceScores()` after processing multiple files

**Problem**: No case patterns detected  
**Solution**: Lower `minCoOccurrenceThreshold` and `minConfidenceScore` parameters

## Next Steps

1. Process your first batch of files (5-10 mixed types)
2. Query `cross_type_keywords` view to find high-signal terms
3. Run case pattern detection
4. Explore numeric associations for quantitative keywords
5. Add domain-specific stop words as needed

## Full Documentation

See `docs/CASE_IDENTIFIER_README.md` for complete API reference and advanced usage.

## Example Queries (SQL)

```sql
-- Top 20 keywords by relevance
SELECT term, relevance_score, document_frequency
FROM extracted_keywords
ORDER BY relevance_score DESC
LIMIT 20;

-- Keywords in both data and text
SELECT * FROM cross_type_keywords
WHERE quantitative_occurrences > 0 
AND qualitative_occurrences > 0
ORDER BY relevance_score DESC;

-- All files processed
SELECT filename, extension, processing_status, 
       import_timestamp
FROM file_imports
ORDER BY import_timestamp DESC;

-- Detected cases
SELECT keyword_count, confidence_score, 
       cross_type_validated, keywords
FROM case_patterns
WHERE confidence_score > 0.7
ORDER BY confidence_score DESC;
```

## Architecture Diagram

```

     CSV  JSON  XML  PDF  DOCX  XLSX     

             
             

      Format-Specific Parsers            
  (CSV→rows, XML→tree, PDF→text blocks)  

             
             

       Content Analyzer                  
  Calculate numeric_density,             
  detect prose, infer schema             

             
             

     Segment Classifier                  
  >70% numeric → quantitative            
  >70% text → qualitative                
  30-70% → mixed                         

             
             

     Keyword Extractor                   
  N-grams, entities, headers             
  Stop word filter, relevance score      

             
             

        Supabase Storage                 
  file_imports, segments, keywords       
  With full-text search & GIN indexes    

             
             

   Query & Pattern Detection             
  Cross-type search, case clustering     

```

Start small, iterate quickly! 
