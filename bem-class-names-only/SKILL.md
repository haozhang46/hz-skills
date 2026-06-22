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

## Red Flags — Immediate STOPS

- `flex`, `grid`, `p-4`, `m-2`, `gap-4` in className
- `text-white`, `bg-gray-950`, `border-white/10` in className
- `max-w-*`, `rounded-*`, `font-bold` in className
- `[` or `]` in any className
- `#` or `px` in any className
- `className` with more than 2 space-separated values

**Any of these = DELETE and rewrite with BEM names.**

## When to Use Multiple Classes

Only for combining modifiers or states:

```html
<!-- ✅ OK — block + modifier -->
<div className="post-card post-card--featured">

<!-- ✅ OK — element + modifier -->
<div className="scroll-indicator__segment scroll-indicator__segment--active">
```

Never chain unrelated utility classes. Each className tells WHAT this element IS, not HOW it looks.
