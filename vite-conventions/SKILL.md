---
name: vite-conventions
description: Use when configuring Vite — covers HMR optimization, esbuild, env files, source maps, and package.json scripts
---

# Vite Conventions

## 1. HMR Optimization for Large Projects

```ts
// vite.config.ts
export default defineConfig({
  server: {
    warmup: {
      clientFiles: ['./src/**/*.tsx'], // pre-transform on startup
    },
  },
  optimizeDeps: {
    include: ['lodash-es', 'ahooks'], // pre-bundle heavy deps
    exclude: [],                      // exclude packages that break when pre-bundled
  },
});
```

| Optimization | Effect |
|-------------|--------|
| `warmup.clientFiles` | Pre-transform on dev start, no first-visit lag |
| `optimizeDeps.include` | Pre-bundle heavy deps via esbuild, skip per-request transform |
| Route-based code splitting | Only load current page's modules |

## 2. esbuild — Built-in, No Config Needed

Vite uses esbuild internally for dev transforms and dependency pre-bundling. It's 10-100x faster than babel-based tooling. No extra plugin needed.

```ts
// esbuild is used automatically for:
// - TypeScript stripping (no type-checking — that's tsc --noEmit in CI)
// - JSX transform
// - Dependency pre-bundling
// - Minification (build)

// For build, esbuild is the default. Nothing to configure.
```

## 3. Source Maps

```ts
// vite.config.ts
export default defineConfig({
  build: {
    sourcemap: true,                     // generate .map files for production debugging
    // or
    sourcemap: 'hidden',                 // .map exists but not referenced in bundle (safer)
  },
});
```

| Value | Use |
|-------|-----|
| `true` | Separate `.map` files, referenced in bundle |
| `'hidden'` | `.map` exists but not referenced — give to error tracker only |
| `'inline'` | Embedded in bundle — dev only |
| `false` | No source maps — smallest bundle |

## 4. Env Files

```
.env                # default, committed (non-secret defaults)
.env.local          # local overrides, gitignored
.env.development    # dev-specific
.env.production     # prod-specific
```

```ts
// Client — VITE_ prefix auto-exposed
const apiUrl = import.meta.env.VITE_API_URL;

// Server-side — not accessible
// import.meta.env.VITE_* is undefined in server code
```

## 5. package.json Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "dev:staging": "vite --mode staging",
    "build": "tsc --noEmit && vite build",
    "build:prod": "tsc --noEmit && vite build --mode production",
    "preview": "vite preview",
    "analyze": "vite build --mode analyze"
  }
}
```

**Key:** `tsc --noEmit` before build — catches type errors esbuild would skip.

## 6. Chunk Splitting — Control Bundle Size

Vite uses Rollup under the hood. Configure `output.manualChunks` in `vite.config.ts`:

```ts
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // Vendor chunks — split heavy deps from app code
          react: ['react', 'react-dom'],
          three: ['three'],
          lodash: ['lodash-es'],
          // Group related deps
          ui: ['@blog/ui', '@blog/theme'],
          // Everything else in node_modules → shared vendor chunk
          vendor: ['ahooks', 'swr', 'gsap'],
        },
      },
    },
  },
});
```

**Auto-chunk strategy (function form):**
```ts
manualChunks(id: string) {
  // Split node_modules into per-package chunks
  if (id.includes('node_modules')) {
    if (id.includes('react') || id.includes('react-dom')) return 'react';
    if (id.includes('three')) return 'three';
    if (id.includes('lodash-es')) return 'lodash';
    return 'vendor'; // rest of deps
  }
  // App code stays together (or split by route)
}
```

| Strategy | Use |
|----------|-----|
| Named vendor chunks | Few large deps (React, Three.js, lodash) |
| Function-based | Many deps, auto-group by package |
| No manualChunks | Small projects — default is fine |

**Split by route (lazy load pages):**
```ts
manualChunks(id: string) {
  if (id.includes('pages/posts')) return 'posts';
  if (id.includes('pages/about')) return 'about';
}
```

## Red Flags

- `process.env.*` in client code → `import.meta.env.VITE_*`
- `import.meta.env.VITE_*` in server code → undefined
- No `tsc --noEmit` in CI → types unchecked at build time
- `.env.production` committed with secrets
- `sourcemap: false` in production → can't debug errors
