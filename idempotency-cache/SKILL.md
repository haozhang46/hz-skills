---
name: idempotency-cache
description: 幂等设计与 Redis/MySQL 双缓存方案 — 幂等 Token/去重表/状态机，缓存穿透/击穿/雪崩，双写一致性
---

# 幂等与 Redis/MySQL 双缓存

## 幂等设计

### 什么是幂等

同一个操作执行多次和执行一次结果相同。用户重复提交、消息队列重复消费、重试机制都需要幂等。

### 常见幂等方案

| 方案 | 原理 | 适用场景 |
|------|------|---------|
| Token 预生成 | 请求前先拿 token，提交时校验并删除 | 表单提交、支付下单 |
| 去重表 | 唯一索引防重复插入 | 消息消费、入账 |
| 状态机 | 状态流转有向，已终态不可回退 | 订单状态、审批流 |
| 全局唯一 ID | 唯一键冲突即重复 | 通用场景 |

#### 方案一：Token 预生成

```sql
-- 流程：
-- 1. 客户端 GET /token → 生成 uuid 存入 Redis（key=token, value=userID, TTL=30min）
-- 2. 客户端 POST /submit + header: Idempotent-Token: xxx
-- 3. 服务端先 DEL key，DEL 成功 = 首次提交，DEL 失败（key 不存在）= 重复请求

-- Redis Lua 脚本保证原子性
-- del_if_exists.lua
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
else
  return 0
end
```

```python
# Python 伪代码
def submit_order(request):
    token = request.headers['Idempotent-Token']
    user_id = request.user.id

    # Lua 原子操作：校验 + 删除
    ok = redis.eval(DEL_IF_EXISTS_LUA, [f"idempotent:{token}"], [user_id])
    if not ok:
        return 409, "重复请求"         # HTTP 409 Conflict

    # 执行业务逻辑（保证业务操作本身也幂等）
    order = create_order(request.body)
    return 200, order
```

> 服务端**先删除 token，再执行业务**（而不是先执行业务再删）。如果业务失败，客户端需要重新获取 token 重试，避免 token 被占用后业务没做成。

#### 方案二：去重表（唯一索引）

```sql
-- 消息消费去重
CREATE TABLE message_dedup (
  message_id    VARCHAR(64) NOT NULL PRIMARY KEY,   -- 消息全局唯一 ID
  consumer      VARCHAR(64) NOT NULL,               -- 消费者标识
  status        TINYINT NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE INDEX uk_msg_consumer (message_id, consumer)
);

-- 消费时 INSERT，唯一键冲突 = 重复
INSERT INTO message_dedup (message_id, consumer, status)
VALUES ('msg_001', 'order_service', 0);
-- 如果已存在：Duplicate entry → 忽略（幂等）
```

```go
// Go 伪代码
func ConsumeMessage(msg Message) error {
    err := db.Exec(
        "INSERT INTO message_dedup (message_id, consumer) VALUES (?, ?) ON DUPLICATE KEY UPDATE status=status",
        msg.ID, "order_service",
    )
    if err != nil {
        return err  // 可能其他错误
    }
    if rowsAffected == 0 {
        return nil  // 已消费，幂等忽略
    }
    return ProcessOrder(msg) // 首次消费
}
```

#### 方案三：状态机

```sql
-- 订单状态只能正向流转，不允许回退
-- 待支付 → 已支付 → 已发货 → 已完成
--                        → 已取消（待支付状态下可取消）

CREATE TABLE orders (
  id         BIGINT PRIMARY KEY,
  status     VARCHAR(20) NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_status (status)
);

-- 通过 WHERE status=当前状态 保证状态机不后退
UPDATE orders
SET status = '已支付'
WHERE id = 1001 AND status = '待支付';   -- 只有当前是待支付才能更新成功

-- 如果已经支付过，WHERE status='待支付' 不匹配，影响行数 = 0
-- 应用层判断 AffectedRows == 0 说明状态已变 → 幂等
```

#### 方案四：全局唯一业务 ID

```sql
-- 利用业务自身的唯一约束
CREATE TABLE payments (
  payment_no   VARCHAR(64) PRIMARY KEY,   -- 业务单号，客户端生成
  order_id     BIGINT NOT NULL,
  amount       DECIMAL(10,2) NOT NULL,
  status       TINYINT NOT NULL DEFAULT 0,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 重复提交 payment_no 冲突 → 返回已有记录
INSERT INTO payments (payment_no, order_id, amount)
VALUES ('PAY_20240101_001', 1001, 99.00);
-- Duplicate entry → 已存在，幂等
```

### 各方案对比

| 方案 | 网络开销 | 实现复杂度 | 适用场景 |
|------|---------|-----------|---------|
| Token | 多一次获取 token 的网络调用 | 低 | 表单提交、支付 |
| 去重表 | 无额外调用 | 低 | MQ 消费、异步任务 |
| 状态机 | 无 | 中 | 订单、审批 |
| 唯一业务 ID | 无 | 低 | 支付单号、流水号 |

---

## Redis/MySQL 双缓存

### 常见缓存模式

#### Cache Aside（旁路缓存）

```python
def get_user(id):
    # 1. 先查 Redis
    user = redis.get(f"user:{id}")
    if user:
        return user

    # 2. Redis 没有 → 查 MySQL
    user = db.query("SELECT * FROM users WHERE id = ?", id)

    # 3. 写入 Redis（设置 TTL 防缓存雪崩）
    if user:
        redis.setex(f"user:{id}", 3600, user)

    return user

def update_user(id, data):
    # 1. 更新 MySQL
    db.execute("UPDATE users SET name = ? WHERE id = ?", data['name'], id)

    # 2. 删除 Redis 缓存（而不是更新）
    redis.delete(f"user:{id}")
```

**为什么是删除缓存而不是更新？**
- 更新缓存需要知道旧数据结构，复杂场景易出错
- 删除后下次查询再加载，保证读到最新数据
- 懒惰加载减少写缓存的频率

#### 双写一致性

Cache Aside 在并发下存在短暂不一致：

```
线程 A: 更新 MySQL → 删除缓存
线程 B:          → 缓存删除前读到旧数据 → 回写旧数据到缓存
```

**解决方案：**

| 方案 | 原理 | 缺点 |
|------|------|------|
| 延迟双删 | 更新 MySQL → 删缓存 → 延迟 500ms 再删一次 | 多一次删除，短暂不一致 |
| 消息队列 | 更新 MySQL → 发消息 → 消费者删缓存 | 引入 MQ 复杂度 |
| 监听 binlog | Canal 监听 binlog → 自动删除/更新缓存 | 运维复杂度高 |
| 最终一致性 | 接受短暂不一致（缓存 TTL 自动过期） | 适合对一致性不敏感的场景 |

```python
# 延迟双删
def update_user(id, data):
    redis.delete(f"user:{id}")          # 第一次删除
    db.execute("UPDATE users SET name = ? WHERE id = ?", data['name'], id)

    # 异步延迟删除（500ms 后）
    def delayed_delete():
        time.sleep(0.5)
        redis.delete(f"user:{id}")

    thread = Thread(target=delayed_delete)
    thread.start()
```

#### Read-Through（穿透读）

应用层不直接操作 Redis，由缓存层自动回源：

```python
# 使用 Redis 的 read-through 能力需要配合客户端库
# 或者自己在 Service 层封装

class UserCache:
    def __init__(self, redis_client, db_client):
        self.redis = redis_client
        self.db = db_client

    def get(self, user_id):
        # 封装了 cache aside 逻辑
        user = self.redis.get(f"user:{user_id}")
        if user:
            return user
        user = self.db.query("SELECT * FROM users WHERE id = ?", user_id)
        if user:
            self.redis.setex(f"user:{user_id}", 3600, user)
        return user
```

### 三大缓存问题

#### 缓存穿透

查询一个**不存在**的数据，每次都会穿透到 DB。

```python
# ❌ 穿透：查一个不存在的 id，每次都查 DB
def get_user(id):
    user = redis.get(f"user:{id}")
    if user:
        return user
    # 如果 id=999999 不存在，每次都走到这里
    user = db.query("SELECT * FROM users WHERE id = ?", id)
    if user:
        redis.setex(f"user:{id}", 3600, user)
    return user

# ✅ 解决方案 1：缓存空值（短 TTL）
def get_user(id):
    user = redis.get(f"user:{id}")
    if user is not None:  # None 表示 key 不存在，空值也返回
        return user if user != 'NULL' else None

    user = db.query("SELECT * FROM users WHERE id = ?", id)
    if user:
        redis.setex(f"user:{id}", 3600, user)
    else:
        redis.setex(f"user:{id}", 120, 'NULL')  # 缓存空值，TTL 短
    return user

# ✅ 解决方案 2：布隆过滤器（Bloom Filter）
# 请求前先判断 id 是否可能存在，不存在直接返回
if not bloom_filter.might_contain(id):
    return None
```

#### 缓存击穿

一个**热点 key** 在过期瞬间，大量请求同时打到 DB。

```python
# ✅ 互斥锁（只让一个请求回源，其他等待）
def get_hot_product(id):
    key = f"product:{id}"
    product = redis.get(key)
    if product:
        return product

    # 分布式锁，只让一个线程回源
    lock_key = f"lock:{key}"
    if redis.setnx(lock_key, 1, ex=10):
        try:
            product = db.query("SELECT * FROM products WHERE id = ?", id)
            redis.setex(key, 3600, product)
            return product
        finally:
            redis.delete(lock_key)
    else:
        # 其他请求等待锁释放后从缓存读取
        time.sleep(0.05)
        return get_hot_product(id)  # 递归重试

# ✅ 或者永不过期 + 异步刷新（逻辑过期）
# 缓存不设 TTL，后台定时刷新
redis.set("hot_product", product)  # 不设过期
# 另起定时任务每隔一段时间刷新缓存
```

#### 缓存雪崩

大量 key **同时过期**，或 Redis **宕机**，所有请求打到 DB。

```sql
-- ✅ 解决方案 1：过期时间加随机偏移
SETEX key 3600 + random(0, 300) value;

-- ✅ 解决方案 2：多级缓存（本地缓存 + Redis）
-- 本地缓存（Caffeine/Guava）→ Redis → MySQL

-- ✅ 解决方案 3：Redis 高可用
-- 主从 + Sentinel / Redis Cluster / 持久化 AOF+RDB

-- ✅ 解决方案 4：限流降级
-- DB 层做限流，超出阈值直接返回失败或降级数据
```

```python
# 多级缓存示例
import functools

@functools.lru_cache(maxsize=1000)  # 本地缓存（一级）
def get_user_with_local_cache(id):
    user = redis.get(f"user:{id}")  # Redis 缓存（二级）
    if user:
        return user
    user = db.query("SELECT * FROM users WHERE id = ?", id)  # DB（三级）
    if user:
        redis.setex(f"user:{id}", 3600, user)
    return user
```

### 三种缓存问题对比

| 问题 | 原因 | 表现 | 解决方案 |
|------|------|------|---------|
| 穿透 | 查不存在的数据 | DB 压力持续增加 | 空值缓存 / Bloom Filter |
| 击穿 | 热点 key 过期 | DB 单点压力暴增 | 互斥锁 / 永不过期 + 异步刷新 |
| 雪崩 | 大量 key 同时过期 / Redis 宕机 | DB 整体压力暴增 | TTL 随机 / **多级缓存** / 高可用 |

---

## 多级缓存架构（Caffeine + Redis）

高并发场景下的最优方案：**本地缓存（L1）→ 分布式缓存（L2）→ DB（L3）**，逐级回源。

```
                    ┌──────────────┐
    请求  ──→       │  Caffeine     │  (L1, 本地内存, 纳秒级)
                    │  (每台机器)   │
                    └──────┬───────┘
                           │ miss
                    ┌──────▼───────┐
                    │  Redis        │  (L2, 分布式, 毫秒级)
                    └──────┬───────┘
                           │ miss
                    ┌──────▼───────┐
                    │  MySQL        │  (L3, 持久化)
                    └──────────────┘
```

### 为什么 Caffeine + Redis 是最优组合

| 特性 | Caffeine (L1) | Redis (L2) | MySQL (L3) |
|------|-------------|-----------|-----------|
| 延迟 | 纳秒级（堆内） | 毫秒级（网络） | 毫秒~秒级（磁盘） |
| 容量 | 几百 MB（JVM 堆） | GB~TB | TB 级 |
| 共享 | 单机独有 | 全局共享 | 全局共享 |
| 一致性 | 最终一致 | 最终一致 | 强一致 |

**核心价值：** Redis 宕机时，Caffeine 仍然抗住大部分读请求，DB 不会被流量打死。解决缓存雪崩的终极方案。

### 读取流程

```java
// Java Spring Boot 示例 — Caffeine + Redis 多级缓存
@Service
public class UserService {

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    private final Cache<String, User> localCache = Caffeine.newBuilder()
        .maximumSize(10_000)                     // 最多 1 万条
        .expireAfterWrite(30, TimeUnit.SECONDS)   // L1 短 TTL（30s）
        .recordStats()                            // 开启命中率统计
        .build();

    public User getUser(Long id) {
        String key = "user:" + id;

        // 1️⃣ L1: Caffeine 本地缓存
        User user = localCache.getIfPresent(key);
        if (user != null) {
            return user;
        }

        // 2️⃣ L2: Redis 分布式缓存
        Object cached = redisTemplate.opsForValue().get(key);
        if (cached != null) {
            User redisUser = (User) cached;
            // 回填 L1（异步，避免阻塞）
            localCache.put(key, redisUser);
            return redisUser;
        }

        // 3️⃣ L3: MySQL 回源（加分布式锁防止击穿）
        String lockKey = "lock:" + key;
        RLock lock = redissonClient.getLock(lockKey);
        lock.lock(5, TimeUnit.SECONDS);
        try {
            // 双重检查（DCL）：拿到锁后再查一次缓存
            cached = redisTemplate.opsForValue().get(key);
            if (cached != null) {
                return (User) cached;
            }

            user = userMapper.selectById(id);
            if (user == null) {
                // 空值标记，防穿透（短 TTL）
                redisTemplate.opsForValue().set(key, null, 120, TimeUnit.SECONDS);
                return null;
            }

            // 回填 L2 + L1
            redisTemplate.opsForValue().set(key, user, 1, TimeUnit.HOURS);
            localCache.put(key, user);
            return user;
        } finally {
            lock.unlock();
        }
    }
}
```

### 写入流程

```java
public void updateUser(Long id, UserUpdateDTO dto) {
    String key = "user:" + id;

    // 1. 更新 MySQL
    userMapper.updateById(id, dto);

    // 2. 删除 L2 (Redis)
    redisTemplate.delete(key);

    // 3. 删除 L1 (Caffeine) — 注意：本地缓存不共享，需通知其他机器
    localCache.invalidate(key);

    // 4. 可选：MQ 广播给其他机器删除它们的 L1
    // rocketMQTemplate.send("cache-invalidate-topic", key);
}
```

### L1 缓存一致性问题

Caffeine 是**本地缓存**，每台机器各存一份。A 机器更新了数据，B 机器的 L1 还是旧的。

| 方案 | 一致性 | 复杂度 | 适用 |
|------|--------|--------|------|
| L1 TTL 设短（30s） | 最终一致（30s 内） | 无 | ✅ 推荐，大多数场景够用 |
| MQ 广播失效 | 准实时 | 中 | 一致性要求高的场景 |
| Redis Pub/Sub 通知 | 准实时 | 中 | 轻量广播 |
| 不设 L1，只用 L2 | 强一致 | 无 | 一致性 > 性能 |

**推荐：** Caffeine TTL 设 30~60s + 写入时 delete L1。这样最多有 30s 窗口读到旧数据，但对大多数业务可以接受。如果不行，加 MQ 广播。

### Caffeine 配置最佳实践

```java
Cache<String, User> cache = Caffeine.newBuilder()
    .maximumSize(10_000)                  // 最大条数（不是内存），防止 OOM
    .expireAfterWrite(30, TimeUnit.SECONDS) // 写入后 30s 过期
    // .expireAfterAccess(10, TimeUnit.SECONDS) // 10s 不访问就过期（适合低频数据）
    // .refreshAfterWrite(20, TimeUnit.SECONDS) // 20s 后异步刷新（不阻塞读）
    .recordStats()                         // 打开统计，监控命中率
    .removalListener((key, value, cause) -> {
        log.info("Cache evict: key={}, cause={}", key, cause);
    })
    .build();
```

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `maximumSize` | 5000~50000 | 按业务数据量设，不是越大越好 |
| `expireAfterWrite` | 30~60s | L1 TTL 够短，一致性窗口可控 |
| `refreshAfterWrite` | 20s | 配合 expire，20s 后异步刷新，读请求不阻塞 |
| `recordStats` | 开启 | 监控命中率，低于 80% 说明 TTL 太长或容量太小 |

### 多级缓存监控

```bash
# JMX 查看 Caffeine 命中率（Spring Boot Actuator）
GET /actuator/caches
# 返回每个 Cache 的 hitRate, missRate, loadTime, evictionCount

# Redis 命中率
redis-cli INFO stats
# keyspace_hits / (keyspace_hits + keyspace_misses) = 命中率

# 监控指标
# L1 命中率 > 80%  → 缓存有效
# L1 命中率 < 50%  → TTL 太短或容量太小，调整配置
# L2 命中率 > 90%  → 缓存有效
# L2 命中率 < 70%  → 考虑加 L1 或优化 key 设计
```

### 降级策略

```java
public User getUserWithDegrade(Long id) {
    try {
        return getUser(id);                   // 正常三级
    } catch (RedisException e) {
        // L2 降级：跳过 Redis，L1 → DB
        log.warn("Redis degrade, fallback to L1+DB");
        User user = localCache.getIfPresent(key);
        if (user != null) return user;
        return userMapper.selectById(id);
    } catch (Exception e) {
        // L1+L2 完全降级：只查 DB（限流保护）
        log.error("Cache degrade, fallback to DB with rate limit");
        if (rateLimiter.tryAcquire()) {
            return userMapper.selectById(id);
        }
        throw new ServiceException("服务繁忙");
    }
}
```

### 架构总结

```
正常:  Caffeine → Redis → MySQL
L2 降级: Caffeine → MySQL（Redis 挂了）
L1+L2 降级: MySQL（限流保护）
全链路降级: 返回兜底数据 / 错误提示
```

| 场景 | 表现 | 应对 |
|------|------|------|
| Redis 宕机 | L2 不可用，L1 仍然命中 | -> L1 抗大部分读，DB 压力可控 |
| Redis + L1 都 miss | 请求打到 DB | -> 限流 + 熔断保护 DB |
| 热点 key 百万 QPS | L1 在每台机器缓存热点，单机几百 QPS → 每台 L1 命中 | -> DB 零压力 |
| 数据更新 | L1 TTL 30s 内最终一致 | -> 广播 MQ 可缩短窗口 |

---

## Redis 高可用完整方案

> 🚧 **待补充** — 哨兵 Sentinel、Cluster 集群、生产落地细节
>
> 覆盖内容计划：
> - 哨兵模式（Sentinel）：架构、选主、脑裂、客户端配置
> - Cluster 集群：分片策略（16384 slots）、resharding、moved/ask 重定向
> - 生产落地：持久化策略（RDB/AOF 混搭）、内存淘汰（LRU/LFU）、大 key 治理
> - 监控：Redis INFO、slowlog、latency monitor、内存分析（redis-rdb-tools / RDR）

---

## 幂等 + 缓存最佳实践

```
用户提交表单
  │
  ├─ 1. 获取 Token（Redis SET token TTL 30min）
  │
  ├─ 2. 提交（携带 Token）
  │     │
  │     ├─ Token 校验（Redis DEL，原子操作）
  │     │   ├─ 失败 → 409 重复请求
  │     │   └─ 成功 ↓
  │     │
  │     ├─ 业务逻辑（状态机 WHERE status=当前 保证幂等）
  │     │   ├─ 更新 MySQL
  │     │   └─ 删除 Redis 缓存（延迟双删）
  │     │
  │     └─ 返回结果
```

---

## Red Flags

- ❌ 先执行业务再删 Token — 业务失败 token 被占用，客户端无法重试，必须先删 token 再执行业务
- ❌ 缓存更新不是删除 — 更新缓存容易写错，删除后懒惰加载最安全
- ❌ 缓存不设 TTL — 数据变更后缓存永远不一致，必须设 TTL 兜底
- ❌ 穿透不处理 — 恶意攻击用不存在 id 可以打垮 DB，空值缓存或 Bloom Filter 必须加
- ❌ 所有 key 同一过期时间 — 雪崩，加随机偏移
- ❌ 状态机允许回退 — WHERE 条件必须限制前置状态
