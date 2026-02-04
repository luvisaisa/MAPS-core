# Performance Optimization Deployment Checklist

##  Pre-Deployment Verification

### Code Changes Review
- [x] Backend caching layer implemented (`pylidc_service.py`)
- [x] Database connection pooling configured (`dependencies.py`)
- [x] Keyword service caching added (`keyword_service.py`)
- [x] Response compression middleware added (`main.py`)
- [x] Configuration settings updated (`config.py`)
- [x] Frontend debouncing implemented (`PYLIDCIntegration.tsx`)
- [x] Pagination prefetching added (React Query)
- [x] Loading skeleton states created
- [x] Custom debounce hook created (`useDebounce.ts`)

### Documentation
- [x] Performance optimization report created
- [x] Quick reference guide generated
- [x] Database migration SQL prepared
- [x] Deployment checklist (this file)

### Testing Status
- [ ] Backend unit tests passing
- [ ] Frontend TypeScript compilation successful
- [ ] Integration tests validated
- [ ] Performance benchmarks measured

---

##  Deployment Steps

### Step 1: Backup Current State
```bash
# Backup database
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup environment config
cp .env .env.backup
```

### Step 2: Update Backend Dependencies
```bash
# Ensure SQLAlchemy 2.0+ installed
pip install --upgrade sqlalchemy psycopg2-binary

# Verify installation
python -c "import sqlalchemy; print(sqlalchemy.__version__)"
# Should be 2.0.0 or higher
```

### Step 3: Update Environment Variables
```bash
# Add to .env
cat >> .env << EOF

# Performance Optimization Settings (added $(date +%Y-%m-%d))
CACHE_TTL=300
PYLIDC_CACHE_TTL=3600
ENABLE_RESPONSE_COMPRESSION=true

# Database Connection Pooling
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10
DB_POOL_RECYCLE=3600
DB_POOL_TIMEOUT=30
EOF
```

### Step 4: Apply Database Indexes (Optional but Recommended)
```bash
# Connect to Supabase and run migration
psql $SUPABASE_DB_URL -f migrations/performance_indexes.sql

# Verify indexes created
psql $SUPABASE_DB_URL -c "SELECT indexname FROM pg_indexes WHERE tablename='keyword_directory';"
```

### Step 5: Deploy Backend
```bash
# Pull latest code
git pull origin main

# Restart backend
pkill -f "uvicorn.*8000" || true
python -m uvicorn src.maps.api.main:app --host 0.0.0.0 --port 8000 &

# Wait for startup
sleep 5

# Verify health
curl http://localhost:8000/health
```

### Step 6: Deploy Frontend
```bash
cd web

# Install dependencies (if package.json changed)
npm install

# Build for production
npm run build

# Start frontend
npm run dev &  # or deploy dist/ to hosting

# Verify frontend loads
curl http://localhost:5173/
```

### Step 7: Warm Caches (Optional)
```bash
# Trigger PYLIDC cache population
curl "http://localhost:8000/api/v1/pylidc/scans?page=1&page_size=30"

# Trigger keyword cache population
curl "http://localhost:8000/api/v1/keywords/directory"
curl "http://localhost:8000/api/v1/keywords/search?query=nodule&limit=50"
```

---

##  Post-Deployment Validation

### Backend Health Checks
```bash
# 1. API health
curl http://localhost:8000/health
# Expected: {"status":"healthy","service":"MAPS API","version":"1.0.0"}

# 2. PYLIDC endpoint (first call - cold cache)
time curl "http://localhost:8000/api/v1/pylidc/scans?page=1&page_size=5" > /dev/null
# Expected: 5-40 seconds (depending on PYLIDC dataset access)

# 3. PYLIDC endpoint (second call - warm cache)
time curl "http://localhost:8000/api/v1/pylidc/scans?page=1&page_size=5" > /dev/null
# Expected: <1 second

# 4. Keyword search (first call)
time curl "http://localhost:8000/api/v1/keywords/search?query=lung" > /dev/null
# Expected: 300-500ms

# 5. Keyword search (second call)
time curl "http://localhost:8000/api/v1/keywords/search?query=lung" > /dev/null
# Expected: <100ms

# 6. Response compression check
curl -H "Accept-Encoding: gzip" -I "http://localhost:8000/api/v1/pylidc/scans?page=1"
# Expected: Content-Encoding: gzip

# 7. Connection pool stress test
ab -n 100 -c 10 http://localhost:8000/health
# Expected: No errors, consistent response times
```

### Frontend Validation
```bash
# 1. Check frontend loads
curl -I http://localhost:5173/
# Expected: 200 OK

# 2. Open in browser
open http://localhost:5173/pylidc

# Manual checks:
# - PYLIDC page loads without errors
# - Filter inputs don't trigger immediate API calls (500ms debounce)
# - Loading skeleton appears during fetch
# - Next page navigation feels instant (prefetch working)
# - Browser Network tab shows GZip compression
```

### Performance Benchmarks
```bash
# Run performance test suite
curl -w "\n\ntime_namelookup:  %{time_namelookup}\n\
time_connect:  %{time_connect}\n\
time_appconnect:  %{time_appconnect}\n\
time_pretransfer:  %{time_pretransfer}\n\
time_redirect:  %{time_redirect}\n\
time_starttransfer:  %{time_starttransfer}\n\
----------\n\
time_total:  %{time_total}\n\
size_download:  %{size_download}\n" \
-o /dev/null -s \
"http://localhost:8000/api/v1/pylidc/scans?page=1&page_size=30"
```

**Expected Results:**
| Metric | Target | Pass/Fail |
|--------|--------|-----------|
| PYLIDC cached | <1s |  |
| Keyword cached | <100ms |  |
| Response compressed | >60% |  |
| No connection errors | 100% |  |
| Frontend loads | <2s |  |

---

##  Monitoring Setup

### Add Logging for Cache Metrics
```python
# Add to pylidc_service.py or create metrics endpoint
import logging
logger = logging.getLogger(__name__)

def _get_cached(key: str):
    cached = # ... existing logic
    if cached:
        logger.info(f"Cache HIT: {key}")
    else:
        logger.info(f"Cache MISS: {key}")
    return cached
```

### Monitor Database Connection Pool
```bash
# Add to dependencies.py or create metrics endpoint
@app.get("/api/v1/metrics/database")
def get_db_pool_stats():
    pool = engine.pool
    return {
        "pool_size": pool.size(),
        "checked_in": pool.checkedin(),
        "checked_out": pool.checkedout(),
        "overflow": pool.overflow(),
        "status": "healthy"
    }

# Test endpoint
curl http://localhost:8000/api/v1/metrics/database
```

### Browser Performance Monitoring
```javascript
// Add to web/src/main.tsx
window.addEventListener('load', () => {
  const perfData = window.performance.timing;
  const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;
  console.log(`Page load time: ${pageLoadTime}ms`);
});
```

---

##  Rollback Plan

### If Issues Occur

**Symptom: Backend crashes or errors**
```bash
# 1. Revert to previous code
git revert HEAD
git push origin main

# 2. Restart with old .env
cp .env.backup .env
pkill -f uvicorn
python -m uvicorn src.maps.api.main:app --host 0.0.0.0 --port 8000 &
```

**Symptom: Database connection errors**
```bash
# 1. Remove connection pooling settings
sed -i.bak '/DB_POOL/d' .env

# 2. Restart backend
pkill -f uvicorn
python -m uvicorn src.maps.api.main:app --host 0.0.0.0 --port 8000 &
```

**Symptom: Caching issues (stale data)**
```bash
# 1. Reduce cache TTL
export CACHE_TTL=60
export PYLIDC_CACHE_TTL=300

# 2. Restart backend to clear cache
pkill -f uvicorn
python -m uvicorn src.maps.api.main:app --host 0.0.0.0 --port 8000 &
```

**Symptom: Frontend errors**
```bash
# 1. Revert frontend changes
cd web
git checkout main -- src/pages/PYLIDCIntegration.tsx src/hooks/useDebounce.ts

# 2. Rebuild
npm run build
npm run dev &
```

---

##  Success Criteria

### Performance Targets Met
- [ ] PYLIDC cached queries: <1 second
- [ ] Keyword cached queries: <100ms
- [ ] Response size reduction: >60%
- [ ] Frontend filter debouncing: 90% fewer API calls
- [ ] Pagination: Instant navigation

### Stability Verified
- [ ] No backend crashes after 1 hour
- [ ] No database connection errors
- [ ] No frontend console errors
- [ ] Cache invalidation working correctly

### User Experience Improved
- [ ] PYLIDC page loads smoothly
- [ ] Filter interactions feel responsive
- [ ] Loading states provide clear feedback
- [ ] Pagination is seamless

---

##  Post-Deployment Tasks

### Immediate (Within 24 hours)
- [ ] Monitor error logs for issues
- [ ] Check database connection pool usage
- [ ] Verify cache hit rates in logs
- [ ] Test all critical user workflows

### Short-term (Within 1 week)
- [ ] Analyze performance metrics
- [ ] Gather user feedback
- [ ] Optimize cache TTL values if needed
- [ ] Consider increasing connection pool size

### Medium-term (Within 1 month)
- [ ] Implement cache metrics dashboard
- [ ] Add cache warming on startup
- [ ] Consider Redis migration for multi-instance
- [ ] Apply database indexes if not already done

---

##  Performance Regression Prevention

### Before Future Deployments
1. Run performance benchmarks
2. Compare against baseline metrics
3. Check for N+1 query problems
4. Verify no unbounded queries
5. Test under concurrent load

### Code Review Checklist
- [ ] No synchronous database calls in loops
- [ ] Proper use of caching for expensive operations
- [ ] Database queries use indexes
- [ ] Frontend debounces expensive inputs
- [ ] Large payloads are paginated

---

##  Support Contacts

**If issues arise:**
- Backend: Check logs at `logs/api.log`
- Database: Monitor Supabase dashboard
- Frontend: Check browser console
- Performance: Use Chrome DevTools Performance tab

---

##  Deployment Sign-off

**Deployed by:** _________________  
**Date:** _________________  
**Time:** _________________  
**Git commit:** _________________  
**All checks passed:** [ ] Yes [ ] No  
**Rollback plan verified:** [ ] Yes [ ] No  

---

**Last Updated:** November 23, 2025  
**Version:** 1.0.0
