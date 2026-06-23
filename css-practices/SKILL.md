---
name: css-practices
description: CSS 实践 — Grid vs Flexbox 选择、间距规范（gap / margin-bottom-only）、BEM 命名规范、响应式断点、Tailwind 对应
---

# CSS 实践

## 核心原则

```
显示模式
├── inline    → 行内，不能设宽高，text-align 对齐
├── block     → 块级，占满父级宽度，margin: 0 auto 居中
├── inline-block → 行内但可设宽高
├── flex      → 一维布局（水平或垂直），justify-content / align-items
└── grid      → 二维布局（行列同时），多列列表首选

间距
├── gap（推荐）→ 无 margin 折叠问题
├── margin-bottom（仅上面的元素设，下面的不设）
└── * + * { margin-top }（所有兄弟间加间距）

尺寸
├── 按钮/标签/卡片 → 不固定宽高，min-width + padding 撑开
├── 图标/头像     → 固定宽高
└── 字号 → rem，边框/阴影 → px

命名
├── HTML 只用语义化 BEM class（block__element--modifier）
├── CSS 用 @apply 使用 Tailwind 工具类
├── Nesting 允许但必须写完整类名（禁止 &__）
└── 条件类名用 clsx

单位
├── 字号 → rem（支持用户缩放）
├── 间距 → rem（随字号同步）
├── 边框 → px（固定不变）
├── 宽高 → % 或 vw/vh（响应式）
└── 圆角 → px（小） / %（圆形）

对齐
├── inline 水平 → text-align: center
├── inline 垂直 → line-height / vertical-align
├── block 水平  → margin: 0 auto
├── flex 水平   → justify-content
├── flex 垂直   → align-items
└── 绝对居中    → flex + justify-content: center + align-items: center
```

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

---

## Position & z-index 层级

### z-index 相同时：后面的覆盖前面的

```html
<div class="box box-1">盒子 1</div>
<div class="box box-2">盒子 2（在后面，显示在上层）</div>
```

```css
.box {
  position: absolute;
  width: 100px;
  height: 100px;
}
.box-1 { top: 0; left: 0; background: red; z-index: 1; }
.box-2 { top: 20px; left: 20px; background: blue; z-index: 1; }
/* z-index 相同 → box-2 在 DOM 后面，渲染在上层 */
```

**规则：** 同层 `z-index` 相同时，**DOM 中靠后的元素在上层**。所以如果想让某个元素在上层，可以：
- 调整 DOM 顺序（简单但影响语义）
- 或者给更大的 `z-index`

### Stacking Context（层叠上下文）

`z-index` 只在同一个层叠上下文中比较。不同上下文互不影响。

```html
<div class="parent-1">
  <div class="child child-high">子元素 z-index: 999</div>
</div>
<div class="parent-2">
  <div class="child child-low">子元素 z-index: 1</div>
</div>
```

```css
.parent-1 { position: relative; z-index: 1; }    /* 创建 Stacking Context */
.parent-2 { position: relative; z-index: 2; }    /* 创建 Stacking Context */

.child-high { position: absolute; z-index: 999; } /* 在 parent-1 内，最高也没用 */
.child-low  { position: absolute; z-index: 1; }   /* 在 parent-2 内，z=1 也在上面 */
/* parent-2 整体在 parent-1 上面 → child-low 在最上层 */
```

**`z-index: 999` 不一定比 `z-index: 1` 高** — 要看父级的层叠上下文顺序。

### 哪些属性会创建 Stacking Context

| 属性 | 说明 |
|------|------|
| `position: relative/absolute` + `z-index` 非 auto | 最常见 |
| `position: fixed` / `sticky` | 自动创建 |
| `opacity < 1` | 如 `opacity: 0.99` |
| `transform` 非 none | 如 `transform: scale(1)` |
| `filter` 非 none | 如 `filter: blur(0)` |
| `will-change` | 浏览器预创建 |
| `isolation: isolate` | **主动隔离（推荐）** |

### 隔离层级：isolation: isolate

```css
/* ✅ 主动隔离：不需要 position + z-index 也能建上下文 */
.popup {
  isolation: isolate;    /* 创建独立 Stacking Context */
  /* 内部 z-index 不会影响外部 */
  /* 外部 z-index 也不影响内部 */
}

/* 适用场景：弹窗、下拉菜单、Tooltip 等需要独立层级的组件 */
```

### 常见问题

```html
<!-- ❌ 弹窗被遮住：弹窗的父级 z-index 比遮罩低 -->
<div class="mask" style="z-index: 100">
  <div class="modal" style="z-index: 999">弹窗</div>
  <!-- modal 的 z-index 在 mask 上下文内 → 无效 -->
</div>

<!-- ✅ 弹窗和遮罩平级 -->
<div class="mask" style="z-index: 100"></div>
<div class="modal" style="z-index: 101">弹窗</div>
<!-- 或 modal 用 isolation: isolate 独立 -->
```

| 场景 | 原因 | 解决 |
|------|------|------|
| 弹窗被遮罩挡住 | modal 嵌套在 mask 内部 | modal 和 mask 同级，z-index 更高 |
| 下拉菜单被遮住 | 父级 z-index 低于其他元素 | isolation: isolate 或提升父级 z-index |
| Tooltip 显示不全 | 父级 overflow: hidden | Tooltip 放 body 级或 popper 方案 |
| z-index: 9999 无效 | 父级层叠上下文更低 | 检查父级 position + z-index |

### z-index 具名规范

**绝不在代码里直接写 `z-index: 123`**，所有 z-index 用 CSS 变量集中管理。

```css
/* ❌ 魔数 — 不可维护 */
.header { z-index: 100; }
.modal  { z-index: 999; }
.tooltip { z-index: 9999; }
/* 后来者不知道 100 是什么层，只能猜 */

/* ✅ 全局 z-index 变量 — 具名、分层、可维护 */
:root {
  /* 层级阶梯 — 每层预留 10 个值空间 */
  --z-base:          auto;       /* 默认层 */
  --z-sticky:        10;         /* 粘性头部 */
  --z-dropdown:      100;        /* 下拉菜单 */
  --z-nav:           200;        /* 导航栏 */
  --z-mask:          500;        /* 遮罩层 */
  --z-modal:         600;        /* 弹窗 */
  --z-tooltip:       700;        /* Tooltip / Popover */
  --z-toast:         800;        /* Toast 通知 */
  --z-loading:       900;        /* 全屏加载 */
  --z-max:           99999;      /* 兜底最高层 */
}
```

```css
/* 使用时 */
.header {
  z-index: var(--z-sticky);
}
.modal-overlay {
  z-index: var(--z-mask);
}
.modal-content {
  z-index: var(--z-modal);
}
.tooltip {
  z-index: var(--z-tooltip);
}
.toast {
  z-index: var(--z-toast);
}
```

**层级分配策略：**

| 变量 | 值 | 用途 | 间隔 |
|------|-----|------|------|
| `--z-sticky` | 10 | 粘性头部、侧边栏 | — |
| `--z-dropdown` | 100 | 下拉菜单、选择器 | 90 |
| `--z-nav` | 200 | 固定导航栏 | 100 |
| `--z-mask` | 500 | 遮罩/背景 | 300 |
| `--z-modal` | 600 | 弹窗 | 100 |
| `--z-tooltip` | 700 | 提示、Popover | 100 |
| `--z-toast` | 800 | 消息通知 | 100 |
| `--z-loading` | 900 | 全屏 Loading | 100 |

> 预留足够间隔（至少 10），方便中间插入新层。不同项目可调整具体值，**关键是用变量名表达语义，而不是用数字猜层级**。

```css
/* Tailwind 中配置 */
module.exports = {
  theme: {
    extend: {
      zIndex: {
        'sticky':   '10',
        'dropdown': '100',
        'nav':      '200',
        'mask':     '500',
        'modal':    '600',
        'tooltip':  '700',
        'toast':    '800',
        'loading':  '900',
      },
    },
  },
};
/* 用：<div class="z-modal"> */

---

## CSS 继承 — auto / % / 固定值的场景

### 哪些属性默认继承

```css
/* ✅ 默认继承的属性（文字相关） */
color           /* 文字颜色 */
font-family     /* 字体 */
font-size       /* 字号（注意：继承的是 computed value，不是百分比） */
font-weight     /* 字重 */
line-height     /* 行高 */
text-align      /* 文字对齐 */
visibility      /* 可见性 */

/* ❌ 不继承的属性（布局相关） */
width / height  /* 宽高 */
margin / padding /* 外边距/内边距 */
border          /* 边框 */
background      /* 背景 */
display         /* 显示模式 */
position        /* 定位 */
```

### width / height — auto vs % vs 固定

```css
/* ─── width ─── */

/* auto（默认）：块级元素自动撑满父级宽度 */
.block {
  width: auto;       /* 默认值，等价于不设，= 父级 content 宽度 */
}

/* 100%：明确等于父级 content 宽度 */
.full {
  width: 100%;       /* 和 auto 在普通 flow 下效果一样 */
}

/* 区别在于：padding + border 时的计算方式不同 */
.box-auto {
  width: auto;           /* 容器宽度 - padding - border，自动压缩内容区 */
  padding: 20px;
  border: 2px solid;
  /* 实际：内容区 = 容器宽 - 40px - 4px，总宽正好等于容器 */
}

.box-100 {
  width: 100%;           /* 容器宽度，然后 + padding + border，会溢出 */
  padding: 20px;
  border: 2px solid;
  /* 实际：总宽 = 容器宽 + 40px + 4px，超出容器 */
  /* ✅ 修复：加 box-sizing: border-box */
}

/* min-width / max-width 兜底 */
.card {
  width: auto;           /* 撑满父级 */
  max-width: 480px;      /* 最宽 480px */
  min-width: 280px;      /* 最窄 280px */
}

/* ─── height ─── */

/* auto（默认）：由内容撑开 */
.no-height {
  height: auto;       /* 默认值，内容多高就多高 */
}

/* 100%：父级必须有显式高度才生效 */
.parent {
  height: 400px;      /* 父级有固定高度 */
}
.child {
  height: 100%;       /* = 400px，生效 */
}

/* 否则 height: 100% 不生效 */
.no-parent-height {
  height: 100%;       /* ❌ 父级高度 auto → 子级 100% 无效 */
}

/* 让 height: 100% 生效的三种方式 */
/* 1. 父级固定高度 */
.parent { height: 500px; }
/* 2. 父级 height: 100%（需要一直往上链到 html,body） */
html, body { height: 100%; }
.parent { height: 100%; }
.child { height: 100%; }
/* 3. 父级用 flex/grid（隐式拉伸） */
.parent { display: flex; }
.child { height: 100%; }     /* flex 下 100% 有效 */
```

### width / height 场景选择

| 场景 | width | height |
|------|-------|--------|
| 普通块级元素 | `auto`（默认） | `auto`（内容撑开） |
| 全宽子元素 | `auto` 或 `100%` | — |
| 定宽侧边栏 | `280px` | `100vh` |
| 百分比布局 | `50%` | `100%`（父级需固定） |
| 响应式卡片 | `auto` + `max-width` + `min-width` | `auto` |
| 全屏区域 | `100vw` | `100vh` |
| 正方形 | — | `width` 设值后 `aspect-ratio: 1` |

### font-size — 继承与计算

```css
/* 默认继承：子元素的 font-size 继承 computed value（计算后的 px） */
html  { font-size: 16px; }        /* 基准 */
body  { font-size: 100%; }        /* = 16px（100% 相对父级） */
h1    { font-size: 2em; }         /* = 32px（2 × 父级 16px） */
.card { font-size: 0.875rem; }    /* = 14px（相对 html 基准） */

/* ─── em vs rem 的区别 ─── */
.parent { font-size: 20px; }

.child-em {
  font-size: 1.5em;               /* = 30px（相对父级 20px） */
  padding: 1em;                    /* = 30px（相对自身 font-size） */
  /* ⚠️ em 嵌套会叠加：ul > li > ul → 字号越来小 */
}

.child-rem {
  font-size: 1.5rem;              /* = 24px（相对 html 16px） */
  padding: 1rem;                   /* = 16px（相对 html） */
  /* ✅ rem 不叠加，始终相对 html */
}

/* ─── font-size 用 100% 的作用 ─── */
body { font-size: 100%; }          /* = 浏览器默认（通常是 16px） */
/* 用户改了浏览器字号时，100% 跟随用户设置 */
```

| 单位 | 相对谁 | 嵌套叠加 | 推荐场景 |
|------|--------|---------|---------|
| `px` | 绝对 | — | 边框、阴影、小尺寸 |
| `%` | 父级 font-size | ✅ 叠加 | body 基准 `100%` |
| `em` | 父级 font-size | ✅ 叠加 | 组件内局部相对尺寸（少用） |
| `rem` | html font-size | ❌ 不叠加 | **字号首选** |
| `lh` | 行高 | ❌ | 与行高关联的尺寸 |

### line-height 的继承

```css
body { line-height: 1.6; }           /* ✅ 无单位：相对自身 font-size，子级继承比值 */
body { line-height: 160%; }          /* ⚠️ 百分比：先算成 px，子级继承固定 px */
body { line-height: 24px; }          /* ❌ 固定 px：子级字号改变后行高不变 */

/* ✅ 推荐：无单位（比值），继承后仍相对当前字号 */
body  { line-height: 1.6; }
.title { font-size: 32px; line-height: 1.6; }  /* = 51.2px，正确 */
.body  { font-size: 16px; line-height: 1.6; }  /* = 25.6px，正确 */
```

### 关键区别总结

| 属性 | auto | 100% | 固定值 |
|------|------|------|--------|
| width | 填充父级剩余空间 | 等于父级 content 宽 | 固定 px/rem |
| height | 内容撑开 | 父级必须设固定高度 | 固定 vh/px |
| font-size | — | 父级 font-size 的 % | px/rem/em |

```
width: auto   → 自动填充父级（默认行为，推荐大多数场景）
width: 100%   → 需要配合 box-sizing: border-box 防溢出
height: auto  → 内容撑开（默认行为，推荐大多数场景）
height: 100%  → 需要父级有确定高度，否则无效（⚠️ 常见坑）
```

---

## ::before / ::after 装饰元素

使用伪元素添加装饰性内容（线条、图标、分割线），而不是在 HTML 里多加空标签。

### 正确做法

```css
/* 分割线 — 用 ::after 画一条线 */
.divider {
  position: relative;
  text-align: center;
}
.divider::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 0;
  width: 100%;
  height: 1px;
  background: #ddd;
}
.divider span {
  position: relative;    /* 让文字在线上层 */
  background: #fff;
  padding: 0 16px;
  z-index: 1;
}

/* 图标装饰 */
.link-external::after {
  content: '↗';
  display: inline-block;
  margin-left: 4px;
  font-size: 0.75em;
}

/* 必填 * 标记 */
.required::after {
  content: '*';
  color: red;
  margin-left: 4px;
}

/* ✅ 比在 HTML 里加空标签优雅 */
/* <!-- ❌ <div class="divider"><hr></div> --> */
/* <!-- ✅ <div class="divider"><span>文字</span></div> --> */
```

### 注意事项

```css
/* 伪元素必须设 content */
.box::before { }                          /* ❌ 不生效 */
.box::before { content: ''; }             /* ✅ 为空也要写 content */
.box::after  { content: attr(data-tip); } /* ✅ 用属性当内容 */

/* 伪元素默认是 inline，需要转成 block 才能设宽高 */
.box::before {
  content: '';
  display: block;         /* 或 inline-block / absolute */
  width: 100%;
  height: 2px;
}

/* 如果伪元素要定位，不用 content-box */
.box::after {
  content: '';
  position: absolute;    /* 脱离文档流，box-sizing 不影响 */
  top: 0;
  left: 0;
}
```

### box-sizing — content-box 是默认，但建议改

```css
/* ❌ 默认 content-box */
/* width = 内容区宽度，padding + border 在外部叠加 */
.box {
  width: 100%;
  padding: 20px;
  border: 2px solid #ddd;
  box-sizing: content-box;     /* 默认值 */
  /* 实际总宽 = 100% + 40px + 4px → 溢出容器 */
}

/* ✅ 全局推荐：border-box */
*, *::before, *::after {
  box-sizing: border-box;
}
/* width = 内容 + padding + border，总宽正好 100% */
.box {
  width: 100%;
  padding: 20px;
  border: 2px solid #ddd;
  /* 实际总宽 = 100%，padding 和 border 往里压缩 */
}
```

```css
/* ::before / ::after 同样受 box-sizing 影响 */
/* 如果全局没改 border-box，伪元素默认也是 content-box */

/* 但伪元素通常只做装饰（线条、图标），很少需要 padding + border */
/* 所以大多数情况下不影响，统一用 border-box 省心 */
*,
*::before,
*::after {
  box-sizing: border-box;
}
```

---

## 1px 方案 — Retina 屏真 1px

CSS `1px` 在 2x/3x Retina 屏上等于 **2~3 物理像素**，看着粗。真 1px 方案：

### 方案一：transform: scale（推荐，通用）

```css
/* 单边下边框 */
.border-bottom {
  position: relative;
}
.border-bottom::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  width: 100%;
  height: 1px;
  background: #ddd;
  transform: scaleY(0.5);           /* 高缩放 0.5 → 1 CSS px = 1 物理 px */
  transform-origin: 0 0;
}

/* 四边边框 */
.border-all {
  position: relative;
}
.border-all::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 200%;                        /* 先放大 2 倍 */
  height: 200%;
  border: 1px solid #ddd;
  border-radius: 16px;
  transform: scale(0.5);              /* 再缩小一半 → 1 物理 px */
  transform-origin: 0 0;
  pointer-events: none;
}
```

### 方案二：直接写 transparent 边框（简单）

```css
.border-line {
  border-bottom: 1px solid transparent;
  /* iOS 上设置 transparent 在某些场景会变细，但不可靠 */
}
```

### 方案三：box-shadow 模拟（轻量）

```css
.border-line {
  box-shadow: inset 0 -1px 0 0 #ddd;
  /* 适合单边，box-shadow 在 Retina 可能会模糊 */
}
```

### 方案四：UniApp 内置方案

```css
/* UniApp 支持 0.5px */
.border-line {
  border-bottom: 0.5px solid #ddd;
  /* iOS 支持 0.5px 渲染为 1 物理像素 */
  /* Android 部分版本不支持，会渲染为 0 */
}
```

### 各方案对比

| 方案 | 实现 | 兼容性 | 推荐 |
|------|------|--------|------|
| `transform: scale(0.5)` | `::after` 伪元素 | ✅ 全平台 | ⭐ **最推荐** |
| `border: 0.5px` | 直接写 | ⚠️ Android 部分不支持 | ✅ 有用到就加 |
| `box-shadow` | 阴影模拟 | ✅ 但可能模糊 | ⚠️ 凑合用 |
| `viewport` 缩放 | `<meta>` + rem | ❌ 影响全局 | ❌ 别用 |

---

## position: sticky — 能用就不要自己算

粘性定位（`sticky`）是纯 CSS 实现，比 JS 监听 scroll 事件自己算高效得多。

```css
/* ✅ sticky — 纯 CSS，浏览器原生优化 */
.sticky-header {
  position: sticky;
  top: 0;                     /* 滚动到顶部时固定 */
  z-index: var(--z-sticky);  /* 盖住滚动内容 */
  background: #fff;
}

/* ❌ 不要自己算 — 性能差、卡顿、容易出 bug */
let prevScroll = 0;
window.addEventListener('scroll', () => {
  const header = document.querySelector('.header');
  if (window.scrollY > 100) {
    header.classList.add('fixed');   // ❌ 频繁触发回流
  }
});
```

### 使用场景

```css
/* 粘性导航栏 */
.nav {
  position: sticky;
  top: 0;
}

/* 粘性侧边栏（在父容器范围内固定） */
.sidebar {
  position: sticky;
  top: 100px;                 /* 离顶部 100px 时开始固定 */
}

/* 粘性表头 */
thead th {
  position: sticky;
  top: 0;
  background: #f5f5f5;
}

/* 粘性分组标题 */
.section-title {
  position: sticky;
  top: 0;                     /* 滚动到该组时标题固定，下一组顶上来 */
}
```

### sticky 方向

```css
.sticky-top {
  position: sticky;
  top: 0;           /* 顶部固定 */
}

.sticky-bottom {
  position: sticky;
  bottom: 0;        /* 底部固定（如底部工具栏） */
}
```

### 注意要点

```css
/* ⚠️ sticky 在父容器范围内生效，父容器滚出视口时 sticky 也跟着走 */
.parent {
  height: 200vh;               /* 父容器高度够大 */
}
.sticky-child {
  position: sticky;
  top: 0;                     /* 只在父容器内固定 */
  /* 父容器滚出视口 → sticky 也跟着走 */
}

/* ⚠️ 父容器 overflow: hidden 会破坏 sticky */
.parent { overflow: hidden; }  /* ❌ 让 sticky 失效 */
.parent { overflow: visible; } /* ✅ 让 sticky 正常工作 */
```

| 场景 | 方案 | 推荐 |
|------|------|------|
| 导航栏随滚动固定 | `sticky` | ✅ 首选 |
| 侧边栏跟随 | `sticky` | ✅ 首选 |
| 表格表头固定 | `sticky` | ✅ 首选 |
| 需要复杂的动画/交互 | 自行 JS 计算 | ⚠️ 必要时才用 |
| 兼容非常旧的浏览器 | JS 计算兜底 | ⚠️ |

> **能用 `position: sticky` 就不要自己用 JS 算 scroll 来模拟粘性。** 浏览器原生支持、不触发回流、60fps 流畅。

---

## Red Flags

- ❌ 多列列表用 `flex-wrap` + `width: calc()` — 换 Grid 一行搞定
- ❌ Flexbox 多列每行不对齐 — Grid 默认等高
- ❌ 最后一行不够数左对齐不对 — Grid 默认左对齐，Flexbox 需 flex-start + 空白占位
- ❌ 多列用 Flexbox 然后手动算 `nth-child` 加 margin — Grid 的 `gap` 处理好了
- ❌ 一维布局（导航栏）硬用 Grid — 过度设计，Flexbox 更简洁
- ❌ `z-index: 123` 直接写魔数 — 必须用 CSS 变量具名管理，不然没人知道 123 是什么层
