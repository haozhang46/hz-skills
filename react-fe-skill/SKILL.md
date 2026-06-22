---
name: react-fe-skill
description: Use when writing React components or hooks — enforces named hook functions, component/hook splitting by cohesion, and team conventions not covered by vercel-react-best-practices
---

# React Frontend Conventions

Team-specific React rules complementing `vercel-react-best-practices`.

## 1. Component Design — Before Writing Code

Before implementing, write a component breakdown:

```
Component: PostCard
  Props: { post: PostCardDTO; index: number }
  Responsibility: render a single post with left accent bar
  Scope: page — only used in BlogHomeSections
  Data flow: BlogHomeSections → useSWR → toPostCard[] → PostCard

Component: PostHero
  Props: { post: PostCardDTO }
  Responsibility: expanded first post with excerpt
  Scope: page — only used in BlogHomeSections
  Data flow: same as PostCard

Decision:
  - PostCard + PostHero → DON'T merge (different layout, different responsibilities)
  - PostCard → page-level, NOT global (only used by one page)
```

**Checklist before writing code:**

1. List each component with its props type signature
2. One sentence describing what it does (no "and")
3. Page-level or global?
4. Data source → which parent provides props → which child consumes them
5. Can any components merge? (same data, same responsibility, only styling differs)
6. Does any page component need promotion to global? (now used by 2+ pages)

## 2. Named Hook Functions

All React hooks must use named functions. Anonymous arrow functions forbidden.

```tsx
// ❌ anonymous
useEffect(() => { fetchData(); }, []);

// ✅ named
useEffect(function syncScroll() { fetchData(); }, []);
```

## 3. Component Splitting — High Cohesion, Low Coupling

**By scope:**

```
components/
├── ParticleBackground.tsx    # global — used across multiple pages
├── ScrollIndicator.tsx       # global
├── PostHero.tsx              # page — only used in blog home
├── PostListItem.tsx          # page
```

| Type | Location | Rule |
|------|----------|------|
| Global | `components/` | Used by 2+ pages or the root layout |
| Page | `app/<page>/` colocated | Only used by one page |

**By responsibility:** One component = one clear job. If you need "and" to describe what it does, split it.

```tsx
// ❌ too many responsibilities
function PostCardAndChat() { ... }

// ✅ single responsibility
function PostCard() { ... }
function ChatPanel() { ... }
```

## 4. Hook vs Util — The State Rule

```
Needs useState/useEffect/useRef? → Custom hook (useXxx)
Pure computation / formatting?    → Util function (src/utils/)
```

```tsx
// ❌ duplicate stateful logic in components
function PageA() {
  const [scroll, setScroll] = useState(0);
  useEffect(() => { ... }, []);
}
function PageB() {
  const [scroll, setScroll] = useState(0); // duplicated!
  useEffect(() => { ... }, []);
}

// ✅ extract to custom hook
function useScrollProgress() {
  const [scroll, setScroll] = useState(0);
  useEffect(() => { ... }, []);
  return scroll;
}

// ✅ extract to util (no state)
function formatPostDate(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}
```

| Has state / effects? | Extract to |
|---------------------|------------|
| Yes | `hooks/useXxx.ts` |
| No | `lib/xxx.ts` or `utils/xxx.ts` |

## 5. useContext + useReducer + useSelector

When `useContext` holds complex state, pair it with `useReducer` for predictable transitions and a custom `useSelector` to avoid full re-renders.

```tsx
// ✅ Context + Reducer + Selector pattern
type State = { posts: Post[]; filter: string; loading: boolean };
type Action = { type: 'SET_POSTS'; posts: Post[] } | { type: 'SET_FILTER'; filter: string };

function postReducer(state: State, action: Action): State { ... }

const PostCtx = createContext<{ state: State; dispatch: Dispatch<Action> }>(null!);

// Custom selector — component only re-renders when its slice changes
function useSelector<T>(selector: (s: State) => T): T {
  const { state } = useContext(PostCtx);
  const ref = useRef(selector(state));
  const next = selector(state);
  if (!Object.is(ref.current, next)) ref.current = next;
  return ref.current;
}

// Usage in component — no re-render on unrelated state changes
function PostList() {
  const posts = useSelector(s => s.posts);
  ...
}
```

**Why not just useContext alone:** Every state change re-renders ALL consumers. `useReducer` + `useSelector` gives you Redux-like precision without a library.

## 6. State Management — When to Use What

```
Component local state?
  → useState / useReducer

Shared by 2-5 components in same subtree?
  → useContext + custom hook wrapping it

Shared across pages, or 6+ consumers, or needs outside-React access?
  → Zustand (lightweight, selector-based, no boilerplate)

Large team, complex middleware, time-travel debugging?
  → Redux Toolkit
```

| Tool | Use when |
|------|----------|
| `useState` | Local to one component |
| `useContext` | Few consumers, same subtree, simple get/set |
| **Zustand** | App-wide, many consumers, outside React, selectors |
| Redux | Rare — only if the team/project already uses it |

**Key rule:** Never jump to a state library because "we might need it later." Start with `useContext`, extract to Zustand when the context re-render problem actually bites.

## 7. Error Boundaries — Crash a Section, Not the Whole Page

Wrap each logical section in its own ErrorBoundary. One component crashes → only that section shows fallback, the rest stays functional.

```tsx
// ✅ section-level boundaries
<ScrollSections>
  <section id="posts">
    <ErrorBoundary fallback={<p>Failed to load posts.</p>}>
      <PostList />
    </ErrorBoundary>
  </section>
  <section id="about">
    <ErrorBoundary fallback={<p>About section crashed.</p>}>
      <About />
    </ErrorBoundary>
  </section>
</ScrollSections>
```

Use `react-error-boundary` — same API as class-based, but hooks-friendly:

```tsx
import { ErrorBoundary } from 'react-error-boundary';

function PostList() {
  return (
    <ErrorBoundary
      fallback={<p className="editorial-empty">Something went wrong.</p>}
      onError={(err) => console.error(err)}
    >
      <Posts />
    </ErrorBoundary>
  );
}
```

| Rule | Why |
|------|-----|
| One per logical section | Isolate crashes, don't take down the page |
| `fallback` is a ReactNode | Match the design system, not a generic "Error!" text |
| `onError` to log | Don't swallow errors silently |
| NOT around every component | Only at meaningful boundaries (page sections, feature blocks) |

## 8. Suspense — Loading States Without `isLoading` Booleans

Use `Suspense` to handle async boundaries declaratively. No manual `if (isLoading)` checks.

```tsx
// ❌ manual loading flag — every component repeats this pattern
function Posts() {
  const { data, isLoading } = useSWR('/api/posts', fetcher);
  if (isLoading) return <Skeleton />;
  return <PostList posts={data} />;
}

// ✅ Suspense — loading lives at the boundary, component stays clean
function Posts() {
  const { data } = useSWR('/api/posts', fetcher, { suspense: true });
  return <PostList posts={data} />; // no isLoading check!
}

// Parent wraps with Suspense + fallback
<Suspense fallback={<PostListSkeleton />}>
  <Posts />
</Suspense>
```

Pair with ErrorBoundary for complete async state coverage:

```tsx
<ErrorBoundary fallback={<p>Failed</p>}>
  <Suspense fallback={<Skeleton />}>
    <Posts />
  </Suspense>
</ErrorBoundary>
// ↑ loading → Skeleton, error → Failed, success → Posts
```

| Pattern | Use |
|---------|-----|
| `if (isLoading)` in component | Simple, one-off — fine for small components |
| `Suspense` at page/section level | Multiple async components, want clean component code |
| `Suspense` + `ErrorBoundary` | Full coverage — loading + error handled declaratively |

## 9. Avoid forwardRef — Return API Object from Hook Instead

`forwardRef` + `useImperativeHandle` is fragile. Expose component API via a hook that returns methods.

```tsx
// ❌ forwardRef — fragile contract, no type-safe return, hidden API
const Table = forwardRef<TableHandle, Props>((props, ref) => {
  useImperativeHandle(ref, () => ({ reset: () => { ... }, refresh: () => { ... } }));
  return <table>...</table>;
});
// Usage: <Table ref={tableRef} /> — parent needs ref + typeof TableHandle

// ✅ hook returns API object — explicit, type-safe, discoverable
function useTable() {
  const [data, setData] = useState([]);
  const reset = () => setData([]);
  const refresh = () => fetchData().then(setData);
  return { data, reset, refresh };
}

function Table({ data }: { data: Item[] }) {
  return <table>...</table>;
}

// Usage:
function Page() {
  const { data, reset, refresh } = useTable();
  return (
    <>
      <button onClick={reset}>Reset</button>
      <Table data={data} />
    </>
  );
}
```

**Why:**
- Hook return type is explicit and IDE-discoverable
- No hidden imperative API — `const { reset } = useTable()` is self-documenting
- No ref juggling — `ref.current?.reset()` vs just calling `reset()`
- Works with React DevTools — ref methods are invisible

**Exception:** `forwardRef` is fine for DOM ref forwarding (`ref` to an `<input>` for focus management). Just don't use it to expose custom imperative methods.

## 10. Dynamic Rendering — Conditional Components, Lazy Load, Registry

**Conditional render — simple ternary or map:**

```tsx
// ✅ status → component map (strategy pattern)
const VIEW_MAP = { loading: Skeleton, error: ErrorCard, empty: Empty, ready: PostList } as const;

function Posts({ status }: { status: 'loading' | 'error' | 'empty' | 'ready' }) {
  const View = VIEW_MAP[status];
  return <View />;
}
```

**Dynamic import — heavy component, load on demand:**

```tsx
// ✅ Next.js dynamic — component only loaded when rendered
import dynamic from 'next/dynamic';
const HeavyChart = dynamic(() => import('./Chart'), {
  loading: () => <Skeleton />,
  ssr: false, // if it uses window/DOM
});
```

**Lazy — React built-in (no Next.js):**

```tsx
import { lazy, Suspense } from 'react';
const Chart = lazy(() => import('./Chart'));
<Suspense fallback={<Skeleton />}><Chart /></Suspense>
```

**Component Registry — render by name from data:**

```tsx
// ✅ registry pattern — data drives which component renders
const BLOCK_RENDERER: Record<string, React.FC<Block>> = {
  text: TextBlock,
  image: ImageBlock,
  code: CodeBlock,
  embed: EmbedBlock,
};

function Article({ blocks }: { blocks: Block[] }) {
  return blocks.map((b) => {
    const Renderer = BLOCK_RENDERER[b.type] ?? FallbackBlock;
    return <Renderer key={b.id} block={b} />;
  });
}
```

| Pattern | Use when |
|---------|----------|
| Ternary / `&&` | 2 states, simple |
| Map object | 3+ states, static list of variants |
| `dynamic()` | Next.js, heavy lib, SSR-skip |
| `lazy()` + `Suspense` | Plain React, code-splitting |
| Component registry | Data drives which component renders (CMS, block editor) |

## 11. Avoid cloneElement — Use Render Prop or Registry

`cloneElement` creates a new element every render, breaks `memo`, and causes cascading re-renders.

```tsx
// ❌ cloneElement — new element every render, breaks memo
function FormField({ children, label }: { children: ReactElement; label: string }) {
  return (
    <div>
      <span>{label}</span>
      {cloneElement(children, { id: label, required: true })}
    </div>
  );
}

// ✅ render prop — no clone, explicit contract
function FormField({ render, label }: { render: (props: FieldProps) => ReactNode; label: string }) {
  return (
    <div>
      <span>{label}</span>
      {render({ id: label, required: true })}
    </div>
  );
}
<FormField label="Email" render={(p) => <Input {...p} />} />

// ✅ component registry — data drives rendering, no clone
const FIELD_COMPONENTS = { text: Input, select: Select, date: DatePicker } as const;

function FormField({ type, ...fieldProps }: { type: keyof typeof FIELD_COMPONENTS } & FieldProps) {
  const Component = FIELD_COMPONENTS[type];
  return (
    <div>
      <span>{fieldProps.label}</span>
      <Component {...fieldProps} />
    </div>
  );
}

// ✅ children as function — pass props through function call
function FormField({ children, label }: { children: (props: FieldProps) => ReactNode; label: string }) {
  return <div><span>{label}</span>{children({ id: label, required: true })}</div>;
}
```

**Why cloneElement is harmful:**
- New React element object every render → `memo` is useless on children
- Cascading re-renders down the tree
- Hidden contract — child has no idea what props are being injected
- Slower than function call or JSX

**When cloneElement IS acceptable:** Injecting a class name or style into a single immediate child in a design-system component (e.g., `ButtonGroup` adding margin to `Button` children). Even then, prefer CSS `gap` or `:has()`.

## Why a Separate Skill

`vercel-react-best-practices` is upstream. Team conventions live here so the upstream skill stays updateable.
