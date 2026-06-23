---
name: fe-security
description: Frontend security — XSS, form encoding, CSRF, token storage, CSP, CORS, IDOR, iframe postMessage, dependency audit
---

# Frontend Security

## 1. XSS — Never `dangerouslySetInnerHTML` Without Sanitization

```tsx
// ❌ XSS hole — user content rendered as HTML
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// ✅ sanitize first
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userInput) }} />
```

**Rules:**
- React's JSX auto-escapes `{userInput}` — safe by default
- `dangerouslySetInnerHTML` = must sanitize with `DOMPurify`
- URL params rendered in JSX → encode with `encodeURIComponent`
- Never pass user input to `eval()`, `new Function()`, `setTimeout(string)`

## 2. Token Storage — httpOnly Cookie, Not localStorage

```ts
// ❌ XSS steals token
localStorage.setItem('token', jwt);

// ✅ httpOnly cookie — JS can't read it
// Set-Cookie: token=xxx; HttpOnly; SameSite=Strict; Secure; Path=/
```

| Storage | XSS-safe? | CSRF-safe? | Use |
|---------|-----------|------------|-----|
| `localStorage` | ❌ | ✅ | Never for tokens |
| `sessionStorage` | ❌ | ✅ | Never for tokens |
| Cookie (no HttpOnly) | ❌ | ❌ | Never |
| **Cookie + HttpOnly + SameSite** | ✅ | ✅ | Always |

Axios: `withCredentials: true` sends httpOnly cookies automatically.

## 3. CSRF — SameSite Cookie + Token Header

```ts
// SameSite=Lax — blocks cross-site POST requests
// Set-Cookie: token=xxx; HttpOnly; SameSite=Lax; Path=/
```

Modern browsers block cross-site cookies by default with `SameSite=Lax`. Double-submit cookie or CSRF token header for extra safety on critical endpoints.

## 4. CSP — Content Security Policy Header

```html
<!-- server response header -->
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' https:; connect-src 'self' https://api.example.com; font-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none';
```

**Key directives:**

| Directive | Purpose |
|-----------|---------|
| `script-src 'self'` | Block inline scripts + external scripts |
| `connect-src` | Limit where fetch/XHR can go |
| `frame-ancestors 'none'` | Prevent clickjacking |
| `object-src 'none'` | Block Flash/ActiveX |

## 5. CORS — Whitelist, Not Wildcard

```ts
// ❌
Access-Control-Allow-Origin: *

// ✅
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Credentials: true
```

Credentials + wildcard origin = browser rejects the combination. Always whitelist specific origins.

## 6. Dependency Audit

```bash
pnpm audit                    # npm audit equivalent
pnpm audit --prod             # production deps only
```

CI should run `pnpm audit --audit-level=high` and fail on critical vulnerabilities.

## 7. Input / Output Boundaries

```ts
// Input — validate at the boundary
const email = z.string().email().parse(input); // Zod validates

// Output — encode for context
encodeURIComponent(userInput)   // URL param
DOMPurify.sanitize(userInput)   // HTML
JSON.stringify(userInput)       // JSON (prevents injection in <script> tags)
```

## 8. IDOR — URL 中 ID 的权限校验

URL 里带 ID（`/api/orders/123`）本身不是问题，问题在于**后端有没有校验当前用户是否有权限访问这个 ID**。

### 正确做法：后端校验（不是前端能控制的）

```ts
// ❌ 只查订单，不查归属
app.get('/api/orders/:id', (req, res) => {
  const order = db.query('SELECT * FROM orders WHERE id = ?', req.params.id);
  res.json(order);
});

// ✅ 校验当前用户是否属于这个订单
app.get('/api/orders/:id', (req, res) => {
  const order = db.query(
    'SELECT * FROM orders WHERE id = ? AND user_id = ?',  // ← 关键
    req.params.id, req.user.id
  );
  if (!order) return res.status(403).json({ error: '无权访问' });
  res.json(order);
});
```

### ID 可预测时的额外防护

即使有了权限校验，可预测的 ID（自增 1,2,3）在以下场景仍有风险：

| 场景 | 风险 | 防护 |
|------|------|------|
| 订单列表 | 知道别人的订单号 | ✅ `WHERE user_id = ?` 已过滤 |
| 用户公开资料 | ID 可遍历抓取 | 加频率限制（Rate Limit） |
| 邀请链接 / 分享 | 猜别人 ID 看私密内容 | 用 UUID 替代自增 ID |

### 防止 ID 遍历

```ts
// ❌ 自增 ID 可遍历
/api/users/1
/api/users/2
/api/users/3  // 暴力猜

// ✅ UUID 不可预测
/api/users/a1b2c3d4-e5f6-7890-abcd-ef1234567890

// ✅ 或者加 Rate Limit
app.use('/api/users/:id', rateLimit({
  windowMs: 60 * 1000,   // 1 分钟
  max: 10,                // 最多 10 次
}));
```

### 常见误区

```ts
// ❌ 误区：前端把 ID 藏起来就安全了
// 前端不显示 ID，但浏览器 DevTools Network 还是能看到请求

// ❌ 误区：用 POST 代替 GET 来隐藏 ID
// POST /api/order  body: { id: 123 }  → 同样暴露

// ❌ 误区：前端加密 ID
// 前端加密 → 后端解密 → 加密算法暴露在 JS 里 → 伪安全

// ✅ 正确：后端永远校验权限，URL 里有没有 ID 不重要
```

### 三层防御

```
第一层：认证（你是谁）          → JWT / Session
第二层：授权（你能做什么）      → WHERE user_id = ?
第三层：限流（防止暴力遍历）    → Rate Limit
```

| 措施 | 解决什么问题 | 谁负责 |
|------|------------|--------|
| 权限校验 `WHERE user_id = ?` | 别人拿你的 ID 访问 | 后端 |
| UUID 替代自增 ID | 防止 ID 被猜出来 | 后端 |
| Rate Limit | 防止批量遍历 | 后端/Nginx |
| 前端不暴露多余信息 | 减少攻击面 | 前端 |



---

## 9. 表单编码 — HTML Entity / URL / XSS

### 编码场景

| 场景 | 编码方式 | 示例 |
|------|---------|------|
| HTML 内容中显示 | HTML Entity | `&lt;script&gt;` |
| HTML 属性中显示 | HTML Entity + 引号转义 | `&quot;` `&#39;` |
| URL 参数中传递 | URL 编码 | `%3Cscript%3E` |
| JSON 中传递 | JSON 序列化（内置转义） | `\u003Cscript\u003E` |

### 使用 `xss` npm 包

```bash
npm install xss
```

```js
const xss = require('xss');

xss('<script>alert(1)</script>');                                // 全过滤
xss(userInput, { whiteList: { b: [], i: [], a: ['href'] } });    // 白名单
xss(userInput, { whiteList: {} });                                // 纯文本
```

| 能力 | `xss` 包 | 手动转义 |
|------|---------|---------|
| `<script>` 转义 | ✅ | ✅ |
| 事件属性（`onerror=`） | ✅ | ❌ |
| `javascript:` 协议 | ✅ | ❌ |
| CSS 注入 | ✅ | ❌ |
| 白名单标签 | ✅ | ❌ |

### DOMPurify

```tsx
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userInput, {
  ALLOWED_TAGS: ['b', 'i', 'em', 'a', 'p'],
  ALLOWED_ATTR: ['href', 'target'],
}) }} />
```

### URL 编码

```js
// ✅ 参数值必须编码
fetch(`/api/search?q=${encodeURIComponent(userInput)}`);

// ❌ 手动拼 form 数据
const formData = `name=${userInput}`;

// ✅ URLSearchParams（自动编码）
const params = new URLSearchParams();
params.append('name', userInput);
```

| API | 自动编码 | 文件 |
|-----|---------|------|
| `URLSearchParams` | ✅ | ❌ |
| `FormData` | ✅ | ✅ |
| 手动拼接 | ❌ | ❌ |

### 常见 XSS 注入点

```tsx
// ❌ 属性注入
<img src={userInput} />    // " onfocus="alert(1)

// ❌ javascript: 协议
<a href={userInput}>链接</a>

// ✅ 协议白名单
function safeUrl(url) {
  const allowed = ['http:', 'https:', 'mailto:', 'tel:'];
  try { const p = new URL(url); return allowed.includes(p.protocol) ? url : '#'; }
  catch { return '#'; }
}
```

### 编码对比表

| 输入 `<script>alert(1)</script>` | 输出 | 安全 |
|---|---|---|
| 不处理 | 弹窗 | ❌ |
| React `{input}` | 显示文本 | ✅ |
| `xss(input)` | `&lt;script&gt;` | ✅ |
| `encodeURIComponent(input)` | `%3Cscript%3E` | ✅ |
| `DOMPurify.sanitize(input)` | 空（白名单外） | ✅ |

---

## 10. iframe postMessage — 域名白名单

```tsx
// 父页面 → iframe（必须指定 targetOrigin）
iframeRef.current?.contentWindow?.postMessage(data, 'https://trusted.com');
// ❌ postMessage(data, '*')
```

```tsx
// 父页面 ← iframe（校验 event.origin）
const ALLOWED = ['https://trusted-app.example.com'];
useEffect(() => {
  const handler = (e: MessageEvent) => {
    if (!ALLOWED.includes(e.origin)) return;   // 1️⃣ 域名白名单
    if (!e.data?.type) return;                  // 2️⃣ 结构校验
    switch (e.data.type) { /* 3️⃣ 分发 */ }
  };
  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}, []);
```

| 做法 | 风险 |
|------|------|
| `postMessage(data, '*')` | 任何窗口能收到 |
| 不校验 `event.origin` | 任意网站伪造消息 |
| 不校验 `data` 结构 | Prototype pollution |
| 只校验 `event.source` | 可伪造 |

## Red Flags

- `localStorage.getItem('token')` — migrate to httpOnly cookie
- `dangerouslySetInnerHTML` without `DOMPurify`
- `Access-Control-Allow-Origin: *` with credentials
- No CSP header on the page
- `eval()` or `new Function()` anywhere near user input
- JWT stored in sessionStorage — still readable by XSS
- `href={userInput}` 不校验 → `javascript:` 协议 XSS
- 手动拼 URL 参数不 `encodeURIComponent` → 参数注入
- 前端编码就够了，后端不需要 → 后端也必须编码/校验
- `postMessage(data, '*')` → 必须指定具体域名
- `message` 事件不校验 `event.origin` → 任意网站伪造消息
