# hz-skills

Personal Claude Code skill collection — 30+ skills covering React, Next.js, TypeScript, Three.js, Zustand, and engineering workflow.

## Custom Skills (12)

| Skill | Purpose |
|-------|---------|
| **bem-class-names-only** | BEM semantic naming, Tailwind `@apply` in CSS, `classnames`/`clsx` for conditionals, no `&` nesting |
| **nextjs-hydration-rules** | 7 hydration safety rules — browser APIs, time/random, list keys (uuid), ClientOnly pattern |
| **dto-mapper-layer** | Mapper/DTO transform BEFORE committing API data to state |
| **react-fe-skill** | 11 rules — component design review, named hooks, splitting, hook vs util, useContext+useReducer+useSelector, state management decision tree, immutability + immer, ErrorBoundary, Suspense, dynamic render, forwardRef avoidance, cloneElement ban |
| **js-coding-conventions** | 13 rules — `?.`/`??`, flat conditionals, early return, flags, Map/Set/WeakMap/WeakSet, promise catch, function arguments, cloneDeep limits, class get/set, recursion guard, Object.freeze, immutability |
| **ts-conventions** | 7 rules — atomic global types, compose, centralized enums + useGetEnum, type guards, as const, prefer type over interface |
| **axios-fetch-conventions** | No raw fetch/axios in React, unified instance, interceptors, cancellation, retry |
| **lodash-conventions** | lodash-es, ES native replaces lodash, `flow` over long chains, deepSet/deepPick utils |
| **ahooks-best-practices** | useMemoizedFn > useCallback, useDebounceFn, useEventListener, useLocalStorageState |
| **react-coding-conventions** | Named hook functions (migrated to react-fe-skill) |

## Third-Party Skills (via `./install.sh`)

### React / Next.js / State
| Skill | Source | Content |
|-------|--------|---------|
| **vercel-react-best-practices** | Vercel Engineering | 45+ rules for React/Next.js |
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
| **threejs-fundamentals** | CloudAI-X | Scene, cameras, renderer |
| **threejs-geometry** | CloudAI-X | BufferGeometry, instancing |
| **threejs-materials** | CloudAI-X | PBR, shader materials |
| **threejs-lighting** | CloudAI-X | Lights, shadows |
| **threejs-textures** | CloudAI-X | UV, env maps |
| **threejs-animation** | CloudAI-X | Keyframe, skeletal |
| **threejs-loaders** | CloudAI-X | GLTF/GLB loading |
| **threejs-shaders** | CloudAI-X | GLSL, ShaderMaterial |
| **threejs-postprocessing** | CloudAI-X | EffectComposer, bloom |
| **threejs-interaction** | CloudAI-X | Raycasting, controls |
| **webgpu-threejs-tsl** | dgreenheck | WebGPU + TSL shaders |

### Workflow
| Skill | Source | Content |
|-------|--------|---------|
| **planning-with-files** | OthmanAdi | Persistent planning across context loss |

## Usage

```bash
git clone https://github.com/haozhang46/hz-skills.git
cd hz-skills
./install.sh  # fetch all 18 third-party skills
cp -r . your-project/.claude/skills/
```

Third-party skills are managed via `sources.yaml` + `install.sh` rather than committed directly — keeps the repo lean and upstream-updateable.

## About

Built test-driven (RED-GREEN-REFACTOR via subagent baseline testing) alongside my personal blog project. Each custom skill addresses a real convention gap. 30+ skills covering the full React/Next.js/TypeScript/Three.js stack.
