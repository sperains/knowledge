# ICCE 应用命令重构方案

## 当前结论

| 已完成 | 明确保留的边界 |
| --- | --- |
| 应用命令、工作流和运行时职责已分开；正式画布变更统一经过应用命令；命令结果保留业务语义；快速添加、连线插入和引用快照已采用完整计划与集中应用 | 当前仍不是状态级回滚事务；异常发生在底层写入中途时，已完成写入可能保留；状态快照、事实事件缓冲和嵌套事务另行设计 |

阅读本文时，前面的“目标”章节用于说明设计依据，末尾第 15、16 节用于确认实际落地结果。

## 1. 背景

当前 `src/views/icce/application/commands` 同时放置了两类职责不同的代码：

- 直接依赖 `CanvasMutationRuntime`，负责事务、状态写入和事实事件的原子变更用例。
- 依赖 `CanvasMutationFacade`，组合多个原子变更并处理选择状态、ID 和交互语义的场景用例。

目录中的用例已经具备较清晰的领域规划与应用执行分层，但仍存在以下问题：

1. 原子变更和场景编排混在同一目录，阅读文件名无法判断事务边界和依赖方向。
2. `CanvasMutationFacade` 将部分明确的命令结果压缩为 `boolean` 或空数组，调用方无法区分忽略、业务拒绝和写入失败。
3. 场景用例重复注入 `getShape`、`getLine`、`getParentId`、`getDescendantIds` 等零散查询函数。
4. `update-shapes-command.ts` 同时承担规划、区域扩张、关联内容移动、写入、连线同步和事件发布，主流程不够突出。
5. `contextual-canvas-command.ts` 实际是 UI 动作分派器，却与核心变更用例处于同一层级。
6. 快速添加、连线中插入图形等场景采用“先写入、失败后手工删除”的补偿方式，原子性依赖调用方自行维护。

本次重构不追求减少文件数量，也不引入命令总线或类继承体系。目标是通过明确分层和少量稳定接口，让每个文件的职责、调用方向和事务边界容易理解。

## 2. 重构原则

### 2.1 保留显式用例

继续使用普通函数表达应用用例，不引入以下抽象：

- `Command<T>`、`CommandHandler<T>` 等通用命令协议。
- `BaseCommand` 等继承体系。
- Command Bus、Handler Registry 或依赖注入容器。
- 为每个循环、事件或写入动作单独建立 service。

不同用例真正共享的是运行环境，而不是完整算法流程。显式函数比通用执行框架更容易追踪。

### 2.2 单向依赖

目标依赖方向如下：

```text
UI
  → interaction
  → workflow
  → command
  → domain plan
  → runtime
  → store / event / transaction
```

约束如下：

- 只有 `commands` 可以直接依赖 `CanvasMutationRuntime`。
- `workflows` 通过应用命令入口完成状态变更，不直接写 Store。
- `interactions` 只解释 UI 动作并转换结果，不实现核心变更逻辑。
- 只有 `infrastructure` 可以装配 Pinia Store、接口请求和具体事务实现。
- `domain` 继续负责无副作用的规则判断与变更计划。

### 2.3 一个场景只有一个明确事务边界

一个用户动作产生的多项变更应共享同一个 `operationId`，并在所有业务条件确认后统一应用。选择状态只能在变更整体成功后更新，不允许每个步骤各自决定补偿策略。

### 2.4 结果必须保留业务语义

应用命令应明确区分：

- `created`、`updated`、`deleted`、`handled`：按用例语义表达成功并返回实际结果。
- `ignored`：目标为空、无变化或当前场景无需处理。
- `rejected`：业务规则不允许或写入失败。
- `requires-confirmation`：需要用户确认后才能继续，仅用于有确认流程的用例。

不要求所有命令套用同一个泛型类型，但相同状态的含义必须一致。

## 3. 目标目录结构

```text
application/
├── commands/
│   ├── shape/
│   │   ├── create-shape.ts
│   │   ├── update-shapes.ts
│   │   ├── delete-selection.ts
│   │   ├── move-shapes.ts
│   │   ├── update-shape-properties.ts
│   │   └── reorder-shapes.ts
│   ├── line/
│   │   ├── create-line.ts
│   │   ├── update-line.ts
│   │   └── delete-line.ts
│   └── containment/
│       └── update-containment.ts
├── workflows/
│   ├── quick-add.ts
│   ├── insert-shape-into-line.ts
│   ├── quote-snapshot-into-region.ts
│   └── auto-create-regions-after-load.ts
├── execution/
├── contracts/
├── runtime/
│   └── canvas-mutation-runtime.ts
├── contextual-canvas-command.ts
└── canvas-command-api.ts
```

画布只读查询不再作为 application port 存在，运行时实例统一位于
`infrastructure/composition/canvas-query.ts`。

目录只表达三种职责：

| 目录或文件                  | 职责                                  | 是否直接操作 Runtime |
| --------------------------- | ------------------------------------- | -------------------- |
| `commands`                  | 单个应用变更及其事务、写入和事件      | 是                   |
| `workflows`                 | 组合多个应用命令形成完整用户场景      | 否                   |
| `contextual-canvas-command` | 编排上下文工具栏动作并转换应用命令结果 | 否                   |

## 4. 核心命令设计

### 4.1 保留的原子变更命令

以下命令继续独立存在：

- `createShape`
- `updateShapes`
- `deleteSelection`
- `moveShapes`
- `createLine`
- `updateLine`
- `deleteLine`
- `updateContainment`

每个命令采用相同的概念流程：

```text
读取当前状态
  → 调用领域服务生成计划
  → 返回 ignored / rejected
  → 在单一事务中应用计划
  → 记录图形、连线和关系变更
  → 事务结束时统一发布 operation:sync
  → 返回完整结果
```

命令函数仍然接收普通 `options` 对象，不创建命令实例。

### 4.2 保留意图适配命令

`updateShapeProperties` 和 `reorderShapes` 虽然主要复用 `updateShapes`，仍建议保留为独立命令，因为它们表达了清晰的用户意图：

```text
修改图形属性
  → 领域服务生成 ShapeUpdate[]
  → updateShapes

调整图层顺序
  → 领域服务生成 zIndex 更新
  → updateShapes
```

调用方不需要知道底层 `ShapeBatchUpdateItem` 的构造方式。此类薄包装具有应用语义，不属于无效抽象。

### 4.3 命令结果

结果类型按用例显式声明，但状态语义统一。例如：

```ts
export type ReorderShapesResult =
  | { status: 'success'; updates: ShapeBatchUpdatedItem[] }
  | { status: 'ignored'; reason: 'shape-not-found' | 'no-changes' }
  | { status: 'rejected'; reason: 'write-failed' | 'region-expansion' };
```

不建议为了减少几行联合类型而强制所有用例使用一个复杂泛型。比类型复用更重要的是调用方可以可靠地区分处理结果。

## 5. `updateShapes` 的收敛方式

`updateShapes` 继续作为图形更新的唯一核心入口，不拆成多个可被外部调用的小命令。主函数只保留三个阶段：

```ts
export function updateShapes(options: UpdateShapesOptions): UpdateShapesResult {
  const plan = resolveShapeUpdatePlan(options);
  if (plan.status !== 'ready') return plan;

  return options.runtime.runTransaction(options.meta, 'modify', (meta) => {
    const result = applyShapeUpdatePlan(plan, options.runtime, meta);
    publishShapeUpdateResult(result, options.runtime, meta);
    return toUpdateShapesResult(result);
  });
}
```

其中：

- `resolveShapeUpdatePlan` 负责单图形规划、目标存在性和区域扩张准入。
- `applyShapeUpdatePlan` 负责区域扩张、关联内容移动、图形写入和连线同步。
- `publishShapeUpdateResult` 负责单图形事件、批量事件和关系差异事件。

上述函数优先作为同文件私有函数存在。只有执行逻辑达到独立复杂度并已有多个调用方时，才移动到 `execution` 目录。

## 6. 应用命令入口

应用层通过 `CanvasCommands` 隐藏运行时并集中装配应用命令。应用接口位于 `canvas-command-api.ts`，基础设施组合根位于 `canvas-command-composition.ts`，UI 和 workflow 直接消费完整命令结果。

```ts
export interface CanvasCommands {
  createShape(shape: Shape, meta?: CanvasMutationMeta, options?: ShapeAddOptions): CreateShapeResult;
  updateShapes(updates: ShapeBatchUpdateItem[], meta?: CanvasMutationMeta): UpdateShapesResult;
  deleteSelection(options: DeleteSelectionInput): DeleteSelectionApplicationResult;
  move(options: MoveCommandInput): CanvasMoveResult;

  createLine(line: Line, meta?: CanvasMutationMeta): CreateLineResult;
  updateLine(lineId: string, changes: Partial<Line>, meta?: CanvasMutationMeta): UpdateLineResult;
  deleteLine(lineId: string, meta?: CanvasMutationMeta): DeleteLineResult;
}
```

该入口负责：

- 在组合根创建并注入 `CanvasMutationRuntime` 及其执行服务。
- 调用对应核心命令。
- 隐藏基础设施装配细节。
- 保留并返回核心命令的完整结果。

该入口不负责：

- 将所有结果转换成 `boolean`。
- 解释上下文工具栏等 UI action。
- 包含领域规则或变更算法。
- 暴露 Runtime 的底层写入方法。

UI 需要布尔判断时，应在调用位置显式判断 `result.status`，不再由应用层兼容门面统一压缩结果。

## 7. 查询接口收敛

运行时查询统一由组合层的普通对象提供：

```ts
export const canvasQuery = {
  getShape,
  getLine,
  getLinesByShape,
  getParentId,
  getDescendantIds,
};
```

每个场景用例在本地声明实际需要的最小查询结构：

```ts
export interface WorkflowDependencies {
  commands: CanvasCommands;
  query: {
    getShape(shapeId: string): Shape | undefined;
    getParentId(shapeId: string): string | undefined;
  };
  selection: CanvasSelection;
  newId(): string;
}
```

不再引入 `CanvasQuery` 类、DataSource、工厂或应用层查询端口。纯搜索和几何算法继续留在领域层，组合层只负责从 store 读取数据并组装查询结果。所有查询方法都是不依赖 `this` 的普通函数，可以安全作为回调传递。

## 8. 场景编排

### 8.1 快速添加

`quick-add` 保留两个明确入口：

- 连接已有图形。
- 创建新图形并建立连线。

它负责：

- 调用领域服务生成完整计划。
- 生成本次操作所需 ID。
- 调用应用命令完成变更。
- 在整体成功后更新选择状态。

它不直接调用 Store，也不自行发布事件。

### 8.2 连线中插入图形

该场景包含：

1. 创建新图形。
2. 创建两条替代连线。
3. 删除原连线。
4. 选中新图形。

领域服务必须在写入前生成完整计划并完成端点、图形类型和包含范围校验。应用层一次性应用计划，避免调用方维护“新增失败后再删除”的补偿流程。

### 8.3 引用快照到区域

该场景继续负责 ID 重映射和放置偏移，但建议把流程明确拆为：

```text
生成引用计划
  → 清理区域原内容
  → 批量创建克隆图形
  → 按 ID 映射创建克隆连线
  → 返回实际创建结果
```

克隆数据时必须保持字段真实来源。未保留的数据应为空或删除，不使用其他字段补齐当前字段。

### 8.4 加载后自动创建区域

该场景包含异步加载和过期任务判断，继续放在 workflow 层。执行顺序保持：

```text
检查图类型和画布是否为空
  → 加载树
  → shouldContinue
  → 生成区域计划
  → shouldContinue
  → 批量应用
```

接口请求和异常记录仍由 infrastructure composition 负责，workflow 只接收 `loadTree` 依赖。

## 9. 上下文工具栏交互

`contextual-canvas-command.ts` 位于 application 根目录，负责将 UI action 转换为应用能力并编排上下文画布操作。它不是单一图形或连线的原子命令，因此不放入 `commands/` 子目录。

建议保留当前 `switch`，因为动作数量有限且一眼可见，比动态 handler registry 更容易维护：

```ts
switch (action) {
  case 'delete':
    return handleDelete(...);
  case 'clear-region':
    return handleClearRegion(...);
  case 'update-property':
    return handleUpdateProperty(...);
  case 'insert-shape':
    return insertShapeIntoLine(...);
  case 'swap-arrow':
    return handleSwapArrow(...);
  case 'bring-to-front':
  case 'send-to-back':
    return handleReorder(...);
}
```

各私有 handler 只负责：

- 校验 action 是否支持当前 target。
- 构造命令输入。
- 将应用结果转换为交互结果。
- 返回确认文案和 `operationId`。

不要为每个 action 创建独立类，也不要在 interaction 层重复实现删除、属性更新或排序规则。

## 10. 多实体变更的原子性

快速添加、连线中插入图形和引用快照都可能一次修改多个实体。当前手工回滚方式容易遗漏关系、连线同步、选择状态或已发布事件。

### 10.1 当前事务能力

当前 `runCanvasTransaction` 的实际职责是：

- 建立和结束一次画布操作作用域。
- 聚合嵌套操作产生的图形、连线和关系变化。
- 在最外层操作结束后发布 `OPERATION_SYNC`。

它目前不具备以下能力：

- 记录并恢复 Store 的事务前状态。
- 在异常或业务失败时恢复图形、连线、关系和选择状态。
- 不再由命令链路发布 `SHAPE_CREATED`、`LINE_UPDATED` 等图形、连线和关系小事件；正式变更在最外层操作结束时统一发布 `OPERATION_SYNC`。
- 撤销提交区域失效、连线同步等已经执行的副作用。

因此当前代码中的 transaction 应理解为“操作和同步作用域”，不能将它视为具有 commit/rollback 语义的状态事务。本轮重构不通过改名或局部补偿掩盖这一事实。

### 10.2 本轮处理方式

建议新增一个范围明确的批量应用能力，例如：

```ts
interface CompositeMutationPlan {
  shapesToCreate?: PlannedShapeCreation[];
  linesToCreate?: Line[];
  shapeIdsToDelete?: string[];
  lineIdsToDelete?: string[];
  selectionAfterSuccess?: SelectionSnapshot;
}
```

该能力只服务于一个场景内的多实体集中变更，不演变成通用事务 DSL。由于本轮不提供真正的状态回滚，代码和文档中不将其描述为原子事务。它必须满足：

1. 写入前完成所有可执行的业务校验。
2. 所有步骤共享同一个 `operationId`。
3. 中途失败时不发布整体成功结果。
4. 选择状态只在全部写入成功后更新。
5. workflow 不再直接编写补偿删除。

本轮先通过“完整计划、完整预检、集中应用”减少写入中途失败和部分成功的概率。该方案提升一致性，但不承诺异常发生后的状态恢复。

### 10.3 真正状态回滚的后续方案

真正可靠的状态事务需要同时处理状态和事件，不能只在异常时恢复 Store。建议后续新增范围明确的 `runAtomicCanvasMutation`，执行流程为：

```text
保存事务前状态
  → 暂存事实事件和同步变化
  → 执行状态写入
  → 成功：提交状态并统一发布事件
  → 失败：恢复状态并丢弃暂存事件
```

需要覆盖的状态至少包括：

- shapes、lines 和连线顺序。
- relations 及其父节点、子节点、类型索引。
- selection。
- 写入过程中产生的提交区域失效结果。

该能力优先只服务多实体 commit 场景，不直接覆盖实时拖拽的 `live/commit` 生命周期。嵌套事务、事实事件缓冲和实时操作失败语义需要单独设计，因此将其作为后续基础设施改造，不混入本轮应用命令重构。

## 11. 分阶段落地

当前以下阶段均已完成。多实体场景采用结构预检、预生成完整计划和集中应用，不包含状态级回滚。

### 阶段一：整理目录和命名

- 按 `commands`、`workflows`、`interactions` 调整文件位置。
- `move-command` 改为 `move-shapes`，使命名与实际目标一致。
- 更新引用路径，不改变执行行为和公开结果。

该阶段的目标是先让职责从目录结构上可见。

### 阶段二：收敛查询依赖

- 引入组合层 `canvasQuery` 普通对象。
- 由 infrastructure composition 提供具体实现。
- 将 workflow 中零散的 `getShape`、`getLine`、`getParentId` 等依赖替换为 `query`。
- 暂不拆分 `CanvasMutationRuntime`。

### 阶段三：统一应用命令入口和结果

- 将 Facade 定位为 `CanvasCommands`。
- 保留核心命令的完整结果，不再统一压缩为布尔值。
- 统一成功状态、`ignored`、`rejected` 的语义。
- 由 interaction 或 UI 决定如何展示失败和忽略结果。

### 阶段四：收敛复杂命令内部结构

- 将 `updateShapes` 整理为“规划、应用、发布”三个阶段。
- 复核 `deleteSelection` 和 `moveShapes` 的事务内外职责。
- 私有逻辑优先留在用例文件内，只提取具有独立复杂度的执行模块。

### 阶段五：处理多实体场景

- 统一 quick-add、insert-shape-into-line 的完整计划和操作 ID。
- 移除 workflow 中的手工回滚。
- 评估 quote-snapshot 是否使用同一批量应用能力。
- 确保选择状态在整体成功后更新。
- 明确该阶段采用预检和集中应用，不承诺状态级回滚。

## 12. 改造价值

### 12.1 修改范围更容易判断

重构后的依赖方向固定为：

```text
UI → interaction → workflow → command → domain plan → runtime → infrastructure
```

修改业务准入时定位 domain plan，修改场景步骤时定位 workflow，修改工具栏行为时定位 interaction，修改写入和事件时定位 command/runtime。开发者不再需要逐个判断同一 `commands` 目录下的文件究竟属于哪个层次。

### 12.2 降低调用方耦合

`canvasQuery` 集中对接 shape 和 relation store；workflow 仅声明自身需要的最小查询结构。查询实现或关系存储发生变化时，场景编排不需要感知具体 store。

### 12.3 保留失败的真实原因

`CanvasCommands` 返回完整结果后，调用方能够区分空目标、无变化、规则拒绝、区域扩张失败、写入失败和需要确认，不再将不同结果统一压缩成 `boolean`、空数组或 `null`。这会改善 UI 反馈、日志记录和问题定位。

### 12.4 降低复杂更新的理解成本

`updateShapes` 收敛为“规划、应用、发布”三个阶段后，主流程可以直接阅读，同时继续集中复用区域扩张、关联内容移动和连线同步能力，避免这些规则散落到移动、属性更新和排序调用方。

### 12.5 提升多实体场景的一致性

完整计划和预检可以让 ID、端点、父区域和删除目标在写入前确定；集中应用可以保证所有步骤共享一个 `operationId`，选择状态只在整体成功后更新，并消除 workflow 内容易遗漏的手工补偿代码。

### 12.6 为真正状态回滚建立前置条件

本轮不会直接提供完整回滚，但会先完成必要的结构准备：写入集中到 command/runtime、多实体场景拥有完整计划、操作 ID 和结果语义统一、事件发布阶段更加明确。后续引入状态快照和事件缓冲时将有清晰落点。

### 12.7 固化可自动检查的架构边界

目录和依赖职责明确后，可以通过架构规则持续约束 workflow 不依赖 Runtime、application 不依赖 Pinia 和 infrastructure、interaction 不直接写 Store，避免后续需求再次破坏分层。

## 13. 不在本次范围内的事项

- 不重写现有领域规则和领域服务。
- 不将函数式用例改造成类。
- 不引入 CQRS 框架或事件溯源框架。
- 不按每种图类型复制一套应用命令。
- 不为了接口隔离而拆分大量只有一个方法的 Port。
- 不在目录迁移阶段顺带修改业务行为。
- 不通过其他字段补齐缺失业务数据。
- 不为现有 `runCanvasTransaction` 补充全局状态回滚。
- 不在本轮实现事实事件缓冲、嵌套回滚和实时拖拽回滚。

## 14. 完成标准

重构完成后应满足：

1. 从文件位置即可判断代码属于原子命令、场景编排还是 UI 交互。
2. 只有核心命令及其应用命令网关直接依赖 `CanvasMutationRuntime`。
3. workflow 不直接依赖 Pinia Store，也不手工发布事实事件。
4. 调用方能够区分成功、忽略、规则拒绝和写入失败。
5. `updateShapes` 主流程能直接看出规划、执行和事务记录三个阶段。
6. 上下文工具栏只负责 action 分派和结果转换。
7. 多实体场景共享一个操作 ID，选择状态在整体成功后更新。
8. 不引入命令总线、基类、注册表或通用事务 DSL。
9. 文档和代码不再将操作作用域描述成支持状态回滚的事务。

## 15. 行为等价性审计结果（2026-07-19）

本轮在停止结构调整后，对重构前后的原子命令、workflow、调用方结果判断和运行时组合进行了逐项复核。

审计结论：

- 图形、连线、包含关系、移动、排序、属性更新和删除等原子命令保持原有领域计划、写入顺序与事务变更记录语义；`updateShapes` 仅将原流程整理为规划、应用和记录三个私有阶段。
- `CanvasCommands` 保留原 Facade 调用的同一命令入口，但返回完整命令结果；UI 和 interaction 已在原布尔判断位置显式判断对应成功状态。
- 快速添加、连线中插入图形和引用快照存在明确的设计内行为变化：写入前预生成完整 ID、检查结构冲突、失败后不更新选择状态，并取消 workflow 内的手工补偿删除。
- 多实体 workflow 仍不具备状态级回滚。预检通过后若底层写入中途失败，已完成的写入可能保留；该风险不应被描述为原子事务，后续只能通过状态快照与事件缓冲统一解决。

审计期间确认并修复两项回归：

1. `CanvasQuery` 类方法作为回调传递时丢失 `this`，导致快速连接读取父级关系异常。查询实现现已简化为组合层普通函数对象，从结构上消除实例绑定问题。
2. `contextual-canvas` 向连线插入 workflow 透传查询依赖时缺少 `getShape` 类型契约，现已补齐最小依赖结构。

新增验证覆盖：

- 快速连接已有图形、复用已有连线、ID 冲突、图形或连线创建失败。
- 连线中插入图形的完整成功链路、ID 冲突、替代连线失败和原连线删除失败。
- 引用快照的 ID 冲突、旧内容删除失败和新图形创建失败。
- 真实 `workflow → canvasQuery → CanvasCommands → runtime → Pinia store` 链路下的快速连接、连线插入和区域内容替换。

最终验证结果为 99 个测试文件、398 条 Vitest 用例全部通过，测试 TypeScript 配置检查及差异格式检查通过。原 `src/views/icce/components/FormItemRight.vue` 已确认迁移为 `src/views/icce/ui/detail/basic-info/BasicInfoFields.vue`，功能块调用方和全仓旧路径守卫已同步；Vite 测试环境构建通过，共完成 5994 个模块转换。本轮应用命令重构至此完成，真正的状态快照、事件缓冲和失败回滚作为后续独立基础设施改造处理。

## 16. 命令链路进一步收敛（2026-07-22）

- 移动命令不再接收提交区域影响、功能图包含关系刷新和快照记录等外部回调，统一由运行时能力和包含关系命令完成。
- 删除命令与移动命令统一通过运行时查询提交区域影响，组合层不再重复装配同一查询能力。
- 事务变更记录使用独立的记录模型，不再复用带元数据的事件载荷；事件协议与事务记录协议保持分离。
- 包含关系命令将显式设置和刷新流程的默认行为归一为策略对象，减少布尔参数组合。
