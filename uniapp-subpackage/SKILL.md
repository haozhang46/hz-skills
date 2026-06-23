---
name: uniapp-subpackage
description: UniApp 分包策略 — pages.json 分包配置、主包体积控制、分包预加载、依赖分包、小程序平台限制、工程化最佳实践
---

# UniApp 分包策略

## 为什么需要分包

小程序平台对包体积有严格限制（以微信为例）：

| 限制 | 大小 |
|------|------|
| 主包 + 所有分包 | ≤ 20MB |
| 单个分包/主包 | ≤ 2MB |

超过限制无法上传发布。分包的核心目标：**主包只放首页 + 公共依赖，其他页面按需加载。**

---

## 分包配置

### pages.json 基础配置

```json
{
  "pages": [
    // 主包 — 首页和 Tab 页
    { "path": "pages/index/index" },
    { "path": "pages/cart/cart" },
    { "path": "pages/mine/mine" }
  ],
  "subPackages": [
    {
      "root": "pages/goods",         // 分包根目录
      "pages": [
        { "path": "detail/detail" },  // 实际路径: pages/goods/detail/detail
        { "path": "list/list" }
      ]
    },
    {
      "root": "pages/order",
      "pages": [
        { "path": "confirm/confirm" },
        { "path": "list/list" },
        { "path": "detail/detail" }
      ]
    },
    {
      "root": "pages/user",
      "pages": [
        { "path": "profile/profile" },
        { "path": "settings/settings" },
        { "path": "address/address" }
      ]
    }
  ]
}
```

### 目录结构

```
src/
├── pages/                    # 主包
│   ├── index/
│   │   └── index.vue
│   ├── cart/
│   │   └── cart.vue
│   └── mine/
│       └── mine.vue
├── pages/goods/              # 分包 1
│   ├── detail/
│   │   └── detail.vue
│   └── list/
│       └── list.vue
├── pages/order/              # 分包 2
│   ├── confirm/
│   │   └── confirm.vue
│   ├── list/
│   │   └── list.vue
│   └── detail/
│       └── detail.vue
├── pages/user/               # 分包 3
│   ├── profile/
│   │   └── profile.vue
│   ├── settings/
│   │   └── settings.vue
│   └── address/
│       └── address.vue
├── static/                   # 静态资源（主包）
├── uni_modules/              # 插件（占用主包体积）
└── App.vue
```

---

## 分包策略

### 策略一：按业务模块分

```
主包: 首页 + Tab 页 + 登录 + 公共组件
├── pages/index      → 首页
├── pages/cart       → 购物车（Tab）
├── pages/mine       → 我的（Tab）
└── pages/login      → 登录（被多个分包引用）

分包 goods:    商品详情、商品列表
分包 order:    订单确认、订单列表、订单详情
分包 user:     个人资料、设置、地址管理
分包 activity:  活动页面、优惠券
```

### 策略二：按访问频率分

```
高频（主包）: 首页、搜索、Tab 页
中频（分包，可预加载）: 商品详情、订单列表
低频（分包，按需加载）: 设置、关于、帮助
```

### 策略三：按功能独立性分

```
独立功能拆到独立分包，方便团队并行开发
└── packages/
    ├── module-home/       # 首页模块
    ├── module-goods/      # 商品模块
    ├── module-order/      # 订单模块
    └── module-user/       # 用户模块
```

---

## 分包跳转

```vue
<!-- 主包 → 分包：正常路由跳转 -->
<navigator url="/pages/goods/detail/detail?id=10086">
  商品详情
</navigator>

<!-- 分包 → 主包：正常路由 -->
<navigator url="/pages/index/index">
  回首页
</navigator>

<!-- 分包 → 分包：使用分包路径 -->
<navigator url="/pages/order/confirm/confirm">
  去结算
</navigator>
```

```ts
// JS 跳转
uni.navigateTo({ url: '/pages/goods/detail/detail?id=10086' });
uni.switchTab({ url: '/pages/index/index' });  // Tab 页
```

---

## 分包预加载

在跳转前预加载目标分包，减少用户等待时间。

```json
{
  "subPackages": [
    {
      "root": "pages/goods",
      "pages": [{ "path": "detail/detail" }, { "path": "list/list" }]
    },
    {
      "root": "pages/order",
      "pages": [{ "path": "confirm/confirm" }]
    }
  ],
  "preloadRule": {
    "pages/index/index": {              // 从首页进入
      "network": "all",                  // 网络环境 all / wifi
      "packages": ["pages/goods"]        // 预加载 goods 分包
    },
    "pages/goods/detail/detail": {       // 从商品详情进入
      "network": "all",
      "packages": ["pages/order"]        // 预加载 order 分包
    }
  }
}
```

| 配置 | 说明 |
|------|------|
| `preloadRule` | 分包预加载规则 |
| `key` | 触发预加载的页面路径 |
| `packages` | 需要预加载的分包目录 |
| `network` | `all`（所有网络）/ `wifi`（仅 wifi） |

**预加载时机：** 进入 key 页面后立即开始下载指定分包，不阻塞当前页面渲染。

---

## 依赖分包（Independent SubPackages）

普通分包可以引用主包的资源（组件、工具函数等），但**独立分包**完全不依赖主包，**独立分包内的代码可以自己独立运行**。

```json
{
  "subPackages": [
    {
      "root": "pages/activity",
      "pages": [{ "path": "seckill/seckill" }],
      "independent": true   // 独立分包：不依赖主包的 JS
    }
  ]
}
```

**独立分包的使用场景：**
- 活动页面（秒杀、大促），可能单独部署
- 错误页/兜底页（主包挂了还能显示）
- A/B 测试页面

> ⚠️ 独立分包不能引用主包的组件/工具函数，需要自包含。

---

## 主包瘦身

### 控制主包体积（目标 < 1.5MB，留余量）

```bash
# 查看分包体积（HBuilderX 发行 → 查看包体积）
# 微信小程序开发者工具 → 详情 → 基本信息 → 本地代码大小
```

#### 1. 把三方组件移到分包

```diff
- // 主包引入大组件（膨胀主包）
- import Vant from 'vant-weapp';

+ // 分包各自引入需要的组件
+ // pages/goods/ 分包内单独引入
```

#### 2. 静态资源放 CDN

```vue
<!-- ❌ 大图片放主包 static/ -->
<image src="/static/banner.png" />

<!-- ✅ 大图片放 CDN -->
<image src="https://cdn.example.com/banner.png" />
```

#### 3. 公共组件按需引用

```diff
- // components/ 下的公共组件全部打入主包
+ // 只在某个分包用的组件，放到分包目录下
```

#### 4. 分包体积分析

```bash
# 发版时关注各分包体积
pages/goods      → 1.2MB  ✅
pages/order      → 0.8MB  ✅
pages/user       → 0.5MB  ✅
主包             → 1.8MB  ⚠️ > 1.5MB，需瘦身

# 快速定位大文件
find pages/main -name "*.vue" -exec ls -lh {} \; | sort -k5 -rh | head -10
```

### 主包只能放什么

```
主包 ✅：
├── Tab 页（首页、购物车、我的）
├── 公共组件（被多个分包使用）
├── 全局样式
├── App.vue / main.js
├── 路由配置

主包 ❌：
├── 只在一个分包使用的页面
├── 只在特定分包使用的组件
├── 大图片（放 CDN）
├── 完整字体文件
├── 不必要的大型三方库
```

---

## 分包工程规范

### pages.json 模板

```json
{
  "pages": [
    { "path": "pages/index/index" },
    { "path": "pages/cart/cart" },
    { "path": "pages/mine/mine" }
  ],
  "subPackages": [
    {
      "root": "pages/goods",
      "pages": [
        { "path": "list/list" },
        { "path": "detail/detail", "style": { "navigationBarTitleText": "商品详情" } }
      ]
    },
    {
      "root": "pages/order",
      "pages": [
        { "path": "list/list" },
        { "path": "detail/detail" },
        { "path": "confirm/confirm" }
      ]
    },
    {
      "root": "pages/user",
      "pages": [
        { "path": "profile/profile" },
        { "path": "settings/settings" }
      ]
    }
  ],
  "preloadRule": {
    "pages/index/index": {
      "network": "all",
      "packages": ["pages/goods"]
    },
    "pages/goods/detail/detail": {
      "network": "all",
      "packages": ["pages/order"]
    }
  }
}
```

---

## 分包策略总结

| 策略 | 做法 | 适用 |
|------|------|------|
| 按业务分 | 商品、订单、用户各一分包 | 模块清晰的项目 |
| 按频率分 | 高频主包、中频预加载、低频按需 | 大流量产品 |
| 独立分包 | `independent: true` 不依赖主包 | 活动页、兜底页 |

**核心原则：**
- 主包只放 Tab 页 + 公共依赖，越小越好（< 1.5MB）
- 分包按业务拆分，每个分包 ≤ 2MB
- 预加载用户最可能去的下一个分包
- 大图片/字体放 CDN，不打包
- 只在某分包内使用的组件，放到分包目录下

---

## Red Flags

- ❌ 主包体积超过 1.5MB — 微信限制 2MB，留余量防止后续膨胀
- ❌ 把只在一个分包用的组件放到主包 components/ — 无端增大主包
- ❌ 大图片打包到 static/ — 应该放 CDN
- ❌ 所有页面塞主包 — 小项目也建议拆分，为后续扩展留空间
- ❌ 独立分包引用主包组件 — 运行时报错，必须自包含
- ❌ 忘记 `preloadRule` — 用户从首页点商品详情要等分包下载完成
