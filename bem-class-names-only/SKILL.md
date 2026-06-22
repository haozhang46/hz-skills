---
name: bem-class-names-only
description: Use when writing HTML/JSX className — enforces BEM semantic naming only, NO Tailwind utility classes
---

# BEM — Semantic Class Names Only

**No Tailwind utility classes in HTML. Every className must be a meaningful BEM name. All styles go in CSS files.**

## The Rule

```html
<!-- ❌ FORBIDDEN — Tailwind utility classes -->
<div className="flex items-center gap-4 bg-gray-950 text-white p-6 rounded-lg">

<!-- ❌ FORBIDDEN — arbitrary values -->
<div className="bg-[#050505] text-[#999] max-w-[880px]">

<!-- ✅ REQUIRED — BEM semantic names -->
<div className="post-card">
  <h2 className="post-card__title">Title</h2>
  <p className="post-card__excerpt">Excerpt</p>
  <span className="post-card__date">Date</span>
</div>
```

## BEM Naming Convention

### Block
Independent component. Lowercase, hyphens for multi-word.

```
header    post-card    scroll-indicator    particle-bg
```

### Element  
Part of a block. Block + `__` + element name.

```
header__logo       post-card__title
header__nav        post-card__excerpt
scroll-indicator__segment
```

### Modifier
Variant of a block or element. Block/Element + `--` + modifier name.

```
post-card--featured
scroll-indicator__segment--active
header--transparent
```

## CSS Goes in Stylesheets — with Tailwind @apply

HTML stays BEM-only. CSS uses Tailwind `@apply` to compose styles from design tokens:

```css
/* ✅ globals.css, page.css, or component .module.css */

.post-card {
  @apply border-l-[3px] px-5 py-3 mb-5;
  border-color: #fff;
}

.post-card__title {
  @apply text-[15px] font-bold text-white tracking-[-0.3px];
}

.post-card__date {
  @apply text-[9px] text-gray-500;
}

.post-card--featured {
  @apply border-l-[3px];
  border-color: #fff;
}
```

**Note:** The `bem-class-names-only` rule applies to HTML className only. `@apply` with Tailwind utilities inside CSS files is the intended pattern — it keeps the design system DRY while HTML stays semantic.

## No `&` Nesting — Full Class Names Only

Every selector must be a complete, searchable class name. No `&__`, `&--`, `&:`, `&::` shortcuts.

```css
/* ❌ & nesting — unsearchable, hides the full selector */
.post-card {
  @apply px-5 py-3;
  &__title { @apply font-bold; }
  &--featured { border-color: #fff; }
  &:hover { opacity: 0.8; }
  &::after { content: ''; }
}

/* ✅ full class names — grep-friendly, explicit */
.post-card {
  @apply px-5 py-3;
}
.post-card__title {
  @apply font-bold;
}
.post-card--featured {
  border-color: #fff;
}
.post-card:hover {
  opacity: 0.8;
}
.post-card::after {
  content: '';
}
```

**Why:**
- `grep post-card__title` finds the exact definition
- No mental compile step — see the class in HTML, find it in CSS immediately
- `&` nesting hides the cascade and specificity problems

## Conditional Class → classnames / clsx — No Template Ternaries

```tsx
// ❌ template ternary — unreadable, noisy
<div className={`post-card ${featured ? 'post-card--featured' : ''} ${loading ? 'post-card--loading' : ''}`}>

// ❌ inline ternary chain
<div className={`post-card${featured ? ' post-card--featured' : ''}${loading ? ' post-card--loading' : ''}`}>

// ✅ classnames / clsx — clean
import cn from 'classnames';
<div className={cn('post-card', { 'post-card--featured': featured, 'post-card--loading': loading })}>
```

Always use `classnames` or `clsx` for any conditional className. Template literals with ternaries are banned.

## Husky Enforcement — Block Tailwind Utilities in JSX

Add to `lint-staged` to catch violations pre-commit:

**`package.json`:**
```json
{
  "lint-staged": {
    "*.{tsx,jsx}": [
      "prettier --write",
      "node scripts/check-bem-classnames.mjs"
    ]
  }
}
```

**`scripts/check-bem-classnames.mjs`:**
```js
#!/usr/bin/env node
import { readFileSync } from 'fs';

const PATTERNS = [
  /\b(flex|grid|p-\d|m-\d|gap-\d|w-\d|h-\d|text-white|bg-gray|border-white|rounded-|font-bold|font-semibold|px-\d|py-\d|pt-\d|pb-\d|pl-\d|pr-\d|mt-\d|mb-\d|ml-\d|mr-\d|max-w-)\b/g,
  /className="[^"]*\[[^\]]*\][^"]*"/,
];

let failed = false;
for (const file of process.argv.slice(2)) {
  if (!file.endsWith('.tsx') && !file.endsWith('.jsx')) continue;
  const content = readFileSync(file, 'utf-8');
  for (const pattern of PATTERNS) {
    const matches = content.match(pattern);
    if (matches) {
      console.error(`  ${file}: Tailwind utility in className — ${matches.join(', ')}`);
      failed = true;
    }
  }
}
if (failed) process.exit(1);
```

This catches:
- Tailwind utility classes (`flex`, `grid`, `p-4`, `text-white`, etc.)
- Arbitrary values (`bg-[#xxx]`, `max-w-[880px]`)

**Also add `classnames`/`clsx` to allowed className patterns** — template ternary ban is handled by ESLint `no-restricted-syntax`.

## Red Flags — Immediate STOPS
