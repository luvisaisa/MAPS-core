# Schema-Agnostic Case Identifier System

A unified system for processing ANY file type (CSV, JSON, XML, PDF, Word, Excel) through a single pipeline that classifies content as quantitative, qualitative, or mixed, extracts keywords with context, and identifies case patterns across all content types.

## Architecture Overview

```
ANY FILE → Parse → Analyze → Classify → Extract Keywords → Store in Supabase → Query & Detect Patterns
```

**Core Principle**: Content types, not file types
- No assumptions about whether a file contains data or text
- Same processing flow handles all formats
- Classification based on actual content analysis

## Key Features

 **Unified Import Pipeline**: All file types processed identically  
 **Content-Based Classification**: Segments classified as quantitative (>70% numeric), qualitative (>70% text), or mixed (30-70%)  
 **Intelligent Keyword Extraction**: N-grams, named entities, column headers, categorical values  
 **Stop Word Filtering**: Configurable exclusion with preservation of technical terms  
 **Multi-Factor Relevance Scoring**: TF-IDF × position_weight × cross_type_bonus × numeric_association  
 **Cross-Content Queries**: Find keywords spanning both data and narrative  
 **Case Pattern Detection**: Automatic clustering of co-occurring keywords  
 **Numeric Associations**: Track values linked to each keyword  
 **Supabase Backend**: Full relational querying with RLS policies

## Database Schema

### Source Tracking
- **file_imports**: All imported files (any format) with processing status

### Content Segments
- **quantitative_segments**: Numerical data, tables, structured values (>70% numeric)
- **qualitative_segments**: Text passages, narratives, descriptions (>70% text)
- **mixed_segments**: Interleaved quan/qual content (30-70% numeric)

### Keyword System
- **stop_words**: Configurable exclusion list
- **extracted_keywords**: Unique terms with aggregated statistics
- **keyword_occurrences**: Each instance with context (polymorphic: links to ANY segment type)

### Case Identification
- **case_patterns**: Detected clusters based on keyword co-occurrence

### Views & Functions
- **unified_segments**: All segments across types
- **cross_type_keywords**: Keywords in BOTH quan and qual
- **keyword_numeric_associations**: Numbers linked to keywords
- **get_keyword_contexts()**: Retrieve all contexts for a term
- **find_files_with_keywords()**: Files containing keyword pattern

## Installation

### 1. Database Setup

```sql
-- Run the schema migration
psql -U postgres -d your_database -f migrations/002_unified_case_identifier_schema.sql
```

### 2. TypeScript Dependencies

```bash
npm install @supabase/supabase-js
npm install xml2js pdf-parse mammoth xlsx
npm install @types/node @types/xml2js
```

### 3. Environment Variables

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
```

## Usage

### Basic File Processing

```typescript
import { createClient } from '@supabase/supabase-js';
import { UnifiedFileProcessor, FormatParserFactory } from './file-processor';
import { ContentAnalyzer, SegmentClassifier } from './content-analyzer';
import { KeywordExtractor } from './keyword-extractor';
import { KeywordProcessor } from './keyword-relevance';

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_KEY!);

// Initialize pipeline
const formatParser = new FormatParserFactory();
const contentAnalyzer = new ContentAnalyzer();
const segmentClassifier = new SegmentClassifier();
const keywordProcessor = new KeywordProcessor(supabase);
await keywordProcessor.initialize();
const keywordExtractor = new KeywordExtractor(supabase, keywordProcessor);

const processor = new UnifiedFileProcessor(
  formatParser,
  contentAnalyzer,
  segmentClassifier,
  keywordExtractor,
  supabase
);

// Process any file type
const fileId = await processor.processFile('/path/to/file.csv', 'file.csv');
```

### Cross-Type Keyword Search

```typescript
import { CrossContentQueryBuilder } from './query-interface';

const queryBuilder = new CrossContentQueryBuilder(supabase);

// Find keywords appearing in BOTH quantitative and qualitative content
const crossTypeKeywords = await queryBuilder.findCrossTypeKeywords({
  minRelevanceScore: 10,
  minFileCount: 2,
  limit: 20
});

for (const keyword of crossTypeKeywords) {
  console.log(`${keyword.term}: ${keyword.relevance_score}`);
}
```

### Numeric Associations

```typescript
// Get all numbers associated with a keyword
const associations = await queryBuilder.getKeywordNumericAssociations('dosage');

for (const assoc of associations) {
  console.log(`${assoc.filename}: ${assoc.associated_values}`);
}
```

### Case Pattern Detection

```typescript
import { CasePatternDetector } from './case-detector';

const detector = new CasePatternDetector(supabase);

// Detect patterns with cross-type validation
const patterns = await detector.detectPatterns({
  minKeywordCount: 3,
  minCoOccurrenceThreshold: 2,
  minConfidenceScore: 0.6,
  requireCrossTypeValidation: true
});

for (const pattern of patterns) {
  console.log(`Pattern: ${pattern.keywords.map(k => k.term).join(', ')}`);
  console.log(`Confidence: ${pattern.confidence_score}`);
}
```

## Content Classification

### Classification Heuristics

**Quantitative (numeric_density >= 0.70)**:
- High ratio of numbers, dates, currencies
- Tabular structures with numeric columns
- Schema inferred from structured data

**Qualitative (numeric_density <= 0.30)**:
- Natural language prose
- Sentence structure with punctuation
- Multi-paragraph text passages

**Mixed (0.30 < numeric_density < 0.70)**:
- Annotated data tables
- Key-value pairs with text values
- XML with nested text + numbers

### Detection Algorithm

```typescript
// For each parsed element:
1. Calculate numeric density (ratio of numeric tokens)
2. Detect prose patterns (sentence structure)
3. Identify structural markers (tables, trees)
4. Infer schema for structured content
5. Classify based on density thresholds
```

## Keyword Extraction

### Source-Specific Strategies

**From Quantitative Segments**:
- Column headers / field names
- Repeated categorical values
- Enum-like patterns
- Numeric context stored with each occurrence

**From Qualitative Segments**:
- N-gram extraction (1-3 words)
- Named entity recognition (capitalized phrases, quoted terms)
- Section-aware weighting (abstract > body)

**From Mixed Segments**:
- Extract from both text and numeric elements
- Maintain link between keywords and neighboring numbers
- XML attributes and element tags as structural keywords

### Stop Word Filtering

**Excluded by Default**:
- Common English (~300 terms): articles, prepositions, pronouns
- Academic phrases: "et al", "ibid", "figure"
- Structural noise: "null", "undefined", "N/A"
- Single characters and short numbers

**Preserved**:
- Technical terms and acronyms (e.g., "API", "HTTP")
- Proper nouns (capitalized phrases)
- Meaningful codes (e.g., "B2B", "24/7", "COVID-19")

### Relevance Scoring

```
relevance_score = 
  term_frequency × 
  inverse_document_frequency × 
  position_weight × 
  cross_type_bonus × 
  numeric_association_weight
```

**Position Weight**: 2.0× for headers/titles, 1.5× for first paragraph, 1.7× for column headers

**Cross-Type Bonus**: 1.8× if appears in both quan and qual, 2.0× if in all three types

**Numeric Association Weight**: 1.0-1.5× based on frequency near significant numbers

## Query Patterns

### Find Keywords Spanning Content Types

```sql
SELECT * FROM cross_type_keywords
WHERE relevance_score > 10
AND file_count >= 2
ORDER BY relevance_score DESC;
```

### Get All Contexts for a Keyword

```sql
SELECT * FROM get_keyword_contexts('treatment');
```

### Find Files with Keyword Pattern

```sql
SELECT * FROM find_files_with_keywords(ARRAY['patient', 'treatment', 'outcome']);
```

### Compare Distributions

```typescript
const csvKeywords = await queryBuilder.compareKeywordDistributions({
  extension: 'csv',
  topN: 20
});

const pdfKeywords = await queryBuilder.compareKeywordDistributions({
  extension: 'pdf',
  topN: 20
});
```

## Case Pattern Detection

### Algorithm

1. **Find Co-Occurrences**: Build matrix of keywords appearing together in segments
2. **Extract Clusters**: Use connected components to find keyword groups
3. **Calculate Confidence**: 
   - Keyword count (more = higher)
   - Segment frequency (more = higher)
   - Cross-type validation (big boost)
   - Average relevance of keywords
4. **Store Patterns**: Deduplicate using signature hash

### Confidence Score Formula

```
confidence = 
  (keyword_count/10 * 0.3) +
  (segment_count/20 * 0.2) +
  (cross_type_validated * 0.3) +
  (avg_relevance/100 * 0.2)
```

## Edge Cases & Handling

### Empty Files
- Parser returns empty array
- No segments created
- File marked as "complete" with 0 segments

### Corrupt Data
- Processing status set to "failed"
- Error message stored in `processing_error` column
- Can be reprocessed after fixing source

### Purely One Type
- File classified entirely as quantitative or qualitative
- Still processes through same pipeline
- May have lower keyword diversity

### Keywords That Are Numbers
- Special handling for meaningful codes (e.g., "365", "24/7")
- Pure numbers < 3 digits filtered out
- Numbers with context preserved (e.g., "COVID-19")

### Idempotent Imports
- Content hash calculated (SHA-256)
- Reimporting same file updates existing record
- No duplicates created

## Performance Considerations

### Classification Speed
- CSV/TSV: ~1000 rows/sec
- JSON/XML: Depends on nesting depth
- PDF: ~10 pages/sec (text extraction)

### Indexing
- GIN indexes on JSONB columns
- Full-text search indexes on qualitative content
- Composite indexes on common query patterns

### Streaming Large Files
- Use streaming parser for files >10MB
- Process in chunks to avoid memory issues
- Batch insert segments and keywords

## Trade-Offs

### Accuracy vs Speed
- More sophisticated NLP would improve entity recognition but slow processing
- Current approach: Fast heuristics with good-enough accuracy

### Strict vs Flexible
- Mixed category (30-70%) catches edge cases
- Could tighten thresholds (40-60%) for stricter classification

### Precision vs Recall
- Stop word filtering prioritizes precision (fewer false positives)
- N-gram extraction prioritizes recall (catch all potential keywords)

## Extending the System

### Add New File Parser

```typescript
class CustomParser implements FileParser {
  async parse(filePath: string): Promise<ParsedElement[]> {
    // Your parsing logic
    return elements;
  }
}

formatParser.registerParser('custom', new CustomParser());
```

### Custom Classification Thresholds

```typescript
const customSegmentType = segmentClassifier.classifyWithThresholds(
  analysis,
  0.80,  // quantThreshold
  0.20   // mixedLowerBound
);
```

### Add Domain-Specific Stop Words

```typescript
await keywordProcessor.getFilter().addStopWords(
  ['domain', 'specific', 'terms'],
  'domain_specific'
);
```

## License

MIT

## Support

See `examples.ts` for comprehensive usage examples covering all features.
