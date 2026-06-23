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

## 2. Unified Instance — No Manual Token Header

```ts
// lib/http.ts
import axios from 'axios';

export const http = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 15000,
  withCredentials: true, // sends httpOnly cookies automatically
});

// ❌ NEVER do this — token in localStorage = XSS hole
http.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ✅ httpOnly cookie — browser sends it via withCredentials, JS can't read it
// No interceptor needed. No manual header. Cookie is invisible to JS.
```

**Why `withCredentials` is enough:**
- httpOnly cookie is set by backend (`Set-Cookie` header)
- Browser attaches it to every request automatically
- JS can't read the token → XSS can't steal it
- No manual `Authorization` header needed

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

[more lines below; pass offset=229 to continue]

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

---

## 9. Request Queue — 防止重复与控制并发

### 场景：重复请求合并

同一个请求在短时间内被多次触发（如搜索输入、快速切换 Tab），只发一次，复用结果。

```ts
class RequestQueue {
  private pending = new Map<string, Promise<any>>();

  async enqueue<T>(key: string, fetcher: () => Promise<T>): Promise<T> {
    // 已有相同请求在途 → 复用
    if (this.pending.has(key)) {
      return this.pending.get(key)!;
    }

    // 发起请求，存入队列
    const promise = fetcher().finally(() => {
      this.pending.delete(key);
    });
    this.pending.set(key, promise);
    return promise;
  }
}

const queue = new RequestQueue();

// 使用：连续调用 10 次也只发 1 次
const data = await queue.enqueue('search:keyword', () =>
  axios.get(`/api/search?q=keyword`).then(r => r.data)
);
```

### 场景：取消上一次请求

搜索框场景，每次输入取消上一次未完成的请求。

```ts
let cancelRef: AbortController | null = null;

async function search(keyword: string) {
  // 取消上一次请求
  cancelRef?.abort();
  cancelRef = new AbortController();

  try {
    const res = await axios.get('/api/search', {
      params: { q: keyword },
      signal: cancelRef.signal,
    });
    return res.data;
  } catch (err) {
    if (axios.isCancel(err)) {
      console.log('上一次请求已取消');
      return null;
    }
    throw err;
  }
}
```

### 场景：并发控制（限制同时请求数）

```ts
class ConcurrencyQueue {
  private queue: (() => Promise<any>)[] = [];
  private running = 0;

  constructor(private maxConcurrency = 5) {}

  async add<T>(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await task();
          resolve(result);
        } catch (e) {
          reject(e);
        }
      });
      this.run();
    });
  }

  private run() {
    while (this.running < this.maxConcurrency && this.queue.length > 0) {
      const task = this.queue.shift()!;
      this.running++;
      task().finally(() => {
        this.running--;
        this.run();
      });
    }
  }
}

// 使用：最多同时 3 个请求
const q = new ConcurrencyQueue(3);
const results = await Promise.all(
  urls.map(url => q.add(() => axios.get(url).then(r => r.data)))
);
```

### 各场景对比

| 场景 | 方案 | 适用 |
|------|------|------|
| 搜索输入、重复点击 | 取消上一次（AbortController） | 只需最新结果 |
| 搜索、页面 Tab 切换 | 重复请求合并（Map + Promise） | 相同请求复用一个结果 |
| 批量上传、大量列表拉取 | 并发控制（ConcurrencyQueue） | 限制同时请求数 |
| 请求失败自动重试 | 重试队列（指数退避） | 临时性故障 |

### 通用 axios 拦截器（请求去重）

```ts
const requestMap = new Map<string, Promise<any>>();

http.interceptors.request.use((config) => {
  const key = `${config.method}:${config.url}:${JSON.stringify(config.params || {})}`;

  // GET 请求可以安全去重
  if (config.method === 'get' && requestMap.has(key)) {
    return Promise.reject({ isDuplicate: true, existingPromise: requestMap.get(key) });
  }

  const promise = http.request(config);
  if (config.method === 'get') {
    requestMap.set(key, promise);
    promise.finally(() => requestMap.delete(key));
  }
  return config;
});
```

---

## 10. React 请求库 + axios 结合

把统一的 axios 实例传给请求库，让请求库管理 loading/cache/状态，axios 实例管理拦截器/超时/取消。

### useSWR + axios

```ts
// lib/http.ts — 统一实例（拦截器、超时已配置）
import http from './http';

// fetcher 用 axios 实例
const fetcher = (url: string) => http.get(url).then(res => res.data);

// 组件中使用
function UserProfile({ id }: { id: number }) {
  const { data, error, isLoading } = useSWR(`/api/users/${id}`, fetcher);

  // 请求取消 — SWR 自动处理（组件卸载时 abort）
  return <div>{data?.name}</div>;
}
```

### TanStack Query + axios

```ts
import { useQuery, useMutation } from '@tanstack/react-query';
import http from './http';

// fetcher 绑定 axios
const queryClient = new QueryClient();

function Posts() {
  const { data, isLoading } = useQuery({
    queryKey: ['posts'],
    queryFn: () => http.get('/posts').then(r => r.data),
    // staleTime 控制缓存时效
    staleTime: 30_000,         // 30s 内不重新请求
    gcTime: 5 * 60_000,        // 5min 后回收缓存
  });

  const createMutation = useMutation({
    mutationFn: (body: { title: string }) =>
      http.post('/posts', body).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['posts'] });
    },
  });

  return <button onClick={() => createMutation.mutate({ title: 'New' })}>创建</button>;
}
```

### ahooks useRequest + axios

```ts
import { useRequest } from 'ahooks';
import http from './http';

function SearchInput() {
  const { data, loading, run, cancel } = useRequest(
    (keyword: string) => http.get('/api/search', { params: { q: keyword } }).then(r => r.data),
    {
      debounceWait: 300,            // 防抖 300ms
      manual: true,                  // 手动触发
      retryCount: 2,                 // 失败重试 2 次
      cancelOnLeave: true,           // 组件卸载取消
    },
  );

  return (
    <input
      onChange={(e) => run(e.target.value)}
      onBlur={cancel}
    />
  );
}
```

### 关键整合点

| 请求库 | axios 实例角色 | 取消机制 | 重试机制 |
|--------|---------------|---------|---------|
| useSWR | fetcher 用 `http.get` | SWR 自动 abort | SWR `errorRetryCount` |
| TanStack Query | queryFn 用 `http.get` | `signal` 传入 axios | `retry` 配置项 |
| ahooks useRequest | requestFn 用 `http.get` | `cancelOnLeave` | `retryCount` |

**核心：axios 实例只负责「发请求 + 拦截器 + 超时」，请求库只负责「状态管理 + 缓存 + 生命周期」。两者各司其职，不重复实现对方的功能。**
