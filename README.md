# hz-skills

Personal Claude Code skill collection — 36+ skills covering React, Next.js, TypeScript, Three.js, Security, DevOps, and engineering workflow.

## Custom Skills (18)

### Frontend Core
| Skill | Purpose |
|-------|---------|
| **react-fe-skill** | 11 rules — component design, named hooks, splitting, hook vs util, context+reducer+selector, state management, immutability+immer, ErrorBoundary, Suspense, dynamic render, forwardRef ban, cloneElement ban |
| **react-best-practices** | Vercel — 45+ React/Next.js performance rules |
| **nextjs-hydration-rules** | 7 hydration safety rules — browser APIs, time/random, list keys (uuid), ClientOnly |
| **dto-mapper-layer** | Mapper/DTO transform BEFORE committing API data to state |
| **ahooks-best-practices** | useMemoizedFn > useCallback, useDebounceFn, useEventListener, useLocalStorageState |

### JavaScript / TypeScript
| Skill | Purpose |
|-------|---------|
| **js-coding-conventions** | 13 rules — `?.`/`??`, flat conditionals, early return, flags, Map/Set/WeakMap, promise catch, function args, cloneDeep, class get/set, recursion guard, Object.freeze |
| **ts-conventions** | 7 rules — atomic global types, compose, centralized enums+useGetEnum, type guards, as const |
| **lodash-conventions** | lodash-es, ES native > lodash, `flow` over chains, deepSet/deepPick utils |

### CSS / Styling
| Skill | Purpose |
|-------|---------|
| **bem-class-names-only** | BEM naming, Tailwind `@apply` in CSS, `classnames`/`clsx`, no `&` nesting, husky enforcement |

### Data Fetching
| Skill | Purpose |
|-------|---------|
| **axios-fetch-conventions** | No raw fetch in React, httpOnly cookie via withCredentials, interceptors, cancellation, retry, SSE+generator streaming, blob download, Range chunked, responseType |

### Tooling / Workflow
| Skill | Purpose |
|-------|---------|
| **git-commit-conventions** | Conventional commits, husky+lint-staged, prettier+eslint flat config, commitlint, lock file rules |
| **build-tooling** | Vite/Webpack HMR optimization, env files, per-environment config |
| **monorepo-conventions** | pnpm workspaces, git submodule usage, shared package rules, Turborepo |
| **project-ai-context** | CLAUDE.md / AGENTS.md structure, what goes in file vs skill |

### Cross-Cutting
| Skill | Purpose |
|-------|---------|
| **fe-security** | XSS, CSRF, CSP, httpOnly cookie, CORS, dependency audit, input/output sanitization |
| **i18n-conventions** | next-intl, ICU message format, locale routing, translation file structure |

## Third-Party Skills (via `./install.sh`)

### React / State / Design
| Skill | Source | Content |
|-------|--------|---------|
| **vercel-react-best-practices** | Vercel | 45+ React/Next.js rules |
| **web-design-guidelines** | Vercel | 247 design heuristics |
| **zustand-patterns** | yonatangross/orchestkit | Zustand 5.x — slices, Immer, useShallow, middleware |
| **react-native-best-practices** | callstackincubator | RN performance — JS, Native, Bundling |

### Web Quality
| Skill | Source | Content |
|-------|--------|---------|
| **web-quality-accessibility** | Addy Osmani | WCAG 2.2 a11y audit |
| **web-quality-performance** | Addy Osmani | Performance optimization |
| **web-quality-core-web-vitals** | Addy Osmani | LCP / INP / CLS |
| **web-quality-best-practices** | Addy Osmani | Security + code quality |
| **web-quality-seo** | Addy Osmani | Search engine optimization |

### Three.js / WebGPU
| Skill | Source | Content |
|-------|--------|---------|
| **threejs** | mrgoonie | Mega-skill, 5 levels |
| **threejs-fundamentals…interaction** | CloudAI-X | 10 specialized Three.js skills |
| **webgpu-threejs-tsl** | dgreenheck | WebGPU + TSL shaders |

### Workflow
| Skill | Source | Content |
|-------|--------|---------|
| **planning-with-files** | OthmanAdi | Persistent planning across context loss |

## Usage

```bash
# 1. Clone + install third-party skills
git clone https://github.com/haozhang46/hz-skills.git
cd hz-skills
./install.sh

# 2. Install superpowers (engineering workflow skills)
claude plugin add anthropic/superpowers

# 3. Copy to your project
cp -r . your-project/.claude/skills/
```

**Superpowers** (install separately — plugin marketplace only):

| Skill | Purpose |
|-------|---------|
| brainstorming | Design ideas through structured dialogue — must use before creative work |
| writing-plans | Create implementation plans from specs |
| subagent-driven-development | Execute plans via fresh subagent per task + two-stage review |
| test-driven-development | Write test first, watch it fail, write minimal code |
| systematic-debugging | Root cause tracing — before proposing fixes |
| verification-before-completion | Evidence before assertions — run verification before claiming done |
| requesting-code-review | Review completed work before merge |
| receiving-code-review | Process review feedback with rigor |
| finishing-a-development-branch | Structured merge/PR/cleanup after implementation |
| using-git-worktrees | Isolated workspace for feature work |
| writing-skills | Create skills via TDD (RED-GREEN-REFACTOR) |
| dispatching-parallel-agents | Run independent tasks in parallel |
| executing-plans | Execute plan in separate session with checkpoints |

Third-party skills managed via `sources.yaml` + `install.sh` — not committed directly, upstream-updateable.

## About

Built test-driven (RED-GREEN-REFACTOR via subagent baseline testing) alongside my personal blog project. 36+ skills covering the full modern frontend stack — from React component design to Three.js shaders, from git hooks to CSP headers.
