# ADR-014 Python 包采用命名空间包并清理死代码导出

- 状态：Accepted
- 日期：2026-08-07
- 作者：fastapi-skeleton 项目组
- 整理工具：WorkBuddy
- 相关领域：Python 包结构 / 构建分发
- 所属项目：fastapi-skeleton

---

## 背景（Context）

骨架各层包（repositories / schemas / services / models / utils / api）的 `__init__.py` 中写了 re-export（如 `from app.repositories.user import UserRepository; __all__ = [...]`），但全项目没有任何代码走聚合导入路径，全部使用 `from app.xxx.module import Yyy` 全路径显式导入。这些 re-export 是死代码，还带来模块加载副作用（import 包即连带加载 models → database → 创建 engine）。

另一约束：项目采用 src layout，`pyproject.toml` 中 hatchling 配置为 `packages = ["src/app"]`，需确认删除 `__init__.py` 后构建与分发不受影响。

## 考虑方案（Options）

### 方案 A：删除所有死代码 `__init__.py`，层包退化为命名空间包

优点：

- 无死代码、无聚合导入副作用，导入路径唯一（全路径显式）。
- 命名空间包是 Python 3.3+ 原生机制，运行时无兼容问题。

缺点：

- 需要验证 hatchling 对命名空间包的打包发现行为，存在不确定性。

### 方案 B：保留空 `__init__.py`（仅 docstring）

优点：

- 包身份显式，与旧版工具链兼容性最稳。

缺点：

- 保留了一个无功能的文件，与「删干净」的诉求相悖。

### 方案 C：保留 re-export 聚合导出

优点：

- 多一条 `from app.repositories import UserRepository` 捷径。

缺点：

- 死代码 + 加载副作用，且捷径与全路径导入并存造成风格分裂。

## 决策（Decision）

最终选择：**方案 A：删除所有死代码 `__init__.py`，层包退化为命名空间包**。

> 三连实测验证通过：
> 1. `uv build` 构建成功，wheel 内 11 个模块文件全部进包（hatchling 对显式 `packages=["src/app"]` 的命名空间发现生效）；
> 2. wheel 安装到独立 venv，`app` 解析为命名空间模块，`import app.main / app.api.v1 / app.models.user / app.utils.errors` 全部成功；
> 3. `make check`（editable 模式）ruff / pyright / pytest 全绿。

原因：

1. 全项目唯一消费点是功能性的 `app/api/v1/__init__.py`（router 聚合），其余 re-export 均为死代码。
2. 实测证明 hatchling 默认支持命名空间包发现，打包风险不成立。
3. 全路径显式导入是更可检索、更可静态分析的风格。

## 后果（Consequences）

### 正面影响

- 终态只保留 1 个 `__init__.py`：`app/api/v1/__init__.py`（router 聚合，删除后应用无法装配路由）。
- 所有层包为命名空间包，导入统一走全路径显式风格。

### 负面影响

- 依赖「删除 `__init__.py` 后打包正常」这一 hatchling 行为，若未来更换构建后端（如 setuptools）需重新验证。

### 后续约束

以后需要遵守：

- 新建层包时不再写 re-export `__init__.py`；导入统一使用 `from app.<层>.<模块> import <类>`。
- 仅当 `__init__.py` 承载真实功能（如路由聚合、版本导出）时才保留。
- 删除任何 `__init__.py` 前必须完成 build + wheel 内容 + 独立安装 import 三连验证。

## 相关文档

- [[ADR-013-FastAPI分层架构与异步事务边界]]

## AI 指导原则

实现相关功能时：

- 必须：各层包采用命名空间包（无 `__init__.py`），导入走全路径显式风格。
- 必须：任何「这个文件必须保留」的论断，先实测（build + wheel 内容 + 独立安装 import）再下结论，禁止凭假设断言。
- 禁止：为聚合导出编写 `__init__.py` re-export，除非有真实消费方。
