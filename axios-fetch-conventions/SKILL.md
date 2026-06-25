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

> 如果用了 SWR / TanStack Query / ahooks，组件卸载自动取消，不需要手写 `AbortController`。
> 以下方案只在**非请求库环境**（手动 `useEffect` + axios）时需要。

```ts
// 非请求库环境：手动取消
useEffect(() => {
  const controller = new AbortController();
  http.get('/posts', { signal: controller.signal });
  return () => controller.abort();
}, []);
```

## 5. Retry on Transient Failures

> SWR: `errorRetryCount: 3` / TanStack Query: `retry: 3` / ahooks: `retryCount: 2`
> 请求库自带重试，以下方案只在**非请求库环境**需要。

```ts
// 非请求库环境：手动重试
async function fetchWithRetry<T>(url: string, retries = 2): Promise<T> {
  for (let i = 0; i <= retries; i++) {
    try {
      return (await http.get<T>(url)).data;
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

### 异步下载方案

`createObjectURL` + `a.click()` 是同步的，对大文件 UI 线程会卡。以下异步方案按场景选：

#### 方案一：进度跟踪 + 异步下载

```ts
async function downloadWithProgress(url: string, filename: string) {
  const res = await http.get(url, {
    responseType: 'blob',
    onDownloadProgress: (e) => {
      const pct = Math.round((e.loaded / e.total!) * 100);
      console.log(`下载进度: ${pct}%`);
      // 更新 UI 进度条
      updateProgress(pct);
    },
  });

  // 下载完成后触发浏览器保存（用户点击触发）
  const blobUrl = URL.createObjectURL(res.data);
  const a = document.createElement('a');
  a.href = blobUrl;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(blobUrl);
}
```

#### 方案二：File System Access API + 流式写入（不占内存）

```ts
async function downloadToFile(url: string) {
  // 弹出「另存为」对话框（用户选择目录）
  const handle = await (window as any).showSaveFilePicker({
    suggestedName: 'report.pdf',
  });

  // 流式下载 + 流式写入，不占内存
  const response = await fetch(url);
  const writable = await handle.createWritable();
  await response.body!.pipeTo(writable);
  // 下载完成，文件已保存到用户指定位置
}
```

> ⚠️ `showSaveFilePicker` 目前 Chrome/Edge 支持，Safari/Firefox 不支持。

#### 方案三：Web Worker 下载（不阻塞 UI）

```ts
// worker.ts
self.onmessage = async (e) => {
  const { url, filename } = e.data;
  const res = await fetch(url);
  const blob = await res.blob();
  self.postMessage({ blob, filename });
};

// main.ts
const worker = new Worker(new URL('./worker.ts', import.meta.url));
worker.postMessage({ url: '/files/report.pdf', filename: 'report.pdf' });
worker.onmessage = (e) => {
  const { blob, filename } = e.data;
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
  worker.terminate();
};
```

#### 方案四：直接触发服务器下载（零前端代码）

```tsx
// 服务端返回 Content-Disposition: attachment
// 前端直接用 <a> 或 window.open，不经过 JS 下载
<a href="/api/files/report.pdf" download>下载</a>
// 或
window.open('/api/files/report.pdf');
// ✅ 最简单，大文件不占前端内存
// ❌ 无法跟踪进度、无法自定义请求头
```

#### 各方案对比

| 方案 | 内存占用 | 支持进度 | 支持自定义请求头 | 浏览器兼容 |
|------|---------|---------|----------------|-----------|
| `createObjectURL` + `a.click` | 高（全量内存） | ❌ | ✅ | ✅ 全平台 |
| `onDownloadProgress` + blob | 高 | ✅ | ✅ | ✅ 全平台 |
| `showSaveFilePicker` + stream | **低（流式）** | ❌ | ✅ | ⚠️ Chrome/Edge |
| Web Worker 下载 | 中 | ❌ | ✅ | ✅ 全平台 |
| 直接 `<a download>` 触发 | **零（服务器直传）** | ❌ | ❌ | ✅ 全平台 |

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

## 9. 并发控制 — 浏览器请求上限与批量请求

批量上传、大量数据拉取时，需要控制并发数以保护服务端不被瞬时高峰打垮。HTTP/2 没有 6 连接限制，但服务端有自身承载上限。

> SWR / TanStack Query 自带的去重/重试/取消不处理并发上限问题。以下方案在**批量场景**使用。

### ConcurrencyQueue

```ts
class ConcurrencyQueue {
  private queue: (() => Promise<any>)[] = [];
  private running = 0;
  constructor(private maxConcurrency = 5) {}

  async add<T>(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try { resolve(await task()); }
        catch (e) { reject(e); }
      });
      this.run();
    });
  }

  private run() {
    while (this.running < this.maxConcurrency && this.queue.length > 0) {
      const task = this.queue.shift()!;
      this.running++;
      task().finally(() => { this.running--; this.run(); });
    }
  }
}
```

### 总结

| 场景 | 用请求库 | 手写 |
|------|---------|------|
| 页面数据加载 | ✅ SWR/Query | ❌ |
| 去重、缓存、重试 | ✅ 库自带 | ❌ |
| **批量上传并发控制** | ❌ 不处理 | ✅ ConcurrencyQueue |
| **非请求库环境的取消** | ❌ 不适用 | ✅ AbortController |

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
