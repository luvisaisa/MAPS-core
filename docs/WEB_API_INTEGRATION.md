# web interface api integration

technical documentation for integrating the MAPS web interface with the fastapi backend.

## table of contents

1. [overview](#overview)
2. [api client architecture](#api-client-architecture)
3. [endpoint reference](#endpoint-reference)
4. [authentication](#authentication)
5. [error handling](#error-handling)
6. [type definitions](#type-definitions)
7. [testing](#testing)

## overview

the web interface communicates with the backend via rest api. all endpoints are prefixed with `/api/v1/`.

### base configuration

```typescript
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';
```

### api client setup

located in `src/services/api.ts`:

```typescript
class APIClient {
  private client: AxiosInstance;

  constructor(baseURL: string = API_BASE_URL) {
    this.client = axios.create({
      baseURL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }
}
```

## api client architecture

### interceptors

**response interceptor**:
```typescript
this.client.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    console.error('API Error:', error.response?.data || error.message);
    return Promise.reject(error);
  }
);
```

**request interceptor** (for future auth):
```typescript
this.client.interceptors.request.use(
  (config) => {
    const token = getAuthToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  }
);
```

### type safety

all api methods use typescript interfaces for requests and responses:

```typescript
async getProfiles(): Promise<Profile[]> {
  const response = await this.client.get<Profile[]>('/api/v1/profiles');
  return response.data;
}
```

### error handling

errors are caught and typed:

```typescript
try {
  const data = await apiClient.getProfiles();
} catch (error) {
  const apiError = error as AxiosError<APIError>;
  console.error(apiError.response?.data.error);
}
```

## endpoint reference

### health check

**get /health**

check api status.

request:
```http
GET /health
```

response:
```json
{
  "status": "healthy",
  "service": "MAPS API",
  "version": "1.0.0"
}
```

implementation:
```typescript
async healthCheck() {
  const response = await this.client.get('/health');
  return response.data;
}
```

### profile management

#### list profiles

**get /api/v1/profiles**

retrieve all available profiles.

request:
```http
GET /api/v1/profiles
```

response:
```json
[
  {
    "profile_name": "lidc-idri",
    "file_type": "xml",
    "description": "LIDC-IDRI XML parsing profile",
    "mappings": [...],
    "validation_rules": {...}
  }
]
```

implementation:
```typescript
async getProfiles(): Promise<Profile[]> {
  const response = await this.client.get<Profile[]>('/api/v1/profiles');
  return response.data;
}
```

usage:
```typescript
const { data: profiles } = useQuery({
  queryKey: ['profiles'],
  queryFn: () => apiClient.getProfiles(),
});
```

#### get single profile

**get /api/v1/profiles/{name}**

retrieve a specific profile by name.

request:
```http
GET /api/v1/profiles/lidc-idri
```

response:
```json
{
  "profile_name": "lidc-idri",
  "file_type": "xml",
  "description": "LIDC-IDRI XML parsing profile",
  "mappings": [...],
  "validation_rules": {...}
}
```

implementation:
```typescript
async getProfile(name: string): Promise<Profile> {
  const response = await this.client.get<Profile>(`/api/v1/profiles/${name}`);
  return response.data;
}
```

#### create profile

**post /api/v1/profiles**

create a new profile.

request:
```http
POST /api/v1/profiles
Content-Type: application/json

{
  "profile_name": "custom-profile",
  "file_type": "xml",
  "description": "Custom parsing profile",
  "mappings": [...],
  "validation_rules": {...}
}
```

response:
```json
{
  "success": true,
  "message": "Profile created successfully",
  "data": {...}
}
```

implementation:
```typescript
async createProfile(profile: Profile): Promise<APIResponse<Profile>> {
  const response = await this.client.post<APIResponse<Profile>>(
    '/api/v1/profiles', 
    profile
  );
  return response.data;
}
```

#### update profile

**put /api/v1/profiles/{name}**

update an existing profile.

request:
```http
PUT /api/v1/profiles/custom-profile
Content-Type: application/json

{
  "description": "Updated description",
  "mappings": [...]
}
```

response:
```json
{
  "success": true,
  "message": "Profile updated successfully"
}
```

implementation:
```typescript
async updateProfile(name: string, profile: Profile): Promise<APIResponse<Profile>> {
  const response = await this.client.put<APIResponse<Profile>>(
    `/api/v1/profiles/${name}`, 
    profile
  );
  return response.data;
}
```

#### delete profile

**delete /api/v1/profiles/{name}**

delete a profile.

request:
```http
DELETE /api/v1/profiles/custom-profile
```

response:
```json
{
  "success": true,
  "message": "Profile deleted successfully"
}
```

implementation:
```typescript
async deleteProfile(name: string): Promise<APIResponse> {
  const response = await this.client.delete<APIResponse>(
    `/api/v1/profiles/${name}`
  );
  return response.data;
}
```

### file upload & processing

#### upload files

**post /api/v1/parse/upload**

upload xml files for processing.

request:
```http
POST /api/v1/parse/upload
Content-Type: multipart/form-data

files: [File, File, ...]
profile: "lidc-idri"
```

response:
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "files_uploaded": 5,
  "message": "Files uploaded successfully and queued for processing"
}
```

implementation:
```typescript
async uploadFiles(
  files: File[], 
  profileName: string, 
  onProgress?: (progress: { loaded: number; total?: number }) => void
): Promise<UploadResponse> {
  const formData = new FormData();
  files.forEach((file) => formData.append('files', file));
  formData.append('profile', profileName);

  const response = await this.client.post<UploadResponse>(
    '/api/v1/parse/upload', 
    formData, 
    {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent) => {
        if (onProgress) {
          onProgress({ 
            loaded: progressEvent.loaded, 
            total: progressEvent.total 
          });
        }
      },
    }
  );

  return response.data;
}
```

usage with progress tracking:
```typescript
const uploadMutation = useMutation({
  mutationFn: ({ files, profile }: { files: File[]; profile: string }) => {
    return apiClient.uploadFiles(files, profile, (progress) => {
      setProgress(Math.round((progress.loaded / progress.total!) * 100));
    });
  },
});
```

### job management

#### list jobs

**get /api/v1/batch/jobs**

list all processing jobs with pagination and filters.

request:
```http
GET /api/v1/batch/jobs?page=1&page_size=20&status=completed&profile_name=lidc-idri
```

query parameters:
- `page`: page number (default: 1)
- `page_size`: items per page (default: 20)
- `status`: filter by status
- `profile_name`: filter by profile
- `date_from`: filter by start date
- `date_to`: filter by end date
- `sort_by`: field to sort by
- `sort_order`: asc or desc

response:
```json
{
  "items": [...],
  "total": 150,
  "page": 1,
  "page_size": 20,
  "total_pages": 8
}
```

implementation:
```typescript
async getJobs(
  params?: PaginationParams & JobFilters
): Promise<PaginatedResponse<ProcessingJob>> {
  const response = await this.client.get<PaginatedResponse<ProcessingJob>>(
    '/api/v1/batch/jobs',
    { params }
  );
  return response.data;
}
```

usage:
```typescript
const { data } = useQuery({
  queryKey: ['jobs', page, pageSize, filters],
  queryFn: () => apiClient.getJobs({ 
    page, 
    page_size: pageSize,
    ...filters 
  }),
});
```

#### get job details

**get /api/v1/batch/jobs/{id}**

get details for a specific job.

request:
```http
GET /api/v1/batch/jobs/550e8400-e29b-41d4-a716-446655440000
```

response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "profile_name": "lidc-idri",
  "file_count": 5,
  "processed_count": 5,
  "error_count": 0,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:35:00Z",
  "completed_at": "2025-01-15T10:35:00Z"
}
```

implementation:
```typescript
async getJob(jobId: string): Promise<ProcessingJob> {
  const response = await this.client.get<ProcessingJob>(
    `/api/v1/batch/jobs/${jobId}`
  );
  return response.data;
}
```

#### cancel job

**post /api/v1/batch/jobs/{id}/cancel**

cancel a running job.

request:
```http
POST /api/v1/batch/jobs/550e8400-e29b-41d4-a716-446655440000/cancel
```

response:
```json
{
  "success": true,
  "message": "Job cancelled successfully"
}
```

implementation:
```typescript
async cancelJob(jobId: string): Promise<APIResponse> {
  const response = await this.client.post<APIResponse>(
    `/api/v1/batch/jobs/${jobId}/cancel`
  );
  return response.data;
}
```

#### delete job

**delete /api/v1/batch/jobs/{id}**

delete a job and its results.

request:
```http
DELETE /api/v1/batch/jobs/550e8400-e29b-41d4-a716-446655440000
```

response:
```json
{
  "success": true,
  "message": "Job deleted successfully"
}
```

implementation:
```typescript
async deleteJob(jobId: string): Promise<APIResponse> {
  const response = await this.client.delete<APIResponse>(
    `/api/v1/batch/jobs/${jobId}`
  );
  return response.data;
}
```

### export & download

#### export job results

**get /api/v1/export/job/{id}**

export processed data in specified format.

request:
```http
GET /api/v1/export/job/550e8400-e29b-41d4-a716-446655440000?format=excel
```

query parameters:
- `format`: excel, json, csv (required)
- `template`: standard, template, multi-folder (excel only)

response:
```json
{
  "download_url": "/api/v1/export/download/export_550e8400.xlsx",
  "file_name": "export_550e8400.xlsx",
  "file_size": 1048576
}
```

implementation:
```typescript
async exportJob(
  jobId: string, 
  options: { format: ExportFormat }
): Promise<ExportResponse> {
  const response = await this.client.get<ExportResponse>(
    `/api/v1/export/job/${jobId}`,
    { params: { format: options.format } }
  );
  return response.data;
}
```

usage:
```typescript
const exportMutation = useMutation({
  mutationFn: (format: ExportFormat) => {
    return apiClient.exportJob(jobId, { format });
  },
  onSuccess: (data) => {
    window.open(data.download_url, '_blank');
  },
});
```

#### download file

**get /api/v1/export/download/{filename}**

download an exported file.

request:
```http
GET /api/v1/export/download/export_550e8400.xlsx
```

response: binary file data

implementation:
```typescript
async downloadFile(fileName: string): Promise<Blob> {
  const response = await this.client.get(
    `/api/v1/export/download/${fileName}`,
    { responseType: 'blob' }
  );
  return response.data;
}
```

### analytics & statistics

#### dashboard statistics

**get /api/v1/analytics/dashboard**

get dashboard statistics.

request:
```http
GET /api/v1/analytics/dashboard?date_from=2025-01-01&date_to=2025-01-31
```

query parameters:
- `date_from`: start date (optional)
- `date_to`: end date (optional)

response:
```json
{
  "total_documents": 1250,
  "total_jobs": 87,
  "success_rate": 96.5,
  "error_rate": 3.5,
  "parse_case_distribution": {
    "case_a": 450,
    "case_b": 350,
    "case_c": 450
  },
  "processing_trends": [...],
  "storage_usage": {
    "total_size": 524288000,
    "document_count": 1250,
    "average_size": 419430
  }
}
```

implementation:
```typescript
async getDashboardStats(): Promise<DashboardStats> {
  const response = await this.client.get<DashboardStats>(
    '/api/v1/analytics/dashboard'
  );
  return response.data;
}
```

## authentication

currently the api does not require authentication. for future auth implementation:

### jwt authentication

```typescript
// login
async login(credentials: { username: string; password: string }) {
  const response = await this.client.post('/api/v1/auth/login', credentials);
  const { access_token } = response.data;
  localStorage.setItem('auth_token', access_token);
  return response.data;
}

// logout
async logout() {
  localStorage.removeItem('auth_token');
}

// get token
function getAuthToken(): string | null {
  return localStorage.getItem('auth_token');
}
```

### protected routes

```typescript
// add auth check to protected pages
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const token = getAuthToken();
  
  if (!token) {
    return <Navigate to="/login" />;
  }
  
  return <>{children}</>;
}
```

## error handling

### error types

```typescript
export interface APIError {
  error: string;
  detail?: string;
  path?: string;
  status_code?: number;
}
```

### error handling pattern

```typescript
try {
  const data = await apiClient.getProfiles();
} catch (error) {
  const axiosError = error as AxiosError<APIError>;
  
  if (axiosError.response) {
    // server responded with error
    const apiError = axiosError.response.data;
    console.error(`API Error: ${apiError.error}`);
    
    switch (axiosError.response.status) {
      case 400:
        // bad request
        break;
      case 401:
        // unauthorized
        break;
      case 404:
        // not found
        break;
      case 500:
        // server error
        break;
    }
  } else if (axiosError.request) {
    // request made but no response
    console.error('Network error: no response from server');
  } else {
    // error setting up request
    console.error('Request error:', axiosError.message);
  }
}
```

### react query error handling

```typescript
const { data, error, isError } = useQuery({
  queryKey: ['profiles'],
  queryFn: () => apiClient.getProfiles(),
  onError: (error: AxiosError<APIError>) => {
    toast.error(error.response?.data.error || 'An error occurred');
  },
});

if (isError) {
  return <ErrorMessage error={error} />;
}
```

## type definitions

### core types

located in `src/types/api.ts`:

```typescript
export interface Profile {
  profile_name: string;
  file_type: string;
  description: string;
  mappings: ProfileMapping[];
  validation_rules: ValidationRules;
  transformations?: Record<string, unknown>;
}

export interface ProcessingJob {
  id: string;
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled';
  profile_name: string;
  file_count: number;
  processed_count: number;
  error_count: number;
  created_at: string;
  updated_at: string;
  completed_at?: string;
  error_message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}
```

### type generation

for automatic type generation from openapi schema:

```bash
npm install -D openapi-typescript-codegen

# generate types
npx openapi-typescript-codegen --input http://localhost:8000/openapi.json --output ./src/types/generated
```

## testing

### mocking api calls

```typescript
import { rest } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  rest.get('http://localhost:8000/api/v1/profiles', (req, res, ctx) => {
    return res(ctx.json([
      {
        profile_name: 'test-profile',
        file_type: 'xml',
        description: 'Test profile',
        mappings: [],
        validation_rules: { required_fields: [] },
      },
    ]));
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### testing api client

```typescript
import { describe, it, expect } from 'vitest';
import { apiClient } from '../services/api';

describe('API Client', () => {
  it('fetches profiles successfully', async () => {
    const profiles = await apiClient.getProfiles();
    expect(profiles).toBeInstanceOf(Array);
  });

  it('handles errors correctly', async () => {
    await expect(
      apiClient.getProfile('nonexistent')
    ).rejects.toThrow();
  });
});
```

## cors configuration

backend cors must allow web interface origin:

```python
# src/maps/api/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://web:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## rate limiting

future implementation for rate limiting:

```typescript
import pRetry from 'p-retry';

async function apiCallWithRetry<T>(
  fn: () => Promise<T>,
  retries: number = 3
): Promise<T> {
  return pRetry(fn, {
    retries,
    onFailedAttempt: (error) => {
      console.warn(
        `Attempt ${error.attemptNumber} failed. ${error.retriesLeft} retries left.`
      );
    },
  });
}

// usage
const profiles = await apiCallWithRetry(() => apiClient.getProfiles());
```

## websocket integration

for real-time updates (future):

```typescript
import { io } from 'socket.io-client';

const socket = io('http://localhost:8000');

socket.on('job-progress', (data: ProcessingProgress) => {
  // update ui with progress
  setProgress(data.percentage);
});

socket.on('job-complete', (data: ProcessingJob) => {
  // refresh job list
  queryClient.invalidateQueries(['jobs']);
});
```

## best practices

1. **type everything**: use typescript interfaces for all api interactions
2. **centralize api calls**: keep all api methods in api client
3. **handle errors**: always catch and handle errors appropriately
4. **use react query**: leverage caching and automatic refetching
5. **track progress**: show progress for long-running operations
6. **validate responses**: check response data structure
7. **retry logic**: implement retries for transient failures
8. **timeout handling**: set appropriate timeouts for requests
9. **cancel requests**: cancel requests when components unmount
10. **mock in tests**: always mock api calls in unit tests
