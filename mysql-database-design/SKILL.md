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

### 慢查询分析

```sql
-- 开启慢查询日志
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;  -- 超过 1 秒记录
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';

-- 用 pt-query-digest 分析
pt-query-digest /var/log/mysql/slow.log
```

### 常见 SQL 优化

```sql
-- ❌ 函数导致索引失效
WHERE DATE(created_at) = '2024-01-01';
-- ✅ 改用范围查询
WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02';

-- ❌ 隐式类型转换
WHERE phone = 13800138000;      -- phone 是 VARCHAR
-- ✅ 同类型比较
WHERE phone = '13800138000';

-- ❌ 前置通配符不走索引
WHERE name LIKE '%keyword%';
-- ✅ 后缀通配符走索引
WHERE name LIKE 'keyword%';

-- ❌ OR 可能导致索引失效
WHERE status = 1 OR status = 2;
-- ✅ 用 IN / UNION
WHERE status IN (1, 2);
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

## 常用设计模式

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

```sql
-- 传统分页（OFFSET 大时慢）
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 0;    -- 第 1 页
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 20;   -- 第 2 页
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 1000; -- ❌ 已翻 50 页

-- 游标分页（推荐，稳定走索引）
SELECT * FROM articles WHERE id < 10000 ORDER BY id DESC LIMIT 20;   -- 下一页
SELECT * FROM articles WHERE id > 500 ORDER BY id ASC LIMIT 20;      -- 上一页

-- 带排序的游标分页
SELECT * FROM articles
WHERE (created_at, id) < ('2024-01-01', 10000)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

---

## Red Flags

- ❌ `SELECT *` — 应明确列出字段，避免回表和网络浪费
- ❌ 在 WHERE 条件列上使用函数 — 导致索引失效
- ❌ 大表 OFFSET 分页 — 用游标分页替代
- ❌ FLOAT/DOUBLE 存金额 — 用 DECIMAL
- ❌ 字符串列和数字列隐式比较 — 类型不匹配不走索引
- ❌ 事务内做 HTTP 请求 — 长事务导致锁竞争
- ❌ 不加 WHERE 的 UPDATE/DELETE — 先 SELECT 确认范围
- ❌ 过度索引 — 写性能下降，每个索引增加写入开销
