---
name: js-coding-conventions
description: Use when writing JavaScript/TypeScript logic — enforces optional chaining, nullish coalescing, flat conditionals, extracted flags, early returns, and practical design patterns
---

# JavaScript Coding Conventions

## 1. `?.` and `??` Over Ternary / `&&`

```ts
// ❌ verbose, unsafe
const name = obj && obj.user && obj.user.name ? obj.user.name : 'unknown';

// ✅ optional chaining + nullish coalescing
const name = obj?.user?.name ?? 'unknown';
```

| Use | Instead of |
|-----|-----------|
| `a?.b` | `a && a.b` or `a ? a.b : undefined` |
| `a ?? b` | `a != null ? a : b` or `a || b` (when `0`/`''`/`false` are valid) |

## 2. No Nested Ternary

```ts
// ❌ unreadable
const label = loading ? 'Loading...' : error ? 'Error' : empty ? 'No data' : 'Ready';

// ✅ if/else, map object, or switch
const LABEL_MAP = { loading: 'Loading...', error: 'Error', empty: 'No data', ready: 'Ready' };
const label = LABEL_MAP[status];

// ✅ or extract to function with early returns
function getLabel(status: string) {
  if (status === 'loading') return 'Loading...';
  if (status === 'error') return 'Error';
  if (status === 'empty') return 'No data';
  return 'Ready';
}
```

## 3. No Nested If-Else — Flatten with Early Return

```ts
// ❌ arrow anti-pattern
function process(order: Order) {
  if (order.isPaid) {
    if (order.items.length > 0) {
      if (!order.isShipped) {
        ship(order);
      } else {
        throw new Error('Already shipped');
      }
    } else {
      throw new Error('No items');
    }
  } else {
    throw new Error('Not paid');
  }
}

// ✅ guard clauses — main logic at the end, no nesting
function process(order: Order) {
  if (!order.isPaid) throw new Error('Not paid');
  if (order.items.length === 0) throw new Error('No items');
  if (order.isShipped) throw new Error('Already shipped');
  ship(order);
}
```

## 4. Extract Conditions as Named Flags

```ts
// ❌ what does this mean?
if (user.role === 'admin' && user.subscription?.tier === 'pro' && !user.isBanned) { ... }

// ✅ self-documenting
const isProAdmin = user.role === 'admin' && user.subscription?.tier === 'pro';
const isActiveUser = !user.isBanned;
if (isProAdmin && isActiveUser) { ... }
```

Naming convention: `isXxx`, `hasXxx`, `canXxx`, `shouldXxx`, `needsXxx`.

## 5. Early Return — Fail Fast

```ts
function validate(input: Input): Result {
  if (!input.email) return { ok: false, error: 'Email required' };
  if (!input.password) return { ok: false, error: 'Password required' };
  if (input.password.length < 8) return { ok: false, error: 'Too short' };
  return { ok: true, value: sanitize(input) };
}
```

Main logic goes after all guards. No `else` needed.

## 6. Practical Design Patterns

### Strategy / Map Dispatch

```ts
// ❌ long switch/if-else chain
function handle(type: string) {
  if (type === 'email') return sendEmail();
  if (type === 'sms') return sendSMS();
  if (type === 'push') return sendPush();
}

// ✅ strategy map
const handlers: Record<string, () => void> = {
  email: sendEmail,
  sms: sendSMS,
  push: sendPush,
};
handlers[type]?.();
```

### Builder (for complex object construction)

```ts
class QueryBuilder {
  private filters: string[] = [];
  private sort = '';
  where(field: string, value: string) { this.filters.push(`${field}=${value}`); return this; }
  orderBy(field: string) { this.sort = `ORDER BY ${field}`; return this; }
  build() { return `SELECT * ${this.filters.join(' AND ')} ${this.sort}`.trim(); }
}
```

### Observer (for decoupled event handling)

```ts
type Listener = (data: unknown) => void;
const listeners = new Map<string, Set<Listener>>();

function on(event: string, fn: Listener) { ... }
function emit(event: string, data: unknown) { ... }
function off(event: string, fn: Listener) { ... }
```

### Factory (when construction logic is non-trivial)

```ts
function createUser(type: 'admin' | 'member', email: string): User {
  const base = { email, createdAt: new Date() };
  if (type === 'admin') return { ...base, role: 'admin', permissions: ALL } as Admin;
  return { ...base, role: 'member', permissions: DEFAULT } as Member;
}
```

## 7. Map / Set / WeakMap / WeakSet — When to Use

| Structure | Use when | Don't use when |
|-----------|----------|----------------|
| **Map** | Key-value pairs with non-string keys (objects, functions); need `size`; frequent add/delete; iteration order matters | Keys are always strings → plain `{}` |
| **Set** | Unique values; `has()`/`delete()` performance; deduplication | Simple arrays with few items |
| **WeakMap** | Key is an object, value is metadata; auto-GC when object is unreachable; private data | Need to iterate; need `size`; keys are primitives |
| **WeakSet** | Track object membership without preventing GC; "has this object been seen?" | Need to iterate; storing primitives |

```ts
// ✅ Map — DOM node → state mapping
const nodeStates = new Map<HTMLElement, { clicked: boolean }>();
nodeStates.set(el, { clicked: true });
nodeStates.get(el); // O(1), no string coercion

// ✅ Set — deduplication
const seen = new Set<string>();
items.filter((i) => !seen.has(i.id) && seen.add(i.id));

// ✅ WeakMap — attach private metadata to objects, auto-cleanup
const metadata = new WeakMap<object, { createdAt: Date }>();
function track(obj: object) { metadata.set(obj, { createdAt: new Date() }); }
// obj gets GC'd → metadata entry disappears automatically

// ✅ WeakSet — "was this object already processed?"
const processed = new WeakSet<object>();
function process(obj: object) {
  if (processed.has(obj)) return;
  processed.add(obj);
}
```

| Scenario | Best choice |
|----------|-------------|
| Cache with object keys → auto-evict on GC | `WeakMap` |
| Deduplicate array by value | `Set` |
| Object → extra data (DOM elements, React refs) | `Map` |
| Private per-instance data not on prototype | `WeakMap` |
| "Already visited?" for graph/tree traversal | `WeakSet` or `Set` (depends on GC need) |
| Simple config object with string keys | Plain `{}` — not Map |

## 8. Every Promise Must Handle Rejection

No uncaught promises. Every `await`/`.then()` must have a corresponding catch or try/catch.

```tsx
// ❌ uncaught — silent failure, swallowed error
await fetchPosts();
fetch('/api/posts').then(r => r.json());

// ✅ try/catch
try {
  await fetchPosts();
} catch (err) {
  console.error('Failed to fetch posts', err);
}

// ✅ .catch()
fetch('/api/posts')
  .then(r => r.json())
  .catch(err => console.error('Failed', err));

// ✅ SWR/React Query handle errors internally — no manual catch needed
const { data, error } = useSWR('/api/posts', fetcher);
```

**Exception:** Library-managed promises (SWR, React Query, ahooks useRequest) — they expose `error` in return value, no manual catch needed.

**For async event handlers:** wrap the body in try/catch.

```tsx
// ❌ uncaught in event handler
onClick={async () => { await submit(); }}

// ✅
onClick={async () => { try { await submit(); } catch (err) { setError(err.message); } }}
```

## 9. Function Arguments — Destructure, No `arguments`, Max 3

```tsx
// ❌ positional — unreadable at call site
function createPost(title: string, content: string, published: boolean, authorId: string) {}
createPost('Hello', '...', true, 'u-123'); // what does true mean?

// ✅ options object, destructure in body
function createPost(params: CreatePostParams) {
  const { title, content, published = false, authorId } = params;
}
createPost({ title: 'Hello', content: '...', authorId: 'u-123' });
```

**Rules:**

| Rule | Why |
|------|-----|
| Max 3 parameters | Beyond 3 → refactor to options object |
| Destructure in body | `const { a, b } = props` — not in signature |
| Signature is `props: Props` | Single typed parameter, clean |
| Defaults in destructure | `const { published = false } = props` |
| Type the options object | `CreatePostParams` interface, not inline |
| Never use `arguments` | Use rest params `...args` instead |
| Boolean params → options object | `createPost({ published: true })` not `createPost(true)` |

```tsx
// ❌ destructure in signature — noisy, messy with spread
function PostCard({ title, excerpt, date, ...rest }: Props) { ... }

// ✅ clean signature, destructure in body
function PostCard(props: Props) {
  const { title, excerpt, date } = props;
}
```

```tsx
// ❌ arguments object — no type safety, no arrow function support
function sum() { return Array.from(arguments).reduce((a, b) => a + b, 0); }

// ✅ rest parameters
function sum(...nums: number[]) { return nums.reduce((a, b) => a + b, 0); }
```

## Red Flags

- `await x()` without `try` above it — needs catch
- `.then(r => r.json())` without `.catch` — unhandled rejection
- `a ? a.b.c : default` → `a?.b?.c ?? default`
- `&&` chain for property access → `?.`
- `||` for defaults where `0`/`''`/`false` is valid → `??`
- Nested ternary (more than one `?`) → map object or function
- Nested `if` (more than 1 level deep) → flatten with early return
- Raw boolean expression repeated in JSX → extract as named flag
- Long `if/else if` on the same variable → strategy map
