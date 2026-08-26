---
title: React Query 与 Axios 查询缓存架构
type: design
status: current
date: 2026-08-24
updated: 2026-08-24
project: Expo
owner: 待补充
source_repo: expo-learning
source_ref: 当前工作区未提交状态
related:
  - "[[MOC]]"
  - "[[Expo学习计划与进度]]"
---

# React Query 与 Axios 查询缓存架构

> 当前结论：Task App 使用 Axios 负责 HTTP 通信，使用 TanStack Query 管理服务端状态；`queryKey` 是客户端缓存中一份服务端数据的身份标识，不等同于接口地址，也不按 `create/update/delete` 机械建模。查询键应围绕可缓存的数据和查询场景组织，写操作成功后根据受影响的查询范围执行精确或前缀失效。

## 文档职责

本文是 Expo Task App 中 Axios、React Query 和 Query Key 设计知识的独立事实来源，记录稳定的概念边界、键层级和缓存失效规则。学习计划只维护阶段进度和后续安排，项目入口只维护导航，不重复保存本文正文。

## 一、分层职责

```text
页面组件
  ↓ 展示数据、触发操作
业务 Hook
  ↓ 组合查询、Mutation、加载和错误状态
API 层
  ↓ 定义任务接口和请求参数
Axios 客户端
  ↓ 基础地址、超时、认证请求头、统一错误处理
服务端
```

- `api/client.ts`：创建 Axios 实例，集中处理基础地址、超时、请求头和错误转换。
- `api/task-api.ts`：定义任务列表、创建、更新和删除接口，不承担 React 状态。
- `hooks/use-tasks.ts`：组合 `useQuery`、`useMutation` 和 Query Client，向页面暴露业务动作和状态。
- `lib/query-client.ts`：配置全局 Query Client，例如默认缓存时间和重试策略。
- Query Key 定义：描述任务查询的缓存身份，不属于 React Hook 本身；小项目可放在 `lib`，业务特性目录成熟后应与任务模块一起维护。

## 二、Server State 与 Client State

- 任务列表、任务详情、任务统计属于 Server State：数据来源于远程服务端，需要缓存、重新获取、失效和同步。
- 输入框内容、弹窗显示、当前选中的筛选项属于 Client State：由当前界面控制，不应放入 React Query。
- React Query 不是 `useState` 的替代品，而是处理异步远程数据生命周期的工具。

## 三、Query Key 的定义

`queryKey` 是 Query Cache 中一份服务端数据的主键。它负责：

- 定位缓存；
- 在多个组件之间共享数据；
- 对相同查询去重；
- 标识哪些查询需要重新获取；
- 支持按前缀批量失效。

它不等同于 HTTP 地址：

```text
["tasks", "list"] → 客户端缓存身份
taskApi.list()     → 实际请求方式
GET /tasks         → 服务端接口地址
```

## 四、Query Key 的层级设计

任务查询键采用资源、查询类型、查询参数的层级：

```ts
export const taskKeys = {
  all: ["tasks"] as const,
  lists: () => [...taskKeys.all, "list"] as const,
  list: (params: TaskListParams = {}) =>
    [...taskKeys.lists(), params] as const,
  details: () => [...taskKeys.all, "detail"] as const,
  detail: (id: number) =>
    [...taskKeys.details(), id] as const,
  stats: () => [...taskKeys.all, "stats"] as const,
};
```

对应关系：

```text
["tasks"]
  └── 所有任务相关查询的命名空间

["tasks", "list"]
  └── 所有任务列表查询

["tasks", "list", { completed: false }]
  └── 未完成任务列表

["tasks", "detail", 10]
  └── 编号为 10 的任务详情

["tasks", "stats"]
  └── 任务统计数据
```

### `all` 与 `list` 的区别

- `all` 是任务查询的根前缀，不一定对应一份具体数据。
- `lists` 是所有列表查询的前缀。
- `list(params)` 是某个具体筛选条件下的列表缓存。

当前只有一个无参数列表时，可以简化为：

```ts
export const taskKeys = {
  all: ["tasks"] as const,
  list: () => [...taskKeys.all, "list"] as const,
};
```

不需要为了形式完整而提前实现详情、统计和分页键。

## 五、查询参数必须进入 Query Key

如果 `queryFn` 依赖参数，参数必须进入 Query Key：

```ts
useQuery({
  queryKey: taskKeys.list({ completed: false, page: 1 }),
  queryFn: () => taskApi.list({ completed: false, page: 1 }),
});
```

否则参数改变而键不变时，React Query 可能继续复用旧缓存。

Query Key 应由可序列化的数据组成。数组层级顺序表达语义，不能把函数、组件实例或随机值放进键中。

## 六、Query Key 与缓存失效

默认情况下，`invalidateQueries` 支持按前缀匹配：

```ts
queryClient.invalidateQueries({
  queryKey: taskKeys.all,
});
```

会匹配所有以 `["tasks"]` 开头的查询，例如列表、详情和统计。

只让列表过期：

```ts
queryClient.invalidateQueries({
  queryKey: taskKeys.lists(),
});
```

精确匹配：

```ts
queryClient.invalidateQueries({
  queryKey: taskKeys.list(),
  exact: true,
});
```

失效不是立即删除数据，而是将查询标记为过期；正在使用该查询的组件通常会在后台重新获取数据。

## 七、Mutation 与 Query Key 的关系

`create`、`update`、`delete` 是写操作，不是三份需要长期缓存的数据。它们成功后影响哪些 Query Key：

| 写操作 | 典型受影响查询 |
| --- | --- |
| 创建任务 | 任务列表、任务统计 |
| 更新任务 | 任务详情、任务列表、任务统计 |
| 删除任务 | 删除对应详情、任务列表、任务统计 |

例如创建成功后：

```ts
onSuccess: () => {
  queryClient.invalidateQueries({
    queryKey: taskKeys.lists(),
  });
  queryClient.invalidateQueries({
    queryKey: taskKeys.stats(),
  });
}
```

`mutationKey` 可以用于 Mutation 分类、调试或全局配置，但它不负责存储 Mutation 结果，也不能替代 Query Key。

## 八、是否抽取通用 CRUD Key 工厂

可以抽取公共的层级结构，但不应把所有业务强行约束成 `create/update/delete/detail/list` 模板。

不同业务的可缓存查询可能是：

- 任务：列表、详情、统计、搜索；
- 订单：待支付、历史、详情、金额统计；
- 消息：收件箱、未读数量、会话、搜索；
- 项目：列表、详情、成员、权限、活动记录。

因此，通用工厂最多抽取 `all`、`lists`、`details` 等重复层级；`stats`、`search`、`members` 等业务语义仍由具体模块显式定义。当前 Task App 尚未采用通用 CRUD 工厂，后续在出现多个同构业务模块后再评估。

## 九、目录边界

`lib` 不是“所有不知道放哪里的代码”，而是项目级基础能力或第三方库封装，例如：

```text
lib/query-client.ts  → 全局 React Query 配置
lib/storage.ts       → 本地存储封装
lib/logger.ts        → 日志封装
```

`task-query-keys.ts` 是任务模块的查询定义，不是 Hook。当前可以放在 `lib`，但更准确的长期归属是任务特性目录，例如：

```text
features/tasks/query-keys.ts
```

如果项目暂时采用按技术层分类的目录，也可以放在 `api/` 或 `lib/`，关键是保持唯一事实来源，不要在多个目录复制同一套键。

## 十、当前实现边界

- 当前只确认 Query Key 和缓存失效设计，不代表所有接口 Mutation 已经在项目中完成。
- JSONPlaceholder 可以用于练习请求、缓存和 Mutation 流程，但不能作为真正的持久化后端事实来源。
- 乐观更新、失败回滚、登录用户缓存隔离和退出登录清理，属于后续学习内容。
