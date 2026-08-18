---
title: ICCE 画布 Plan-Commit 变更架构
type: design
status: current
date: 2026-08-17
updated: 2026-08-17
project: ICCE
owner: ICCE 项目组
source_repo: jd_ipd
source_ref: src/views/icce/docs/ICCE画布Plan-Commit变更架构.md
related:
  - "[[ADR/ADR-002-应用命令作为画布变更唯一入口]]"
  - "[[ADR/ADR-017-命令结果仅承载状态与影响范围]]"
  - "[[ADR/ADR-018-提交态失效仅由业务内容变化触发]]"
  - "[[ICCE画布交互协作设计方案]]"
---

# ICCE 画布 Plan/Commit 变更架构

- 状态：已落地（2026-08-17 完成全部迁移，旧 `runTransaction` 机制已从生产代码移除）
- 适用范围：`src/views/icce` 内所有会改变并持久化画布模型的本地操作
- 核心决策：所有持久化模型变更统一经过 `Plan → Commit → ChangeSet → Publish`

## 1. 架构概览

ICCE 画布的持久化模型变更统一走显式的 Plan/Commit 架构：

```text
Intent
  ↓
Plan(snapshot, intent)
  ↓
ReadyPlan | Rejected
  ↓
Commit(plan)
  ↓
CommittedChangeSet | Stale | Failed
  ↓
Publish(meta, changeSet)
```

统一约束：

1. 领域推导在 Plan 阶段完成。
2. Commit 阶段只校验计划是否仍可应用，并执行确定性的模型写入。
3. Commit 显式返回一次操作产生的完整 `CanvasChangeSet`。
4. Publish 只消费已成功提交的变更集，并且一次顶层操作只发布一次。
5. 协作分组不再依赖全局同步调用栈或嵌套函数关系。

简单操作在一个应用命令内部完成轻量 Plan 和 Commit，不要求为形式统一而制造无业务价值的中间抽象；复杂操作必须拥有可组合、可校验的显式计划。

关键模块：

- [`contracts/canvas-change-set.ts`](../application/contracts/canvas-change-set.ts)：变更集、提交结果与公共提交器签名（`CanvasOperationCommitter`）契约
- [`changes/change-set-ops.ts`](../application/changes/change-set-ops.ts)：变更集创建、合并、快照投影、复合规划累积器（`createChangeSetProjector`）与协作载荷投影
- [`changes/submitted-region-changes.ts`](../application/changes/submitted-region-changes.ts)：提交区域失效规划
- [`canvas-operation.ts`](../infrastructure/transaction/canvas-operation.ts)：操作元数据规范化（`resolveCanvasOperationMeta`）与 `OPERATION_SYNC` 唯一发布入口（`publishCanvasOperation`）
- [`canvas-command-api.ts`](../application/canvas-command-api.ts)：公共提交入口 `commitOperation`（前态校验、写入、单次发布）与各命令网关
- [`useCollabSync.ts`](../ui/collaboration/useCollabSync.ts) 与 [`drag-message-codec.ts`](../infrastructure/collaboration/drag-message-codec.ts)：协作编码与发送

## 2. 历史背景

迁移前的旧机制是 `runTransaction + record* + 全局操作作用域` 的隐式变更收集：

```text
runTransaction
  → beginCanvasOperation
  → recordShapeChange / recordLineChange
  → 按实体 uid 折叠 add / modify / delete
  → 嵌套作用域合并
  → 最外层结束时发布 OPERATION_SYNC
```

该机制存在三个结构性问题，也是当前架构的设计动因：

1. **不是真正的事务**：不回滚、不保证原子生效、无隔离级别；回调异常时仍可能发布部分变化，异步回调时作用域提前关闭。
2. **操作边界由调用栈决定**：全局 `scopeStack` 按同步嵌套关系合并变更，而不是按 `operationId` 分组，子作用域 meta 会被父作用域覆盖。
3. **副作用隐式捕获**：深层调用产生的变化被收集器自动带走，无法在编译期或计划中确认完整性。

旧实现（`operation-sync.ts`、`event-adapter.ts`、全局操作栈和各类 `record*` 入口）已全部删除，没有保留兼容层。

## 3. 目标与非目标

### 3.1 目标

1. 一次持久化模型操作具有明确的输入意图、计划、提交结果和协作结果。
2. 所有直接变化和派生变化都进入同一个显式 `CanvasChangeSet`。
3. 失败或过期计划在任何 Store 写入之前被拒绝。
4. 一次顶层操作只发布一条最终模型协作消息。
5. 本地提交结果与远端回放结果保持一致。
6. 复合操作在临时投影快照上继续规划，最终一次性提交。
7. 为撤销重做、操作审计、冲突处理和离线操作保留完整事实基础。

### 3.2 非目标

1. 不要求读取、选择、视口或纯 UI 操作进入 Plan/Commit。
2. 不把交互预览和最终模型提交合并成同一协议。
3. 不为了形式统一给简单命令增加复杂计划对象。
4. 不假设 Plan/Commit 天然等于数据库事务；原子性仍需通过预校验、批量写入或回滚能力保证。

## 4. 适用边界

应进入 Plan/Commit 的状态：

- Shape 新增、修改和删除；
- Line 新增、修改和删除；
- CanvasRelation 新增、修改和删除；
- 由模型变化引起的 submitted 状态失效；
- 需要持久化并同步给协作者的其他画布模型字段。

不进入持久化 ChangeSet 的状态：

- 本地选中集；
- 远端选中装饰；
- 移动、缩放、绘制、框选和连线过程预览；
- 光标、视口、工具状态和弹窗状态；
- 调试信息和临时交互会话。

选择变化如需协作，继续使用独立的 selection 消息；过程预览继续使用 interaction 消息。最终模型只通过 operation 消息发布。

## 5. 核心架构不变量

任何改动都必须始终满足以下不变量：

1. **Plan 纯净性**：相同快照和相同意图必须产生相同计划，不读取或写入响应式 Store。
2. **规则唯一性**：领域规则只在 Plan 阶段运行，Commit 不重复推导业务结果。
3. **提交前拒绝**：能够预见的缺失目标、权限、规则和冲突必须在首个写入前处理。
4. **实际事实优先**：ChangeSet 使用实际写入后的对象，不使用其他字段或旧对象冒充当前结果。
5. **完整副作用**：区域、后代、连线、关系和 submitted 等派生变化不能留在 ChangeSet 之外。
6. **单次发布**：一次顶层操作只发布一次最终模型变更。
7. **本地远端一致**：将 ChangeSet 应用到操作前快照，结果必须等于本地 Commit 后快照。
8. **操作边界显式**：`operationId` 是显式相关标识，不由函数调用栈推断。
9. **提交同步性**：本地模型 Commit 必须是同步、有限且不可等待外部 IO 的过程。
10. **发布后置**：只有 Commit 成功后才能发布协作和持久化意图。

## 6. 数据契约

### 6.1 实体变化

```ts
export interface EntityAdded<T> {
  after: T;
}

export interface EntityModified<T> {
  before: T;
  after: T;
}

export interface EntityDeleted<T> {
  before: T;
}

export interface EntityChanges<T> {
  add: EntityAdded<T>[];
  modify: EntityModified<T>[];
  delete: EntityDeleted<T>[];
}

export interface CanvasChangeSet {
  shapes: EntityChanges<Shape>;
  lines: EntityChanges<Line>;
  relations: EntityChanges<CanvasRelation>;
}
```

内部变更集保留 before/after，协作编码器再投影为协议所需形式：

- add 使用 `after`；
- modify 使用 `after`；
- delete 使用 `before`。

### 6.2 计划结果

```ts
export type CanvasPlanResult<TPlan, TReason extends string> =
  { status: 'ready'; plan: TPlan } | { status: 'unchanged' } | { status: 'rejected'; reason: TReason };
```

语义约定：

- `unchanged`：意图合法，但不会造成模型变化；
- `rejected`：当前快照下意图不合法或不允许；
- `ready`：计划完整，可以进入 Commit；
- `stale`：仅由 Commit 返回，表示计划基于的前置状态已变化。

### 6.3 提交结果

```ts
export type CanvasCommitResult<TValue = void> =
  | {
      status: 'committed';
      value: TValue;
      changes: CanvasChangeSet;
    }
  | {
      status: 'stale';
      reason: 'revision-changed' | 'entity-changed' | 'entity-missing';
    }
  | {
      status: 'failed';
      reason: string;
    };
```

`failed` 只表示不可预见的基础设施失败。正常业务分支必须在 Plan 或提交前置校验阶段结束。

### 6.4 操作发布

```ts
export interface CanvasOperationCommit {
  meta: CanvasResolvedMutationMeta;
  changes: CanvasChangeSet;
}
```

meta 规范化与变更收集解耦，入口为 `resolveCanvasOperationMeta`，只负责补全操作元数据；发布挂载在 `CanvasMutationRuntime.publishOperation` 上（见第 15 节运行时端口）。

## 7. 各阶段职责

### 7.1 Intent

Intent 只描述用户或业务希望完成什么，不包含已经推导出的派生变化。例如：

```ts
type MoveIntent = {
  rootShapeIds: string[];
  targetPositions: ReadonlyMap<string, Point>;
};
```

Intent 不应携带通过别的字段补齐出来的数据。缺少必要信息时应保留缺失状态并由 Plan 拒绝，不能使用其他字段冒充。

### 7.2 Snapshot

Snapshot 是 Plan 的唯一模型输入，应满足：

- 内容不可变；
- 包含规划需要的 Shape、Line、Relation；
- 提供必要索引；
- 能记录 revision 或用于比对的 before 状态；
- 不暴露响应式 Store 引用。

几何规划使用的 `CanvasGeometrySnapshot` 是统一快照模型的参考；不要求所有命令共用一个过大的快照类型，可以按领域裁剪，只要复合操作能够投影和组合。

### 7.3 Plan

Plan 负责：

- 权限之外的领域准入；
- 目标存在性校验；
- 几何和结构推导；
- 派生 Shape、Line、Relation 变化；
- submitted 失效等模型变化；
- 记录提交所需的前置条件；
- 输出可投影到临时快照的确定性结果。

Plan 不负责：

- 写 Store；
- 发事件；
- 发 WebSocket；
- 修改选择态；
- 读取当前时间或生成随机 ID。

ID、时间和操作标识应在进入 Plan 前由应用层提供，确保相同输入产生相同结果。

### 7.4 Commit

Commit 负责：

1. 一次性验证计划前置条件。
2. 在任何写入前判断计划是否 stale。
3. 按计划写入 Store。
4. 返回实际写入后的完整对象。
5. 生成 `CanvasChangeSet`。

Commit 不负责：

- 重新执行领域规划；
- 通过当前 Store 临时猜测遗漏的副作用；
- 发布协作消息；
- 修改交互预览；
- 在部分写入后返回普通业务 rejected。

### 7.5 Publish

Publish 负责：

- 将内部 ChangeSet 投影为协作协议；
- 携带 operationId 和 phase；
- commit 相位设置持久化意图；
- 发送一次最终模型消息；
- 保持 interaction、selection、operation 三条消息语义分离。

Publish 不重新读取 Store，也不补充 ChangeSet 中缺失的实体。

## 8. ChangeSet 合并规则

合并由纯函数 `mergeCanvasChangeSets(current, incoming): CanvasChangeSet` 完成，不持有全局状态。同一实体在一次操作内的基本合并语义：

| 已有变化 | 新变化 | 合并结果                             |
| -------- | ------ | ------------------------------------ |
| 无       | add    | add                                  |
| 无       | modify | modify                               |
| 无       | delete | delete                               |
| add      | modify | add，保留最新 after                  |
| add      | delete | 抵消，不产生最终变化                 |
| modify   | modify | modify，保留最初 before 和最新 after |
| modify   | delete | delete，保留最初 before              |
| delete   | add    | 根据实体身份策略判定为 modify 或替换 |

`delete → add` 不能仅凭 uid 武断处理。Relation 可能保留 uid 但改变父子对，Shape/Line 也可能存在替换语义，需以实体类型和身份约束明确决定。

## 9. 计划过期与并发协作

Plan 基于某个本地快照产生。在 Commit 前，远端协作可能改变模型，因此 Commit 必须识别 stale plan。分层校验：

1. 检查计划涉及的实体是否仍存在或仍不存在。
2. 比较计划中的 `before` 与当前实体关键字段。
3. 必要时比较 Shape、Line、Relation revision。
4. 所有前置条件通过后才开始写入。

stale 后的处理策略由操作类型决定：

| 操作类型   | 策略                                               |
| ---------- | -------------------------------------------------- |
| 移动、缩放 | 基于最新快照重算，保持用户看到的最终目标位置或边界 |
| 属性修改   | 若目标仍存在，可基于最新对象重新规划补丁           |
| 删除       | 重新建立删除计划和影响范围                         |
| 创建       | 重新校验 ID、重叠、包含关系和端点                  |
| 复合操作   | 整体重新规划，不允许只重试其中一个子步骤           |

重算必须有明确上限，不能形成无限重试。

## 10. 原子性策略

Plan/Commit 本身不自动提供原子性。当前约定是：Commit 一旦开始，正常业务逻辑不再失败。保障顺序：

1. 把所有可预测失败提前到 Plan。
2. Commit 前统一校验全部实体和前置条件。
3. Store 提供批量写入入口，避免每个实体独立返回业务失败。
4. 批量写入先在暂存 Map 中生成下一状态，再一次性替换正式状态或统一更新索引。
5. 如果基础设施仍可能在写入中途失败，引入回滚快照或恢复操作。

不能依赖"发生部分写入后仍发布这些事实"来维持远端一致，这会让本地和远端共同进入业务上不完整的状态。

## 11. 派生变化的处理

### 11.1 区域扩容、推挤和后代传播

由移动、缩放 plan 显式产生，直接进入 Shape modify，不通过提交后的快照补记。

### 11.2 连线变化

Plan 输出每条受影响连线的最终变化，Commit 写入后使用实际 Line 作为 ChangeSet.after。如果关系变化会再次改变连线路由，关系计划必须在最终连线规划之前完成，或显式返回二次连线变化并与几何 ChangeSet 合并。

### 11.3 功能图包含关系

移动、缩放、创建和删除的显式规划直接产生 Relation add/delete、新父节点业务字段清理和关系变化后的连线同步。这些关系副作用纳入各自操作的同一个 ChangeSet，不存在独立的包含关系提交入口。

### 11.4 submitted 状态失效

submitted 失效属于持久化模型变化，必须是 Plan 或明确派生计划的结果，进入 Shape modify。每种命令需明确是在本次操作中直接失效、等待用户确认，还是由另一条业务流程处理；共享纯规划函数见 [`submitted-region-changes.ts`](../application/changes/submitted-region-changes.ts)。

触发语义：仅**业务内容变化**触发失效——图形类型或数据变化、连线端点/箭头/数据变化、区域内图形或连线的增删；**纯几何变化不触发**（图形位移/缩放/图层调整、连线路径重路由）。判定谓词见 [`region-submitted-invalidation-service.ts`](../domain/services/region-submitted-invalidation-service.ts)。

### 11.5 选择结果

选择态不是持久化模型 ChangeSet 的组成部分。命令可以在 committed result 中附带建议选择结果，由 UI 在 Commit 成功后应用；选择协作继续走独立 selection 消息。

## 12. 复合操作

复合操作不能通过依次执行多个已提交的子命令来获得原子性。典型场景：

- 快速添加：创建图形并创建连线；
- 向连线插入图形：创建图形、创建两条新线、删除旧线；
- 粘贴：创建多个图形、连线和关系；
- 引用快照到区域：删除旧内容，再创建新内容；
- 批量上下文命令：对多个目标执行同类变化。

统一流程：

```text
初始真实快照
  ↓
规划第一个子意图
  ↓
把子计划应用到临时投影快照
  ↓
基于投影快照规划下一个子意图
  ↓
合并所有子 ChangeSet
  ↓
一次前置校验
  ↓
一次 Commit
  ↓
一次 Publish
```

投影能力由纯函数提供：

```ts
applyChangeSetToSnapshot(snapshot, changes): CanvasSnapshot
```

该函数不写 Store，既服务复合规划，也作为本地提交与远端回放一致性的基准实现。

## 13. 交互预览与最终提交

交互消息和模型提交保持两条链路：

```text
过程帧：Intent → Plan → Preview Projection → Interaction Message

提交帧：Latest Snapshot → Final Plan → Commit → ChangeSet → Operation Message
```

约束：

1. 预览不写领域 Store。
2. Interaction commit/reset 只结束远端预览，不携带最终模型。
3. Operation commit 携带最终模型，并按 operationId 清理对应预览。
4. 预览计划可以被丢弃；最终计划必须针对最新可提交快照。

移动、缩放的实现（`move-service.ts`、`resize-service.ts`、`move-session.ts`、`selection-resize-interaction.ts`、`geometry-mutation-executor.ts`）是其他连续交互的参考样板。

## 14. 失败语义

| 阶段             | 状态             | 是否写 Store         | 是否 Publish                       |
| ---------------- | ---------------- | -------------------- | ---------------------------------- |
| Plan             | unchanged        | 否                   | 否                                 |
| Plan             | rejected         | 否                   | 否                                 |
| Commit preflight | stale            | 否                   | 否                                 |
| Commit           | committed        | 是                   | 是，一次                           |
| Commit           | failed           | 必须恢复到提交前状态 | 否                                 |
| Publish          | transport failed | 本地已提交           | 进入既定的重发、刷新或错误恢复策略 |

Publish 失败与 Commit 失败必须区分。WebSocket 是外部 IO，不能纳入同步本地 Commit，也不能因为发送失败直接回滚已经对用户生效的本地模型。

## 15. 运行时端口

`CanvasMutationRuntime` 只承载状态查询、模型写入和显式操作发布接线，依赖方向保持清晰：

```ts
interface CanvasSnapshotReader {
  createSnapshot(...): CanvasSnapshot;
}

interface CanvasPlanCommitter {
  commit(plan: CanvasOperationPlan): CanvasCommitResult;
}

interface CanvasOperationPublisher {
  publishOperation(operation: CanvasOperationCommit): void;
}
```

- Planner 只依赖普通快照数据；
- Committer 只依赖模型写入能力；
- Publisher 只依赖变更集和协作基础设施；
- UI 不直接调用 Store 写入或事件总线完成业务提交。

## 16. 架构约束（验收标准）

### 16.1 单命令

1. rejected、unchanged 和 stale 不改变模型。
2. committed ChangeSet 完整描述操作前后的所有持久化变化。
3. 一次命令只产生一次 operation 发布。
4. 实际 Store 对象与 ChangeSet.after 一致。

### 16.2 复合命令

1. 任一子计划失败时真实 Store 不发生变化。
2. 所有子计划基于投影快照连续规划。
3. 最终只执行一次 Commit 和一次 Publish。
4. 不存在"前半部分成功、后半部分返回 false"的状态。

### 16.3 协作一致性

1. 相同操作的本地提交结果与远端回放结果一致。
2. operationId 分组不受函数嵌套结构影响。
3. 最终模型消息能够正确清除相同 operationId 的远端预览。
4. commit 和 live 的持久化语义保持现有协议兼容。

### 16.4 架构边界

1. Planner 不依赖 Store、EventBus 或 WebSocket。
2. Committer 不依赖协作传输。
3. Publisher 不执行领域规则或重新读取模型补数据。
4. UI 不绕过应用命令直接提交持久化模型。

以上边界由 `tests/architecture/runtime-mutation-boundary.spec.ts` 静态守卫，改动命令链路时需保持守卫通过。

## 17. 维护风险与控制

### 17.1 遗漏派生副作用

显式 ChangeSet 可能漏掉关系、连线或 submitted 更新。改动命令时对比操作前后完整快照差异与 ChangeSet；发现差异必须回到 Planner 或 Committer 补充显式事实，不能在 Publisher 中临时扫描 Store。

### 17.2 计划对象过度膨胀

统一的是 Plan/Commit/ChangeSet 语义，不是所有计划的具体结构。简单命令保持轻量计划，不携带无用字段。

### 17.3 Commit 部分失败

Store 逐项写入存在中途失败风险。先完成全量 preflight，再逐步增强批量暂存和整体替换能力；在具备恢复能力前，不宣称 Commit 已实现强原子性。

### 17.4 协作期间计划过期

远端变更可能发生在 Plan 与 Commit 之间。所有提交都校验 before/revision；连续交互使用最新快照重算，离散命令按明确策略重算或返回 stale。

### 17.5 Store 防御性规范化导致结果偏差

计划 after 可能与 Store 实际写入后的对象不同。领域 Plan 尽量复用同一规范化规则；ChangeSet.after 始终取实际提交结果，不直接把未经确认的 plan.after 当作事实发布。

### 17.6 提交入口唯一性

所有持久化命令统一经公共 `commitOperation` 提交（由 `canvas-command-api.ts` 的 `createCanvasOperationCommitter` 组装）：命令只负责把意图规划为完整 `CanvasChangeSet`，前态校验、实际写入和单次发布都在公共入口完成。计划模型与 EntityChanges 不一致时，由纯函数在提交前折叠，不另建提交通道：

- 几何命令的"同一图形多条部分补丁"由 `foldGeometryCommitPlan` 折叠为单条 modify；
- 轻量图形补丁由 `buildShapePatchChangeSet` 折叠（属性更新、图层排序共用）。

新增命令不得绕过公共入口自行写入 Store 或发布事件；`OPERATION_SYNC` 的唯一生产者仍是 `publishCanvasOperation`。

## 18. 术语

- `Intent`：调用方意图；
- `Snapshot`：规划输入；
- `Plan`：可提交的确定性变化方案；
- `Commit`：校验并应用计划；
- `ChangeSet`：实际提交事实；
- `Publish`：把已提交事实发送到协作和持久化通道；
- `Operation`：一次顶层用户或业务操作；
- `Interaction`：不落模型的过程态交互。

不把同步作用域、事件聚合或批量写入称为 Transaction，除非未来真正具备原子提交和回滚语义。
