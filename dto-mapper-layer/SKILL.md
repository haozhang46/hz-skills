---
name: dto-mapper-layer
description: Use when fetching data from any source (REST, GraphQL, etc.) before storing in state — enforces a mapper/DTO transform layer, never store raw response directly
---

# DTO Mapper Layer

**Raw response → Mapper → DTO → State. Library-agnostic — SWR, React Query, fetch, axios, GraphQL all use the same pattern.**

## The Rule

```tsx
// ❌ BROKEN — raw response shape leaks into UI
const [posts, setPosts] = useState<Post[]>([]);
useEffect(() => { fetch('/api/posts').then(r => r.json()).then(setPosts); }, []);
// posts[0].created_at — snake_case, API-specific fields, nulls

// ❌ Also broken with any library
const { data } = useSWR('posts', url);     // SWR
const { data } = useQuery(...);             // React Query
const data = await fetch(...).then(r => r.json()); // plain fetch

// ✅ Mapper layer — works with any data fetching approach
const { data: raw } = useSWR('posts', fetchPosts);
const posts = useMemo(() => (raw ?? []).map(toPostCard), [raw]);

// DTO: clean, camelCase, UI-specific defaults
type PostCard = {
  id: string;
  title: string;
  excerpt: string;
  date: string;
};

// Mapper: API → DTO
function toPostCard(raw: Post): PostCard {
  return {
    id: raw.id,
    title: raw.title,
    excerpt: raw.content?.slice(0, 140) ?? '',
    date: new Date(raw.createdAt).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    }),
  };
}
```

## Why

- **API shape changes break UI in one place** — only the mapper, not every component
- **UI doesn't care about snake_case, nulls, or raw timestamps** — DTO gives it clean data
- **Testable** — mapper is a pure function, no mocking needed
- **Type-safe** — DTO types protect components from API drift

## Pattern

```
API Response (snake_case, raw types)
    ↓
Mapper Function (pure, testable)
    ↓
DTO (camelCase, UI-ready defaults)
    ↓
React State / useSWR
    ↓
Component
```

## Naming Convention

| Layer | Naming | Example |
|-------|--------|---------|
| API type | `Post` (from `@blog/api-client`) | `post.created_at` |
| Mapper | `toPostCard`, `toPostDetail` | Pure function |
| DTO type | `PostCard`, `PostDetail` | `postCard.date` |

## Red Flags

- `data.posts.map` in JSX without a mapper function
- `post.created_at` or `post.published_at` in component code
- `new Date(post.createdAt)` repeated across multiple components
- `post.content?.slice(0, 140)` inline in JSX
- Null checks on API fields scattered in components

**Any of these = extract a mapper function and a DTO type.**
