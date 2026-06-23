---
name: frontend-monitoring
description: 前端日志/打点/错误上报 — 结构化日志、用户行为埋点、错误捕获与上报、Sentry 接入、性能指标上报
---

# 前端日志 / 打点 / 错误上报

## 错误上报

### 全局错误捕获

```ts
// 1. JS 运行时错误
window.onerror = (message, source, lineno, colno, error) => {
  reportError({
    type: 'RUNTIME_ERROR',
    message: typeof message === 'string' ? message : message.message,
    source,
    lineno,
    colno,
    stack: error?.stack,
    url: window.location.href,
    timestamp: Date.now(),
  });
  return true; // 阻止默认错误处理
};

// 2. Promise 未捕获拒绝
window.addEventListener('unhandledrejection', (event) => {
  reportError({
    type: 'UNHANDLED_REJECTION',
    message: event.reason?.message || String(event.reason),
    stack: event.reason?.stack,
    url: window.location.href,
    timestamp: Date.now(),
  });
});

// 3. 资源加载失败（图片、script、CSS）
window.addEventListener('error', (event) => {
  if (event.target && (event.target as HTMLElement).tagName) {
    reportError({
      type: 'RESOURCE_ERROR',
      tagName: (event.target as HTMLElement).tagName,
      src: (event.target as HTMLScriptElement).src || (event.target as HTMLImageElement).src,
      url: window.location.href,
    });
  }
}, true); // 捕获阶段
```

### React 错误边界

```tsx
class ErrorBoundary extends React.Component<
  { children: React.ReactNode; fallback?: React.ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    reportError({
      type: 'REACT_ERROR',
      message: error.message,
      stack: error.stack,
      componentStack: info.componentStack,
      url: window.location.href,
    });
  }

  render() {
    if (this.state.hasError) return this.props.fallback || <div>出错了</div>;
    return this.props.children;
  }
}
```

### 主动上报

```ts
function reportError(error: {
  type: string;
  message?: string;
  stack?: string;
  [key: string]: unknown;
}) {
  // 生产环境才上报
  if (process.env.NODE_ENV !== 'production') {
    console.error('[ErrorReport]', error);
    return;
  }

  // 使用 sendBeacon（页面卸载时也能送达）
  const body = JSON.stringify({
    ...error,
    userAgent: navigator.userAgent,
    timestamp: Date.now(),
    page: window.location.href,
  });

  // try sendBeacon 优先，不支持则 fallback 到 fetch
  if (navigator.sendBeacon) {
    navigator.sendBeacon('/api/log/error', body);
  } else {
    fetch('/api/log/error', {
      method: 'POST',
      body,
      keepalive: true, // 页面卸载时仍然发送
    });
  }
}
```

---

## 前端日志

### 结构化日志

```ts
// 不是直接用 console.log，而是统一日志级别
const LOG_LEVELS = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 } as const;
type LogLevel = keyof typeof LOG_LEVELS;

interface LogEntry {
  level: LogLevel;
  message: string;
  data?: Record<string, unknown>;
  timestamp: number;
  page: string;
}

const currentLevel = process.env.NODE_ENV === 'production' ? 'INFO' : 'DEBUG';

function log(level: LogLevel, message: string, data?: Record<string, unknown>) {
  if (LOG_LEVELS[level] < LOG_LEVELS[currentLevel]) return;

  const entry: LogEntry = {
    level,
    message,
    data,
    timestamp: Date.now(),
    page: window.location.href,
  };

  // 开发环境直接 console
  if (process.env.NODE_ENV !== 'production') {
    const fn = level === 'ERROR' ? console.error : level === 'WARN' ? console.warn : console.log;
    fn(`[${level}] ${message}`, data || '');
    return;
  }

  // 生产环境：WARN/ERROR 上报，DEBUG/INFO 存本地
  if (level === 'WARN' || level === 'ERROR') {
    reportError(entry); // 复用错误上报接口
  }
  // 需要离线日志时写入 localStorage（限制大小）
  saveToLocalLog(entry);
}

// 使用
log('INFO', '用户进入页面', { page: 'home' });
log('ERROR', 'API 请求失败', { url: '/api/data', status: 500 });
```

### 本地日志缓存

```ts
const MAX_LOG_SIZE = 100; // 最多保留 100 条

function saveToLocalLog(entry: LogEntry) {
  try {
    const logs = JSON.parse(localStorage.getItem('frontend_logs') || '[]');
    logs.push(entry);
    if (logs.length > MAX_LOG_SIZE) logs.splice(0, logs.length - MAX_LOG_SIZE);
    localStorage.setItem('frontend_logs', JSON.stringify(logs));
  } catch {
    // localStorage 满了就清空旧日志
    localStorage.removeItem('frontend_logs');
  }
}
```

---

## 用户行为打点

### 通用打点函数

```ts
interface TrackEvent {
  event: string;          // 事件名，如 'page_view', 'button_click'
  properties?: Record<string, unknown>; // 事件属性
  page?: string;
  timestamp?: number;
}

function track(event: string, properties?: Record<string, unknown>) {
  const payload: TrackEvent = {
    event,
    properties,
    page: window.location.pathname,
    timestamp: Date.now(),
  };

  if (process.env.NODE_ENV !== 'production') {
    console.log('[Track]', payload);
    return;
  }

  // sendBeacon 上报
  navigator.sendBeacon?.('/api/log/track', JSON.stringify(payload));
}
```

### 常见埋点

```ts
// 页面访问
track('page_view', { referrer: document.referrer });

// 按钮点击
<button onClick={() => {
  track('button_click', { buttonId: 'submit_order', orderId: '123' });
  submitOrder();
}}>提交订单</button>

// 用户操作
track('search', { keyword: '手机', resultsCount: 42 });

// 表单提交
track('form_submit', { formName: 'login', success: true });

// 错误
track('api_error', { url: '/api/orders', status: 500, duration: 3200 });
```

### PV / UV 统计

```ts
// 页面停留时长
let pageEnterTime = Date.now();

document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    // 用户离开页面
    const duration = Date.now() - pageEnterTime;
    track('page_leave', { duration, path: window.location.pathname });
  } else {
    // 用户回到页面
    pageEnterTime = Date.now();
    track('page_return', { path: window.location.pathname });
  }
});
```

### 打点去重（防止重复上报）

```ts
const sentEvents = new Set<string>();

function trackOnce(event: string, key?: string) {
  const dedupKey = `${event}_${key || ''}`;
  if (sentEvents.has(dedupKey)) return;
  sentEvents.add(dedupKey);
  track(event);
}
```

---

## 性能指标上报

### Web Vitals

```ts
import { onLCP, onFID, onCLS, onINP } from 'web-vitals';

function reportWebVitals() {
  onLCP((metric) => track('web_vital', { name: 'LCP', value: metric.value }));
  onFID((metric) => track('web_vital', { name: 'FID', value: metric.value }));
  onCLS((metric) => track('web_vital', { name: 'CLS', value: metric.value }));
  onINP((metric) => track('web_vital', { name: 'INP', value: metric.value }));
}
```

### 自定义性能标记

```ts
// 记录关键操作耗时
performance.mark('search-start');
await searchAPI();
performance.mark('search-end');
performance.measure('search-duration', 'search-start', 'search-end');

const entries = performance.getEntriesByName('search-duration');
if (entries.length > 0) {
  track('performance', { name: 'search', duration: entries[0].duration });
  performance.clearMarks('search-start');
  performance.clearMarks('search-end');
}
```

---

## 使用场景总结

| 场景 | 用什么 | 上报方式 |
|------|--------|---------|
| JS 运行时错误 | `window.onerror` | sendBeacon |
| Promise 异常 | `unhandledrejection` | sendBeacon |
| React 组件错误 | ErrorBoundary | sendBeacon |
| 调试日志 | 结构化 `log()` | 开发环境 console，生产 WARN/ERROR 上报 |
| 用户行为 | `track()` | sendBeacon |
| PV/UV 停留时长 | visibilitychange | sendBeacon |
| 性能指标 | web-vitals | sendBeacon |

---

## Sentry 接入

```bash
npm install @sentry/react @sentry/browser
```

```ts
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.NEXT_PUBLIC_VERSION,
  tracesSampleRate: 0.1,         // 性能采样率 10%
  replaysSessionSampleRate: 0.1, // 录屏回放采样
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
});

// 主动上报
Sentry.captureException(error);
Sentry.captureMessage('用户操作异常', 'warning');

// 设置用户上下文（关联错误到用户）
Sentry.setUser({ id: userId, email: userEmail });

// 设置标签（方便过滤）
Sentry.setTag('page', 'checkout');
```

---

## Red Flags

- ❌ 生产环境 console.log 不处理 → 用户能看到，且丢失错误
- ❌ 错误上报用 fetch 而不是 sendBeacon → 页面卸载时 fetch 可能被取消
- ❌ localStorage 日志无限增长 → 限制条数（MAX_LOG_SIZE）
- ❌ 打点事件名不一致 → 统一命名规范 `{module}_{action}` 如 `order_submit`
- ❌ 重复上报（同一个错误报多次）→ 用 Set 去重
- ❌ 不上报用户上下文 → 无法定位到具体用户的错误
