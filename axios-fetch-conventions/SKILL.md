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

## 8. SSE — Generator + Async Iteration for Streaming

```ts
// Backend (NestJS) — generator yields SSE chunks
async *generateStream(prompt: string): AsyncGenerator<string> {
  const stream = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [{ role: 'user', content: prompt }],
    stream: true,
  });
  for await (const chunk of stream) {
    yield chunk.choices[0]?.delta?.content ?? '';
  }
}

// Express / NestJS SSE endpoint
@Post('/chat/stream')
async chatStream(@Body() body: ChatDto, @Res() res: Response) {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  for await (const chunk of this.generateStream(body.prompt)) {
    res.write(`data: ${JSON.stringify({ content: chunk })}\n\n`);
  }
  res.write('data: [DONE]\n\n');
  res.end();
}
```

**Frontend — consume SSE with fetch + ReadableStream:**
```ts
async function* consumeSSE(url: string, body: unknown): AsyncGenerator<string> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`SSE error: ${res.status}`);
  if (!res.body) throw new Error('No response body');

  const reader = res.body.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += value;
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6);
        if (data === '[DONE]') return;
        yield JSON.parse(data).content;
      }
    }
  }
}

// Usage in React hook
async function handleSend(prompt: string) {
  for await (const chunk of consumeSSE('/api/chat/stream', { prompt })) {
    setMessages((prev) => [...prev.slice(0, -1), { role: 'assistant', content: prev[prev.length - 1].content + chunk }]);
  }
}
```

**When to use SSE vs other patterns:**

| Pattern | Use when |
|---------|----------|
| SSE + Generator | Server → client streaming text (AI chat, logs, progress) |
| WebSocket | Bidirectional real-time (chat with user input, live collab) |
| Polling (SWR `refreshInterval`) | Simple, stateless periodic refresh |
| Chunked download (Range) | Large binary file, need progress + resume |

**Key:** `for await (... of generator)` handles backpressure — consumer controls pace, server doesn't flood.
