---
name: monorepo-conventions
description: Use when organizing monorepo structure, deciding what goes in shared packages, or choosing between git submodule and workspace package
---

# Monorepo & Git Submodule Conventions

## 1. Monorepo vs Polyrepo vs Submodule

| Approach | Use when | Don't use when |
|----------|----------|----------------|
| **Monorepo** (pnpm workspaces) | Shared code changes together, 2-10 packages, single team | Unrelated projects, different deploy cadences |
| **Polyrepo** | Independent services, different teams, different CI/CD | Tightly coupled code that changes together |
| **Git Submodule** | External dependency you need source access to but don't own | Code your team owns — put it in the monorepo |

```bash
# Submodule — for external code you don't control
git submodule add https://github.com/other-org/shared-lib.git libs/shared-lib
# Updates: git submodule update --remote
```

## 2. What Goes in Shared Packages

```
packages/
├── api-client/     # ✅ shared — API types + fetch functions
├── theme/          # ✅ shared — Tailwind preset, design tokens
├── ui/             # ✅ shared — Button, Card, Modal (used by web + mobile)
├── utils/          # ✅ shared — formatDate, deepSet, deepPick
├── config/         # ✅ shared — eslint, prettier, tsconfig bases
└── types/          # ✅ shared — DTOs, enums, shared interfaces
```

| Put in shared | Keep in app |
|---------------|-------------|
| API types + client functions | Page-specific components |
| Design tokens + theme config | Route handlers |
| Generic UI components (used by 2+ apps) | App-specific layouts |
| Enums + shared types | Business logic unique to one app |
| ESLint/Prettier/TS config | One-off utility functions |

**Decision rule:** Used by 2+ apps → shared package. Used by 1 app → colocate.

## 3. pnpm Workspace Structure

```
pnpm-workspace.yaml:
  packages:
    - 'apps/*'
    - 'packages/*'
```

**app → package dependency:**
```json
// apps/web/package.json
{ "dependencies": { "@blog/api-client": "workspace:*", "@blog/theme": "workspace:*" } }
```

Build shared packages first: `pnpm --filter @blog/api-client build`

## 4. Git Submodule — When and How

```bash
# Add external shared config
git submodule add https://github.com/haozhang46/hz-skills.git .claude/skills

# Clone with submodules
git clone --recursive <repo-url>

# Update to latest
git submodule update --remote .claude/skills
```

**Use submodule for:**
- Claude Code skills shared across projects → `hz-skills`
- Shared ESLint/Prettier config across org repos
- Third-party libs you need source access to

**Don't use submodule for:**
- Code your team owns and changes daily → monorepo package
- Anything that needs different versions per consumer

## 5. Turborepo — When Monorepo Gets Big

```
3+ apps, 5+ packages, slow builds → add Turborepo
```

```json
// turbo.json
{ "pipeline": { "build": { "dependsOn": ["^build"], "outputs": [".next/**", "dist/**"] } } }
```

**Key:** `^build` means "build dependencies first, then this." Caches unchanged packages.

## Red Flags

- Copy-pasting the same `formatDate` across 3 apps → put in shared package
- Submodule for code you change daily → move to monorepo package
- `workspace:*` dependency without building it first → CI must `pnpm build` shared packages
