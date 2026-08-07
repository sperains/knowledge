# fastapi-skeleton 架构决策记录

本目录记录 `fastapi-skeleton` 项目（FastAPI + Pydantic v2 分层 REST API 骨架）的长期架构决策。ADR 说明「为什么这样组织」，具体实现以项目代码为准。项目代码位于 Workspace，不在本知识库内。

## 决策索引

| 编号 | 决策 | 状态 |
| --- | --- | --- |
| [[ADR-013-FastAPI分层架构与异步事务边界]] | api → services → repositories 单向分层，事务边界归 service | Accepted |
| [[ADR-014-Python包采用命名空间包清理死代码导出]] | 删除死代码 `__init__.py`，层包退化为命名空间包 | Accepted |
| [[ADR-015-质量门禁必须包含类型检查]] | `make check` = ruff + pyright + pytest | Accepted |

## 记录范围

本批 ADR 根据 2026-08-07 的项目搭建、类型检查接入与包结构清理过程整理。它们描述已经落地并验证的架构约束。

## 项目范围

- 本目录只维护 fastapi-skeleton 项目的架构决策索引和具体 ADR。
- 通用 ADR 编写规范统一维护在根目录的 [[../../../ADR_RULES|ADR 记录规则]]。
- 新建 ADR 时使用全局 [[../../../Templates/ADR模板|ADR 模板]]，并在本目录的决策索引中补充记录。
