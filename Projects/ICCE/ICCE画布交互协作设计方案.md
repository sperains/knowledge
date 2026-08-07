# ICCE 画布交互协作设计方案

## 1. 文档目的

本文定义 ICCE 主画布以下交互的多人协作需求与技术方案：

- 框选过程与选中结果协作。
- 单图形、多图形拖拽过程协作。
- 图形和区域 resize 过程协作。
- 图形、区域和连线绘制过程协作。
- 超大数据量下的框选、选区展示和批量拖拽协作。

本文是在既有 `drag` 协作通道上扩展过程态协作的设计。实施时必须保留当前应用命令、事务、协作协议编码、传输、回放和 UI 生命周期的职责边界。过程态扩展 `handleData.interaction`，选中状态扩展 `handleData.selection`，均不进入既有正式数据回放器。

## 2. 结论摘要

交互协作必须拆为两条链路：

1. **过程态协作**：框选框、远端选区、拖拽位移、resize 边界、绘制草稿。过程态允许丢帧，不写正式业务 Store，不触发持久化。
2. **提交态协作**：最终坐标、尺寸、图形新增、连线变化和包含关系变化。提交态必须可靠、幂等，并继续进入现有应用命令和事务链路。

超大选区拖拽不得在每个 pointer frame 中发送所有图形的完整记录。正确模型是：

```text
开始：声明一次选区或 selectionRef
过程：持续发送整体 dx / dy 或目标 bounds
结束：提交一次最终变更
```

远端过程态由独立的协作状态和协作渲染层承载，不得写入本地 `selectionStore`、`previewStore` 或正式 `shapesStore`。

当前首期实现四类过程态协作：

1. 普通图形的拖拽绘制过程协作。
2. 单图形 resize 过程协作。
3. 框选过程协作。
4. 单图形和多图形移动过程协作。

区域 resize、区域绘制、连线绘制、`selectionRef` 和超大选区优化仍不属于当前实现范围。

## 3. 当前实现基线

当前 ICCE 已具备以下基础：

- 画布变更使用应用命令和事务组织。
- 操作同步区分 `live` 与 `commit`。
- 拖拽和 resize 使用 `operationId` 关联单次操作。
- 协作消息具备协议编码、节流分发、WebSocket 传输、远端回放和 UI 生命周期分层。
- 图形绘制使用本地 interaction session 和 preview 状态。
- 选择、图形、连线、关系分别有明确的状态边界。

当前实现仍存在以下不足。

### 3.1 选中状态协作已闭环

- 选择消息使用独立的 `selection` 快照，包含图形和连线 ID；空快照用于清除远端选中态。
- `remote-selection-store` 按用户保存远端选中 ID，不写入本地 `selectionStore` 或正式图形 Store。
- `SelectionLayer` 只负责本地选中态和交互手柄，`PreviewLayer` 负责远端选中轮廓和整体包围盒。
- 远端选中轮廓与本地选中样式共用统一视觉配置，图形、区域、连线和包围盒不再分别维护临时模板。

### 3.2 实时变更数据量随选区规模增长

- 实时消息默认按 16ms 节流，频率接近 60FPS。
- 多选拖拽每帧为每个选中图形生成绝对坐标更新。
- 协作编码为每个图形附带完整 `data`、尺寸和层级数据。
- 接收端把 live 数据直接写入正式 Store，引发响应式计算和正式渲染。

其复杂度近似为：

```text
消息与更新成本 = 选中对象数 N × 实时帧数 F × 单对象完整数据大小
```

### 3.3 大选区渲染成本过高

- 选择层会为每个被选图形生成独立描边配置。
- 多选拖拽会持续更新大量图形和关联连线。
- 框选结束需要检查图形和连线范围；未引入空间索引时容易退化为全量扫描。
- Vue 深响应式、数组复制、集合转数组和 computed 重算会进一步放大成本。

### 3.4 绘制过程已支持远端临时预览

- 图形绘制过程中通过 `interaction` 发送图形类型和最新包围盒，接收端只更新远端过程态 Store。
- 图形抬起并成功创建后才进入正式变更同步，远端临时节点不写入正式 Store。
- 多名用户同时绘制时按用户和会话区分远端草稿。

### 3.5 单图形 resize 过程协作已闭环

- 本地 resize 过程仍按现有交互更新正式图形 Store，但正式协作发送会跳过 resize 的 live 完整图形消息。
- 远端只接收轻量包围盒并更新独立预览 Store，不触发正式图形回放。
- 最终尺寸和关联变化继续通过应用命令产生的提交态同步；操作序号、基础版本和同目标冲突约束仍待补充。

### 3.6 图形移动过程协作已闭环

- 移动开始时发送当前移动图形编号和相对会话起点的总位移，后续更新只发送最新总位移。
- 远端过程态只更新独立预览 Store，不修改正式图形、连线、包含关系或本地选中状态。
- 多图形移动预览同时显示各图形轮廓和移动后的联合包围盒；单图形移动不重复绘制整体框。
- 最终位置、区域联动、连线和包含关系继续以应用命令产生的正式提交态为准。

### 3.7 协作消息与几何精度已收敛

- `handleData` 只发送当前消息实际需要的字段，空的新增、修改和删除数组在发送出口省略。
- 旧的完整对象选中数组已经移除，远端选中结果统一由 `selection` 快照表达。
- 过程态包围盒与移动位移在协议编码出口统一为整数；本地指针和约束计算过程仍可保留浮点精度。

## 4. 需求范围

### 4.1 当前首期必须实现

#### 普通图形拖拽绘制协作

- 支持矩形、正方形、椭圆、多边形、开始节点、结束节点和用户节点。
- pointer down 时开启协作会话并发送图形类型和初始包围盒。
- pointer move 时发送发起端计算完成的画布世界坐标包围盒；接收端直接渲染草稿边界。
- 本地绘制预览保持逐 pointer event 更新，网络 `update` 按 25～40ms 节流且每个 session 只保留最新状态。
- 图形创建成功后发送 `commit`，最终正式图形继续通过现有 `createShape` 应用命令和正式协作链路同步。
- 尺寸不足、权限失败、工具切换、页面卸载或创建失败时执行 `reset`，清除远端草稿。
- 多名用户可以同时显示各自绘制草稿；同一用户的并行会话通过不同 `sessionId` 区分。

#### 单图形 resize 过程协作

- resize 开始时发送目标图形、手柄和初始边界；固定锚点可由手柄和初始边界推导。
- resize 更新时发送发起端完成最小尺寸、用户图形归一化和父区域约束后的最终 bounds。
- 远端只在现有 `PreviewLayer` 渲染 resize 边界或半透明代理，不把过程帧写入正式 Store。
- 现有本地 resize 更新逻辑暂时保持不变；正式协作链路必须跳过 `phase: 'live' && intent: 'resize'` 的旧完整图形广播。
- resize 完成后继续通过现有应用命令产生 canonical commit；过程态 `commit` 负责收尾并清理远端预览。
- 目标失效、会话异常、页面卸载或主动中止时执行 `reset`。

#### 框选过程协作

- 框选开始时发送增量选择标记和初始 `bounds`（`mode` 已移除，框选是当前唯一过程态选择方式）。
- 框选更新时只发送当前最新 `bounds`，不发送实时对象列表。
- 框选完成、工具切换或页面卸载时发送 `commit` 或 `reset` 清理远端预览。
- 远端只渲染带用户颜色的框选矩形，不修改本地选择和正式图形状态。

#### 首期通用要求

- 代码 API、画布事件和交互协议统一使用 `start / update / commit / reset`。
- 同一过程会话的所有 `interaction` 数据必须携带相同的 `sessionId`；发送端不携带用户字段，接收端使用后台广播消息中的 `user_info.user_id`。
- `sessionId` 标识一次本地过程交互，是 start/update/commit/reset 分组、乱序判定和远端清理的必需字段。
- 首期过程态协议不要求携带 `operationId`。正式创建和正式 resize commit 继续由现有应用命令独立生成并管理业务 `operationId`。
- `start`、`commit`、`reset` 立即发送；`update` 允许丢帧并只发送最新状态。
- `commit` 和 `reset` 发送前必须丢弃尚未发送的旧 `update`，禁止旧过程帧在会话结束后继续到达远端渲染层。
- 远端过程态不得修改本地选择、工具、interaction、preview 或正式图形 Store。
- leave、断线和 TTL 超时必须清理对应用户的远端会话。

### 4.2 后续总体能力

以下内容属于总体方案目标，不作为当前首期验收范围。

#### 框选正式结果与增强展示

- 框选矩形使用用户固定颜色，并展示用户名或用户简称。
- 框选结束后，协作者能看到远端选区范围、对象数量和必要的对象描边。
- 点击空白、切换工具、主动取消、离开页面或断线时，远端选区能够清理。
- 远端选择不得修改本人的工具栏、属性面板、本地选择和当前编辑对象。
- Ctrl/Meta 增量选择需要在协议中明确表达，不能依赖远端键盘状态推断。

#### 拖拽协作

- 单图形和多图形拖拽过程对其他用户可见。
- 拖拽过程允许丢帧，但最终结果必须一致。
- 多图形拖拽保持整体刚体位移，不能因网络帧到达顺序造成对象相互错位。
- 拖拽涉及子图形、区域、连线或包含关系时，提交态必须包含完整实际影响范围。
- 操作取消时恢复到提交前状态并清理远端预览。

#### resize 协作

- 协作者能看到 resize 类型、操作手柄、锚点和实时目标边界。
- resize 过程不持续写入远端正式 Store。
- 图形最小尺寸、区域子项边界、父区域扩容等约束仍由本地现有规则计算。
- 最终提交以应用命令产出的 canonical 结果为准。

#### 绘制过程协作

- 支持矩形、正方形、椭圆、多边形、开始节点、结束节点、用户节点和区域的绘制草稿同步。
- 连线绘制同步起点、当前点、目标吸附状态和预览路径。
- 绘制过程不得提前创建正式图形。
- 尺寸不足、权限失败、区域失效、按 Esc、工具切换或断线时发送取消语义。
- 多个远端用户的绘制草稿可以同时显示。

#### 通用可靠性

- 消息乱序、重复和丢失不能造成永久错误。
- commit 必须幂等。
- 断线重连后清理旧过程态并恢复最新正式快照。
- 同一对象被多人同时编辑时必须有确定的冲突处理策略。
- 服务端必须校验业务范围、用户权限、操作目标和基础版本。

### 4.3 P1 建议实现

- 远端选区展示“用户 + 已选对象数量”。
- 大选区按规模自动切换渲染策略。
- 远端过程帧通过插值平滑显示。
- WebSocket 堵塞、页面隐藏或设备性能不足时自动降低发送频率。
- 提供消息大小、发送帧率、接收延迟、丢弃旧帧数、选区规模和渲染耗时指标。
- 被其他用户占用的图形展示用户颜色和占用提示。
- 支持服务端拒绝、版本过期和租约失效后的明确用户提示。

### 4.4 总体方案不包含

- 通用撤销重做。
- 长期操作历史审计。
- 离线编辑后自动合并。
- 跨画布或跨业务单据移动对象。
- 将独立逻辑图画布并入本方案。
- 替换现有 WebSocket 技术栈。

## 5. 核心设计原则

### 5.1 过程态与提交态分离

过程态具有以下特征：

- 高频。
- 可被后续帧覆盖。
- 允许丢失中间帧。
- 只影响视觉预览。
- 不进入快照和持久化。

提交态具有以下特征：

- 低频。
- 不允许静默丢失。
- 必须通过现有应用命令生成最终业务变化。
- 必须支持幂等、版本校验和失败恢复。

不得继续使用一个 `needSave` 字段同时承担过程态和提交态的全部语义。

### 5.2 远端交互状态与本地交互状态隔离

本地状态继续使用：

- `selectionStore`：本地选择。
- `interactionStore`：本地交互会话。
- `previewStore`：本地单次预览。
- `shapesStore`、`relationStore`：正式业务状态。

新增远端状态：

```ts
interface RemoteInteractionSession {
  userId: string;
  sessionId: string;
  kind: 'selection' | 'move' | 'resize' | 'drawing' | 'line-drawing';
  updatedAt: number;
  payload: unknown;
}
```

远端会话按 `userId + sessionId` 存储。`sessionId` 必须使用 `nanoid` 或 UUID 一类高随机唯一值，避免同一用户并行会话冲突。远端状态不得反向修改本地选择、工具和属性面板。

### 5.3 实时帧使用可覆盖状态，不使用操作增量队列

实时帧表示“当前最新状态”。发送端在节流窗口内只保留最后一次 `update`，`commit/reset` 前取消尚未发送的 update。首期复用同一 WebSocket 广播链路的消息顺序，不另外引入序号、对账或重放框架。

拖拽帧统一表达相对会话起点的总位移：

```ts
{ dx: 120, dy: -30 }
```

不能表达为“相对上一帧再移动 3px”，否则丢帧会导致永久偏差。

### 5.4 正式结果与过程会话分离

首期过程态协作与正式创建、正式 resize 提交独立实现，不强制共用 `operationId`：

1. 过程态在发送端使用 `sessionId` 标识会话，接收端使用后台广播附加的 `user_info.user_id + sessionId` 作为唯一键。
2. 正式业务变化继续通过现有应用命令、事务和 `OPERATION_SYNC` 同步。
3. 过程 `commit/reset` 只删除远端预览，不与正式图形做额外对账。
4. 最终一致性仍完全由现有正式协作消息保证。

只有后续需要服务端租约、业务提交幂等查询，或必须把过程预览与 canonical 消息精确关联时，才在新协议版本中增加可选 `operationId`。不能仅为复用名称而把过程 session 与业务事务绑定。

## 6. 协作协议设计

### 6.1 协议版本

复用现有 `type: 'drag'` 消息和服务端广播链路，在 `handleData` 中增加可选的 `selection` 和 `interaction` 字段：

```ts
interface DragMessage<TPayload = unknown> {
  type: 'drag';
  data: {
    module: 'icce';
    business_id: number | string;
    user_info?: {
      user_id?: number | string;
    }; // 仅后台广播时附加
    handleData: {
      add?: unknown[];
      modify?: unknown[];
      delete?: unknown[];
      selection?: {
        shapeIds: string[];
        lineIds: string[];
      };
      interaction?: {
        kind: 'shape-drawing' | 'shape-resize' | 'shape-move' | 'selection';
        phase: 'start' | 'update' | 'commit' | 'reset';
        sessionId: string;
        // 过程预览直接携带所需的 bounds、坐标或图形类型
      };
    };
  };
}
```

过程消息发送时不携带 `user_id` 或 `user_info`，后台广播时会自动附加 `data.user_info`，接收端只取其中的 `user_id`。`selection` 是当前用户级选中状态快照，不使用 `sessionId`，每次发送完整的图形 ID 和连线 ID；空数组表示明确清空远端选区。`interaction` 是单个过程消息对象。`handleData` 使用稀疏结构，只保留当前消息实际需要的字段；正式回放器只读取存在的 `add`、`modify`、`delete` 数组，过程态和选中态分别在进入正式回放器前处理。

协议编码出口统一规范过程态几何：包围盒的坐标与尺寸、移动总位移均四舍五入为整数。该规则只约束传输数据，不要求本地指针事件和约束计算过程提前丢失精度。

字段说明：

| 字段                | 说明                                       |
| ------------------- | ------------------------------------------ |
| `user_info.user_id` | 后台广播时附加的用户 ID，仅接收端使用。    |
| `sessionId`         | 一次 pointer down 到结束或取消的交互会话。 |
| `kind`              | 交互类型。                                 |
| `phase`             | 生命周期阶段。                             |
| `selection`         | 当前远程用户的选中图形 ID 和连线 ID 快照。 |

首期代码 API、画布事件和协议 phase 使用相同命名，不额外维护 `begin/frame/cancel` 转换层：

| API      | 协议 phase | 语义                                             |
| -------- | ---------- | ------------------------------------------------ |
| `start`  | `start`    | 建立会话并发送推导后续状态所需的初始数据。       |
| `update` | `update`   | 发送相对本次会话起点的当前最新状态。             |
| `commit` | `commit`   | 正常完成过程会话；正式业务结果仍由应用命令同步。 |
| `reset`  | `reset`    | 清除未完成过程态；不表达正式业务数据回滚。       |

`selection` 不属于 `start/update/commit/reset` 过程会话。它表达远程用户当前的选中状态，直接由本地 `selectionStore` 的变化驱动发送完整 ID 快照；空快照也必须发送。框选过程只发送 `interaction` 包围盒，框选开始时本地清空选区产生的变化可以直接同步，框选完成后 Store 更新为最终合并结果。远端不根据 `additive` 或包围盒再次推导选区。

### 6.2 生命周期

所有过程态交互遵循统一状态机：

```text
idle
  → start
  → update × N
  → commit → wait for canonical result or timeout → cleanup
  → reset → cleanup
```

异常清理：

```text
disconnect / leave / lease timeout / version rejected
  → reset or expire
  → cleanup
```

接收端规则：

- 未收到 start 但先收到 update 时，首期直接丢弃该 update；绘制 update 缺少图形类型和起点，无法可靠重建草稿。
- 已提交或已重置的 session 不再接收 update。
- 相同 `userId + sessionId` 的重复 commit 只处理一次。
- 超过 TTL 未更新的远端 session 自动过期。

选中状态接收规则：

- 收到 `selection` 时只更新对应用户的远端选中状态，不写入本地 `selectionStore`。
- `shapeIds` 和 `lineIds` 均为空时，删除该用户的远端选中状态。
- 远端选中状态按用户保存，不使用过程 `sessionId`；同一用户的新快照覆盖旧快照。
- 选中状态不是高频过程帧，不使用过程态 TTL；通过显式空快照、用户离开和断线清理。

## 7. 框选协作设计

### 7.1 框选过程

interaction 的 `selection` kind 只服务「有过程态的选择方式」，当前唯一即框选；点选（单击，无过程态）直接更新选中集，由 `selection-store` 监听经 `handleData.selection` 同步（见 7.2）。

start 发送增量选择标记和初始包围盒：

```ts
interface SelectionStartPayload {
  additive: boolean;  // 增量选择（Ctrl/Cmd 按下 = 追加选中）；mode 已移除
  bounds: { x: number; y: number; width: number; height: number };
}
```

update 只发送当前边界：

```ts
interface SelectionUpdatePayload {
  bounds: { x: number; y: number; width: number; height: number };
}
```

框选过程中原则上不需要持续计算并广播成员列表。需要显示实时数量时，本地最多每 100～150ms 查询一次，数量更新可以和边界帧合并发送。

### 7.2 最终选中状态

本地 `selectionStore` 发生变化后，发送当前用户的完整选中状态快照：

```ts
interface SelectionStatePayload {
  shapeIds: string[];
  lineIds: string[];
}
```

追加框选由本地 `selectionStore` 完成合并，监听到 Store 变化后直接发送合并后的 ID 列表；不新增选择事务、选择提交事件或专门的选择同步服务。远端不根据 `additive` 或包围盒重新推导成员。

选中状态同步不依赖过程会话结束。单击、框选、快捷键、树节点和对话框等所有本地入口只要改变 `selectionStore`，都由统一监听发送当前快照；过程态仍由交互事件单独发送。发送前按当前快照去重并使用已有协作分发节流即可，不为选中状态增加高频过程帧。

远端渲染时按 ID 从本地正式图形和连线 Store 获取当前几何，因此对象移动、resize 或正式删除后，远端选中轮廓可以跟随最新正式状态。找不到对象时跳过该轮廓，不写入本地正式 Store。

不建议把完整业务对象作为远端选中态的长期数据源，也不建议让接收端只根据 bounds 重新计算选区成员，因为不同客户端可能处于不同业务版本、权限范围或包含关系状态，结果不具确定性。

### 7.3 清空和切换

以下动作导致 `selectionStore` 为空时，必须发送空的 `selection` 状态：

- 点击画布空白并清空选择。
- 切换到不保留选择的工具。
- 本地删除全部已选对象。
- 页面卸载或离开协作房间。
- 用户主动取消选择。

框选过程本身仍使用 `phase: 'reset'` 清除临时框选预览；最终选中态通过空的 `selection` 快照清除。用户离开或断线时，接收端同时清理该 `userId` 的过程预览和最终选中态。

### 7.4 远端展示

- 远端选中态统一放入 `PreviewLayer`，不修改 `SelectionLayer` 的本地交互逻辑。
- 普通图形复用本地形状轮廓规则，使用远端用户颜色描边。
- 多选非区域图形同步显示与本地选区一致的整体包围盒；单个图形继续显示自身轮廓。
- 区域显示远端颜色的边框，可使用低透明度填充。
- 连线显示远端颜色的线条，不显示端点重连手柄。
- 所有远端选中节点都设置 `listening: false`，不创建 resize 手柄、不允许拖拽、不响应双击。
- 多名用户可以同时显示各自的远端选中态，节点 key 使用 `userId + 对象类型 + 对象 ID`。
- 首期按对象 ID 渲染；超大选区后续再引入 `selectionRef`、数量和整体 bounds 作为降级展示。

### 7.5 统一视觉渲染

- `canvas-visual-config.ts` 是统一的临时视觉配置入口，负责按图形、连线和包围盒生成 Konva 配置。
- `CanvasVisualNode.vue` 只负责把视觉配置映射为图形节点，不包含业务状态和交互事件。
- `SelectionLayer` 和 `PreviewLayer` 共享同一套几何与样式生成逻辑；前者保留本地选中、拖拽和 resize 手柄，后者只渲染不可命中的本地预览和远端临时态。
- 远端绘制、resize、框选和选中态统一使用包围盒或对象几何配置，不再在 `PreviewLayer` 中维护独立的图形模板。

## 8. 拖拽协作设计

### 8.1 当前已实现协议

当前移动过程态复用正式画布中的图形编号，不引入服务端选区注册：

```ts
type ShapeMoveInteraction =
  | {
      kind: 'shape-move';
      phase: 'start';
      sessionId: string;
      shapeIds: string[];
      delta: { x: number; y: number };
    }
  | {
      kind: 'shape-move';
      phase: 'update';
      sessionId: string;
      delta: { x: number; y: number };
    };
```

`delta` 始终表示相对会话起点的总位移。远端使用开始消息保存的图形编号，从正式 Store 读取基础几何并叠加最新位移；多图形时额外计算移动后联合包围盒。`commit/reset` 只清除过程预览，正式结果继续由应用命令和事务同步。

### 8.2 目标增强协议：开始拖拽

```ts
interface MoveBeginPayload {
  transformType: 'move';
  selectionRef?: string;
  targetIds?: string[];
  targetCount: number;
  baseBounds: { x: number; y: number; width: number; height: number };
  baseRevision: number;
}
```

start 阶段完成：

1. 确认操作目标。
2. 服务端权限校验。
3. 申请编辑租约。
4. 固定会话起始边界和版本。
5. 接收端建立远端预览。

### 8.3 目标增强协议：实时拖拽

```ts
interface MoveFramePayload {
  dx: number;
  dy: number;
}
```

`dx/dy` 是相对于 start 起点的总位移，不是相对上一条 update 的增量。

实时帧不得携带：

- 全部图形完整数据。
- 每个图形重复的绝对坐标。
- 图形业务 `data`。
- 已能从 selectionRef 和基础快照推导的包含关系数据。

### 8.4 目标增强协议：拖拽提交

commit 表达用户确认结束交互：

```ts
interface MoveCommitPayload {
  selectionRef?: string;
  dx: number;
  dy: number;
  finalSeq: number;
  baseRevision: number;
}
```

最终业务变更仍由应用命令执行，必须包含实际受影响的：

- 图形。
- 区域及其子项。
- 关联连线。
- 包含关系。
- 由区域扩张或业务规则引起的间接变化。

过程态只负责视觉协作，不能替代现有领域规则和应用命令。

## 9. resize 协作设计

### 9.1 resize start

```ts
interface ShapeResizeStartPayload {
  shapeId: string;
  handle:
    | 'top-left'
    | 'top-center'
    | 'top-right'
    | 'middle-left'
    | 'middle-right'
    | 'bottom-left'
    | 'bottom-center'
    | 'bottom-right';
  initialBounds: { x: number; y: number; width: number; height: number };
}
```

`sessionId` 在 resize start 时生成并写入本地 `ShapeResizeMeta`，供过程消息分组。正式 resize commit 的业务 `operationId` 继续由现有应用事务管理，两者不强制相同。

### 9.2 resize update

```ts
interface ShapeResizeUpdatePayload {
  bounds: { x: number; y: number; width: number; height: number };
}
```

`update` 中的 bounds 必须是发起端执行完图形尺寸约束、用户图形归一化和现有边界规则后的结果。远端只渲染目标边界和半透明图形预览，不写正式 Store，也不重复推导区域扩容和包含关系。

本地 resize 仍可按当前逻辑更新本地 Store 以保持交互行为不变，但 `useCollabSync` 必须阻止下列旧过程帧进入正式协作发送：

```ts
payload.phase === 'live' && payload.meta.intent === 'resize';
```

这类过程状态改由 `shape-resize/update` 消息发送，避免远端正式 Store 被 live 数据持续改写。

### 9.3 resize commit/reset

- `commit` 前丢弃 `useCollabSync` 中尚未发送的旧 update。
- 本地应用命令计算最终图形、区域、连线和关系变化，继续通过既有 `OPERATION_SYNC` 正式链路广播 canonical 结果。
- 过程态 commit 携带 `shapeId` 和最终 bounds，用于远端会话收尾；正式图形仍以 canonical 消息为准。
- 目标失效、会话异常或页面卸载时执行 `reset`，立即清除远端过程态。
- 后续接入租约和基础版本后，服务端拒绝时同样执行 reset，并恢复最新正式快照。

## 10. 图形绘制过程协作

### 10.1 普通图形拖拽绘制

start：

```ts
interface ShapeDrawingStartPayload {
  shapeType: 'rect' | 'rect-square' | 'ellipse' | 'polygon' | 'start' | 'end' | 'user';
  bounds: { x: number; y: number; width: number; height: number };
  containingRegionId?: string;
}
```

update：

```ts
interface ShapeDrawingUpdatePayload {
  bounds: { x: number; y: number; width: number; height: number };
}
```

绘制过程发送发起端计算完成的画布世界坐标包围盒，不发送浏览器 `clientX/clientY`。接收端根据 `shapeType + bounds` 直接渲染草稿，不重复计算绘制约束。

本地 `pointermove` 每次立即更新，网络 update 按 25～40ms 节流，并只保留当前 session 的最新 `bounds`。

pointer up 后先执行现有 `createShape` 应用命令：

- 创建成功：发送 `commit`，最终图形继续走正式协作链路。
- 尺寸不足、权限失败、区域失效或创建失败：执行 `reset`。
- 工具切换、页面卸载或其他异常中断：执行 `reset`。

绘制 start 只要求生成并保存过程 `sessionId`。正式 `createShape` 的业务 `operationId` 可以继续在 pointer up 确认创建时生成；创建失败或尺寸不足的过程会话不会产生正式业务事务。

### 10.2 区域绘制

区域草稿需要额外表达：

- 与已有区域是否存在冲突。
- 当前草稿是否已达到最小尺寸。
- 等待用户填写区域信息的状态。

区域绘制抬起后如果仍需弹窗确认，远端草稿可进入 `pending-confirmation` 展示状态；用户取消弹窗后清除，确认后由正式区域替换。

### 10.3 连线绘制

连线 start 表达起点：

```ts
interface LineDrawingStartPayload {
  startShapeId: string;
  startEdge?: string;
  startBoundaryPosition?: number;
  startPoint: { x: number; y: number };
  lineType: string;
}
```

update 表达：

- 当前路径 points。
- 当前悬停目标图形。
- 吸附边和边界位置。
- 箭头和虚线等最小预览样式。

commit 后仍由连线创建应用命令生成 canonical 连线，远端不得根据预览自行创建正式连线。

## 11. 超大数据量设计

### 11.1 目标复杂度

当前模式：

```text
O(N × F × 完整对象大小)
```

目标模式：

```text
选区声明：O(N) 一次，或 selectionRef 下 O(1)
过程帧：O(F)，每帧 O(1)
提交：一次批量业务变更
```

以 10,000 个图形拖拽 3 秒为例，当前 60FPS 模式最多可能产生约 180 万条图形记录。目标模型只产生一次选区声明、约 60～90 个固定大小位移帧和一次提交。

### 11.2 selectionRef

推荐服务端提供短生命周期选区注册：

```text
registerSelection(ids, baseRevision, selectionHash)
  → selectionRef + count + bounds + expiresAt
```

selectionRef 用于：

- 后续拖拽和冲突租约的目标解析。
- 服务端权限校验。
- 最终批量位移。
- 断线清理。
- 防止客户端伪造无权限对象。

selectionRef 应与以下范围绑定：

- `businessId`。
- `diagramType`。
- `userId`。
- `baseRevision`。

默认 TTL 建议为 30～60 秒，活跃 transform update 可续期。

### 11.3 无服务端 selectionRef 时的兼容方案

如果第一阶段不能修改服务端：

1. start 对 ID 进行分片发送。
2. 每片建议包含 500～1000 个 ID，以实际消息限制为准。
3. 所有片携带 `selectionId`、`chunkIndex`、`chunkCount` 和 `selectionHash`。
4. 接收端完成分片校验前只展示整体包围框。
5. 后续 update 仍只发送 `selectionId + dx/dy`。
6. 分片超时或哈希不一致时请求重发或降级为仅展示包围框。

该方案只是过渡方案，无法完整提供服务端目标锁定和高效批量提交。

### 11.4 框选空间索引

超大画布必须增加空间索引：

- 图形以 stage bounds 建立 R-tree 或等价二维索引。
- 连线维护渲染包围盒索引。
- 图形新增、移动、resize 和删除时增量更新索引。
- 框选结束时先通过索引查询候选，再执行精确相交判断。
- 框选过程中原则上不查询全部成员；需要实时数量时降低查询频率。

空间索引是只读查询基础设施，不包含选择权限和业务规则。候选结果仍需通过现有图类型选择策略过滤。

### 11.5 分档渲染

初始建议阈值如下，最终以性能测试数据调整：

|    选区规模 | 本地选择展示            | 远端选择展示            | 拖拽过程                   |
| ----------: | ----------------------- | ----------------------- | -------------------------- |
|     `≤ 200` | 每个对象描边 + 整体边界 | 每个对象描边 + 用户标识 | 实体或节点组预览           |
| `201～2000` | 整体边界，减少对象描边  | 整体边界 + 数量         | Konva 临时 Group transform |
|    `> 2000` | 整体边界 + 数量         | 整体边界 + 数量         | 包围框或低成本轮廓代理     |

超大选区拖拽过程中不得逐个更新 Pinia `Map`。渲染方式应为：

```text
正式 Shape Store
  → MainLayer 正式节点保持不变
  → Collaboration / Interaction Layer 应用临时 transform
  → commit 后批量写正式 Store
  → 清除临时 transform
```

对于本地中等规模选区，可以通过 Konva 节点注册表对选中节点应用一次 Group transform。对于超大选区，直接展示包围框或缓存轮廓，不移动全部实体节点。

### 11.6 Vue 状态性能

- 远端 session 集合使用 `shallowRef<Map<string, RemoteInteractionSession>>`。
- 大 ID 集合保持非深响应式，禁止对每个 ID 建立 Vue 代理。
- 选择变化通过递增 `selectionVersion` 或稳定哈希驱动，不通过 `join(',')` 监听全部 ID。
- 大选区不创建每个图形的 computed 描边配置。
- Store 批量提交应一次替换或分帧批处理，避免一万次独立响应式通知。
- 只在确实需要 UI 展示时把 `Set` 转为数组。

### 11.7 发送频率和背压

建议默认策略：

- 普通过程态：30FPS。
- 选区超过 2000：20FPS。
- 页面隐藏：5～10FPS 或暂停 update，只保证最终 commit。
- `WebSocket.bufferedAmount` 超过阈值：降低到 10FPS，并只保留最新帧。
- commit 前处理最新 update。
- 不排队重放已经过时的 update。

目标是单个 update 不超过 1～2KB，且 update 大小不随选中对象数增长。

## 12. 冲突处理

### 12.1 策略结论

采用“选择自由、编辑加租约”：

- 多名用户可以同时选中同一对象。
- move 和 resize 开始前申请编辑租约。
- 同一对象不能同时属于两个活跃 transform 租约。
- 不重叠对象可以并行操作。
- drawing 通常无需对象租约，但必须校验目标区域版本和创建权限。

仅依赖客户端最后写入覆盖无法保证批量拖拽正确性，不作为正式方案。

### 12.2 租约

租约建议包含：

```ts
interface InteractionLease {
  leaseId: string;
  operationId: string;
  selectionRef?: string;
  targetIds?: string[];
  userId: string;
  baseRevision: number;
  expiresAt: number;
}
```

- 初始租约有效期建议 10 秒。
- 收到合法 update 时续期。
- commit、reset、leave 和断线时释放。
- 租约冲突时服务端拒绝 start，发起端重置本地预览并提示占用用户。

### 12.3 冲突场景

| 场景                           | 处理                                 |
| ------------------------------ | ------------------------------------ |
| 两人同时选择同一对象           | 允许，分别显示用户颜色。             |
| 两人同时拖拽相交选区           | 后申请者被拒绝。                     |
| 一人拖拽、一人 resize 同一对象 | 后申请者被拒绝。                     |
| 远端删除本地正在编辑对象       | 立即取消本地操作并同步最新数据。     |
| commit 时 `baseRevision` 过期  | 拒绝提交，清除过程态并刷新最新快照。 |
| 重复 commit                    | 按 `operationId` 幂等返回原结果。    |
| commit 先于旧 update 到达      | 应用 commit 并忽略后续旧 update。    |
| 操作期间用户断线               | 租约超时释放，过程态过期清理。       |

## 13. 断线、超时和恢复

- 每个远端过程态记录 `updatedAt`。
- selection 建议 30 秒无更新后过期，transform 和 drawing 建议 10～15 秒无更新后过期。
- 收到 leave 时立即清理该 `userId` 的所有过程态；当前无法区分同一用户的不同连接。
- WebSocket 重连后不恢复旧 pointer session。
- 重连流程先清理本地和远端过程态，再同步最新正式快照和当前在线用户状态。
- 本地存在未确认 commit 时，可以按 `operationId` 向服务端查询提交结果，不得盲目重复执行非幂等操作。

## 14. 权限和安全

- 过程数据不在 `interaction` 内携带用户信息；接收端只使用后台广播附加的 `data.user_info.user_id`。
- 服务端不能信任客户端发送的 targetIds、selectionRef、baseRevision 和最终 bounds。
- start 阶段校验查看与编辑权限。
- commit 阶段再次校验权限、租约、业务范围和基础版本。
- selectionRef 只能由创建它的用户用于编辑申请，广播展示可使用脱敏摘要。
- 不向无查看权限的用户广播对象 ID、业务 data 或选择详情。
- 过程态只携带渲染所需最小数据，不能携带完整业务对象。
- 坐标、尺寸、对象数量、ID 数量和消息大小必须设置上限。

## 15. 前端模块设计

建议新增：

```text
src/views/icce/infrastructure/collaboration/
└── drag-message-codec.ts

src/views/icce/infrastructure/stores/
├── remote-interaction-store.ts
└── remote-selection-store.ts

src/views/icce/ui/collaboration/
└── useCollabSync.ts

src/views/icce/ui/canvas/
├── canvas-visual-config.ts
└── selection/
    ├── LineEndpointOverlay.vue
    ├── LineSelectionOverlay.vue
    ├── SelectionHighlightOverlay.vue
    └── SelectionLayer.vue

src/views/icce/ui/components/layers/
├── CanvasVisualNode.vue
└── PreviewLayer.vue
```

模块职责：

| 模块                       | 职责                                                               |
| -------------------------- | ------------------------------------------------------------------ |
| `drag-message-codec`       | 编码选中状态和单个轻量过程对象，规范过程几何并省略空协议字段。     |
| `remote-interaction-store` | 以 `userId + sessionId` 保存远端过程预览。                         |
| `remote-selection-store`   | 以 `userId` 保存远端用户当前的图形和连线选中 ID。                  |
| `useCollabSync`            | 处理选中状态和过程消息的节流、发送、接收及远端 Store 更新。        |
| `canvas-visual-config`     | 统一生成图形、连线、选中轮廓和包围盒的纯视觉配置。                 |
| `CanvasVisualNode`         | 将统一视觉配置映射为非交互的图形节点。                             |
| `PreviewLayer`             | 渲染本地过程预览、远端过程预览和远端选中轮廓；远端节点不响应命中。 |
| `SelectionLayer`           | 渲染本地选中态及缩放、拖拽等交互手柄；保留本地交互职责。           |

现有 `useCollabSync` 同时作为协作传输入口：继续处理正式业务变化同步，并直接订阅 `INTERACTION_SYNC` 画布事件。接收远端 `selection` 后只更新 `remote-selection-store`；接收远端 `interaction` 后只更新 `remote-interaction-store`，两者均不进入 `canvas-replay-applier`。

完整链路：

```text
selectionStore / shape-draw.tool / shape-drag-interaction / selection-resize-interaction
  → CANVAS_EVENTS.INTERACTION_SYNC
  → useCollabSync
  → drag.handleData.selection / interaction
  → WebSocket transport（后台原通道广播）
  → useCollabSync remote subscription
  → remoteSelectionStore / remoteInteractionStore
  → PreviewLayer
```

## 16. 现有交互接入点

| 能力                     | 接入位置                                     | 发送时机                                                             |
| ------------------------ | -------------------------------------------- | -------------------------------------------------------------------- |
| 框选                     | `pointer-interaction.ts`、`selection-box.ts` | start、bounds update、commit、reset。                                |
| 单选/多选结果            | `selection-store.ts`、`useCollabSync.ts`     | 监听 Store 变化，发送完整选中状态快照和空选区清理。                  |
| 拖拽                     | `shape-drag-interaction.ts`                  | move session 开始、最新位移、提交、取消。                            |
| 单图形 resize（首期）    | `selection-resize-interaction.ts`            | start、约束后 bounds update、canonical 提交后的 commit、异常 reset。 |
| 普通图形拖拽绘制（首期） | `shape-draw.tool.ts`                         | start、bounds update、创建成功 commit、失败或中断 reset。            |
| 区域绘制                 | `region.tool.ts`                             | 草稿开始、bounds 更新、待确认、确认或取消。                          |
| 连线绘制                 | `line.tool.ts` 及连线交互模块                | 起点、预览路径、吸附目标、创建或取消。                               |

交互模块只发布轻量过程事件，选择状态由 `selectionStore` 监听提供；两者都不直接调用 WebSocket。`useCollabSync` 统一负责节流、发送和接收，首期不再拆分 publisher、dispatcher 或 applier。

## 17. 服务端能力

正式方案需要服务端支持：

1. 现有 `drag.handleData` 消息的路由和广播，并在广播 data 中附加可信的 `user_info.user_id`。
2. 过程协议的 `sessionId` 范围校验，以及正式业务提交的 `operationId` 校验。
3. selectionRef 注册、查询、续期和释放。
4. transform 编辑租约。
5. `baseRevision` 校验。
6. commit 幂等。
7. 超大批量位移的服务端原子提交。
8. leave、断线和超时清理。
9. 旧客户端兼容策略和协议版本拒绝逻辑。

如果服务端暂时只做消息转发，可以先实现远端过程展示和客户端 ID 分片，但不得把该阶段宣称为已完成冲突安全和超大批量原子提交。

## 18. 兼容与迁移

### 18.1 双协议阶段

- 既有 `drag` 协议继续负责正式 add/modify/delete 数据同步。
- `handleData.interaction` v1 负责绘制、resize、框选和图形移动过程态。
- 新增 `handleData.selection` 负责当前用户级选中状态快照。
- 既有 `select` 完整对象载荷已停止发送并从当前客户端协议类型中移除；接收旧消息时忽略该遗留字段。
- 当前客户端发送消息时省略空的正式操作数组，接收端仍按可选数组兼容旧消息。
- 新客户端收到旧消息时继续按现有逻辑回放正式变化。
- 旧客户端忽略未识别的 `handleData.selection` 和新增过程消息，只看不到远端选中态或过程预览，但仍能看到最终提交结果。

### 18.2 后续收敛

服务端批量 transform commit 稳定后，再评估是否减少 live `modify` 正式快照发送。不得同时发送完整 live modify 和 transform update，避免远端重复渲染与状态抖动。

## 19. 实施阶段

### 阶段一：普通图形拖拽绘制过程协作

- 新增 interaction message 和轻量远端预览 Store，过程消息直接在 `useCollabSync` 中处理。
- 远端草稿直接复用 `PreviewLayer`，不新增协作专用 Layer。
- `shape-draw.tool.ts` 接入 start/update/commit/reset。
- start 发送图形类型和初始 bounds，update 发送最新 bounds，接收端直接渲染包围盒。
- 图形创建结果继续复用现有应用命令和正式协作链路。
- 补齐创建失败、尺寸不足、工具切换、页面卸载、断线和 TTL 清理。

### 阶段二：单图形 resize 过程协作

- `selection-resize-interaction.ts` 接入 start/update/commit/reset。
- update 发送约束后的 bounds，远端只渲染边界或半透明代理。
- `useCollabSync` 停止发送 resize live 的旧正式 modify 消息。
- resize canonical commit 继续复用现有应用命令和正式协作链路。
- 补齐目标失效、页面卸载、断线和 TTL 清理。

### 阶段三：区域、连线和其他绘制过程协作

- 接入区域绘制与待确认状态。
- 接入连线绘制路径、吸附目标和箭头样式。
- 接入区域 resize，并处理子项边界与父区域规则。

### 阶段四：框选与选区协作

- 支持框选矩形、`selection` 状态快照、用户颜色和 reset。
- 新增 `remote-selection-store`，按用户保存图形和连线选中 ID。
- 在 `PreviewLayer` 渲染远端图形轮廓、区域边框和连线轮廓，不创建交互手柄。
- 修复空选择不广播问题，空的 `shapeIds/lineIds` 明确清除远端选中态。
- 追加框选由本地选区完成合并，远端只接收合并后的最终 ID 快照。
- 远端选择与本地 `selectionStore` 隔离。

### 阶段五：拖拽 transform 协作

客户端轻量过程协议、远端独立预览 Store、图形轮廓与联合包围盒展示已落地；服务端选区注册、租约和超大选区降级仍待实现。

- start 声明目标，update 只发送总位移。
- 中小选区使用临时 Group transform。
- commit 后用正式数据替换过程态。
- 禁止继续发送逐对象完整 live modify。

### 阶段六：超大选区

- 增加 selectionRef 或 ID 分片过渡方案。
- 增加空间索引。
- 增加分档选择和拖拽渲染。
- 增加批量 Store 写入和服务端原子位移。
- 完成 1千、1万、5万对象专项压测。

### 阶段七：冲突和可观测性

- 接入编辑租约、版本拒绝和幂等查询。
- 增加协作调试指标和错误提示。
- 验证断线、乱序、丢帧、重复消息，以及同一用户多个 session 的场景。

## 20. 验收标准

### 20.1 功能验收

- 两名以上用户可同时看到彼此的框选、拖拽、resize 和绘制过程。
- 远端选区不影响本地属性面板、工具和选择状态。
- reset、leave、断线和超时均能清理过程态。
- 单图形、多图形、区域、子项和关联连线的最终结果一致。
- 同目标并发编辑被确定性拒绝，不出现静默覆盖。
- 过程帧丢失不影响最终结果。
- 乱序和重复消息不造成倒退或重复提交。

### 20.2 性能验收

建议目标：

- 10,000 图形框选结束查询不超过 200ms。
- 10,000 图形选区拖拽本地交互平均保持 50FPS 左右。
- 过程 update 大小不随选区规模增长，单条不超过 2KB。
- 正常网络下远端过程态视觉延迟低于 150ms。
- 丢失 30% 中间 update 时，远端仍能平滑接近最新状态且最终一致。
- 超大选区不生成等量的 Vue computed 描边和逐对象实时 Store 写入。
- WebSocket 堵塞时内存队列保持有界，只保留最新过程帧。

具体阈值需在目标硬件、目标浏览器和真实业务图数据上复测后固化。

### 20.3 测试范围

测试统一使用 Vitest，并放在 `src/views/icce/tests` 下对应目录：

```text
tests/infrastructure/stores/
└── remote-interaction-store.spec.ts

tests/ui/collaboration/
└── useCollabSync.spec.ts

tests/ui/tools/
├── selection-collab.spec.ts
├── transform-collab.spec.ts
├── resize-collab.spec.ts
└── drawing-collab.spec.ts
```

必须覆盖：

- start/update/commit/reset 正常状态流转。
- start/update/commit/reset 的发送、节流和预览清理。
- 选中状态快照的发送、远端用户隔离、空选区清理和远端轮廓渲染数据。
- 多用户和同一用户多个 session；多标签页只能验证 TTL 兜底，当前不保证精确 leave 清理。
- 空选择清理。
- 大 ID 分片和哈希失败。
- 租约拒绝、超时和断线释放。
- 1千、1万、5万对象的性能基准。
- commit 失败后的回滚和快照恢复。

## 21. 风险与待确认项

### 21.1 需要产品确认

- 远端选择是展示全部对象描边，还是默认只展示整体边界。
- 同一对象被占用时是完全禁止操作，还是允许发起抢占确认。
- 区域绘制等待弹窗确认期间，远端是否持续显示草稿。
- 超大选区拖拽时，本地是否允许只显示包围框代理。
- 远端用户名称、颜色和操作数量的展示形式。

### 21.2 需要服务端确认

- 单条 WebSocket 消息大小限制。
- 是否会校验或过滤 `handleData.interaction`；当前按后台原样广播设计。
- 是否能提供 selectionRef 和批量 transform 原子接口。
- 当前业务数据 revision 来源及粒度。
- 幂等 operationId 的保留时间。
- 连接断开检测和租约释放时机。

### 21.3 技术风险

- Konva 临时 Group transform 与现有层级、区域裁剪、富文本和连线渲染的兼容性。
- 大批量正式提交后 Store 和 MainLayer 的一次性重渲染峰值。
- 旧协议与新过程态同时广播导致重复视觉更新。
- 图形包含关系和区域推动造成实际影响范围大于初始选区。
- 客户端版本不同导致 preview 规则不一致，最终必须以 canonical 提交为准。

## 22. 最终约束

1. 过程态不能进入正式业务 Store。
2. 远端选择不能复用本地 `selectionStore`。
3. 多用户远端草稿不能复用单值 `previewStore`。
4. 超大拖拽 update 不能携带每个图形完整数据。
5. update 必须表达相对会话起点的最新总状态。
6. commit 必须通过现有应用命令和事务产生最终结果。
7. 同目标变更必须有服务端租约或等价的确定性冲突策略。
8. 选择成员必须由 ID、selectionRef 或经校验的分片确定，不能只靠远端重新框选推断。
9. 远端过程态必须支持超时、leave、断线和 reset 清理。
10. 新协议必须独立版本化，不能在旧直接回放协议上形成混合语义。
