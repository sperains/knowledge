# 项目知识地图

## 项目列表

- [[ICCE/MOC|ICCE 项目知识地图]]：画布、详情页、协作、视口、性能和架构决策资料。
- [[LowCode/MOC|LowCode 项目知识地图]]：简易低代码项目的技术选型、架构和目录设计资料。
- [[fastapi-skeleton/MOC|FastAPI 骨架项目知识地图]]：FastAPI 骨架项目的分层架构、质量门禁和 ADR 资料。
- [[DistShip/MOC|DistShip 项目知识地图]]：静态前端项目本地构建与 SSH 增量部署工具的设计和开源计划。

## 项目目录规则

- 每个具体项目使用 `Projects/项目名/` 独立收纳。
- 项目入口文档统一使用 `MOC.md`，负责维护项目内的知识导航。
- 项目专属 ADR 放在项目目录下的 `ADR/` 中，各项目独立编号；引用时使用完整项目路径，避免不同项目的编号产生歧义。
- 项目主题文档统一记录类型、状态、创建日期、更新日期、负责人和关联文档；涉及代码实现时补充源码仓库与版本基线。
- 项目 MOC 只维护简介、状态摘要和导航表，不重复保存技术参数、实现清单和阶段计划。
- 跨项目的工作记录、AI 提示词和知识库全局规则保留在根目录；日报和月报统一归入 `Worklog/`。
- 新增项目时，先创建项目目录和 MOC，再添加具体设计文档。

完成项目文档调整后运行 `ruby AI/examples/check_knowledge_base.rb`，检查元信息、ADR 结构、导航覆盖和失效链接。

## 当前项目

当前已整理项目：

- ICCE：项目资料入口见 [[ICCE/MOC|ICCE 项目知识地图]]。
- LowCode：项目资料入口见 [[LowCode/MOC|LowCode 项目知识地图]]。
- fastapi-skeleton：项目资料入口见 [[fastapi-skeleton/MOC|FastAPI 骨架项目知识地图]]。
- DistShip：项目资料入口见 [[DistShip/MOC|DistShip 项目知识地图]]。
