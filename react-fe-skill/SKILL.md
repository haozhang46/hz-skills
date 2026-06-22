---
name: react-fe-skill
description: Use when writing React components or hooks — enforces named hook functions, explicit returns, and other team conventions not covered by vercel-react-best-practices
---

# React Coding Conventions

Team-specific React rules that complement `vercel-react-best-practices`.

## Named Hook Functions

All React hooks must use named functions. Anonymous arrow functions in hooks are forbidden.

```tsx
// ❌ FORBIDDEN — anonymous
useEffect(() => { fetchData(); }, []);
useCallback(() => { doThing(); }, []);
useMemo(() => compute(items), [items]);

// ✅ REQUIRED — named function
useEffect(function syncScroll() { fetchData(); }, []);
useCallback(function handleClick() { doThing(); }, []);
useMemo(function countTotal() { return compute(items); }, [items]);
```

**Why:**
- Named functions appear in React DevTools profiler instead of "Anonymous"
- Stack traces are readable — `syncScroll` vs `<anonymous>`
- Self-documenting — the name says what the effect does

## Why a Separate Skill

`vercel-react-best-practices` is an upstream dependency. Team-specific conventions live here so the upstream skill stays updateable.
