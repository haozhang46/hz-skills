---
name: node-performance
description: Node.js / Next.js / Nest.js 性能检测与优化 — 性能分析、内存泄漏、V8 GC、Next.js 构建优化、Nest.js 微调
---

# Node.js / Next.js / Nest.js 性能检测与优化

## Node.js 性能检测

### 性能分析工具

| 工具 | 用途 | 命令 |
|------|------|------|
| **clinic.js** | 事件循环延迟、CPU、内存火焰图 | `npx clinic flame -- node app.js` |
| **0x** | 火焰图（低开销） | `npx 0x app.js` |
| **Node --prof** | V8 内置 profiler | `node --prof app.js` |
| **heapdump** | 堆快照分析 | `require('heapdump')` |
| **why-is-node-running** | 检测句柄未释放导致进程不退 | `npx why-is-node-running` |

#### clinic.js 诊断流程

```bash
# 安装
npm install -g clinic

# 1. Doctor — 综合诊断（事件循环延迟、CPU、内存）
clinic doctor -- node app.js
# 压测后 Ctrl+C，自动打开 HTML 报告
# 红色 = 有问题，绿色 = 正常

# 2. Flame — CPU 火焰图（找出最耗 CPU 的函数）
clinic flame -- node app.js

# 3. Bubbleprof — 异步资源追踪（找出 async 瓶颈）
clinic bubbleprof -- node app.js

# 4. Heapprof — 内存分配热点
clinic heapprof -- node app.js
```

#### 火焰图解读

```
火焰图顶部 = 当前正在执行的函数
宽度 = CPU 占用时间
栈从底到顶 = 调用链
```

**关注点：**
- 宽顶平顶 → 某个函数占大量 CPU，需优化
- 栈深 → 调用链过长，考虑缓存或重构
- `libuv` / `syscall` 宽 → IO 瓶颈，考虑连接池或异步化

### 内存泄漏检测

```bash
# 1. 生成堆快照
kill -USR2 <pid>  # 触发 heapdump（需预先加载 heapdump 模块）
# 生成 .heapsnapshot 文件 → Chrome DevTools Memory 加载

# 2. 持续监控内存
# --trace-gc 输出 GC 日志
node --trace-gc --expose-gc app.js

# 3. 检测句柄泄漏
npx why-is-node-running
```

**内存泄漏常见原因：**
- 事件监听器只加不移除（`addEventListener` 无 cleanup）
- 定时器未清除（`setInterval` 没有 `clearInterval`）
- 全局缓存无淘汰策略（用 `lru-cache` 替代普通 Map）
- 大对象被注册到全局事件/定时器的闭包捕获 → 闭包不释放，大对象跟着泄漏
- 事件监听器未移除（`emitter.on()` 没有 `off()`）
- 定时器未清除（`setInterval` 没有 `clearInterval`）
- 大对象缓存无淘汰策略（用 `lru-cache` 替代普通 Map）
- 流未销毁

### V8 垃圾回收（GC）

#### GC 架构

> **V8 GC 不是引用计数，是标记清除（Mark-Sweep）。** 对象能否回收取决于是否「可达」（reachable），而不是有没有被引用。局部变量退出作用域后自动不可达，无需手动干预。

> **循环引用也不是问题。** `a.b = b; b.a = a` 这种在旧的引用计数 GC 中是泄漏，但在标记清除下只要两个对象都不从根可达，就会被一起回收。这也是旧时代的问题，不需要关注。

```
V8 堆
├── Young Generation（新生代）— Scavenge 算法，频繁 GC
│   ├── From-space
│   └── To-space
└── Old Generation（老生代）— Mark-Sweep / Mark-Compact，较少 GC
    ├── 指针区
    └── 数据区
```

| 代 | 算法 | 频率 | 暂停时间 |
|----|------|------|---------|
| Young | Scavenge（复制） | 高 | 短（1~5ms） |
| Old | Mark-Sweep / Mark-Compact | 低 | 长（10~100ms+） |

#### GC 相关命令行

```bash
# 查看 GC 日志
node --trace-gc app.js

# 查看 GC 详细统计
node --trace-gc-verbose app.js

# 暴露 global.gc() 手动触发
node --expose-gc app.js

# 限制老生代内存（默认约 1.4GB）
node --max-old-space-size=512 app.js

# 设置新生代内存
node --max-semi-space-size=64 app.js
```

#### GC 优化实践

```bash
# 1. 限制堆内存，避免 GC 暂停过长
NODE_OPTIONS="--max-old-space-size=512" node app.js

# 2. 增大新生代空间，减少晋升到老生代的频率（适合大量短期对象）
NODE_OPTIONS="--max-semi-space-size=128" node app.js

# 3. 查看 GC 对事件循环的影响
clinic doctor -- node app.js
```

```js
// 4. 代码层面减少 GC 压力
// ❌ 频繁创建临时对象
router.get('/api/users', (req, res) => {
  const result = users.map(u => ({ id: u.id, name: u.name })); // 每次请求创建新对象
  res.json(result);
});

// ✅ 缓存结果（对象复用）
const cache = new Map();
router.get('/api/users', (req, res) => {
  let result = cache.get('users');
  if (!result) {
    result = users.map(u => ({ id: u.id, name: u.name }));
    cache.set('users', result);
  }
  res.json(result);
});

// 5. 事件监听器只加不移除（Node.js 中同样泄漏）
// ❌ 每次调用都加监听，从不移除
function handleRequest(req, res) {
  process.on('uncaughtException', handleError); // 每次请求都加，永远不删
}
// ✅ 在合适的生命周期移除
process.on('uncaughtException', handleError);
process.removeListener('uncaughtException', handleError);

// 流未销毁
// ❌ 可读流不关闭
function readFile(path) {
  const stream = fs.createReadStream(path);
  stream.on('data', console.log);
  // stream 用完后没 close/destroy
}

// ✅ 流用完后销毁
async function readFile(path) {
  const stream = fs.createReadStream(path);
  for await (const chunk of stream) {
    console.log(chunk);
  }
  stream.destroy(); // 显式销毁
}

// 6. 定时器未清除
// ❌ 定时器无限运行
function startPolling() {
  setInterval(() => fetchData(), 5000);
}
// ✅ 保存引用，适时清除
let timer = setInterval(() => fetchData(), 5000);
// 不再需要时
clearInterval(timer);
```

#### Node.js 性能 Checklist

- [ ] 使用 `clinic doctor` 做综合诊断
- [ ] 火焰图找出 CPU 热点
- [ ] heapdump 检查内存泄漏
- [ ] `--max-old-space-size` 限制堆内存
- [ ] 检查事件监听器是否泄漏（`why-is-node-running`）
- [ ] 缓存策略（`lru-cache` 替代 Map）
- [ ] 大量计算的逻辑扔到 Worker Threads

---

## Next.js 性能检测与优化

### 构建分析

```bash
# Bundle Analyzer
npm install @next/bundle-analyzer

# next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer({});

# 分析
ANALYZE=true npm run build
# 自动打开 HTML 报告，显示每个 chunk 的大小
```

### 核心优化

#### 1. Server Components（默认）

```tsx
// ✅ App Router 默认是 Server Components，不发送 JS 到客户端
// 只在需要交互时加 'use client'
export default async function Page() {
  const data = await fetch('https://api.example.com/data');
  return <div>{data.name}</div>;  // 仅在服务端渲染
}
```

#### 2. 动态导入（Code Splitting）

```tsx
import dynamic from 'next/dynamic';

// ❌ 静态导入，打包进主 bundle
import HeavyChart from '@/components/HeavyChart';

// ✅ 动态导入，按需加载
const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <Skeleton />,
  ssr: false,  // 不需要 SEO 的组件可以关闭 SSR
});
```

#### 3. 图片优化

```tsx
import Image from 'next/image';

// ✅ 自动 WebP/AVIF、懒加载、响应式
<Image src="/hero.jpg" alt="hero" width={1200} height={600}
  priority={isAboveTheFold}  // 首屏加 priority
  quality={75}                // 默认 75，降低到 60~70 减小体积
/>
```

#### 4. ISR（增量静态生成）

```tsx
// ✅ 静态生成 + 定期更新，比 SSR 快一个数量级
export default async function Page() {
  const data = await getData();
  return <div>{data.content}</div>;
}

export const revalidate = 60; // 每 60s 后台重新生成
```

#### 5. 缓存策略

```tsx
// ✅ 数据缓存（fetch 默认缓存）
fetch('https://api.example.com/data');  // 默认 force-cache

// ✅ 按需缓存
fetch('https://api.example.com/data', {
  next: { revalidate: 60 },  // 60s 后重新 fetch
});

// ❌ 每次都请求服务端
fetch('https://api.example.com/data', { cache: 'no-store' });
```

#### 6. 减少客户端 JS

```tsx
// ✅ 把不需要交互的组件保留在服务端
// ✅ 第三方库只在客户端加载
const CryptoJS = dynamic(() => import('crypto-js'), { ssr: false });
```

### Next.js 性能指标

| 指标 | 目标 | 工具 |
|------|------|------|
| LCP | < 2.5s | Lighthouse / Web Vitals |
| TTI | < 3.5s | Lighthouse |
| JS Bundle | < 200KB (首屏) | `@next/bundle-analyzer` |
| Image Size | < 100KB | Next.js Image 自动优化 |
| ISR TTFB | < 200ms | 相比 SSR 的 500ms+ |

---

## Nest.js 性能检测与优化

### 性能检测

```bash
# 1. 开启 Nest.js 内置日志（请求耗时）
const app = await NestFactory.create(AppModule, {
  logger: ['log', 'error', 'warn', 'debug', 'verbose'],
});

# 2. 使用 clinic.js 诊断
clinic doctor -- node dist/main

# 3. 添加请求耗时中间件
@Injectable()
export class TimingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const start = Date.now();
    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - start;
        if (duration > 1000) {
          Logger.warn(`Slow request: ${duration}ms`, context.getClass().name);
        }
      }),
    );
  }
}
```

### 核心优化

#### 1. 懒加载模块

```tsx
// ✅ 大型模块懒加载
@Module({
  imports: [
    forwardRef(() => HeavyModule),  // 按需加载
  ],
})
export class AppModule {}
```

#### 2. 缓存

```tsx
@Injectable()
export class UserService {
  constructor(
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  async getUser(id: number) {
    const cached = await this.cacheManager.get(`user:${id}`);
    if (cached) return cached;

    const user = await this.prisma.user.findUnique({ where: { id } });
    await this.cacheManager.set(`user:${id}`, user, 60); // TTL 60s
    return user;
  }
}
```

#### 3. 全局 ValidationPipe 配置

```tsx
// ✅ 关闭冗长的验证（减少 CPU 开销）
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,        // 剔除无用字段
  forbidNonWhitelisted: false, // 不抛错（减少异常处理开销）
  transform: true,
  transformOptions: {
    enableImplicitConversion: true, // 减少手动转换
  },
}));
```

#### 4. 序列化

```tsx
// ✅ 用 @SerializeOptions 控制返回字段，避免返回大对象
@SerializeOptions({
  excludeExtraneousValues: true, // 只返回有 @Expose() 的字段
})
class UserDto {
  @Expose() id: number;
  @Expose() name: string;
  // password 不会返回
}
```

#### 5. 数据库连接池

```tsx
// ✅ Prisma 连接池配置
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
  // 连接池大小 = CPU 核数 * 2 + 1
});

// ✅ TypeORM 连接池
TypeOrmModule.forRoot({
  type: 'mysql',
  extra: {
    connectionLimit: 10,  // 连接池大小
    queueLimit: 0,        // 无限排队（或设上限）
  },
});
```

---

## Red Flags

- ❌ 生产环境不带 `--max-old-space-size` → OOM 时 GC 暂停长达秒级
- ❌ 事件监听器只加不移除 → 回调函数持有大对象引用，组件卸载后仍然存活
- ❌ 事件监听器只加不移除 → 内存泄漏 + 重复执行
- ❌ Next.js 全量 `'use client'` → JS bundle 膨胀，默认用 Server Components
- ❌ 图片不加 `priority` 和 `quality` → LCP 变差，体积变大
- ❌ ISR 忘记 `revalidate` → 永远是旧数据（或永不过期）
- ❌ Nest.js 无缓存拦截器 → 重复查 DB，加 `@Cacheable` 或手动缓存
- ❌ Node.js 单线程做 CPU 密集计算 → 阻塞事件循环，用 Worker Threads
