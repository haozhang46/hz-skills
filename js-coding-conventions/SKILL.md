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

## Red Flags

- `a ? a.b.c : default` → `a?.b?.c ?? default`
- `&&` chain for property access → `?.`
- `||` for defaults where `0`/`''`/`false` is valid → `??`
- Nested ternary (more than one `?`) → map object or function
- Nested `if` (more than 1 level deep) → flatten with early return
- Raw boolean expression repeated in JSX → extract as named flag
- Long `if/else if` on the same variable → strategy map
