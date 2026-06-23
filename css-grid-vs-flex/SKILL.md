---
name: css-grid-vs-flex
description: CSS Grid vs Flexbox — 多列列表用 Grid 不用 Flex 的原因，Grid 对齐/等高/间距优势，响应式网格布局
---

# CSS Grid vs Flexbox — 多列列表

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

## Red Flags

- ❌ 多列列表用 `flex-wrap` + `width: calc()` — 换 Grid 一行搞定
- ❌ Flexbox 多列每行不对齐 — Grid 默认等高
- ❌ 最后一行不够数左对齐不对 — Grid 默认左对齐，Flexbox 需 flex-start + 空白占位
- ❌ 多列用 Flexbox 然后手动算 `nth-child` 加 margin — Grid 的 `gap` 处理好了
- ❌ 一维布局（导航栏）硬用 Grid — 过度设计，Flexbox 更简洁
