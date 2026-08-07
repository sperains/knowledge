# ADR-013 FastAPI 分层架构与异步事务边界

- 状态：Accepted
- 日期：2026-08-07
- 作者：WorkBuddy（Python 全栈工程师）
- 相关领域：后端 REST API 架构

---

## 背景（Context）

需要搭建一个可长期演进的后端 REST API 项目骨架，约束如下：

- 技术栈固定为 FastAPI + Pydantic v2 + SQLAlchemy 2.0 async。
- 必须类型安全、可单测、可部署（Docker）。
- 业务逻辑不能耦合 Web 框架，避免被路由层和 ORM 细节绑架。
- 事务语义必须清晰：多步写操作要么全成要么全败。

## 考虑方案（Options）

### 方案 A：严格分层（api → dependencies → services → repositories → models）

路由层只做参数绑定与响应声明；依赖注入层组装对象图；service 层承载业务规则与事务边界；repository 层只做 SQL 存取；ORM 模型层定义表结构。

优点：

- 单向依赖，替换数据库或加缓存中间件时路由零改动。
- 业务层纯 Python，可直接单测，不依赖 FastAPI。
- 每个请求一个 session + service 实例，生命周期清晰。

缺点：

- 样板代码较多，每个业务域要写 repository + service 两层。
- 层数多，小功能改动成本略高。

### 方案 B：瘦路由 + 业务写在路由处理器

优点：

- 代码量少，起步快。

缺点：

- 业务规则与 HTTP 层耦合，单测需要起 HTTP 上下文。
- 业务增长后路由文件膨胀，无法复用业务逻辑。

### 方案 C：业务写在 ORM 模型方法

优点：

- 模型自带行为，调用直观。

缺点：

- 模型层被迫依赖业务语义，与表结构职责混淆。
- 多实体协作逻辑无处安放。

## 决策（Decision）

最终选择：**方案 A：严格分层**。

> api/v1 → dependencies → services（业务 + 事务）→ repositories（纯 SQL）→ models（ORM）
> schemas（Pydantic v2）作为请求 / 响应校验层独立存在。

原因：

1. 业务层保持纯 Python，是唯一能同时满足「可单测、可复用、不绑框架」的形态。
2. 事务边界归 service 层，repository 只做 add/flush/delete、绝不 commit，多步写操作天然全成或全败。
3. 依赖注入层（dependencies）是对象图的唯一组装点，替换实现无需改动路由。

## 后果（Consequences）

### 正面影响

- 单测覆盖 service 层（纯业务）与 api 层（HTTP 语义）两层，已实现 15 个测试全绿。
- PATCH 语义借助 Pydantic v2 的 `model_fields_set` 判断显式传入字段，未传字段不覆盖。
- 业务异常 `BusinessError(code/message/status_code)` 由全局异常处理器统一转 JSON，错误格式全站一致。
- 默认 SQLite + aiosqlite 零外部依赖可跑，生产切 `postgresql+asyncpg` 只改 `DATABASE_URL`。

### 负面影响

- 每个业务域需维护 repository + service 两个文件，纯 CRUD 场景存在样板感。

### 后续约束

以后需要遵守：

- 路由层禁止写业务逻辑，只做参数绑定与响应声明，ORM → Schema 显式 `model_validate` 转换。
- repository 禁止 commit，事务提交与回滚只允许在 service 层。
- service 层禁止 import FastAPI 的 HTTPException，错误统一抛 `BusinessError`。
- 新增业务域按「models → schemas → repositories → services → api/v1」顺序补齐，并在 `api/v1/__init__.py` 注册路由。

## 相关文档

- [[ADR-014-Python包采用命名空间包清理死代码导出]]
- [[ADR-015-质量门禁必须包含类型检查]]

## AI 指导原则

实现相关功能时：

- 必须：保持 api → dependencies → services → repositories → models 单向依赖，禁止反向 import。
- 必须：事务边界写在 service 层，repository 不 commit。
- 必须：路由返回类型与函数标注一致，用 `UserRead.model_validate(orm)` 显式转换。
- 必须：service 抛 `BusinessError`，不抛 `HTTPException`。
- 优先：数据库默认 SQLite 开发、PostgreSQL 生产，切换只改配置。
- 禁止：在路由处理器中直接操作 ORM session 或写业务规则。
