# fastapi-skeleton

FastAPI + Pydantic v2 分层架构 REST API 项目骨架。项目代码位于 Workspace 的 `fastapi-skeleton/` 目录，本目录只沉淀架构决策与经验。

## 技术栈

- FastAPI + Pydantic v2（`from_attributes` 模式序列化 ORM）
- SQLAlchemy 2.0 async（默认 SQLite，生产切 PostgreSQL + asyncpg）
- pydantic-settings 配置、uv 包管理、Ruff + pyright + pytest 质量门禁

## 架构导航

- 分层：api/v1 → dependencies → services（业务 + 事务）→ repositories（纯 SQL）→ models（ORM），schemas 为请求 / 响应校验层
- 包结构：除 `app/api/v1/__init__.py`（router 聚合）外全部为命名空间包，导入走全路径显式风格
- 质量门禁：`make check`（ruff + pyright + pytest）全绿才算完成

## 架构决策

- [[ADR/ADR-013-FastAPI分层架构与异步事务边界|ADR-013 分层架构与异步事务边界]]
- [[ADR/ADR-014-Python包采用命名空间包清理死代码导出|ADR-014 命名空间包与死代码清理]]
- [[ADR/ADR-015-质量门禁必须包含类型检查|ADR-015 质量门禁包含类型检查]]

本项目 ADR 在项目内独立编号；引用时使用上述项目路径，不与其他项目的同编号 ADR 混用。

## 待定事项

- dependencies 扩展方式：当前每个业务域一个显式 `get_xxx_service`；当 service 间互相依赖增多时，考虑按域拆分 `dependencies/` 目录（方案 B），尚未实施。
