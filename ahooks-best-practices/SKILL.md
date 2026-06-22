---
name: ahooks-best-practices
description: Use when writing React hooks — prefer ahooks over hand-written addEventListener/useCallback/localStorage patterns, useMemoizedFn replaces useCallback, useDebounceFn for search input
---

# ahooks Best Practices

**Don't hand-write what ahooks already solved. `pnpm add ahooks`.**

## 1. useDebounceFn / useThrottleFn — Don't Write Your Own

```tsx
// ❌ hand-written debounce — boilerplate, leak-prone
const debounced = useRef(setTimeout(…));
useEffect(() => () => clearTimeout(debounced.current), []);

// ✅ ahooks — one line, auto-cleanup
import { useDebounceFn } from 'ahooks';
const { run: debouncedSearch } = useDebounceFn(searchApi, { wait: 300 });
```

```tsx
// ✅ throttle — scroll lazy-loading
import { useThrottleFn } from 'ahooks';
const { run: throttledLoad } = useThrottleFn(loadMore, { wait: 200 });
```

## 2. useEventListener — Replace Manual addEventListener

```tsx
// ❌ manual — verbose, forgot cleanup = leak
useEffect(() => {
  const handler = (e) => setPos({ x: e.clientX, y: e.clientY });
  window.addEventListener('mousemove', handler);
  return () => window.removeEventListener('mousemove', handler);
}, []);

// ✅ ahooks — clean
import { useEventListener } from 'ahooks';
useEventListener('mousemove', (e) => setPos({ x: e.clientX, y: e.clientY }));
```

Target can be `window`, `document`, a ref, or a CSS selector string.

## 3. useMemoizedFn — Replaces useCallback Entirely

```tsx
// ❌ useCallback — stale closure risk, deps array hell
const handleClick = useCallback(() => {
  console.log(count); // might be stale!
}, [count]);

// ✅ useMemoizedFn — always calls latest, reference never changes
import { useMemoizedFn } from 'ahooks';
const handleClick = useMemoizedFn(() => {
  console.log(count); // always the latest value
});
```

**No deps array needed. Reference is stable forever.** Drop `useCallback` from your codebase.

## 4. useLocalStorageState — Persistent State

```tsx
import { useLocalStorageState } from 'ahooks';

const [theme, setTheme] = useLocalStorageState('theme', { defaultValue: 'dark' });
// auto-persisted, auto-synced across tabs
```

Also: `useSessionStorageState`, `useCookieState`.

## 5. useToggle / useBoolean — Simple State

```tsx
import { useToggle, useBoolean } from 'ahooks';

const [open, { toggle, setLeft, setRight }] = useToggle(false);
const [visible, { setTrue: show, setFalse: hide }] = useBoolean(false);
```

## 6. useUpdateEffect — Skip First Render

```tsx
import { useUpdateEffect } from 'ahooks';

// runs when deps change, but NOT on mount
useUpdateEffect(() => { fetchPosts(filter); }, [filter]);
```

## 7. useClickAway — Dropdown / Modal Close

```tsx
import { useClickAway } from 'ahooks';

const ref = useRef<HTMLDivElement>(null);
useClickAway(() => closeDropdown(), ref);
```

## 8. useLatest — Always Get Latest Value

```tsx
import { useLatest } from 'ahooks';

const latestProps = useLatest(props);
// latestProps.current always reflects the latest props, no stale closure
```

## Quick Decision

| You're writing... | Use |
|-------------------|-----|
| `addEventListener` | `useEventListener` |
| `useCallback(fn, deps)` | `useMemoizedFn(fn)` |
| `useEffect(fn, [])` that should skip mount | `useUpdateEffect(fn, deps)` |
| `setTimeout/clearTimeout` debounce | `useDebounceFn` |
| `localStorage.setItem` + `getItem` | `useLocalStorageState` |
| `useState(true)` toggle | `useToggle` / `useBoolean` |
| Click outside detection | `useClickAway` |
| `useRef(…); ref.current = …` to track latest | `useLatest` |
