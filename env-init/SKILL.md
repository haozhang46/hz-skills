---
name: env-init
description: 项目初始化 env 文件生成 — .env.example 模板、setup-env.sh 脚本、CI 密钥管理、多环境差异化配置
---

# env 初始化 — .env.example + 初始化脚本

## 文件结构

```
project/
├── .env.example          # ✅ committed — 模板，含占位值
├── .env                  # ❌ gitignored — 开发环境真实值
├── .env.local            # ❌ gitignored — 本地覆盖
├── .env.production       # ❌ gitignored — 生产环境
├── scripts/setup-env.sh  # ✅ 开发环境初始化脚本
└── .gitignore
```

## .gitignore

```
.env
.env.local
.env.production
.env.*.local
```

## .env.example（提交到 Git）

```
# 复制此文件为 .env 后填入真实值
VITE_API_BASE_URL=https://api.example.com
VITE_APP_TITLE=MyApp
# VITE_SECRET_KEY=  # 敏感值只写 key，不写占位值
```

## scripts/setup-env.sh（占位模板）

不同项目环境变量来源不同，脚本只提供骨架，按实际场景改。

```bash
#!/bin/bash
set -e

# 示例：从 .env.example 复制
if [ ! -f .env ]; then
  cp .env.example .env
  echo "✅ 已创建 .env，请填入真实值"
fi

# 可选：按参数选择环境
# bash scripts/setup-env.sh prd → 用 .env.prd
ENV=${1:-dev}
if [ -f ".env.${ENV}" ]; then
  cp ".env.${ENV}" .env
  echo "✅ 已从 .env.${ENV} 创建 .env"
fi
```

**可能的实际场景（项目按需实现）：**

| 场景 | 脚本行为 |
|------|---------|
| 小项目开发环境 | `cp .env.example .env` |
| 多环境切换 | `bash scripts/setup-env.sh prd` → 用 `.env.prd` |
| CI 拉取 Secret Manager | 调用内部 API 写入 `.env` |
| Monorepo 多包 | 在 `packages/*` 下循环执行 |

## CI/生产环境通过 API 拉取

CI 或部署脚本从内部 Secret Manager API 拉取敏感值，写入 `.env` 文件。`.env` 文件位置为项目根目录，与 `.env.example` 同级。

**流程描述：**
1. 运行 `scripts/setup-env.sh` 创建 `.env` 模板
2. 调用内部 Config API 获取当前环境（dev/staging/production）的配置值
3. 鉴权通过 CI 的环境变量传入
4. 将 API 返回值写入 `.env`

## 多环境差异化

```
.env.example          → 开发环境占位值
.env.production       → 生产环境（CI 拉取，不上传 Git）
.env.staging          → 预发环境
.env.local            → 个人本地覆盖（gitignore）
```

## 初始化流程

1. 新开发者 `git clone` → 运行 `scripts/setup-env.sh`
2. `.env.example` 复制为 `.env`，填入真实值
3. CI/生产 → 从 Secret Manager API 拉取，不手填
