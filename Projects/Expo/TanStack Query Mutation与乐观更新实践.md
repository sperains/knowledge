---
title: TanStack Query Mutation 与乐观更新实践
type: design
status: current
date: 2026-08-24
updated: 2026-08-24
project: Expo
owner: 待补充
source_repo: expo-learning
source_ref: master（当前工作区未提交）
related:
  - "[[MOC]]"
  - "[[Expo学习计划与进度]]"
  - "[[React Query与Axios查询缓存架构]]"
---

# TanStack Query Mutation 与乐观更新实践

> 当前结论：Task App 使用 `useMutation` 执行服务端写操作。`add`、`update`、`delete` 共享 Mutation 生命周期，但输入、服务端语义和受影响的缓存范围不同。本阶段仅对任务完成状态切换使用乐观更新，以学习请求前更新、失败回滚和最终服务端校准；创建和删除仍优先使用成功后失效查询的保守策略。

## 一、Mutation 解决什么问题

`useMutation` 不是把一次 HTTP 调用变得更短，而是集中管理服务端写操作的生命周期：

```text
用户操作
  ↓
Mutation pending
  ↓
API 请求
  ├── 成功：更新或失效相关查询
  └── 失败：展示错误或回滚本地变更
```

如果只使用 API 加 `setState`，这些状态和缓存同步逻辑仍然存在，只是会分散在页面代码中。

## 二、Add、Update、Delete 的差异

三者都可以通过 `useMutation` 执行，但不是同一个业务动作：

| 操作 | 输入 | 典型影响 |
|---|---|---|
| Add | 新资源内容 | 服务端生成新 ID，影响列表和统计 |
| Update | ID 加修改内容 | 影响详情、列表、筛选结果和统计 |
| Delete | ID | 移除详情，影响列表和统计 |

因此不按 CRUD 动词创建 Query Cache，而是根据操作影响的查询执行 `invalidateQueries`、`setQueryData` 或乐观更新。

## 三、三种缓存处理策略

### 1. 成功后失效查询

```ts
const updateMutation = useMutation({
  mutationFn: taskApi.update,
  onSuccess: () => {
    queryClient.invalidateQueries({
      queryKey: taskKeys.all,
    });
  },
});
```

流程是“请求成功后，以服务端结果重新获取缓存”。优点是简单、可靠，适合创建任务、删除任务和复杂编辑表单。

### 2. 使用服务端返回值更新缓存

当服务端返回完整且规范化后的资源时，可以直接用 `setQueryData` 替换缓存，减少一次列表请求。此时需要自行确认列表、详情、统计和筛选缓存是否都同步。

### 3. 乐观更新

乐观更新先假设请求会成功，立即修改缓存；失败时恢复快照，最后仍然用服务端结果校准：

```text
onMutate   → 取消查询、保存旧快照、立即改缓存
onError    → 使用旧快照回滚
onSettled  → 失效查询并重新确认服务端结果
```

乐观更新带来的价值是降低用户感知延迟，不是取消服务端校准。

## 四、Task App 的 toggle 乐观更新

任务完成状态切换适合作为练习，因为它是局部、即时、容易回滚的操作。

```ts
const toggleMutation = useMutation({
  mutationFn: ({ id, completed }) =>
    taskApi.update(id, { completed }),

  onMutate: async ({ id, completed }) => {
    await queryClient.cancelQueries({
      queryKey: taskKeys.list(),
    });

    const previousTasks = queryClient.getQueryData<Task[]>(
      taskKeys.list(),
    );

    queryClient.setQueryData<Task[]>(
      taskKeys.list(),
      (oldTasks) =>
        oldTasks?.map((task) =>
          task.id === id
            ? { ...task, completed }
            : task,
        ),
    );

    return { previousTasks };
  },

  onError: (_error, _variables, onMutateResult) => {
    if (onMutateResult?.previousTasks) {
      queryClient.setQueryData(
        taskKeys.list(),
        onMutateResult.previousTasks,
      );
    }
  },

  onSettled: () => {
    queryClient.invalidateQueries({
      queryKey: taskKeys.all,
    });
  },
});
```

### 为什么 `onSettled` 仍然需要失效

乐观更新只是客户端的临时假设。服务端可能拒绝请求、补充字段、执行权限判断，或者已经被其他设备修改。`onSettled` 的最终请求负责让缓存回到服务端事实。

这不会必然导致整页重新显示 Loading。已有数据时，Query 进入的是后台重新获取：

```text
isLoading = false
isFetching = true
isRefetching = true
```

页面应保留旧列表，只显示轻量同步提示；只有第一次没有数据时才显示整页 Loading。

## 五、Query 状态的页面使用方式

TanStack Query v5 已提供派生状态：

- `isPending`：Query 状态仍为 pending。
- `isFetching`：请求函数正在执行，包括首次请求和后台重新请求。
- `isLoading`：首次请求正在执行，等价于 `isPending && isFetching`。
- `isRefetching`：已有数据时后台重新请求，等价于 `isFetching && !isPending`。

当前页面优先使用：

```text
isLoading    → 整页 Loading
isRefetching → 保留列表并显示同步提示
```

不要用 `isFetching` 直接替代整页 Loading，否则每次失效查询都可能造成页面闪烁。

## 六、TanStack Query v5 回调签名

`onMutate` 返回的值会传给 `onError` 和 `onSettled`。v5 中 `onError` 的参数顺序是：

```ts
onError(
  error,
  variables,
  onMutateResult,
  mutationContext,
)
```

第三个参数建议命名为 `onMutateResult`，因为它是 `onMutate` 的返回值；不要把它和第四个参数的 Mutation 运行上下文混为一谈。

## 七、组件回调契约

如果 `TaskItem` 声明：

```ts
onPress: (id: number) => void;
```

但父组件传入的函数通过闭包使用 `item.id`，完全忽略传入的 ID，那么代码可能可以运行，但回调契约不一致：

```text
子组件认为：我会把 id 传给父组件
父组件实际：我不需要这个 id，我已经闭包捕获了 item
```

需要在后续代码整理中选择一种明确契约：要么由子组件传递 `id` 和目标状态，要么由子组件只发出无参数的切换事件，由父组件负责组装 Mutation 参数。

## 八、当前边界

- 当前只对 `toggle` 实现乐观更新，作为学习实验；不代表所有 Mutation 都采用乐观策略。
- 创建和删除暂时使用成功后失效查询的保守方案。
- JSONPlaceholder 不是持久化业务后端，不能用它验证真实的跨请求一致性。
- 当前还没有完成 Mutation 错误展示、并发 Mutation、离线恢复和请求重试策略。
