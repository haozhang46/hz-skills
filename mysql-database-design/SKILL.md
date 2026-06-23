---
name: mysql-database-design
description: MySQL 数据库设计与 SQL 优化 — Schema 设计、DDL、DML、索引优化、EXPLAIN、事务隔离级别、死锁排查、设计模式
---

# MySQL — 数据库设计与 SQL 优化

## Schema 设计

### 范式化

| 范式 | 规则 | 说明 |
|------|------|------|
| 1NF | 每列不可再分 | 原子性，不存数组/JSON 当字符串 |
| 2NF | 非主键列完全依赖于主键 | 联合主键时，每列依赖整个主键而非部分 |
| 3NF | 非主键列不传递依赖 | 非主键列不能依赖其他非主键列 |

### 常用字段类型选择

| 类型 | 推荐场景 | 说明 |
|------|---------|------|
| `BIGINT UNSIGNED` | 主键 ID | AUTO_INCREMENT 自增 |
| `CHAR(N)` | 定长：手机号、身份证 | 长度固定时比 VARCHAR 快 |
| `VARCHAR(N)` | 变长：名称、邮箱 | N 按最常长度设，不宜过大 |
| `TEXT` / `MEDIUMTEXT` | 大文本 | 不建索引，需前缀索引 |
| `INT UNSIGNED` | 状态枚举、计数 | 小数据量 |
| `DECIMAL(10,2)` | 金额 | 不用 FLOAT/DOUBLE（精度问题） |
| `DATETIME` | 时间戳 | 时区无关用 DATETIME，有关用 TIMESTAMP |
| `JSON` | MySQL 5.7+ 动态字段 | 可索引，但查询效率低于关系表 |

### 索引策略

```sql
-- 单列索引
CREATE INDEX idx_email ON users(email);

-- 联合索引（最左前缀原则）
CREATE INDEX idx_status_created ON orders(status, created_at);
-- 生效: WHERE status=1, WHERE status=1 AND created_at>'2024-01-01'
-- 不生效: WHERE created_at>'2024-01-01'（跳过了最左列）

-- 唯一索引
CREATE UNIQUE INDEX idx_username ON users(username);

-- 前缀索引（TEXT 类型）
CREATE INDEX idx_content ON articles(content(20));

-- 覆盖索引（查询字段都在索引里，不回表）
-- 如果 idx_a_b 覆盖了 SELECT a, b FROM t WHERE a=1，就是覆盖索引
```

**索引设计原则：**
- 区分度高的列在前（唯一值 / 总行数 越大越好）
- 短字段在前（INT 优于 VARCHAR）
- 查询频率高的列在前
- 不要过度索引（写性能下降、占用空间）

---

## DDL — 表定义

```sql
CREATE TABLE users (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email      VARCHAR(255) NOT NULL,
  nickname   VARCHAR(50)  NOT NULL,
  status     TINYINT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  UNIQUE INDEX idx_email (email),
  INDEX idx_status_created (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 约束

```sql
-- NOT NULL — 必填
-- DEFAULT — 默认值
-- UNIQUE — 唯一约束
-- PRIMARY KEY — 主键（自动 NOT NULL + UNIQUE）
-- FOREIGN KEY — 外键（InnoDB 支持）
-- CHECK — 检查约束（MySQL 8.0+ 生效）

ALTER TABLE users ADD CONSTRAINT chk_status CHECK (status IN (0, 1));
ALTER TABLE orders ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE users ADD INDEX idx_email (email);
ALTER TABLE users DROP INDEX idx_email;
ALTER TABLE users MODIFY COLUMN nickname VARCHAR(100) NOT NULL;
```

### 外键注意

```sql
-- 外键影响写性能，分布式/分库分表不支持
-- 大流量系统通常用应用层保证引用完整性，不用外键
```

---

## 表关系设计原理

### 三种关系

#### 一对一（1:1）

用户 ↔ 用户档案、订单 ↔ 发票

```sql
CREATE TABLE user_profile (
  user_id   BIGINT UNSIGNED PRIMARY KEY,  -- 与 users.id 一一对应
  avatar    VARCHAR(255),
  bio       TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

**设计要点：**
- 从表的主键就是外键（`user_id` 同时是 PK 和 FK）
- 或者从表用自增 ID + 唯一外键（`UNIQUE INDEX idx_user_id`）
- 不常用，大多数 1:1 可以直接合并到主表，除非字段访问频率差异大

#### 一对多（1:N）

用户 → 订单、分类 → 商品

```sql
CREATE TABLE orders (
  id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,          -- 外键，指向 users.id
  amount  DECIMAL(10,2) NOT NULL,
  INDEX idx_user_id (user_id)                -- 必建索引
);
```

**设计要点：**
- 外键建在**多**的那张表（orders.user_id）
- **被驱动表的外键列必须建索引**（否则 JOIN 全表扫）
- 索引名规范：`idx_被引用表_列名`（`idx_user_id`）

#### 多对多（N:N）— 中间表

学生 ↔ 课程、用户 ↔ 角色、商品 ↔ 标签

```sql
CREATE TABLE student_course (
  student_id BIGINT UNSIGNED NOT NULL,
  course_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (student_id, course_id),       -- 复合主键
  INDEX idx_course_id (course_id)            -- 反向查询索引
);
```

### 中间表设计原则

#### 复合主键 vs 自增 ID

```sql
-- ✅ 推荐：复合主键（唯一约束天然满足，省一次索引）
CREATE TABLE user_role (
  user_id BIGINT UNSIGNED NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id)
);
-- 不允许同一个用户有重复角色

-- ❌ 不推荐：自增 ID + 唯一索引（多一个无意义的列）
CREATE TABLE user_role (
  id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,  -- 无意义
  user_id BIGINT UNSIGNED NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  UNIQUE INDEX uk_user_role (user_id, role_id)          -- 冗余
);
```

| | 复合主键 | 自增 ID + 唯一索引 |
|--|---------|-----------------|
| 存储空间 | 少（2 个 INT = 8B） | 多（+ 自增 ID 8B + 唯一索引 16B） |
| 查询效率 | 聚簇索引直接覆盖 | 多一次回表 |
| 业务含义 | user_id + role_id 就是唯一标识 | ID 无意义 |
| ORM 兼容 | 复合主键某些框架支持差 | ✅ 通用 |

**什么时候用自增 ID？** 中间表有独立业务含义（如订单-商品需要 ID 做其他表的外键）。

#### 双向索引

```sql
CREATE TABLE user_role (
  user_id BIGINT UNSIGNED NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),            -- 查用户的所有角色：走 PK
  INDEX idx_role_id (role_id)                -- 查角色的所有用户：走这个索引
);

-- 如果查反向（通过角色查用户）很少，可以不加这个索引
```

**判断是否需要反向索引：** 业务中是否会有「查询某个角色下的所有用户」这种需求。

#### 带属性的中间表

中间表除了关联双方 ID，还可以携带关联本身的属性。

```sql
-- 学生选课：带成绩、选课时间
CREATE TABLE enrollment (
  student_id BIGINT UNSIGNED NOT NULL,
  course_id  BIGINT UNSIGNED NOT NULL,
  score      DECIMAL(5,2) DEFAULT NULL,      -- 关联属性：成绩
  enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, -- 关联属性：选课时间
  status     TINYINT UNSIGNED NOT NULL DEFAULT 1,  -- 1=在读 2=结业 3=退课
  PRIMARY KEY (student_id, course_id),
  INDEX idx_course_id (course_id)
);

-- 订单-商品：带数量、单价
CREATE TABLE order_item (
  order_id   BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity   INT UNSIGNED NOT NULL DEFAULT 1,
  price      DECIMAL(10,2) NOT NULL,         -- 下单时的价格（快照）
  PRIMARY KEY (order_id, product_id),
  INDEX idx_product_id (product_id)
);
```

#### 自引用多对多（好友关系）

```sql
CREATE TABLE friendship (
  user_id   BIGINT UNSIGNED NOT NULL,
  friend_id BIGINT UNSIGNED NOT NULL,
  status    TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- 0=待确认 1=已确认 2=拉黑
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, friend_id),
  INDEX idx_friend_id (friend_id)
);

-- 查询某个用户的所有好友
SELECT * FROM friendship WHERE user_id = 1 AND status = 1;
SELECT * FROM friendship WHERE friend_id = 1 AND status = 1;
-- UNION 或业务层合并
```

> ⚠️ 好友关系查询需要查两个方向（我的好友 vs 我是对方的好友），业务层合并结果或用 `UNION`。

#### 中间表命名规范

| 关系 | 命名 | 示例 |
|------|------|------|
| 用户 ↔ 角色 | `user_role` | 字母序：user 在 role 前 |
| 学生 ↔ 课程 | `student_course` | 字母序 |
| 订单 ↔ 商品 | `order_item` | 有属性时用 item |
| 文章 ↔ 标签 | `article_tag` | 字母序 |
| 好友 | `friendship` | 有业务含义的独立命名 |

### 关系设计决策树

```
A 和 B 需要关联？
├── A 的一条记录对应 B 的一条记录
│   └── 1:1 → 合并到同一张表，或从表主键 = 外键
├── A 的一条记录对应 B 的多条记录
│   └── 1:N → 在 B 表中加 A_id 外键
└── A 的多条记录对应 B 的多条记录
    └── N:N → 中间表（复合主键 + 双向索引）
```

## DML — 查询与操作

### SELECT 基础

```sql
-- JOIN
SELECT u.name, o.amount
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE o.status = 1;

-- 子查询
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders WHERE amount > 100);

-- 分页（深翻页优化：游标分页优于 LIMIT OFFSET）
-- ❌ O(n) 扫描
SELECT * FROM orders ORDER BY id LIMIT 100000, 20;
-- ✅ 游标分页，走索引
SELECT * FROM orders WHERE id > 100000 ORDER BY id LIMIT 20;
```

### INSERT / UPDATE / DELETE

```sql
-- 批量插入
INSERT INTO users (email, nickname) VALUES ('a@x.com', 'A'), ('b@x.com', 'B');

-- 重复键处理
INSERT INTO users (id, email) VALUES (1, 'a@x.com')
  ON DUPLICATE KEY UPDATE email = VALUES(email);

-- 替换（先删后插，小心自增 ID）
REPLACE INTO users (id, email) VALUES (1, 'a@x.com');

-- 多表 UPDATE
UPDATE users u JOIN orders o ON u.id = o.user_id
SET u.status = 2 WHERE o.created_at < '2023-01-01';

-- 软删除（推荐，不用物理 DELETE）
ALTER TABLE users ADD deleted_at DATETIME DEFAULT NULL;
UPDATE users SET deleted_at = NOW() WHERE id = 1;
```

---

## 性能优化

### EXPLAIN 解读

```sql
EXPLAIN SELECT * FROM users WHERE email = 'a@x.com';
```

| 列 | 含义 | 好 | 差 |
|----|------|----|----|
| `type` | 访问类型 | `const` / `ref` / `range` | `ALL`（全表扫） |
| `key` | 使用的索引 | 有值 | `NULL` |
| `rows` | 扫描行数 | 小 | 大 |
| `Extra` | 额外信息 | `Using index` | `Using filesort` / `Using temporary` |

**优化目标：**
- `type` 至少到 `range`，最好 `ref` 或 `const`
- `rows` 尽量小
- 避免 `Using filesort`（加排序索引）
- 避免 `Using temporary`（优化 GROUP BY / DISTINCT）

### JOIN 与 N+1 查询优化

#### JOIN 性能关键

```sql
-- ❌ 全表扫描 JOIN（没有索引，驱动表全表扫 + 被驱动表全表扫）
SELECT * FROM users u
LEFT JOIN orders o ON u.id = o.user_id   -- o.user_id 无索引
WHERE u.status = 1;
-- type: ALL / ALL, rows: 全表 + 全表

-- ✅ 被驱动表连接列建索引（Nested Loop Join 效率提升百倍）
CREATE INDEX idx_user_id ON orders(user_id);
-- type: ALL / ref, rows: 全表 + 少量

-- ✅ 驱动表用小表（MySQL 自动选，但建索引最关键）
-- 驱动表 → 全表扫一次
-- 被驱动表 → 每次通过索引查找，O(log n)
```

**MySQL JOIN 执行过程（Nested Loop Join）：**

```
for each row in 驱动表:              -- 扫描驱动表 N 行
    for each row in 被驱动表:          -- 通过索引查找被驱动表
        if 匹配 → 返回
```

**优化目标：**
- **被驱动表的连接列必须建索引**（`o.user_id`、`o.product_id`）
- 驱动表用小表（MySQL 优化器自动选，必要时用 `STRAIGHT_JOIN` 强制）
- 只 SELECT 需要的列，不要 `SELECT *`
- 大表 JOIN 用分页 + 子查询先缩小范围

```sql
-- ✅ JOIN 前先缩小数据范围
SELECT * FROM (
  SELECT * FROM users WHERE status = 1 LIMIT 100
) u
LEFT JOIN orders o ON u.id = o.user_id;

-- ✅ 只取需要的字段，减少回表
SELECT u.id, u.name, o.order_no, o.amount
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.status = 1;
```

#### N+1 查询问题

N+1 不是 SQL 层面问题，而是 **ORM（MyBatis / JPA / Hibernate）代码层面**的问题：

```
查询 1:  SELECT * FROM users WHERE status = 1               -- 1 条
查询 2:  SELECT * FROM orders WHERE user_id = 1              -- N 条
查询 3:  SELECT * FROM orders WHERE user_id = 2
...
查询 N+1: SELECT * FROM orders WHERE user_id = N
```

N = 100 用户 → 101 条 SQL，网络往返和数据库解析开销巨大。

##### MyBatis 中的 N+1（`<association>` / `<collection>` 懒加载）

```xml
<!-- ❌ N+1：查询用户时，每个用户单独加载 orders -->
<resultMap id="UserWithOrdersLazy" type="User">
  <id column="id" property="id" />
  <result column="name" property="name" />
  <collection property="orders" column="id"
              select="com.example.mapper.OrderMapper.getByUserId"
              fetchType="lazy" />       <!-- 懒加载 → N+1 -->
</resultMap>

<select id="getUsers" resultMap="UserWithOrdersLazy">
  SELECT * FROM users WHERE status = 1     -- 1 条
</select>
<!-- 遍历 100 个用户时 → 额外 100 条 SELECT orders -->

-- ✅ 解决：JOIN 一次查完
<resultMap id="UserWithOrdersJoin" type="User">
  <id column="id" property="id" />
  <result column="name" property="name" />
  <collection property="orders" ofType="Order">
    <id column="order_id" property="id" />
    <result column="order_no" property="orderNo" />
  </collection>
</resultMap>

<select id="getUsersWithOrders" resultMap="UserWithOrdersJoin">
  SELECT u.*, o.id AS order_id, o.order_no
  FROM users u
  LEFT JOIN orders o ON u.id = o.user_id
  WHERE u.status = 1                              -- 1 条 SQL 搞定
</select>
```

##### MyBatis 批量查询替代 N+1

```xml
<!-- ✅ 先查用户列表，再批量查订单，最后内存中组装 -->
<select id="getUsers" resultType="User">
  SELECT * FROM users WHERE status = 1      -- 1 条
</select>

<select id="getOrdersByUserIds" resultType="Order">
  SELECT * FROM orders WHERE user_id IN
  <foreach collection="userIds" item="id" open="(" separator="," close=")">
    #{id}
  </foreach>                                 -- 1 条
</select>
```

```java
// Java 内存组装
List<User> users = userMapper.getUsers();
List<Long> userIds = users.stream().map(User::getId).toList();
List<Order> orders = orderMapper.getOrdersByUserIds(userIds);
Map<Long, List<Order>> orderMap = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId));

users.forEach(u -> u.setOrders(orderMap.getOrDefault(u.getId(), List.of())));
```

**2 条 SQL（原方案）= N+1 条 SQL（现方案）。**

##### JPA / Hibernate 的 N+1

```java
// ❌ N+1：每个 Category 单独查 Products
List<Category> categories = categoryRepository.findAll();
for (Category c : categories) {
    System.out.println(c.getProducts().size()); // 触发 N 次查询
}

// ✅ @EntityGraph 优化
@Query("SELECT c FROM Category c LEFT JOIN FETCH c.products")
List<Category> findAllWithProducts();
```

#### N+1 检测方法

```sql
-- 开启慢查询日志，观察是否有大量结构相同的 SQL
-- N+1 的特征：N 条 SQL 只有参数不同，结构完全一样
SELECT * FROM orders WHERE user_id = 1
SELECT * FROM orders WHERE user_id = 2
SELECT * FROM orders WHERE user_id = 3
...

-- 或者开启 general_log
SET GLOBAL general_log = ON;
SET GLOBAL log_output = 'TABLE';
SELECT * FROM mysql.general_log ORDER BY event_time DESC LIMIT 50;
```

#### 各场景方案

| 场景 | ❌ 错误做法 | ✅ 正确做法 |
|------|-----------|-----------|
| 主表 + 从属表（用户+订单） | `<collection>` 懒加载 | JOIN 一次查或批量 IN 查询 |
| 主表 + 单条关联（用户+头像） | N 次 `findById` | JOIN 或 `IN (...)` |
| 分页列表 + 关联数据 | 循环查关联表 | 先查主表，再批量查关联 |
| 树形结构（分类+子分类） | 递归 N+1 | CTE 递归（MySQL 8.0+）或一次性查完内存组装 |

### 慢查询分析

```sql
-- 开启慢查询日志
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;  -- 超过 1 秒记录
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';

-- 用 pt-query-digest 分析
pt-query-digest /var/log/mysql/slow.log
```

### LIKE 与模糊查询

#### LIKE 的三种匹配及索引行为

```sql
-- ✅ 前缀匹配 — 走索引（B+Tree 按前缀范围扫描）
WHERE name LIKE 'keyword%';
-- EXPLAIN: type=range, key=idx_name（走索引范围扫描）

-- ❌ 后缀匹配 — 不能走索引，全表扫
WHERE name LIKE '%keyword';
-- EXPLAIN: type=ALL（全表扫）

-- ❌ 中间匹配 — 不能走索引，全表扫
WHERE name LIKE '%keyword%';
-- EXPLAIN: type=ALL（全表扫）

-- ❌ 前后通配全表扫，扫描行数 = 全表行数
SELECT COUNT(*) FROM articles WHERE title LIKE '%keyword%';
```

**原理：** B+Tree 索引按字符顺序组织，`keyword%` 可以在索引树上做范围扫描（`key` ≤ x < `keyz`）。`%keyword` 不知道前缀是什么，只能全索引扫描或全表扫。

#### 覆盖索引缓解（不是解决）

```sql
-- 如果查询字段全部在索引里，即使 LIKE '%x%' 也只用扫索引不用回表
-- 索引 (title, id, status) 覆盖了 SELECT title, id, status
SELECT id, title, status FROM articles WHERE title LIKE '%keyword%';
-- Extra: Using where; Using index  （只扫索引，不碰数据行）
-- 比全表扫快，但索引扫描仍然要遍历整个索引
```

#### 全文索引 FULLTEXT（替代 LIKE %keyword%）

MySQL 5.6+ 支持全文索引，适合中等规模的文本搜索（不适合 ES 那种大规模）。

```sql
-- 创建全文索引
ALTER TABLE articles ADD FULLTEXT INDEX ft_title_content (title, content);

-- 自然语言模式（默认，按相关性排序）
SELECT id, title, MATCH(title, content) AGAINST('mysql keyword' IN NATURAL LANGUAGE MODE) AS score
FROM articles
WHERE MATCH(title, content) AGAINST('mysql keyword' IN NATURAL LANGUAGE MODE)
ORDER BY score DESC;

-- 布尔模式（支持 +-*/@ 操作符）
-- + 必须包含, - 不包含, * 通配符, "" 精确短语
SELECT id, title FROM articles
WHERE MATCH(title, content) AGAINST('+mysql -oracle' IN BOOLEAN MODE);

-- 精确短语
SELECT id, title FROM articles
WHERE MATCH(title, content) AGAINST('"database design"' IN BOOLEAN MODE);

-- 高亮关键词（MySQL 5.7+）
SELECT id, title,
  CONCAT(SUBSTRING(content, GREATEST(LOCATE('mysql', content) - 50, 0), 150)) AS snippet
FROM articles
WHERE MATCH(title, content) AGAINST('mysql' IN NATURAL LANGUAGE MODE);
```

**全文索引限制：**
| 限制 | 说明 |
|------|------|
| 最短词长度 | `innodb_ft_min_token_size` 默认 3（英文），中文无效 |
| 停用词 | 默认过滤常见词（the, and 等），可自定义 |
| 中文分词 | 原生不支持中文分词，需 ngram 插件 |
| 性能 | 适合百万级，千万级用 ES/Meilisearch |

#### 中文全文搜索（ngram 解析器）

```sql
-- 建表时指定 ngram 分词（MySQL 5.7.6+）
CREATE TABLE articles (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200),
  content TEXT,
  FULLTEXT INDEX ft_content (content) WITH PARSER ngram
) ENGINE=InnoDB;

-- 或修改已有全文索引
ALTER TABLE articles DROP INDEX ft_content;
ALTER TABLE articles ADD FULLTEXT INDEX ft_content (content) WITH PARSER ngram;

-- 设置分词粒度（默认 2，改完需重建索引）
SET GLOBAL ngram_token_size = 2;
```

> ⚠️ ngram 词粒度 = 2 时「数据库」被拆成「数据」「据库」，搜「数据」能命中。粒度越小结果越多但噪声越大。

#### 搜索引擎替代方案

```sql
-- MySQL LIKE 能解决的问题边界
-- ✅ 前缀匹配：商品 SKU 搜索 ('sku-001%')
-- ✅ 精确匹配：用户名搜索 (WHERE name = 'john')
-- ✅ 简单模糊查询：数据量 < 百万
-- ❌ 全文搜索：文章、评论、商品搜索（用 Elasticsearch）
-- ❌ 中文分词：标题、描述（用 ES + IK 分词器 / Meilisearch）
-- ❌ 拼写纠错、同义词扩展、语义搜索（用 ES）
-- ❌ 毫秒级实时搜索（用 ES / Meilisearch）
```

| 场景 | 方案 | 备注 |
|------|------|------|
| SKU/编号前缀匹配 | `LIKE 'prefix%'` + 索引 | ✅ 足够 |
| 用户名/邮箱精确搜索 | `WHERE name = ?` + 索引 | ✅ 足够 |
| 文章/商品简单搜索 | `FULLTEXT + ngram` | ⚠️ 百万级够用 |
| 电商全站搜索 | Elasticsearch + IK | ✅ 分词、排序、聚合 |
| 快速轻量搜索 | Meilisearch | ✅ 开箱即用、中文友好 |
| 日志搜索 | ClickHouse / Elasticsearch | ✅ 时间序列 + 全文 |

#### EXPLAIN 识别 LIKE 性能问题

```sql
-- 好：走索引范围扫描
EXPLAIN SELECT * FROM users WHERE name LIKE 'john%';
-- type: range, key: idx_name, rows: 几十

-- 差：全表扫
EXPLAIN SELECT * FROM users WHERE name LIKE '%john%';
-- type: ALL, key: NULL, rows: 整个表

-- 差：前缀匹配但排序列不在索引里
EXPLAIN SELECT * FROM users WHERE name LIKE 'john%' ORDER BY created_at;
-- Extra: Using index condition; Using filesort
```

---

## 事务 & 锁

### ACID

| 特性 | 说明 |
|------|------|
| Atomicity | 原子性 — 全成功或全回滚 |
| Consistency | 一致性 — 数据始终合法 |
| Isolation | 隔离性 — 事务互不干扰 |
| Durability | 持久性 — 提交后不丢 |

### 隔离级别

| 级别 | 脏读 | 不可重复读 | 幻读 | 性能 |
|------|------|-----------|------|------|
| READ UNCOMMITTED | ✅ 可能 | ✅ 可能 | ✅ 可能 | 最高 |
| READ COMMITTED | ❌ | ✅ 可能 | ✅ 可能 | ⬇ |
| REPEATABLE READ (默认) | ❌ | ❌ | ✅ 可能 | ⬇ |
| SERIALIZABLE | ❌ | ❌ | ❌ | 最低 |

```sql
-- 查看/设置隔离级别
SELECT @@transaction_isolation;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### 锁

```sql
-- 行锁（InnoDB，基于索引实现，没索引会升级为表锁）
-- 间隙锁 Gap Lock（RR 级别下防止幻读）

-- 排他锁（写锁）：SELECT ... FOR UPDATE
-- 共享锁（读锁）：SELECT ... LOCK IN SHARE MODE

BEGIN;
SELECT * FROM inventory WHERE product_id = 1 FOR UPDATE;  -- 加行锁
UPDATE inventory SET stock = stock - 1 WHERE product_id = 1;
COMMIT;  -- 释放锁
```

### 锁的兜底机制

InnoDB 的锁不是万能的，以下机制作为兜底防线：

#### 1. 无索引 → 行锁升级为表锁

```sql
-- ❌ 没索引的行锁：X 锁附加在聚簇索引上，但如果 WHERE 条件无索引
-- InnoDB 无法确定哪些行需要锁定 → 锁定全表（实际是每行都加锁）
SELECT * FROM users WHERE email = 'a@x.com' FOR UPDATE;
-- email 无索引 → 锁所有行（等价于表锁），并发性能骤降

-- ✅ 保证 WHERE 条件有索引，行锁才能生效
CREATE INDEX idx_email ON users(email);
```

**关键：** InnoDB 行锁是通过在**索引项**上加锁实现的。没有索引时，MySQL 会扫描全表，在每一行上加上锁，再根据 WHERE 条件释放不匹配的行。虽然最终只锁了目标行，但扫描过程中锁了大量行，同样表现如表锁。

#### 2. `innodb_lock_wait_timeout` — 锁等待超时

```sql
-- 一个事务等待锁超过此时间 → 自动放弃并返回错误
-- 默认 50 秒，可根据业务调整

-- 查看当前设置
SHOW VARIABLES LIKE 'innodb_lock_wait_timeout';

-- 会话级修改（推荐低频等待场景改小）
SET SESSION innodb_lock_wait_timeout = 5;  -- 5 秒超时

-- 全局修改
SET GLOBAL innodb_lock_wait_timeout = 10;

-- 超时后会返回
-- ERROR 1205 (HY000): Lock wait timeout exceeded; try restarting transaction
```

> 设为较短时间（如 3~5s）可以让锁问题快速失败，避免请求堆积。但不能过短，否则正常事务可能被误杀。

#### 3. 死锁检测与自动回滚

InnoDB 内部有死锁检测机制（waits-for graph），检测到死锁后自动回滚**代价较小的事务**（影响行数少的）。

```sql
-- 死锁发生时，被回滚的事务收到
-- ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction

-- 查看最近一次死锁详细信息
SHOW ENGINE INNODB STATUS\G;
-- 输出中包含 LATEST DETECTED DEADLOCK 章节
-- 显示：哪两个事务、各自持有的锁、等待的锁、被回滚的是谁
```

**应用层兜底：** 捕获 `1213` 错误，重试事务。

```python
import pymysql
import time

def execute_with_retry(sql, params, max_retries=3):
    for i in range(max_retries):
        try:
            cursor.execute(sql, params)
            connection.commit()
            return
        except pymysql.err.OperationalError as e:
            if e.args[0] == 1213:            # Deadlock
                if i < max_retries - 1:
                    time.sleep(0.1 * (i + 1))  # 递增等待
                    continue
                raise
            raise
```

#### 4. `NOWAIT` / `SKIP LOCKED` — 不等待直接跳过（MySQL 8.0+）

```sql
-- NOWAIT：拿不到锁立刻报错，不等待
SELECT * FROM inventory WHERE product_id = 1 FOR UPDATE NOWAIT;
-- 锁被占用时立刻返回
-- ERROR 3572 (HY000): Statement aborted because lock(s) could not be acquired immediately

-- SKIP LOCKED：跳过已经被锁的行，只返回未锁的行
SELECT * FROM inventory WHERE status = 'available' FOR UPDATE SKIP LOCKED;
-- 适合任务队列场景：多个 worker 抢任务，各自拿到不同行
```

**业务场景对比：**

| 语法 | 行为 | 适用场景 |
|------|------|---------|
| `FOR UPDATE` （默认） | 等待直到超时 | 常规行锁 |
| `FOR UPDATE NOWAIT` | 拿不到立刻报错 | 高并发秒杀、库存扣减 |
| `FOR UPDATE SKIP LOCKED` | 跳过已锁的行 | 任务队列、消息拉取 |

#### 5. 兜底监控与排查

```sql
-- 查看当前所有锁等待
SELECT * FROM performance_schema.data_lock_waits;

-- 查看阻塞链（哪个事务被哪个事务阻塞）
SELECT
  waiting.trx_id AS waiting_trx,
  blocking.trx_id AS blocking_trx,
  waiting.requested_lock_id,
  waiting.blocking_lock_id
FROM performance_schema.data_lock_waits;

-- 快速找到锁等待超时的源头
SELECT
  THREAD_ID,
  PROCESSLIST_ID,
  PROCESSLIST_USER,
  PROCESSLIST_HOST,
  PROCESSLIST_DB,
  PROCESSLIST_COMMAND,
  PROCESSLIST_TIME,
  PROCESSLIST_INFO
FROM performance_schema.threads
WHERE PROCESSLIST_COMMAND = 'Query'
ORDER BY PROCESSLIST_TIME DESC;

-- 监控锁等待情况（定期采集）
SELECT
  trx_id,
  trx_state,
  trx_started,
  trx_requested_lock_id,
  trx_wait_started,
  trx_mysql_thread_id,
  trx_query
FROM information_schema.INNODB_TRX
WHERE trx_state = 'LOCK WAIT';
```

### 死锁排查

```sql
-- 查看最近死锁
SHOW ENGINE INNODB STATUS;

-- 查看当前事务
SELECT * FROM information_schema.INNODB_TRX;
SELECT * FROM performance_schema.data_locks;
SELECT * FROM performance_schema.data_lock_waits;

-- 查看进程列表
SHOW FULL PROCESSLIST;

-- 杀死阻塞的事务
KILL <thread_id>;
```

**预防死锁：**
- 固定访问顺序（如总是先 A 再 B）
- 缩短事务时间，不要在事务内做外部 API 调用
- 合理设置 `innodb_lock_wait_timeout`（默认 50s）

---

## Window Functions & Sliding Window

窗口函数在每一行上定义一个 **帧（Frame）**，帧可以在 `ORDER BY` 排序后的窗口内滑动，这就是滑动窗口（Sliding Window）的底层实现。

### 基础语法

```sql
SELECT value,
  AVG(value) OVER (
    ORDER BY id
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS moving_avg
FROM measurements;
```

`OVER()` 的三部分：
1. `PARTITION BY col` — 按列分组（可选，不加就是全表一个窗口）
2. `ORDER BY col` — 窗口内排序（帧定义依赖排序）
3. `ROWS / RANGE / GROUPS BETWEEN ... AND ...` — 帧范围定义

### 帧范围（Frame Clause）

| 关键词 | 含义 |
|--------|------|
| `UNBOUNDED PRECEDING` | 分区第一行 |
| `N PRECEDING` | 往前 N 行 |
| `CURRENT ROW` | 当前行 |
| `N FOLLOWING` | 往后 N 行 |
| `UNBOUNDED FOLLOWING` | 分区最后一行 |

### 三种帧类型

| 类型 | 基于 | 说明 |
|------|------|------|
| `ROWS BETWEEN` | 物理行数 | 严格按行号偏移，不管值是否相同 |
| `RANGE BETWEEN` | 列值范围 | 相同 ORDER BY 值的行都包含在内 |
| `GROUPS BETWEEN` | 逻辑组 | 相同 ORDER BY 值的行算一组 |

```sql
-- ROWS: 严格 2 行
SELECT id, value,
  AVG(value) OVER (ORDER BY id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS row_avg
FROM t;

-- RANGE: 值偏差 ±10 以内的所有行
SELECT id, value,
  AVG(value) OVER (ORDER BY value RANGE BETWEEN 10 PRECEDING AND 10 FOLLOWING) AS range_avg
FROM t;

-- GROUPS: 相同值的行算一组（MySQL 8.0+）
SELECT id, dept, salary,
  AVG(salary) OVER (ORDER BY salary GROUPS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS group_avg
FROM employee;
```

### 常见滑动窗口应用

#### 移动平均

```sql
-- 7 日移动平均
SELECT date, revenue,
  AVG(revenue) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma_7
FROM daily_revenue;
```

#### 累计求和（Running Total）

```sql
-- 默认帧：RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
SELECT date, amount,
  SUM(amount) OVER (ORDER BY date) AS running_total
FROM transactions;
```

#### 同比环比

```sql
-- 与上一行比较（LAG）
SELECT date, revenue,
  LAG(revenue, 7) OVER (ORDER BY date) AS revenue_7d_ago,
  revenue - LAG(revenue, 7) OVER (ORDER BY date) AS diff
FROM daily_revenue;
```

#### 最大值/N 行范围

```sql
-- 当前行及前后各 1 行的最大值
SELECT id, value,
  MAX(value) OVER (ORDER BY id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS local_max
FROM series;
```

### 默认帧

不写 `BETWEEN` 时默认帧取决于是否有 `ORDER BY`：

```sql
-- 有 ORDER BY：默认 RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
SUM(value) OVER (ORDER BY id)
-- 等价于
SUM(value) OVER (ORDER BY id RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)

-- 无 ORDER BY：默认整分区（相当于 UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING）
SUM(value) OVER ()
```

> ⚠️ `RANGE BETWEEN` 默认帧有个坑：如果 ORDER BY 列有重复值，会一次包含所有相同值，可能导致结果和预期不符。想要严格按行走，用 `ROWS BETWEEN`。

### 底层实现

MySQL 引擎执行窗口函数的过程：

```
原始表 → 排序（Sort / Filesort）→ 窗口计算（逐行扫描，维护帧缓存）→ 输出
```

1. **排序阶段**：按 `PARTITION BY + ORDER BY` 排序，排序结果存入临时表
2. **扫描计算**：逐行扫描排序结果，根据帧定义维护一个**滑动窗口缓冲区**
   - `ROWS BETWEEN N PRECEDING AND M FOLLOWING` — 队列维护最近 N+M+1 行
   - 行进入帧 → 加入聚合计算
   - 行离开帧 → 从聚合中减去
3. **增量聚合**：聚合结果复用（`SUM` 减去离开的值，加上进入的值），不重新全量计算

**性能影响：**
- 排序是主要开销（`Using filesort` 或内存排序）
- 帧越大，缓存越大
- `ROWS` 比 `RANGE` 快（物理偏移判断比值范围判断快）
- 大表上窗口函数可能使用大量临时表空间（`tmp_table_size` / `innodb_temp_tablespaces`）

### Red Flags

- ❌ 默认 `RANGE BETWEEN` 在重复键下行为诡异 — 需要严格行数用 `ROWS`
- ❌ 窗口函数不写 `ORDER BY` 可能不报错但结果全分区聚合
- ❌ 大表 + 大帧 + 无合适索引 = 磁盘临时表 + 性能灾难
- ❌ MySQL 8.0 以下不支持窗口函数（5.7 及之前用变量模拟）

---

## MyBatis — 安全传参 & 动态 SQL

前端传入的变量**绝不能直接拼接 SQL 字符串**，必须用参数化查询。MyBatis 的 `#{}` 自动生成 PreparedStatement 占位符，`${}` 直接拼接（有注入风险）。

### `#{}` vs `${}`

```xml
<!-- ✅ #{} — 参数化查询，防 SQL 注入（PreparedStatement） -->
<select id="getUser" resultType="User">
  SELECT * FROM users WHERE id = #{id}        <!-- ? 占位符 -->
</select>

<!-- ❌ ${} — 直接拼接，SQL 注入风险 -->
<select id="getUserUnsafe" resultType="User">
  SELECT * FROM users WHERE id = ${id}        <!-- 直接拼到 SQL 里 -->
</select>
<!-- 如果 id = "1 OR 1=1" → SELECT * FROM users WHERE id = 1 OR 1=1 -->

<!-- ✅ ${} 唯一合法场景：动态表名/列名（值不能来自用户输入） -->
<select id="queryByTable" resultType="map">
  SELECT * FROM ${tableName} WHERE status = #{status}
</select>
<!-- tableName 必须是后端枚举或白名单校验后的值 -->
```

| | `#{}` | `${}` |
|--|-------|-------|
| 方式 | PreparedStatement `?` 占位符 | 字符串直接拼接 |
| 注入风险 | ❌ 无 | ✅ 有 |
| 类型 | 值传参 | SQL 片段 |
| 适用 | WHERE 值、INSERT 值、UPDATE 值 | 表名、列名、ORDER BY 列 |
| 性能 | 预编译、缓存执行计划 | 每次重新编译 |

### 动态 SQL — 替代字符串拼接

```xml
<!-- ✅ <if> + <where> 替代手动拼 "WHERE 1=1" -->
<select id="searchUsers" resultType="User">
  SELECT * FROM users
  <where>
    <if test="name != null and name != ''">
      AND name LIKE CONCAT('%', #{name}, '%')
    </if>
    <if test="status != null">
      AND status = #{status}
    </if>
    <if test="startDate != null">
      AND created_at >= #{startDate}
    </if>
  </where>
  ORDER BY id DESC
</select>
```

```xml
<!-- ❌ 手动拼 SQL — 易出错的写法 -->
"SELECT * FROM users WHERE 1=1" +
" AND name LIKE '%" + name + "%'" +    -- SQL 注入
" AND status = " + status              -- SQL 注入
```

### 集合参数（IN 查询）

```xml
<!-- ✅ <foreach> 自动展开参数列表 -->
<select id="getUsersByIds" resultType="User">
  SELECT * FROM users WHERE id IN
  <foreach collection="ids" item="id" open="(" separator="," close=")">
    #{id}
  </foreach>
</select>
<!-- ids = [1,2,3] → SELECT * FROM users WHERE id IN (?,?,?) -->
```

### 批量操作

```xml
<!-- ✅ 批量 INSERT（一条语句） -->
<insert id="batchInsert">
  INSERT INTO users (email, nickname) VALUES
  <foreach collection="list" item="u" separator=",">
    (#{u.email}, #{u.nickname})
  </foreach>
</insert>

<!-- ✅ 批量 UPDATE（配合 case when） -->
<update id="batchUpdateStatus">
  UPDATE users SET status = CASE id
    <foreach collection="list" item="u">
      WHEN #{u.id} THEN #{u.status}
    </foreach>
  END
  WHERE id IN
  <foreach collection="list" item="u" open="(" separator="," close=")">
    #{u.id}
  </foreach>
</update>
```

### 排序与分页

```xml
<!-- ✅ ORDER BY 用 ${}，但值必须白名单校验 -->
<select id="getUsers" resultType="User">
  SELECT * FROM users
  <where>
    <if test="status != null">AND status = #{status}</if>
  </where>
  ORDER BY ${orderBy} ${direction}
  LIMIT #{offset}, #{limit}
</select>
```

```java
// 后端白名单校验，防止注入
public String validateSortField(String input) {
    List<String> allowed = Arrays.asList("id", "created_at", "name", "status");
    if (!allowed.contains(input)) {
        return "id"; // 默认排序
    }
    return input;
}
```

### 常见错误

```xml
<!-- ❌ 模糊查询用 ${} 拼接 -->
AND name LIKE '%${name}%'

<!-- ✅ 模糊查询用 CONCAT + #{} -->
AND name LIKE CONCAT('%', #{name}, '%')
```

```xml
<!-- ❌ IN 语句用 ${} 拼接 -->
AND id IN (${ids})

<!-- ✅ IN 语句用 <foreach> + #{} -->
AND id IN <foreach collection="ids" item="id" open="(" separator="," close=")">#{id}</foreach>
```

### Red Flags

- ❌ `${}` 直接接收前端参数 — 必须白名单校验或禁止
- ❌ 手动拼 `WHERE 1=1` — 用 `<where>` 标签自动处理 AND/OR
- ❌ `LIKE '%${x}%'` — 用 `CONCAT('%', #{x}, '%')`
- ❌ `IN (${ids})` — 用 `<foreach>` 展开
- ❌ 前端传字段名直接用 `${}` — 后端必须白名单

### 树结构

```sql
-- 方案一：邻接表（Adjacency List）
CREATE TABLE category (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  parent_id   BIGINT UNSIGNED DEFAULT NULL,
  FOREIGN KEY (parent_id) REFERENCES category(id)
);
-- ✅ 查询子树需要递归 CTE（MySQL 8.0+）
WITH RECURSIVE cte AS (
  SELECT * FROM category WHERE id = 1
  UNION ALL
  SELECT c.* FROM category c JOIN cte ON c.parent_id = cte.id
)
SELECT * FROM cte;
-- ❌ 查询效率随层级增降

-- 方案二：闭包表（Closure Table）
CREATE TABLE category_closure (
  ancestor   BIGINT UNSIGNED NOT NULL,
  descendant BIGINT UNSIGNED NOT NULL,
  depth      TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (ancestor, descendant)
);
-- ✅ 查询子树、祖先、路径都很快，一次 JOIN 即可
-- ❌ 插入/删除需要维护闭包表
```

### 标签系统

```sql
-- 方案一：多对多关系（推荐）
CREATE TABLE tags (
  id   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE
);
CREATE TABLE article_tags (
  article_id BIGINT UNSIGNED NOT NULL,
  tag_id     BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (article_id, tag_id)
);

-- 方案二：JSON 字段（轻量，不跨表查询）
ALTER TABLE articles ADD tags JSON DEFAULT NULL;
-- SELECT * FROM articles WHERE JSON_CONTAINS(tags, '"mysql"');
```

### 审计日志

```sql
-- 方案一：created_at + updated_at + deleted_at（软删除）
ALTER TABLE users ADD COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE users ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
ALTER TABLE users ADD COLUMN deleted_at DATETIME DEFAULT NULL;

-- 方案二：独立审计表
CREATE TABLE user_audit (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT UNSIGNED NOT NULL,
  action     VARCHAR(50)  NOT NULL,  -- 'CREATE', 'UPDATE', 'DELETE'
  old_value  JSON DEFAULT NULL,
  new_value  JSON DEFAULT NULL,
  operator   VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at)
);

-- 方案三：触发器自动记录
CREATE TRIGGER trg_user_audit AFTER UPDATE ON users
FOR EACH ROW
BEGIN
  INSERT INTO user_audit (user_id, action, old_value, new_value, operator)
  VALUES (OLD.id, 'UPDATE',
    JSON_OBJECT('email', OLD.email, 'nickname', OLD.nickname),
    JSON_OBJECT('email', NEW.email, 'nickname', NEW.nickname),
    CURRENT_USER());
END;
```

### 分页

### 方案一：LIMIT OFFSET（传统分页）

```sql
-- 第 N 页
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 0;      -- 第 1 页 (id 1000~981)
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 20;     -- 第 2 页 (id 980~961)
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 980;    -- ❌ 第 50 页
```

**为什么 OFFSET 大时慢？**
```
客户端想看第 50 页 → MySQL 仍然扫描前面的 980 行 → 丢掉前 980 行 → 返回最后 20 行
扫描行数 = OFFSET + LIMIT，翻得越深越慢
```
适合：数据量小（< 10 万行）或只翻前几页

### 方案二：游标分页 / Keyset Pagination（推荐）

利用索引直接跳到目标位置，不扫描跳过的行。

#### 单字段排序（最常见）

```sql
-- 下一页 (id 降序，取比当前最小 id 更小的 20 行)
SELECT * FROM articles
WHERE id < 980                        -- 上一页的最小 id
ORDER BY id DESC
LIMIT 20;

-- 上一页 (id 升序，取比当前最大 id 更大的 20 行，再倒序)
SELECT * FROM articles
WHERE id > 1000                       -- 当前页的最大 id
ORDER BY id ASC
LIMIT 20;
-- 应用层将结果逆序，即上一页
```

**走索引：** `WHERE id < ? ORDER BY id DESC LIMIT 20` → 直接在 `PRIMARY KEY` 上定位 `id=980`，往前取 20 行，1 次索引扫描。

#### 多字段排序

```sql
-- 按 created_at DESC, id DESC 排序的下一页
SELECT * FROM articles
WHERE (created_at, id) < ('2024-01-15 10:00:00', 980)   -- 取上一页最后一条的位置
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

需要联合索引（`(created_at, id)`），支持元组比较（MySQL 8.0+）。

#### 混合排序方向

```sql
-- 按热度降序、id 升序（hot DESC, id ASC）
SELECT * FROM articles
WHERE hot < 1000
   OR (hot = 1000 AND id > 5000)
ORDER BY hot DESC, id ASC
LIMIT 20;
```

索引需为 `(hot, id)`。多方向排序时游标条件要拆成 OR。

### 方案三：子查询加速（延迟关联）

适用于大表 + 宽行（很多列），先只查主键再 JOIN 回原表：

```sql
-- ❌ OFFSET 大时，MySQL 需要把宽行全部扫一遍再丢
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 10000;

-- ✅ 延迟关联：子查询只走 PK 索引，再 JOIN 回原表
SELECT a.* FROM articles a
INNER JOIN (
  SELECT id FROM articles
  ORDER BY id DESC
  LIMIT 20 OFFSET 10000
) tmp ON a.id = tmp.id
ORDER BY a.id DESC;
```

**原理：** 子查询 `SELECT id` 只需要扫索引（不碰数据行），索引比全表小很多，内存能装下。确定 20 个 id 后再回表取完整行，只读 20 行。

### 方案四：分段分页（适合后台翻页报表）

```sql
-- 先估算范围，避免 OFFSET 太大
SELECT @min_id := MIN(id), @max_id := MAX(id), @total := COUNT(*) FROM articles;

-- 按 id 范围切段，每段内 LIMIT OFFSET（OFFSET 可控）
SELECT * FROM articles
WHERE id BETWEEN 50000 AND 100000
ORDER BY id
LIMIT 20 OFFSET 0;
```

### 各方案对比

| 方案 | 深翻页 | 跳页 | 实时排序 | 适用场景 |
|------|--------|------|---------|---------|
| LIMIT OFFSET | ❌ 越深越慢 | ✅ 任意页 | ✅ | 小表 / 前几页 |
| 游标分页 | ✅ 稳定 O(1) | ❌ 只能上下翻 | ✅ | 大表 / 无限滚动 |
| 延迟关联 | ⚠️ 仍有 OFFSET，但快很多 | ✅ 任意页 | ✅ | OFFSET 大 + 宽行 |
| 分段分页 | ✅ | ⚠️ 一段内 OFFSET | ❌ 固定段 | 后台导出 / 报表 |

**推荐：**
- **前台列表/无限滚动** → 游标分页（方案二）
- **后台管理/可跳页** → 延迟关联（方案三）或 LIMIT OFFSET（小数据量）
- **数据导出** → 分段分页（方案四）

---

## Red Flags

- ❌ `SELECT *` — 应明确列出字段，避免回表和网络浪费
- ❌ 在 WHERE 条件列上使用函数 — 导致索引失效
- ❌ 大表 OFFSET 分页 — 翻越深越慢，用游标分页或延迟关联替代
- ❌ 游标分页用于「跳转到第 N 页」— 游标分页只支持上下翻，不能自由跳页
- ❌ 排序列不加索引 — 游标分页依赖索引定位，无索引退化为全表扫
- ❌ 多字段排序只用单字段游标 — 多字段排序必须用 `(col1, col2)` 元组比较，联合索引要匹配
- ❌ FLOAT/DOUBLE 存金额 — 用 DECIMAL
- ❌ 字符串列和数字列隐式比较 — 类型不匹配不走索引
- ❌ 事务内做 HTTP 请求 — 长事务导致锁竞争
- ❌ 不加 WHERE 的 UPDATE/DELETE — 先 SELECT 确认范围
- ❌ 过度索引 — 写性能下降，每个索引增加写入开销
