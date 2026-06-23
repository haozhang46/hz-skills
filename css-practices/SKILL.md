---
name: css-practices
description: CSS 实践 — Grid vs Flexbox 选择、间距规范（gap / margin-bottom-only）、响应式断点、Tailwind 对应
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

## Red Flags

- ❌ 多列列表用 `flex-wrap` + `width: calc()` — 换 Grid 一行搞定
- ❌ Flexbox 多列每行不对齐 — Grid 默认等高
- ❌ 最后一行不够数左对齐不对 — Grid 默认左对齐，Flexbox 需 flex-start + 空白占位
- ❌ 多列用 Flexbox 然后手动算 `nth-child` 加 margin — Grid 的 `gap` 处理好了
- ❌ 一维布局（导航栏）硬用 Grid — 过度设计，Flexbox 更简洁
