---
name: api-codegen
description: Use when generating TypeScript types and React hooks from OpenAPI/GraphQL specs — covers openapi-react-query, orval, and codegen workflow from API spec to typed hooks
---

# API Codegen — OpenAPI → Typed React Hooks

## 1. Tool Choice

| Tool | Generates | Best for |
|------|-----------|----------|
| **openapi-react-query** | TanStack Query hooks + TS types | Already using TanStack Query |
| **orval** | React Query / SWR hooks + Zod schemas + TS types | Want Zod validation built-in |
| **hey-api** | TS types + fetch client + react-query hooks | Lightweight, no codegen config needed |
| **openapi-typescript** | TS types only | Just need types, write hooks manually |

**Recommendation:** `openapi-react-query` if using TanStack Query. `orval` if using SWR or need Zod.

## 2. openapi-react-query Setup

```bash
pnpm add -D @openapi-react-query/openapi-react-query openapi-typescript
```

```ts
// codegen.ts
import { defineConfig } from '@openapi-react-query/openapi-react-query';

export default defineConfig({
  input: './api-spec.yaml',     // or https://api.example.com/openapi.json
  output: './src/api',
  plugins: ['@tanstack/react-query'],
});
```

```json
// package.json
{
  "scripts": {
    "codegen": "openapi-react-query --config codegen.ts"
  }
}
```

**Generated output:**
```
src/api/
├── types.ts           // Post, User, CreatePostInput, etc.
├── posts/
│   ├── useGetPosts.ts     // useQuery({ queryKey: ['posts'], queryFn })
│   ├── useGetPost.ts      // useQuery({ queryKey: ['posts', id], queryFn })
│   ├── useCreatePost.ts   // useMutation({ mutationFn })
│   └── useDeletePost.ts
└── core/
    ├── queryClient.ts
    └── fetcher.ts
```

## 3. orval — SWR / Zod Alternative

```bash
pnpm add -D orval
```

```js
// orval.config.js
module.exports = {
  api: {
    input: './api-spec.yaml',
    output: {
      target: './src/api',
      client: 'swr',               // or 'react-query'
      mode: 'tags-split',           // one file per tag
      override: {
        mutator: { path: './src/lib/http.ts', name: 'http' },
      },
    },
  },
};
```

**Generated output:**
```
src/api/posts/posts.ts   // useGetPosts(), useCreatePost() — SWR hooks
src/api/posts/posts.zod.ts // Zod schemas — runtime validation
src/api/posts/posts.schemas.ts // TypeScript types
```

## 4. Apifox → OpenAPI Spec

Apifox exports OpenAPI 3.0 JSON/YAML. Use that as `input` for any codegen tool.

```bash
# Export from Apifox UI → download spec.yaml
# Then run codegen
pnpm codegen
```

## 5. CI Integration

```json
{
  "scripts": {
    "codegen": "openapi-react-query --config codegen.ts",
    "codegen:check": "pnpm codegen && git diff --exit-code src/api"
  }
}
```

Add to CI: `pnpm codegen:check` — fails if generated code doesn't match spec. Ensures API types always in sync.

## Red Flags

- Hand-writing `useQuery<Post>` with generic type → generate from spec
- API spec changes without re-running codegen → drift
- Generated files in `.gitignore` → commit them, they're source of truth
- `as Post` cast after fetch → use generated types with `useQuery()` return
