---
name: mermaid
description: Mermaid.js Markdown 图表语法 — flowchart, sequenceDiagram, classDiagram, stateDiagram, ER, gitgraph, mindmap, timeline
---

# Mermaid — Markdown 图表

在 Markdown 中用 ` ```mermaid ` 代码块编写图表。

---

## Flowchart — 流程图

```mermaid
flowchart TD
  A[开始] --> B{判断}
  B -->|是| C[处理]
  B -->|否| D[结束]
```

### 方向

| 语法 | 方向 |
|------|------|
| `TD` / `TB` | 从上到下 |
| `BT` | 从下到上 |
| `LR` | 从左到右 |
| `RL` | 从右到左 |

### 节点形状

```mermaid
flowchart LR
  A[矩形] --> B(圆角)
  B --> C([stadium])
  C --> D[[subroutine]]
  D --> E[(database)]
  F{菱形} --> G>asymmetric]
  H((circle)) --> I[/parallelogram/]
  J([double circle])
```

| 语法 | 形状 |
|------|------|
| `A[text]` | 矩形 |
| `A(text)` | 圆角 |
| `A([text])` | stadium |
| `A[[text]]` | subroutine |
| `A[(text)]` | 圆柱（数据库） |
| `A{text}` | 菱形（判断） |
| `A((text))` | 圆形 |
| `A>text]` | 不对称 |
| `A[/text/]` | 平行四边形 |

### 连线

| 语法 | 类型 |
|------|------|
| `A-->B` | 箭头 |
| `A---B` | 无箭头 |
| `A-.->B` | 虚线箭头 |
| `A==>B` | 粗线箭头 |
| `A--text-->B` | 带文字箭头 |
| `A -->|text| B` | 带文字箭头（另一种） |
| `A~~~B` | 不可见线（调整布局） |

### Subgraph

```mermaid
flowchart TB
  subgraph 登录流程
    A[输入] --> B{校验}
    B -->|成功| C[主页]
  end
  subgraph 错误处理
    B -->|失败| D[提示错误]
  end
```

### 样式

```mermaid
flowchart LR
  A[重要] --> B[普通]
  classDef highlight fill:#f96,stroke:#333,stroke-width:4px
  class A highlight
```

---

## Sequence Diagram — 时序图

```mermaid
sequenceDiagram
  participant U as 用户
  participant S as 服务端
  participant DB as 数据库

  U->>S: 登录请求
  activate S
  S->>DB: 查询用户
  activate DB
  DB-->>S: 返回结果
  deactivate DB
  S-->>U: 登录成功
  deactivate S
```

### 消息类型

| 语法 | 类型 |
|------|------|
| `->` | 实线无箭头 |
| `->>` | 实线箭头 |
| `-->>` | 虚线箭头 |
| `-x` | 实线 X 结尾 |
| `--)` | 实线开放箭头（异步） |
| `<<->>` | 双向箭头 |

### 生命周期

```mermaid
sequenceDiagram
  participant A
  participant B
  A->>+B: 激活 B
  B-->>-A: 取消激活
```

`+` = activate, `-` = deactivate（缩写形式）

### 组合片段

```mermaid
sequenceDiagram
  participant A
  participant B

  rect rgb(240, 240, 240)
    Note over A,B: 正常流程
    A->>B: 请求
    B-->>A: 响应
  end

  alt 成功
    A->>B: 提交
  else 失败
    A->>B: 重试
  end

  loop 每隔 30s
    A->>B: 心跳
  end

  par 并行
    A->>B: 任务 1
  and
    A->>B: 任务 2
  end

  opt 可选
    A->>B: 额外处理
  end

  critical 必须成功
    A->>B: 事务
  option 超时
    A->>B: 回滚
  end

  break 异常
    A->>B: 中断
  end
```

### Notes / Actors / Box

```mermaid
sequenceDiagram
  box 紫色 用户端
    participant U
  end
  box 绿色 服务端
    participant S
  end

  Note over U,S: 交互开始
  Note right of U: 用户在操作
  U->>S: 请求
```

---

## Class Diagram — 类图

```mermaid
classDiagram
  class Animal {
    +String name
    +int age
    +makeSound() void
    -privateMethod() void
  }

  class Dog {
    +fetch() void
  }

  class Cat {
    +purr() void
  }

  Animal <|-- Dog
  Animal <|-- Cat
  Animal <.. ZooKeeper
  Animal *-- Leg
  Animal o-- Owner
```

### 关系

| 符号 | 关系 |
|------|------|
| `<\|--` | 继承 |
| `*--` | 组合 |
| `o--` | 聚合 |
| `-->` | 关联 |
| `..>` | 依赖 |
| `..\|>` | 实现 |

### 修饰符

| 符号 | 可见性 |
|------|--------|
| `+` | public |
| `-` | private |
| `#` | protected |
| `~` | package |

---

## State Diagram — 状态图

```mermaid
stateDiagram-v2
  [*] --> 待支付
  待支付 --> 已支付: 支付成功
  待支付 --> 已取消: 超时取消
  已支付 --> 已发货
  已发货 --> 已完成
  已完成 --> [*]

  state 已支付 {
    [*] --> 待发货
    待发货 --> 已发货
  }
```

---

## Entity Relationship Diagram — ER 图

```mermaid
erDiagram
  USER ||--o{ ORDER : places
  USER {
    int id PK
    string name
    string email
  }
  ORDER ||--|{ ORDER_ITEM : contains
  ORDER {
    int id PK
    int user_id FK
    string status
    date created_at
  }
  ORDER_ITEM {
    int id PK
    int order_id FK
    int product_id FK
    int quantity
  }
```

---

## Gitgraph — Git 分支图

```mermaid
gitGraph
  commit
  commit
  branch feature/login
  checkout feature/login
  commit
  commit
  checkout main
  branch feature/header
  commit
  checkout feature/login
  commit
  checkout main
  merge feature/login
  merge feature/header
  commit
```

---

## Mindmap — 思维导图

```mermaid
mindmap
  项目架构
    前端
      React Native
      TypeScript
      Zustand
    后端
      Node.js
      PostgreSQL
    部署
      EAS Build
      App Store
```

---

## Timeline — 时间线

```mermaid
timeline
  title 项目里程碑
  2024 Q1 : 需求评审
           : 技术选型
  2024 Q2 : 开发完成
           : 内测
  2024 Q3 : 正式发布
```

---

## 常用配置

```mermaid
---
config:
  theme: neutral           # default / neutral / dark / forest / base
  flowchart:
    curve: basis           # basis / bumpX / cardinal / catmullRom / linear / step
    defaultRenderer: dagre # dagre / elk（大图用 elk）
---
flowchart LR
  A --> B
```

---

## Red Flags

- ❌ `flowchart` 中节点 ID 不能是纯小写 `end` → 用 `END` 或 `"end"`
- ❌ `flowchart` 中以 `o` / `x` 开头的连线会被解析为 circle / cross edge → 加空格 `dev--- ops`
- ❌ `sequenceDiagram` 中 `end` 作为参与者名会中断 → 用 `(end)`、`[end]` 或引号包裹
- ❌ 外部 CSS 覆盖 Mermaid 样式无效 → 用 `classDef` 语法内部定义
- ❌ 中文换行用 `<br>` 而不是直接换行
