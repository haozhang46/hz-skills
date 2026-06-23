---
name: css-practices
description: CSS 实践 — Grid vs Flexbox 选择、间距规范（gap / margin-bottom-only）、BEM 命名规范、响应式断点、Tailwind 对应
---

# CSS 实践

## 核心原则

```
一维布局（行或列）→ Flexbox
二维布局（行列同时）→ Grid
多列列表（本质是二维）→ Grid
```

**多列列表是二维的**（行 × 列），所以用 Grid 更合适，Flexbox 需要各种 hack 才能对齐。

---

## 对比

### 需求：3 列商品列表

```html
<!-- Flexbox 实现（需要额外包一层） -->
<div class="flex-list">
  <div class="item">商品 1</div>
  <div class="item">商品 2</div>
  <div class="item">商品 3</div>
  <div class="item">商品 4（第二行）</div>
</div>
```

```css
/* ❌ Flexbox — 多列需要额外处理 */
.flex-list {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
}
.item {
  width: calc((100% - 32px) / 3);  /* 手动计算宽度 */
  /* ❌ 高度不相等时不会对齐 */
  /* ❌ 最后一行少于 3 个时左对齐需要额外处理 */
}
```

```css
/* ✅ Grid — 多列天然支持 */
.grid-list {
  display: grid;
  grid-template-columns: repeat(3, 1fr);  /* 3 等分列 */
  gap: 16px;
  /* ✅ 每行自动等高（align-items: stretch 默认） */
  /* ✅ 间距统一由 gap 控制 */
  /* ✅ 最后一行自动左对齐 */
}
```

### 对比表

| 场景 | Flexbox | Grid |
|------|---------|------|
| 3 列等宽布局 | `width: calc(33.33% - gap)` | `grid-template-columns: repeat(3, 1fr)` |
| 列宽自动计算 | 需手动 calc | ✅ 自动 1fr 平分 |
| 每行等高 | ❌ 需 `align-items: stretch` 但子元素影响 | ✅ 默认 |
| 间距 | `gap` 支持（需注意兼容性） | ✅ `gap` 原生 |
| 最后一行不够 3 个时对齐 | ❌ 需要 flex-start + 空元素占位 | ✅ 自动左对齐 |
| 跨行/跨列 | ❌ 不支持 | ✅ `grid-row` / `grid-column` |
| 响应式改列数 | 改 `width` | ✅ 改 `grid-template-columns` 一行搞定 |

---

## 多列列表用 Grid 的场景

### 场景 1：商品列表 / 卡片列表

```css
.product-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  /* 自动列：每列至少 280px，尽量排满 */
  gap: 20px;
}
/* ✅ 不需要媒体查询，自动适应屏幕宽度 */
```

### 场景 2：固定列数 + 响应式断点

```css
.card-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(1, 1fr);  /* 移动端 1 列 */
}

@media (min-width: 640px) {
  .card-grid { grid-template-columns: repeat(2, 1fr); }  /* 平板 2 列 */
}

@media (min-width: 1024px) {
  .card-grid { grid-template-columns: repeat(3, 1fr); }  /* 桌面 3 列 */
}
/* ✅ 只改 grid-template-columns，其他不动 */
```

### 场景 3：跨列（占位突出）

```css
.featured-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.featured-item {
  grid-column: span 2;   /* 跨 2 列 */
  grid-row: span 2;       /* 跨 2 行 */
}
/* ✅ Grid 天然支持，Flexbox 做不到 */
```

### 场景 4：不同宽度列混合

```css
.mixed-grid {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr;  /* 第一列是其他两列的 2 倍宽 */
  gap: 16px;
}
/* ✅ Grid 用 fr 单位灵活分配比例 */
```

### 场景 5：间距比 gap 更灵活

```css
.dense-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px 24px;            /* 行间距 12px，列间距 24px */
  /* ✅ gap 支持行列分开设置 */
}
```

---

## Flexbox 仍然适合的场景

```css
/* 适合：一维排列 */
.toolbar {
  display: flex;
  align-items: center;        /* 垂直居中 */
  gap: 8px;
}
.nav-links {
  display: flex;
  gap: 24px;
}
.avatar-with-text {
  display: flex;
  align-items: center;
  gap: 12px;
}

/* 适合：空间分配不平均 */
.flex-header {
  display: flex;
  justify-content: space-between;  /* 两端对齐 */
}

---

## 间距规范：只用 `margin-bottom`，不用 `margin-top`

### 原则

上下两个元素之间的间距，优先用 `gap`。无法用 `gap` 时，**只由上面元素设 `margin-bottom`**，下面元素不设 `margin-top`。

```html
<div class="card">
  <div class="card__header">标题</div>   <!-- margin-bottom: 16px -->
  <div class="card__body">内容</div>     <!-- 不设 margin-top -->
  <div class="card__footer">底部</div>   <!-- 不设 margin-top -->
</div>
```

```css
/* ❌ 各设各的，不可控 */
.card__header { margin-bottom: 8px; }
.card__body   { margin-top: 8px; margin-bottom: 8px; }
.card__footer { margin-top: 8px; }

/* ✅ 统一用 margin-bottom，只用上面元素控制间距 */
.card__header { margin-bottom: 16px; }
.card__body   { margin-bottom: 16px; }
.card__footer { margin-bottom: 0; }    /* 最后一个不需要 */

/* ✅ 或者用选择器批量处理 */
.card > * { margin-bottom: 16px; }
.card > :last-child { margin-bottom: 0; }

/* ✅ 或者用驼峰选择器（所有兄弟元素除第一个外） */
.card > * + * { margin-top: 16px; }  /* 等价于上面，只是方向不同 */
```

### 为什么

```css
/* ❌ 下面元素设 margin-top 的问题 */
.container {
  display: flex;
  flex-direction: column;
}

/* 如果某个子元素动态隐藏了，它的 margin-top 会消失 */
.item.hidden { display: none; }
/* 隐藏后：上面元素的 margin-bottom 还在，间距还在 */
/* 但如果间距是靠下面元素的 margin-top：隐藏后 margin 也没了 */

/* ❌ 最后一个元素有 margin-bottom 不会撑开容器（无 padding 时） */
/* ❌ margin-top 和 margin-bottom 可能折叠出意料之外的值 */
```

| 问题 | `margin-bottom` | `margin-top` |
|------|---------------|-------------|
| 元素被移除时间距消失 | ❌ 不会（间距在上一元素） | ✅ 会 |
| 最后一个元素多出间距 | ✅ 可用 `:last-child` 清掉 | ⚠️ 最后一个没问题，但中间的可能有问题 |
| margin 折叠 | ⚠️ 可能折叠，但可预测 | ⚠️ 可能折叠 |
| 一致性 | ✅ 始终从上拉 | ❌ 有些从上拉有些从下推 |

### 标准模式

```css
/* 方案一：margin-bottom（推荐） */
.card > * { margin-bottom: 16px; }
.card > :last-child { margin-bottom: 0; }

/* 方案二：驼峰选择器（所有兄弟间加间距，等价） */
.card > * + * { margin-top: 16px; }

/* 方案三：Grid/Flex gap（现代浏览器） */
.card { display: flex; flex-direction: column; gap: 16px; }
/* ✅ gap 没有 margin 的折叠问题，最推荐 */
```

### 决策

```
方案
├── gap（推荐）→ display: flex; gap: 16px;（最安全，无 margin 问题）
├── margin-bottom →  > * { margin-bottom: 16px; } > :last-child { margin-bottom: 0; }
└── * + * →  > * + * { margin-top: 16px; }（所有兄弟间加间距）
```

**上下两个 div 之间的间距：优先用 `gap`，否则只由上面的 div 设 `margin-bottom`，下面的不设 `margin-top`。**
```

---

## 选择决策树

```
布局需求
├── 行内水平排列（导航、工具栏、头像+文字）
│   └── Flexbox（一维）
├── 多列列表（商品、卡片、图片墙）
│   └── Grid（二维）
├── 页面整体布局（侧边栏 + 主内容 + 底部）
│   └── Grid（二维 + 跨列跨行）
├── 内容宽度不确定，需要自动换行
│   ├── flex-wrap（Flexbox）
│   └── auto-fill + minmax（Grid）
└── 需要跨行/跨列
    └── Grid
```

---

## Tailwind 断点 — 768/1024/1280 自带

你说的这三个断点 Tailwind 默认就有，不需要自己定义 CSS 变量。

| Tailwind | 最小宽度 | 说明 |
|----------|---------|------|
| `sm` | 640px | 手机横屏 |
| **`md`** | **768px** | **平板** |
| **`lg`** | **1024px** | **桌面** |
| **`xl`** | **1280px** | **宽屏** |
| `2xl` | 1536px | 超大屏 |

### 用法

```html
<!-- Tailwind：一行搞定响应式多列 -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
  <!-- md(768) 起 2 列，lg(1024) 起 3 列，xl(1280) 起 4 列 -->
  <div class="item">卡片</div>
  <div class="item">卡片</div>
  ...
</div>
```

### 如果你还是想用 CSS 变量定义断点

```css
/* 不是必须的，Tailwind 自带这些值 */
:root {
  --bp-mobile: 768px;
  --bp-tablet: 1024px;
  --bp-desktop: 1280px;
}

/* Tailwind 内部就是这样定义的（在 tailwind.config.js 里改） */
module.exports = {
  theme: {
    screens: {
      'md': '768px',
      'lg': '1024px',
      'xl': '1280px',
    }
  }
}
```

> **Tailwind 直接用 responsive prefix 就行，不用自己写 CSS var。**
> 只有在不用 Tailwind 的纯 CSS 项目里才需要手动定义断点变量。

---

## BEM 命名规范

HTML 中只用语义化 BEM class name，所有样式写在 CSS 文件中（可通过 `@apply` 使用 Tailwind 工具类）。

### 规则

```html
<!-- ❌ FORBIDDEN — Tailwind utility classes in HTML -->
<div class="flex items-center gap-4 bg-gray-950 text-white p-6 rounded-lg">

<!-- ❌ FORBIDDEN — arbitrary values -->
<div class="bg-[#050505] text-[#999] max-w-[880px]">

<!-- ✅ REQUIRED — BEM semantic names -->
<div class="post-card">
  <h2 class="post-card__title">Title</h2>
  <p class="post-card__excerpt">Excerpt</p>
</div>
```

### Block / Element / Modifier

```
Block:           header    post-card    scroll-indicator
Element:         header__logo       post-card__title
Modifier:        post-card--featured    header--transparent
```

### CSS 用 @apply

```css
.post-card {
  @apply border-l-[3px] px-5 py-3 mb-5;
  border-color: #fff;
}
.post-card__title {
  @apply text-[15px] font-bold text-white;
}
```

### Nesting — 必须写完整类名

```css
/* ✅ 允许 nesting，但必须写全类名 */
.post-card {
  @apply px-5 py-3;

  .post-card__title {
    @apply font-bold;
  }
}

/* ❌ &__ 缩写 — 禁止（不可 grep） */
.post-card {
  &__title { @apply font-bold; }
}

/* ✅ & 伪类 — 允许（无全名形式） */
.post-card {
  &:hover { opacity: 0.8; }
  &::after { content: ''; }
}
```

### 条件类名 — clsx

```tsx
// ✅ clsx 替代模板三元
import cn from 'classnames';
<div className={cn('post-card', {
  'post-card--featured': featured,
  'post-card--loading': loading,
})}>
```

---

## 行内对齐方式 — inline / flex / block

### display: inline

行内元素**不能设宽高**，尺寸由内容决定。水平排列，换行才折行。

```css
/* inline 元素 */
span, a, strong, em, img

/* inline 对齐只需设父级 text-align */
.parent {
  text-align: center;   /* inline 元素水平居中 */
  /* 垂直方向：line-height 控制 */
  line-height: 48px;    /* 等于容器高度时垂直居中 */
}
```

| 对齐方式 | 水平 | 垂直 |
|---------|------|------|
| 居中 | `text-align: center` | `line-height: 容器高度` |
| 左对齐 | `text-align: left` | — |
| 右对齐 | `text-align: right` | — |
| 顶部对齐 | — | `vertical-align: top` |
| 中间对齐 | — | `vertical-align: middle` |
| 底部对齐 | — | `vertical-align: bottom` |

### display: block

块级元素默认占满父级宽度，每个占一行。

```css
/* block 水平居中 */
.block {
  width: 200px;               /* 必须设宽度 */
  margin-left: auto;
  margin-right: auto;
}

/* block 垂直居中（需要父级是 flex） */
.parent {
  display: flex;
  align-items: center;
  justify-content: center;
}
```

### display: flex

Flex 是**一维布局**，主轴对齐用 `justify-content`，交叉轴对齐用 `align-items`。

```css
.parent {
  display: flex;
  /* 主轴（默认水平）对齐 */
  justify-content: center;     /* 居中 */
  justify-content: space-between; /* 两端对齐 */
  justify-content: flex-start; /* 左对齐（默认） */
  justify-content: flex-end;   /* 右对齐 */

  /* 交叉轴（默认垂直）对齐 */
  align-items: center;         /* 垂直居中 */
  align-items: stretch;        /* 拉伸填满（默认） */
  align-items: flex-start;     /* 顶部 */
  align-items: flex-end;       /* 底部 */
}
```

| `justify-content` | 效果 |
|-------------------|------|
| `flex-start` | 左对齐（默认） |
| `center` | 水平居中 |
| `flex-end` | 右对齐 |
| `space-between` | 两端对齐，中间等距 |
| `space-around` | 每个元素左右间距相等 |
| `space-evenly` | 所有间距完全相等 |

### 选择决策

```
需求
├── 行内文字居中 / 图片 + 文字一行
│   └── inline + text-align / vertical-align
├── 块级元素水平居中（定宽）
│   └── block + margin: 0 auto
├── 块级元素垂直居中
│   └── flex + align-items: center
├── 多个元素水平分布（导航、工具栏）
│   └── flex + justify-content: space-between
├── 列表 / 多列卡片
│   └── grid + gap
└── 绝对居中（水平和垂直）
    └── flex + justify-content: center + align-items: center

---

## CSS 单位 — rem / px / vw / vh

### 各单位特点

| 单位 | 相对基准 | 适用场景 |
|------|---------|---------|
| `px` | 设备像素（绝对） | 边框、阴影、1px 线、固定尺寸 |
| `rem` | 根元素 `font-size`（默认 16px） | 字号、间距、组件尺寸（可缩放） |
| `em` | 父元素 `font-size` | 组件的局部相对尺寸（少用，容易嵌套混乱） |
| `%` | 父元素同属性值 | 宽度、高度百分比 |
| `vw` / `vh` | 视口宽/高的 1% | 全屏、大区块、视口比例布局 |
| `vmin` / `vmax` | `vw` 和 `vh` 中较小/较大的 | 保持比例的正方形、封面图 |

### 工程化推荐方案

```css
/* 1️⃣ 字号用 rem（支持用户浏览器缩放） */
html {
  font-size: 16px;              /* 浏览器默认，可不设 */
  /* 响应式缩放基准 */
  /* @media (max-width: 768px) { font-size: 14px; } */
}

.title {
  font-size: 1.5rem;            /* 24px */
}
.body {
  font-size: 1rem;              /* 16px */
}
.caption {
  font-size: 0.75rem;           /* 12px */
}

/* 2️⃣ 间距 / 内边距用 rem */
.card {
  padding: 1rem;                /* 16px */
  margin-bottom: 1.5rem;        /* 24px */
  gap: 0.5rem;                  /* 8px */
}

/* 3️⃣ 边框 / 1px 线用 px */
.border {
  border: 1px solid #ddd;       /* 固定 1px，不缩放 */
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

/* 4️⃣ 全屏 / 大区块用 vw/vh */
.hero {
  width: 100vw;                 /* 全屏宽 */
  height: 100vh;                /* 全屏高 */
  /* 避免 vw 出现横向滚动条：父级加 overflow-x: hidden */
}
.full-width {
  width: 100vw;
  margin-left: calc(-50vw + 50%);  /* 打破容器限制，撑到全宽 */
}

/* 5️⃣ 响应式比例用 % */
.sidebar {
  width: 30%;                   /* 父级宽度的 30% */
}
```

### rem 转 px 对照（html font-size: 16px）

| rem | px | 用途 |
|-----|-----|------|
| 0.75rem | 12px | 辅助文字、标注 |
| 0.875rem | 14px | 小号正文 |
| **1rem** | **16px** | **正文（基准）** |
| 1.25rem | 20px | 小标题 |
| 1.5rem | 24px | 标题 h3 |
| 2rem | 32px | 标题 h2 |
| 3rem | 48px | 大标题 h1 |

### 移动端适配方案对比

| 方案 | 原理 | 推荐度 |
|------|------|--------|
| **rem + 媒体查询** | 不同断点改 html font-size | ⭐ 推荐，简单可控 |
| **vw/vh** | 视口单位直接写 | ⚠️ 容易溢出，需注意 |
| **Tailwind（默认 rem）** | 所有单位都是 rem | ✅ 省心 |
| **px + 媒体查询** | 各断点重写 px 值 | ❌ 维护量大 |

```css
/* ✅ 推荐：rem + 媒体查询 */
html { font-size: 16px; }

@media (max-width: 768px) {
  html { font-size: 14px; }     /* 移动端所有 rem 自动缩小 */
}

@media (min-width: 1024px) {
  html { font-size: 18px; }     /* 大屏适当放大 */
}
/* 只需改一个值，所有 rem 同步缩放 */
```

```css
/* ⚠️ vw 方案 */
html { font-size: calc(100vw / 375 * 16); }
/* 以 375px 设计稿为基准，vw 算字号 */
/* 问题：字号随视口连续变化，可能太小或太大 */
```

### 最佳实践

```css
/* ✅ 字号 → rem */
font-size: 1rem;

/* ✅ 间距 → rem */
padding: 1rem;
margin: 1.5rem;
gap: 0.5rem;

/* ✅ 边框 → px */
border: 1px solid #ddd;

/* ✅ 宽高 → % 或 vw/vh */
width: 100%;
height: 100vh;

/* ✅ 圆角 → px（小圆角）或 %（圆形） */
border-radius: 8px;
border-radius: 50%;    /* 正圆形 */

/* ✅ 阴影 → px */
box-shadow: 0 2px 8px rgba(0,0,0,0.1);
```

------

## 按钮 / 卡片 — 不固定宽高，用 min + padding 撑开

按钮、标签、卡片这类组件，**不设固定宽高**，由内容撑开 + `padding` 控制点击区域大小。

### 正确做法

```css
/* ✅ 按钮：不设 width/height，padding 控制大小 */
.btn {
  display: inline-flex;           /* 宽度由内容决定 */
  align-items: center;
  justify-content: center;
  min-width: 40px;                /* 最小宽度（防太窄） */
  min-height: 32px;               /* 最小高度 */
  padding: 6px 16px;              /* 水平 16px，垂直 6px */
  font-size: 14px;
  border-radius: 6px;
  border: 1px solid transparent;
  cursor: pointer;
  white-space: nowrap;            /* 文字不换行 */
}

.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;                    /* 方形图标按钮可以固定宽高 */
  height: 32px;
  padding: 0;                     /* 不需要 padding */
}

/* ✅ 标签 / Tag：内容撑开 */
.tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  font-size: 12px;
  border-radius: 4px;
  /* 不设 width，完全由内容撑开 */
}

/* ✅ 卡片：内容撑开宽度，min 控制最窄 */
.card {
  display: flex;
  flex-direction: column;
  min-width: 280px;               /* 不低于 280px */
  padding: 16px;
  /* max-width 也可以加，防止太宽 */
  max-width: 480px;
}
```

### 为什么

```css
/* ❌ 固定宽高的问题 */
.btn {
  width: 120px;
  height: 40px;
  /* 文本太长时 → 截断或溢出 */
  /* 文本太短时 → 多余空白 */
  /* 多语言翻译后 → 布局崩 */
}

/* ✅ min + padding 的好处 */
.btn {
  min-width: 80px;          /* 最短 80px */
  min-height: 32px;         /* 最低 32px */
  padding: 6px 16px;        /* 控制内边距 */
  /* 文本短时 = 80px */
  /* 文本长时 = 自适应撑开 */
  /* 翻译后不同长度 → 仍然自然 */
}
```

### 什么时候用固定宽高

```css
/* ✅ 固定宽高：图标、头像、正方形 */
.avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  object-fit: cover;
}

/* ✅ 固定宽高：表格列、栅格系统 */
.table-header {
  width: 150px;              /* 列宽固定 */
}

/* ❌ 按钮、标签、卡片 → 不要固定宽高 */
```

### 总结

| 组件 | width/height | 建议 |
|------|-------------|------|
| 按钮 | 不设 | `min-width` + `padding` 撑开 |
| 标签 / Tag | 不设 | 内容撑开 + `padding` |
| 卡片 | 不设 | `min-width` / `max-width` + `padding` |
| 图标按钮 | 固定 | `width: 32px; height: 32px` |
| 头像 | 固定 | `width: 40px; height: 40px` |
| 输入框 | 不设宽 | 父级宽度或 `width: 100%` |

## Red Flags

- ❌ 多列列表用 `flex-wrap` + `width: calc()` — 换 Grid 一行搞定
- ❌ Flexbox 多列每行不对齐 — Grid 默认等高
- ❌ 最后一行不够数左对齐不对 — Grid 默认左对齐，Flexbox 需 flex-start + 空白占位
- ❌ 多列用 Flexbox 然后手动算 `nth-child` 加 margin — Grid 的 `gap` 处理好了
- ❌ 一维布局（导航栏）硬用 Grid — 过度设计，Flexbox 更简洁
