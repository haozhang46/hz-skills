---
name: micro-frontend
description: Use when architecting large frontend projects with multiple teams or independent deployments — covers Module Federation, qiankun, wujie, and micro-frontend vs monorepo decision
---

# Micro-Frontend Architecture

## 1. When to Use — Threshold Check

| Scale | Solution |
|-------|----------|
| 1 team, 1 app, single deploy | Monolith or monorepo |
| 1-2 teams, shared code, same deploy | **Monorepo** (pnpm workspaces + Turborepo) |
| 3+ teams, independent deploy cycles | **Micro-frontend** |
| Legacy migration (gradual rewrite) | Micro-frontend (strangler pattern) |

**Micro-frontend is NOT free.** It adds complexity: shared deps, CSS isolation, inter-app communication, routing. Only use it when independent deploy is non-negotiable.

## 2. Framework Choice

| Framework | Approach | Best for |
|-----------|----------|----------|
| **Module Federation** (Webpack 5 / `@originjs/vite-plugin-federation`) | Runtime shared modules | Webpack or Vite projects, shared deps |
| **qiankun** | Sandboxed iframe-like sub-apps | Alibaba ecosystem, Chinese docs |
| **wujie** | WebComponent sandbox | Modern alternative to qiankun |
| **single-spa** | Framework-agnostic router | Mix React/Vue/Angular |
| **micro-app** | WebComponent-based | JD.com ecosystem |

## 3. Module Federation (Webpack 5)

```js
// Host app — webpack.config.js
const { ModuleFederationPlugin } = require('webpack').container;
module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: 'host',
      remotes: {
        posts: 'posts@https://posts.example.com/remoteEntry.js',
        editor: 'editor@https://editor.example.com/remoteEntry.js',
      },
      shared: { react: { singleton: true }, 'react-dom': { singleton: true } },
    }),
  ],
};
```

```js
// Remote app (posts)
new ModuleFederationPlugin({
  name: 'posts',
  filename: 'remoteEntry.js',
  exposes: { './PostList': './src/PostList' },
  shared: { react: { singleton: true }, 'react-dom': { singleton: true } },
});
```

**Host consumes:**
```tsx
const PostList = lazy(() => import('posts/PostList'));
<Suspense fallback={<Skeleton />}><PostList /></Suspense>
```

| Pro | Con |
|-----|-----|
| Share deps at runtime (single React instance) | Complex config |
| Independent deploy per module | Version mismatch risk |
| No iframe overhead | Shared dep negotiation |

## 4. Vite Module Federation

```bash
pnpm add -D @originjs/vite-plugin-federation
```

```ts
// vite.config.ts (host)
import federation from '@originjs/vite-plugin-federation';
export default defineConfig({
  plugins: [
    federation({
      name: 'host',
      remotes: { posts: 'http://localhost:5001/assets/remoteEntry.js' },
      shared: ['react', 'react-dom'],
    }),
  ],
});
```

## 5. Chunk Strategy for Micro-Frontend

```ts
// Each micro-app controls its own chunks
// vite.config.ts — posts micro-app
build: {
  rollupOptions: {
    output: {
      manualChunks: {
        'posts-vendor': ['react', 'react-dom', 'lodash-es'],
        'posts-editor': ['@blog/editor'],
      },
    },
  },
}
```

Shared deps (`react`, `react-dom`) should be `{ singleton: true }` in Module Federation — only one instance loaded at runtime.

## 6. Monorepo + Micro-Frontend Hybrid

```
apps/
├── host/         # shell — routing, layout, auth
├── posts/        # micro-app — blog posts
├── editor/       # micro-app — writing editor
├── admin/        # micro-app — admin panel
packages/
├── api-client/   # shared — types + fetch (NOT loaded by Module Federation)
├── ui/           # shared — Button, Card (could be a remote module)
└── theme/        # shared — design tokens
```

**Rule:** `packages/` for code that can be bundled at build time. Module Federation for code that must be shared at runtime.

## 7. 部署策略

### 独立部署（核心优势）

每个微前端独立构建、独立部署，互不阻塞。

```
                 ┌─────────────────────┐
                 │    CDN / OSS        │
                 │                     │
                 │  host/              │
                 │   ├── index.html    │ ← 版本入口
                 │   └── assets/       │
                 │                     │
                 │  posts/             │
                 │   ├── remoteEntry.js│ ← 当前版本
                 │   └── 1.2.0/        │ ← 历史版本（回滚用）
                 │                     │
                 │  editor/            │
                 │   └── remoteEntry.js│
                 └─────────────────────┘
```

### 三种部署模式

#### 模式 A：全量部署（简单，适合小团队）

所有微前端一起构建、一起发布。

```
CI 触发 → 构建 host + posts + editor + admin → 统一上传 CDN → 刷新
```

| 优点 | 缺点 |
|------|------|
| 简单，版本一致 | 一个改全部部署，失去独立部署优势 |

#### 模式 B：独立部署（推荐）

每个微前端单独 CI/CD，各自上传 CDN，版本互不依赖。

```
posts 变更 → 构建 posts → 上传 CDN/posts/ → 完成
host 不变，runtime 加载最新 remoteEntry.js
```

```yaml
# posts/.github/workflows/deploy.yml — 只构建和部署 posts
name: Deploy Posts
on:
  push:
    paths:
      - 'apps/posts/**'          # 只有 posts 变更才触发
      - 'packages/api-client/**' # 共享包变更也触发

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - build posts
      - upload to CDN/apps/posts/remoteEntry.js
      - upload to CDN/apps/posts/1.2.3/   # 版本存档
```

#### 模式 C：灰度发布 + 版本 API

通过版本 API 控制流量，逐步切到新版。

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│ 浏览器   │────→│ 版本 API     │────→│  CDN     │
│          │     │ /api/version │     │ v1.0.0/  │
│          │     │              │     │ v2.0.0/  │
└──────────┘     │ v2.0.0 (10%) │     │ v1.0.0/  │
                 │ v1.0.0 (90%) │     └──────────┘
                 └──────────────┘
```

```json
// GET /api/version?app=posts&userId=10086
{
  "version": "2.0.0",
  "entry": "https://cdn.example.com/posts/2.0.0/remoteEntry.js"
}
```

```tsx
// host 启动时获取各微前端版本
const { data: versions } = useQuery('/api/version', {
  query: { apps: ['posts', 'editor', 'admin'] }
});

// 动态加载对应版本的 remoteEntry
const PostsApp = loadRemote(`posts/${versions.posts}/remoteEntry`);
```

### 版本兼容策略

```
posts v1.0.0  ─── 暴露 API: { getPosts, getPost }
posts v2.0.0  ─── 暴露 API: { getPosts, getPost, searchPosts }  ✅ 向前兼容
posts v2.1.0  ─── 暴露 API: { getPosts, getPost, searchPosts }  ✅
posts v3.0.0  ─── 暴露 API: { getPosts, searchPosts }           ❌ 删了 getPost
```

**规则：**
- 微前端暴露的接口（remote 模块）必须**向前兼容**
- 新增 API 可随时发布
- 删除/改名 API 需跨版本过渡（旧版保留 + 新版添加 → 两版共存 → 移旧版）

### CDN 目录结构

```
cdn.example.com/
├── host/
│   └── index.html              # 始终最新
├── posts/
│   ├── remoteEntry.js          # 当前版本（alias，可覆盖）
│   ├── 1.0.0/                  # 历史版本（回滚用）
│   ├── 1.1.0/
│   └── 2.0.0/
├── editor/
│   ├── remoteEntry.js
│   ├── 2.0.0/
│   └── 2.1.0/
└── admin/
    ├── remoteEntry.js
    └── 1.0.0/
```

### 回滚流程

```
# 发现 posts v2.0.0 有 Bug
# 方案一：CDN 别名回滚（秒级）
cd /cdn/posts && cp 1.1.0/remoteEntry.js remoteEntry.js

# 方案二：版本 API 回滚
# /api/version 返回 v1.1.0

# 方案三：host 加载时指定版本（前端兜底）
loadRemote(`posts/${localStorage.getItem('posts-version') || '1.1.0'}/remoteEntry`);
```

### 部署策略选择

| 场景 | 推荐模式 | 原因 |
|------|---------|------|
| 1~2 个团队，统一发版 | A（全量） | 简单，版本一致 |
| 3+ 团队，独立迭代 | B（独立） | 互不阻塞 |
| 大流量产品，需灰度验证 | C（灰度+版本API） | 精细控制，回滚快 |
| 平台型产品（多个 App 共享微前端） | B + C | 独立部署 + 版本管理 |

## Red Flags

- Micro-frontend for < 3 teams → overengineering, use monorepo
- Each micro-app loads its own React → 3× bundle size, use `shared: { singleton: true }`
- CSS leaking between apps → need CSS Modules / Shadow DOM / scoped styles
- Different React versions across apps → singleton + `shared` negotiation
- 微前端版本不向前兼容 → host 升级可能导致某个微前端挂掉
- remoteEntry.js 覆盖部署不留历史 → 回滚需要重新构建，无法秒级恢复
- 灰度发布时版本 API 返回的 entry 不存在 → 用户白屏，CDN 版本发布和 API 更新需协调
- 全量部署时一个微前端构建失败 → 阻塞所有 app 发布，失去独立部署优势
