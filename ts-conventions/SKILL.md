---
name: ts-conventions
description: Use when writing TypeScript types, enums, or interfaces — enforces atomic global types, composition over duplication, enum patterns with useGetEnum hook
---

# TypeScript Conventions

## 1. Types Go Global, Atomic First

Define small, composable types in a shared location before using them.

```
types/
├── post.ts        # Post, PostStatus, PostMeta
├── user.ts        # User, UserRole
├── common.ts      # Paginated<T>, AsyncState<T>
└── index.ts       # re-export all
```

**Atomic:** One type = one concept. Compose later.

```ts
// ✅ atomic — small, focused
type PostStatus = 'draft' | 'published' | 'archived';
type PostMeta = { createdAt: string; updatedAt: string };

// ✅ compose from atoms
interface Post {
  id: string;
  title: string;
  status: PostStatus;
  meta: PostMeta;
}
```

## 2. Compose — interface extends / type union

```ts
// ✅ interface extends
interface PostCard extends PostMeta {
  id: string;
  title: string;
  excerpt: string;
}

// ✅ type intersection
type PostDetail = Post & { author: User; relatedPosts: PostCard[] };

// ✅ union for variants
type AsyncState<T> = 
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: string };
```

## 3. Centralized Enums + useGetEnum Hook

All enums live in one folder. The hook reads from there — no scattered enum definitions.

```
enums/
├── index.ts          # re-export all
├── post.ts           # PostStatus, PostCategory
├── user.ts           # UserRole
├── common.ts         # OrderDirection, Theme
└── labels.ts         # all UI label mappings
```

**Define enum + labels together:**

```ts
// enums/post.ts
export const PostStatus = {
  DRAFT: 'draft',
  PUBLISHED: 'published',
  ARCHIVED: 'archived',
} as const;
export type PostStatus = (typeof PostStatus)[keyof typeof PostStatus];

// enums/labels.ts — centralized label map
import { PostStatus } from './post';
import { UserRole } from './user';

export const ENUM_LABELS = {
  PostStatus: {
    [PostStatus.DRAFT]: 'Draft',
    [PostStatus.PUBLISHED]: 'Published',
    [PostStatus.ARCHIVED]: 'Archived',
  },
  UserRole: {
    [UserRole.ADMIN]: 'Admin',
    [UserRole.MEMBER]: 'Member',
  },
} as const;
```

**The hook reads from centralized labels:**

```ts
// hooks/useGetEnum.ts
import { ENUM_LABELS } from '@/enums/labels';

type EnumPair = [value: string, label: string];

function useGetEnum<K extends keyof typeof ENUM_LABELS>(
  enumName: K
): EnumPair[] {
  return useMemo(() => {
    const labels = ENUM_LABELS[enumName];
    return Object.entries(labels).map(([value, label]) => [value, label] as EnumPair);
  }, [enumName]);
}

// Usage — just pass the enum name
function PostFilter() {
  const statusOptions = useGetEnum('PostStatus');
  // [['draft', 'Draft'], ['published', 'Published'], ['archived', 'Archived']]
}
```

**Key rule:** Add enum → add labels in same commit. Hook doesn't take scattered label maps. Everything centralized.

## 4. No `any` — Use `unknown`

```ts
// ❌
function parse(data: any): Post { ... }

// ✅
function parse(data: unknown): Post {
  if (!isPost(data)) throw new Error('Invalid');
  return data;
}
```

## 5. Type Guards for External Data

Everything from API / localStorage needs runtime validation:

```ts
function isPost(data: unknown): data is Post {
  return (
    typeof data === 'object' &&
    data !== null &&
    'id' in data &&
    'title' in data
  );
}
```

## 6. Prefer `type` Over `interface` Unless Extending

```ts
// ✅ type — for unions, primitives, tuples
type Status = 'on' | 'off';
type Pair = [string, number];

// ✅ interface — when you plan to extend
interface BasePost { id: string; title: string; }
interface PostWithAuthor extends BasePost { author: User; }
```

## 7. `as const` for Literal Inference

```ts
// ❌ type is string[]
const COLORS = ['red', 'green', 'blue'];

// ✅ type is readonly ['red', 'green', 'blue']
const COLORS = ['red', 'green', 'blue'] as const;
```

## Red Flags

- `any` — use `unknown` or proper type
- API data without type guard — runtime will break
- Duplicate type definitions across files — extract to `types/`
- `interface` with only primitives — use `type`
- String union repeated inline — extract to named type
- Missing `as const` on const objects — type widens to `string`
