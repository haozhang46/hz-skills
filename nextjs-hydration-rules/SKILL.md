---
name: nextjs-hydration-rules
description: Use when writing Next.js App Router components — enforces hydration safety rules for browser APIs, client/server boundaries, and list rendering
---

# Next.js App Router — Hydration Safety Rules

**Zero hydration mismatches. Every component must render identically on server and client.**

## The Rules

### 1. Browser APIs → useEffect or ClientOnly

`window`, `localStorage`, `navigator`, `document` do not exist on the server.

```tsx
// ❌ BROKEN — crashes SSR
const width = window.innerWidth;

// ✅ useEffect
useEffect(() => { const width = window.innerWidth; }, []);

// ✅ ClientOnly wrapper
<ClientOnly><Clock /></ClientOnly>
```

### 2. Time / Random / Browser-Only → ClientOnly

`toLocaleDateString()`, `Math.random()`, `Date.now()` differ between server and client.

```tsx
// ❌ HYDRATION MISMATCH
<span>{new Date(post.createdAt).toLocaleDateString()}</span>

// ✅ ClientOnly wrapper
<ClientOnly>
  <span>{new Date(post.createdAt).toLocaleDateString()}</span>
</ClientOnly>
```

### 3. Charts / Maps / Rich Text → dynamic(ssr: false)

```tsx
// ❌ Crashes SSR
import Chart from './Chart';

// ✅ Dynamic import, client only
const Chart = dynamic(() => import('./Chart'), { ssr: false });
```

### 4. Interactive Components → 'use client'

Any component using `onClick`, `onChange`, `useState`, `useEffect`, `useContext` must have `'use client'`.

```tsx
// ✅
'use client';
export default function LikeButton() { ... }
```

### 5. List Keys → Stable Unique ID Only

```tsx
// ❌ BROKEN — re-renders wrong DOM on reorder
{posts.map((_, i) => <div key={i} />)}
{posts.map((p) => <div key={Math.random()} />)}
{posts.map((p) => <div key={Date.now()} />)}

// ✅ Backend ID (preferred)
{posts.map((p) => <div key={p.id} />)}

// ✅ No backend ID → use uuid library
import { v4 as uuid } from 'uuid';
const items = rawItems.map((item) => ({ ...item, _id: uuid() }));
```

**Never** `Math.random()` or `Date.now()` for keys — they change every render and destroy React's reconciliation.

**`useId()` from React is NOT for list keys.** It's for accessibility attributes (`aria-labelledby`). Use `uuid` library or `crypto.randomUUID()` (browser-native).

### 6. suppressHydrationWarning — Time Text Only

```tsx
// ✅ OK — time text that differs by seconds
<span suppressHydrationWarning>{new Date().toISOString()}</span>

// ❌ DO NOT use on structural elements, classes, or as a permanent fix
```

### 7. Conditional First Render → Default + Effect Update

Dark mode, login modals, feature flags — render the safe default first, update in effect.

```tsx
// ❌ HYDRATION MISMATCH
const [dark, setDark] = useState(() => localStorage.getItem('theme') === 'dark');

// ✅ Default + effect
const [dark, setDark] = useState(false);
useEffect(() => {
  setDark(localStorage.getItem('theme') === 'dark');
}, []);
```

## Red Flags

- `window.` outside useEffect or `typeof window === 'undefined'` guard
- `new Date()` in JSX without ClientOnly
- `key={i}` or `key={Math.random()}`
- `suppressHydrationWarning` on non-time elements
- `localStorage` read during render (not in useEffect)

**Any of these = stop and fix before commit.**
