---
title: Expo 学习计划与进度
type: plan
status: current
date: 2026-08-24
updated: 2026-08-24
project: Expo
owner: 待补充
source_repo: expo-learning
source_ref: master（当前工作区未提交）
sources:
  - "https://docs.expo.dev/versions/v57.0.0/"
  - "https://tanstack.com/query/latest/docs/framework/react/overview"
  - "https://tanstack.com/query/latest/docs/framework/react/react-native"
  - "https://axios-http.com/docs/intro"
related:
  - "[[MOC]]"
  - "[[React Query与Axios查询缓存架构]]"
---

# Expo 学习计划与进度

> 当前结论：学习项目已经从 Expo 与 React Native 基础进入生产级数据流设计阶段。Task App 已完成本地任务管理、组件拆分、FlatList 和自定义 Hook 学习；当前正在把任务数据迁移到 Axios + TanStack Query，并建立 API 层、Server State、Query Key、Mutation 和缓存失效的工程边界。代码接入已经开始，但当前数据流仍有未完成项，不能视为生产级实现完成。

## 文档职责

本文是 Expo Task App 学习主题的唯一进度来源，维护学习目标、已学内容、当前代码基线、阶段状态和下一步练习。具体的 Query Key、缓存层级和 Axios 分层知识见 [[React Query与Axios查询缓存架构]]；项目入口 [[MOC]] 只维护导航和摘要。

## 学习目标

目标不是掌握零散 API，而是形成接近生产项目的 Expo + React Native 开发能力：

1. 使用 Expo SDK 57、React Native、TypeScript 和 Expo Router 构建跨平台应用。
2. 设计清晰的 API 层、服务端状态和客户端状态边界。
3. 掌握 Axios、TanStack Query、缓存、Mutation、错误处理和网络状态处理。
4. 完成登录鉴权、本地安全存储、路由保护和用户数据隔离。
5. 理解开发构建、环境配置、EAS Build、EAS Update 和发布验证流程。

## 项目与版本基线

当前练习项目为 `expo-learning` 中的 Task App，主要版本基线如下：

| 项目 | 当前基线 |
|---|---|
| Expo | SDK 57 |
| React Native | 0.86.2 |
| React | 19.2.3 |
| 路由 | Expo Router |
| 语言 | TypeScript |
| HTTP 客户端 | Axios 已加入依赖并已创建客户端封装 |
| 服务端状态 | TanStack Query 已加入依赖并已接入根布局 |
| 数据后端 | 当前使用 JSONPlaceholder 练习请求流程，不是持久化业务后端 |

当前源码工作区存在未提交改动，以下“已落地”只表示当前工作区代码状态，不表示已经创建 Git 提交。

## 已完成学习内容

### 1. Expo 与 React Native 基础

- `View`、`Text`、Flex 布局和样式组织。
- Safe Area 相关布局意识。
- `Pressable` 交互。
- `TextInput` 输入处理。
- `Alert` 校验提示。

这些内容已经作为 Task App 的基础，不再从零重复讲解。

### 2. React 状态与不可变更新

- `useState` 管理界面状态。
- 数组不可变更新。
- 添加、删除和切换任务状态。
- 理解输入框内容属于 Client State。

### 3. FlatList

已理解：

- `data` 是列表数据源。
- `renderItem` 负责单项渲染。
- `keyExtractor` 提供稳定标识。
- FlatList 通过虚拟化减少大量列表的同时渲染压力。

### 4. 组件和 Hook 拆分

已完成：

- `task-item.tsx` 任务项组件抽离。
- `add-task-form.tsx` 添加表单组件抽离。
- `use-tasks.ts` 自定义 Hook 初步抽离。

当前已建立“页面负责组合 UI，Hook 负责业务状态”的方向，但 Hook 仍需继续收敛到完整的查询和 Mutation 编排。

## 当前阶段：Day12 数据流架构

### 已经开始落地

- `QueryClientProvider` 已接入 Expo Router 根布局。
- Axios 实例已建立，包含基础地址、超时、请求头和响应错误转换。
- 任务 API 已具备列表、创建、更新和删除方法。
- 任务 Query Key 已独立定义。
- `useTasks` 已接入 `useQuery` 和任务 Mutation 的基本结构。
- `toggleMutation` 已完成一次乐观更新实验：请求前保存任务列表快照并更新缓存，失败时回滚，结束后重新校准服务端数据。
- 已理解 Server State 与 Client State 的区别。
- 已理解 Query Key 是缓存身份，不是接口地址。
- 已理解 `all`、`list` 等层级用于缓存定位和前缀失效。
- 已明确 Mutation 不应机械地按 `create/update/delete` 建立缓存模型，而应根据写操作影响的查询执行失效或更新。

### 当前未完成

- `addTask` 当前只创建了本地对象，尚未真正调用创建 Mutation。
- 页面尚未完整暴露和使用创建、更新、删除 Mutation 的加载状态。
- Mutation 失败时的用户反馈尚未完成。
- 当前接口使用 JSONPlaceholder，新增、更新和删除不能作为真正的持久化业务结果验证。
- 任务 DTO 与前端领域模型尚未正式分离。
- React Native AppState、网络恢复和请求重新获取策略尚未接入。
- Mutation 错误的页面反馈、并发 Mutation、离线恢复和请求重试尚未学习和实现。

## 学习路线

| 阶段 | 状态 | 核心内容 | 完成标准 |
|---|---|---|---|
| 第一阶段：Expo 与 React Native 基础 | 已完成 | 布局、输入、交互、Safe Area、样式 | 能独立完成基础页面和交互 |
| 第二阶段：Task App 本地状态 | 已完成 | `useState`、不可变更新、FlatList、组件拆分、`useTasks` | 任务列表功能可运行，UI 与基础业务逻辑分离 |
| 第三阶段：Axios 与 API 层 | 进行中 | Axios 实例、接口方法、DTO、错误转换、环境地址 | 页面不直接请求 HTTP，API 契约集中维护 |
| 第四阶段：TanStack Query 服务端状态 | 进行中 | Provider、Query、Mutation、Query Key、缓存失效 | 刷新、重新获取和 Mutation 都以服务端数据为准 |
| 第五阶段：生产级数据状态 | 部分开始 | Loading/Error、背景刷新、AppState、网络恢复、乐观更新、回滚 | 能解释并验证离线、失败和重试场景 |
| 第六阶段：本地存储与鉴权 | 待开始 | SecureStore、访问令牌、刷新令牌、登录状态和用户隔离 | 登录态可恢复，退出登录不会泄露旧用户缓存 |
| 第七阶段：Expo Router 架构 | 待开始 | 路由分组、受保护路由、登录流和页面级数据加载 | 未登录用户不能进入业务页面 |
| 第八阶段：发布流程 | 待开始 | Development Build、EAS Build、EAS Update、环境配置和发布检查 | 能完成一次可复现的测试构建和发布前验证 |

## 下一步练习顺序

1. 完成 Mutation 错误的页面反馈，让创建、切换和删除失败时用户能看到可理解的提示。
2. 检查 `TaskItem` 的回调契约，让子组件传参方式与父组件实际使用方式一致。
3. 统一 Query Key 和失效范围：创建、更新、删除后明确哪些列表、详情和统计需要失效。
4. 学习并验证并发 Mutation、请求取消和失败重试的边界。
5. 用一个可持久化的测试后端替换 JSONPlaceholder，再验证刷新和重新进入页面后数据仍然存在。

完成以上内容后，再进入 React Native 的 AppState、网络恢复和乐观更新，而不是提前扩展登录和本地缓存。

## 已确认的工程边界

- API 请求统一使用 Axios；不以 `fetch` 作为本项目的主要 API 示例。
- 页面组件不直接访问 Axios；请求路径和参数由 API 层维护。
- React Query 管理服务端状态，`useState` 管理界面状态。
- Query Key 围绕可缓存的数据和查询场景设计，不按 HTTP 的 CRUD 动词机械生成。
- `all` 是查询命名空间，`list`、`detail`、`stats` 是具体查询类型；前缀失效与精确失效必须区分。
- `lib` 只放项目级基础能力或第三方库封装；业务专属 Query Key 在业务特性目录成熟后应与业务模块一起维护。
- 不把 JSONPlaceholder 的接口响应当成真实持久化后端能力。
- 乐观更新当前只作为 `toggle` 学习实验，不推广到所有 Mutation。
- 不把尚未实现的登录鉴权和发布流程记录为已完成。

## 待定事项

- 真实练习后端的技术选型和部署地址待确定。
- Task DTO 与领域模型的字段映射方式待实现后确认。
- 是否引入统一表单校验库，待 API 输入校验和表单复杂度增加后评估。
- 是否需要 Query Cache 持久化，待完成登录和离线场景分析后决定。
- 是否需要 Development Build，取决于后续实际使用的原生模块，不提前假设。

## 历史说明

此前文档曾以 Expo Go 连接、iOS 扫码和版本兼容性排查为主要内容；这些内容不再作为当前 Task App 学习主线。相关历史记录保留在知识库日志中，本计划从 2026-08-24 起改为维护 Expo 生产级应用开发和 Task App 数据流演进。
