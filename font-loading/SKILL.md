---
name: font-loading
description: 多国字体加载策略 — @font-face unicode-range 按需加载、font-display、CJK 字体子集化、语言字体栈、FOUT/FOIT 优化
---

# 多国字体加载

## 核心问题

| 字体 | 覆盖范围 | 文件大小 |
|------|---------|---------|
| Latin（英文） | 128 字符 | 几十 KB |
| CJK（中日韩） | 数万字符 | 10~20 MB |
| Arabic | 约 200 字符 | 几百 KB |
| Emoji | 数千个 | 几 MB |

**CJK 字体是最大的问题** — 一套完整中文字体 10~20MB，不可能全量加载。

---

## unicode-range — 按需加载

```css
/* 每个 @font-face 指定 unicode-range，浏览器只下载需要的那一部分 */
@font-face {
  font-family: 'MyFont';
  src: url('/fonts/latin.woff2') format('woff2');
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC; /* 拉丁基本 */
}

@font-face {
  font-family: 'MyFont';
  src: url('/fonts/cjk.woff2') format('woff2');
  unicode-range: U+4E00-9FFF, U+3000-303F, U+FF00-FFEF; /* CJK 统一表意文字 */
}

@font-face {
  font-family: 'MyFont';
  src: url('/fonts/arabic.woff2') format('woff2');
  unicode-range: U+0600-06FF, U+0750-077F; /* 阿拉伯语 */
}

@font-face {
  font-family: 'MyFont';
  src: url('/fonts/japanese.woff2') format('woff2');
  unicode-range: U+3040-309F, U+30A0-30FF, U+4E00-9FFF; /* 平假名 + 片假名 + 汉字 */
}

body {
  font-family: 'MyFont', sans-serif;
}
```

**浏览器行为：**
```
页面包含 "Hello 你好" → 下载 latin.woff2 + cjk.woff2
页面只有英文 → 只下载 latin.woff2
页面只有阿拉伯语 → 只下载 arabic.woff2
```

### 常用 unicode-range

| 语言 | 范围 | 说明 |
|------|------|------|
| 英文（基本拉丁） | `U+0000-00FF` | 字母、数字、标点 |
| 英文（扩展拉丁） | `U+0100-024F` | 重音字符 |
| 中文（CJK 统一） | `U+4E00-9FFF` | 常用汉字（约 2 万字） |
| 中文扩展 | `U+3400-4DBF` | 罕用汉字 |
| 日文平假名 | `U+3040-309F` | 平假名 |
| 日文片假名 | `U+30A0-30FF` | 片假名 |
| 韩文 | `U+AC00-D7AF` | 韩文音节 |
| 阿拉伯语 | `U+0600-06FF` | 阿拉伯字母 |
| 西里尔字母 | `U+0400-04FF` | 俄语等 |
| Emoji | `U+1F300-1F9FF` | 表情符号 |

---

## 字体子集化（Subsetting）

CJK 字体必须子集化，只包含页面用到的字。

### 方案一：构建时子集化（推荐）

```bash
# 使用 glyphhanger 或 fonttools 提取页面用到的字
npx glyphhanger https://example.com --whitelist=0123456789.元角分整 --subset=./source.ttf --format=woff2

# 或者用 fonttools (Python)
pyftsubset source.ttf --unicodes="U+4E00-9FFF,U+3000-303F" --output-file=subset.woff2 --flavor=woff2
```

```js
// 在构建工具中集成（vite/webpack）
// 用 plugin 自动提取页面用到的汉字
import { subset } from 'subset-font';

// 只保留页面出现的汉字
const pageChars = '你好世界Hello123';
const subsetBuffer = await subset(fontBuffer, pageChars, { format: 'woff2' });
```

### 方案二：CDN 动态子集化

```css
/* 使用支持动态子集化的 CDN（如 Google Fonts 早期方式） */
/* 或者自建服务，根据 User-Agent / Accept-Language 返回子集字体 */

@font-face {
  font-family: 'CJK';
  src: url('/api/subset-font?text=你好世界') format('woff2');
}
```

```html
<!-- 通过 JS 动态计算页面字符，请求对应子集 -->
<script>
const text = document.body.innerText;
const uniqueChars = [...new Set(text)].join('');
document.querySelector('#cjk-font').href = `/fonts/subset?chars=${encodeURIComponent(uniqueChars)}`;
</script>
```

### 大小对比

| 字体模式 | 体积 | 说明 |
|---------|------|------|
| 完整中文字体 | 10~20 MB | ❌ 不可能全量加载 |
| 常用字子集（3500 字） | ~500 KB | 覆盖 99% 日常文本 |
| 页面特定子集（几百字） | ~50 KB | 只包含当前页用到的字 |
| Latin 部分 | ~20 KB | 很小 |

---

## font-display 策略

```css
@font-face {
  font-family: 'MyFont';
  src: url('/fonts/latin.woff2') format('woff2');
  font-display: swap;       /* 立即用后备字体，加载后替换 */
  font-weight: 400;
  font-style: normal;
}

@font-face {
  font-family: 'MyFont';
  src: url('/fonts/emoji.woff2') format('woff2');
  font-display: optional;    /* 如果没加载完就不用了，适合装饰性字体 */
}
```

| `font-display` | 阻塞期 | 交换期 | 适用场景 |
|----------------|--------|--------|---------|
| `auto` | 浏览器决定 | 浏览器决定 | 默认 |
| `block` | 3s | 无限 | 图标字体（必须显示） |
| `swap` | 极小 | 无限 | **正文/多数字体（推荐）** |
| `fallback` | 100ms | 3s | 需要字体又不想影响性能 |
| `optional` | 100ms | 无 | 装饰字体，不影响可读性 |

**推荐：正文用 `swap`，图标用 `block`，装饰用 `optional`。**

---

## 语言字体栈

根据 HTML `lang` 属性设置不同语言字体栈：

```css
/* 默认（英文） */
body {
  font-family: 'Inter', 'Helvetica Neue', Arial, sans-serif;
}

/* 中文 */
:lang(zh) {
  font-family: 'Noto Sans SC', 'PingFang SC', 'Microsoft YaHei', sans-serif;
}

/* 日文 */
:lang(ja) {
  font-family: 'Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', sans-serif;
}

/* 韩文 */
:lang(ko) {
  font-family: 'Noto Sans KR', 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif;
}

/* 阿拉伯语 */
:lang(ar) {
  font-family: 'Noto Sans Arabic', 'Traditional Arabic', sans-serif;
}
```

```tsx
// React 中根据语言动态加载字体
import { useTranslation } from 'react-i18next';

function App() {
  const { i18n } = useTranslation();

  useEffect(() => {
    // 切换语言时预加载对应字体
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = `/fonts/${i18n.language}.css`;
    document.head.appendChild(link);
  }, [i18n.language]);

  return <div lang={i18n.language}>{/* content */}</div>;
}
```

---

## 字体加载性能优化

### 预加载关键字体

```html
<!-- 首屏立即加载，不阻塞渲染 -->
<link rel="preload" href="/fonts/latin.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/cjk-subset.woff2" as="font" type="font/woff2" crossorigin>
```

### 字体缓存

```nginx
# Nginx 字体长缓存
location ~* \.(woff2|woff|ttf|eot)$ {
    expires 365d;
    add_header Cache-Control "public, immutable";
    add_header Access-Control-Allow-Origin "*";  # 跨域
}
```

### 懒加载非首屏字体

```js
// 页面滚动到需要特殊字体的区域时才加载
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const font = document.createElement('link');
      font.rel = 'stylesheet';
      font.href = '/fonts/decorative.css';
      document.head.appendChild(font);
      observer.unobserve(entry.target);
    }
  });
});

observer.observe(document.querySelector('.decorative-section'));
```

### 字体加载顺序

```
1. 系统后备字体（立即显示，无网络请求）
2. preload 的基本字体（latin，小体积，快）
3. CJK 子集（稍大，异步加载）
4. 装饰字体（optional，加载不上就算了）
```

---

## Red Flags

- ❌ CJK 字体全量加载 → 10~20MB，用子集化 + unicode-range
- ❌ 不设 `font-display` → 字体加载完之前文字不可见（FOIT），长达 3s 白字
- ❌ 不设 `unicode-range` → 所有语言的字体全部下载，浪费流量
- ❌ 字体不跨域 → Nginx 没加 `Access-Control-Allow-Origin`，浏览器拦截
- ❌ 不 `preload` 关键字体 → 浏览器等 CSSOM 构建完才开始下载字体
- ❌ 所有语言用同一套字体 → 西文用中文字体渲染（笔画复杂，渲染慢）
