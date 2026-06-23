---
name: image-optimization
description: 前端图片加载策略 — 懒加载 (IntersectionObserver / loading=lazy)、占位图 (BlurHash / Low-Quality Preview / Skeleton)、响应式图片 (srcset / picture / @1x @2x)、渐进式加载
---

# 前端图片加载策略

## 懒加载

### 原生 `loading="lazy"`

```html
<!-- ✅ 浏览器原生懒加载（Chrome 76+，兼容性 > 90%） -->
<img src="photo.jpg" loading="lazy" alt="photo" />
<iframe src="map.html" loading="lazy"></iframe>

<!-- 首屏图片加 priority，不要 lazy -->
<img src="hero.jpg" fetchpriority="high" alt="hero" />
```

### IntersectionObserver（自定义控制）

```html
<!-- 自定义懒加载，兼容性更好，控制更精细 -->
<img data-src="photo.jpg" class="lazy" alt="photo" />
```

```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const img = entry.target;
      img.src = img.dataset.src;        // 替换真实地址
      img.classList.remove('lazy');
      observer.unobserve(img);          // 加载后停止观察
    }
  });
}, {
  rootMargin: '200px',                  // 提前 200px 加载（预加载）
  threshold: 0.01,
});

document.querySelectorAll('.lazy').forEach(img => observer.observe(img));
```

### React 懒加载组件

```tsx
function LazyImage({ src, alt, placeholder }: { src: string; alt: string; placeholder: string }) {
  const imgRef = useRef<HTMLImageElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          observer.unobserve(entry.target);
        }
      },
      { rootMargin: '200px' }
    );
    if (imgRef.current) observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={imgRef} style={{ position: 'relative', background: '#f0f0f0' }}>
      {/* 占位图 */}
      {!loaded && <img src={placeholder} alt="" style={{ filter: 'blur(10px)' }} />}
      {/* 真实图片 */}
      {inView && (
        <img
          src={src}
          alt={alt}
          onLoad={() => setLoaded(true)}
          style={{ opacity: loaded ? 1 : 0, transition: 'opacity 0.3s' }}
        />
      )}
    </div>
  );
}
```

---

## 占位图策略

| 策略 | 体积 | 效果 | 实现 |
|------|------|------|------|
| **LQIP** (Low Quality Image Placeholder) | 小（~2KB） | 模糊版本 → 清晰 | 服务端生成缩略图 base64 |
| **BlurHash** | 极小（~200B） | 色块模糊 | 后端生成 hash，前端解码 |
| **SQIP** (SVG-based) | 小（~1KB) | SVG 轮廓 | 比 BlurHash 更清晰 |
| **Skeleton / 骨架屏** | 无 | 占位框 + 动画 | CSS 纯前端 |
| **Dominant Color** | 无 | 纯色背景 | 取主色 `background: #abc` |

### LQIP — 模糊预览图

```html
<!-- 先在 CSS 中加载 tiny 缩略图（20px 宽），再替换为原图 -->
<img
  src="photo.lqip.jpg"            <!-- 20px 宽的模糊缩略图 -->
  data-src="photo.jpg"
  class="lazy"
  onload="this.style.opacity='1'"
  style="filter: blur(20px); transition: opacity 0.3s;"
/>
```

```js
// 加载完成后模糊过渡到清晰
img.addEventListener('load', () => {
  img.style.filter = 'none';
  img.style.transition = 'filter 0.3s';
});
```

### BlurHash（推荐）

```bash
# 服务端生成 BlurHash
pip install blurhash
python -c "from blurhash import encode; print(encode(open('photo.jpg','rb').read(), 4, 3))"
```

```tsx
// 前端解码 BlurHash
import { decode } from 'blurhash';

function BlurhashPlaceholder({ hash }: { hash: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const pixels = decode(hash, 32, 32);    // 解码为 32x32 像素
    const ctx = canvasRef.current?.getContext('2d');
    const imageData = ctx?.createImageData(32, 32);
    imageData?.data.set(pixels);
    ctx?.putImageData(imageData!, 0, 0);
  }, [hash]);

  return <canvas ref={canvasRef} width={32} height={32}
           style={{ width: '100%', height: '100%', position: 'absolute' }} />;
}

// 使用
<div style={{ position: 'relative' }}>
  <BlurhashPlaceholder hash="LEHV6nWB2yk8pyo0adR*.7kCMdnj" />
  <img src="photo.jpg" loading="lazy" style={{ position: 'relative' }} />
</div>
```

### 骨架屏（Skeleton）

```tsx
function ImageSkeleton() {
  return (
    <div style={{
      width: '100%',
      paddingBottom: '56.25%',    // 16:9 宽高比
      background: 'linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%)',
      backgroundSize: '200% 100%',
      animation: 'shimmer 1.5s infinite',
      borderRadius: '8px',
    }} />
  );
}
```

```css
@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

---

## 响应式图片

### `srcset` + `sizes` — 视口适配

```html
<!-- 根据视口宽度和像素比选择合适图片 -->
<img
  src="photo-800.jpg"
  srcset="
    photo-400.jpg  400w,    <!-- 400px 宽 -->
    photo-800.jpg  800w,    <!-- 800px 宽 -->
    photo-1200.jpg 1200w,   <!-- 1200px 宽 -->
    photo-1600.jpg 1600w    <!-- 1600px 宽 -->
  "
  sizes="
    (max-width: 600px) 100vw,   <!-- 手机全宽 -->
    (max-width: 1200px) 50vw,   <!-- 平板半宽 -->
    800px                        <!-- 桌面固定 800px -->
  "
  alt="photo"
/>

<!-- 结果：手机小屏(375px @2x) → 选 800w（375*2=750，最接近的 800w）-->
<!-- 结果：桌面 1200px → 选 1200w -->
```

### `@1x` / `@2x` / `@3x` — 像素比适配

```html
<!-- 按设备像素比（DPR）选择 -->
<img
  src="photo@1x.jpg"
  srcset="
    photo@1x.jpg 1x,    <!-- 普通屏 -->
    photo@2x.jpg 2x,    <!-- Retina 屏 -->
    photo@3x.jpg 3x     <!-- 高密度屏 -->
  "
  alt="photo"
/>
```

### `<picture>` — 格式 + 尺寸 + 像素比全控

```html
<picture>
  <!-- AVIF（最优先） -->
  <source
    type="image/avif"
    srcset="photo-400.avif 400w, photo-800.avif 800w, photo-1200.avif 1200w"
    sizes="(max-width: 600px) 100vw, 800px"
  />
  <!-- WebP（其次） -->
  <source
    type="image/webp"
    srcset="photo-400.webp 400w, photo-800.webp 800w, photo-1200.webp 1200w"
    sizes="(max-width: 600px) 100vw, 800px"
  />
  <!-- JPEG 兜底 -->
  <img
    src="photo-800.jpg"
    srcset="photo-400.jpg 400w, photo-800.jpg 800w, photo-1200.jpg 1200w"
    sizes="(max-width: 600px) 100vw, 800px"
    loading="lazy"
    alt="photo"
  />
</picture>
```

**浏览器选择逻辑：**
```
1. 支持 AVIF → 选最匹配的 avif 图片
2. 不支持 AVIF，支持 WebP → 选最匹配的 webp 图片
3. 都不支持 → 回退到 JPEG
```

### 图片 CDN 服务端缩放

```html
<!-- 配合图片 CDN（如 Cloudinary、imgix、七牛）动态裁剪 -->
<!-- 客户端指定尺寸，CDN 按需生成 -->
<img
  src="https://cdn.example.com/photo.jpg?w=400&h=300&q=75&f=webp"
  srcset="
    https://cdn.example.com/photo.jpg?w=400&h=300&q=75&f=webp 400w,
    https://cdn.example.com/photo.jpg?w=800&h=600&q=75&f=webp 800w,
    https://cdn.example.com/photo.jpg?w=1200&h=900&q=75&f=webp 1200w
  "
  sizes="(max-width: 600px) 100vw, 800px"
  loading="lazy"
  alt="photo"
/>
```

| 参数 | 含义 | 建议 |
|------|------|------|
| `w` | 宽度 | 匹配 CSS 渲染宽度 × DPR |
| `h` | 高度 | 等比例缩放 |
| `q` | 质量 1~100 | 70~80（平衡质量与体积） |
| `f` | 格式 | webp / avif |
| `fit` | 裁剪模式 | cover / contain / fill |

---

## 渐进式加载完整策略

### 图片加载流水线

```
                    LQIP 占位图（~2KB，立即显示）
                          │
               IntersectionObserver 触发加载
                          │
                下一位图（响应式 srcset）
                          │
                onLoad → 过渡动画（模糊 → 清晰）
                          │
               大图加载完成，占位图隐藏
```

### 生产代码示例

```tsx
function ProgressiveImage({
  src,          // 原图 URL
  lqip,         // LQIP 模糊预览 base64
  blurHash,     // BlurHash（可选）
  width,        // 容器宽度
  height,       // 容器高度
  alt,          // 替代文本
  srcset,       // 响应式源
  sizes,        // 尺寸规则
}: Props) {
  const [loaded, setLoaded] = useState(false);
  const [inView, setInView] = useState(false);
  const imgRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          observer.disconnect();
        }
      },
      { rootMargin: '200px' }
    );
    if (imgRef.current) observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={imgRef} style={{
      position: 'relative',
      width, height,
      background: '#f0f0f0',
      overflow: 'hidden',
    }}>
      {/* 阶段 1: LQIP / BlurHash 占位（立即显示） */}
      {!loaded && lqip && (
        <img
          src={lqip}
          alt=""
          style={{
            width: '100%', height: '100%',
            objectFit: 'cover',
            filter: 'blur(20px)',
            transform: 'scale(1.1)',
          }}
        />
      )}

      {/* 阶段 2: 真实图片（进入视口后加载） */}
      {inView && (
        <img
          src={src}
          srcSet={srcset}
          sizes={sizes}
          alt={alt}
          onLoad={() => setLoaded(true)}
          style={{
            position: 'absolute',
            top: 0, left: 0,
            width: '100%', height: '100%',
            objectFit: 'cover',
            opacity: loaded ? 1 : 0,
            transition: 'opacity 0.5s ease-in-out',
          }}
        />
      )}
    </div>
  );
}
```

### 图片优化 Checklist

- [ ] `loading="lazy"` 非首屏图片
- [ ] `fetchpriority="high"` 首屏图片（LCP）
- [ ] LQIP / BlurHash 占位图
- [ ] `srcset` + `sizes` 响应式
- [ ] `<picture>` + WebP/AVIF 格式降级
- [ ] 图片 CDN 动态裁剪（?w=&q=&f=）
- [ ] 宽高比预留防 CLS（`aspect-ratio` / `padding-bottom`）
- [ ] 图片质量 q=70~80（非 100）

---

## Red Flags

- ❌ 不设 `loading="lazy"` → 所有图片首屏全加载
- ❌ 不设宽高比 → CLS（布局偏移）
- ❌ 移动端加载 2000px 大图 → 浪费流量、卡顿
- ❌ 不设 `srcset` → Retina 屏图片模糊
- ❌ JPEG 100% 质量 → 体积比 80% 大 3 倍，肉眼看不出区别
- ❌ 懒加载 `rootMargin` 不设 → 图片到视口边缘才开始加载，用户看到白块
- ❌ LQIP 不设 `blur(20px)` → 低质量缩略图锯齿明显
