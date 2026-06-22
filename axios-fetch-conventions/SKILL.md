---
name: axios-fetch-conventions
description: Use when writing HTTP request code with axios or fetch — enforces unified instance, interceptors, error handling, cancellation, and base URL patterns
---

# Axios / Fetch Conventions

## 1. Never Raw fetch/axios in React Components

Always use a data-fetching library that manages loading, error, caching, and revalidation.

```tsx
// ❌ NEVER raw fetch in a component
function Posts() {
  const [posts, setPosts] = useState([]);
  useEffect(() => { fetch('/api/posts').then(r => r.json()).then(setPosts); }, []);
}

// ❌ NEVER raw axios in a component
function Posts() {
  const [posts, setPosts] = useState([]);
  useEffect(() => { http.get('/posts').then(r => setPosts(r.data)); }, []);
}

// ✅ useSWR
const { data, error, isLoading } = useSWR('/api/posts', fetcher);

// ✅ react-query / tanstack query
const { data, error, isLoading } = useQuery({ queryKey: ['posts'], queryFn: fetchPosts });

// ✅ ahooks useRequest
const { data, error, loading } = useRequest(() => http.get('/posts'));
```

| Library | When |
|---------|------|
| `useSWR` | Already in the project, simple fetch + cache + revalidation |
| `@tanstack/react-query` | Complex server state, mutations, pagination |
| `ahooks` `useRequest` | Lightweight, already using ahooks for other hooks |

## 2. Unified Instance

Don't scatter `axios.get()` with inline URLs. Create a single configured instance.

```ts
// lib/http.ts
import axios from 'axios';

export const http = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 15000,
  withCredentials: true,
});
```

## 3. Interceptors — Error Handling in One Place

```ts
// Response interceptor — normalize errors
http.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      // redirect to login
    }
    if (error.code === 'ECONNABORTED') {
      throw new Error('Request timed out');
    }
    throw error;
  }
);
```

## 4. Request Cancellation

Every request must pass a signal for cleanup.

```ts
// ✅ AbortController
const controller = new AbortController();

useEffect(() => {
  http.get('/posts', { signal: controller.signal });
  return () => controller.abort(); // cleanup on unmount
}, []);
```

## 5. Retry on Transient Failures

```ts
async function fetchWithRetry<T>(url: string, retries = 2): Promise<T> {
  for (let i = 0; i <= retries; i++) {
    try {
      const { data } = await http.get<T>(url);
      return data;
    } catch (err) {
      if (i === retries) throw err;
      await new Promise((r) => setTimeout(r, 1000 * (i + 1)));
    }
  }
  throw new Error('unreachable');
}
```

## 6. File Download — responseType Blob, Not JSON

```ts
// ❌ default responseType='json' — corrupts binary files
const res = await http.get('/files/report.pdf');

// ✅ responseType: 'blob' for any file download
const res = await http.get('/files/report.pdf', { responseType: 'blob' });

// Trigger browser download
const url = URL.createObjectURL(res.data);
const a = document.createElement('a');
a.href = url;
a.download = filename;
a.click();
URL.revokeObjectURL(url);
```

| Data type | responseType |
|-----------|-------------|
| JSON API | `'json'` (default) |
| File download | `'blob'` |
| Raw text | `'text'` |
| Binary processing | `'arraybuffer'` |

## 7. Large File — Sliced Download with Range

```ts
async function downloadLargeFile(url: string, filename: string, onProgress?: (pct: number) => void) {
  const head = await http.head(url);
  const total = Number(head.headers['content-length']);
  if (!total) throw new Error('Server must support Content-Length');

  const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB
  const chunks: Blob[] = [];
  let downloaded = 0;

  while (downloaded < total) {
    const end = Math.min(downloaded + CHUNK_SIZE - 1, total - 1);
    const res = await http.get(url, {
      responseType: 'blob',
      headers: { Range: `bytes=${downloaded}-${end}` },
    });
    chunks.push(res.data);
    downloaded += res.data.size;
    onProgress?.(Math.round((downloaded / total) * 100));
  }
  saveBlob(new Blob(chunks), filename);
}
```

**Pitfalls:**
- Server must return `Accept-Ranges: bytes`
- Without `Content-Length`, can't calculate progress
- CORS: server must expose `Content-Range` via `Access-Control-Expose-Headers`

## Red Flags

- `axios.get('http://...')` with hardcoded URL — use the shared instance
- `try/catch` around every call doing the same error handling — use interceptor
- No `AbortController` on requests made in `useEffect` — memory leak on fast navigation
- `fetch()` with no timeout wrapper — fetch has no built-in timeout
- Download without `responseType: 'blob'` — silent corruption
- Large file without `Range` header → memory OOM
