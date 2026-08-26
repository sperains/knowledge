# Expo 学习项目知识地图

Expo 学习项目用于记录 Expo SDK 57、React Native、Expo Router 和生产级 Task App 演进过程中的学习计划、架构知识与实现进度。

## 当前状态

已完成 Expo 与 React Native 基础、Task App 本地状态、FlatList、组件拆分和自定义 Hook；当前正在推进 Axios + TanStack Query 的服务端数据流，代码已部分接入但 Mutation 完整闭环、真实持久化后端、鉴权和发布流程仍未完成。

## 文档导航

| 文档 | 类型 | 状态 | 内容 |
|---|---|---|---|
| [[Expo学习计划与进度]] | 计划 | 进行中 | 学习目标、已完成进度、下一步练习、阶段路线和待定事项 |
| [[React Query与Axios查询缓存架构]] | 设计 | 当前 | Axios、Server State、Query Key 层级、Mutation 缓存失效和目录边界 |
| [[TanStack Query Mutation与乐观更新实践]] | 设计 | 当前 | Mutation 差异、缓存更新策略、乐观更新回滚、Query 状态和回调契约 |

最近更新日期：2026-08-24。

## 维护边界

- 本文件只维护项目简介、状态摘要和导航。
- 学习计划与进度只在 [[Expo学习计划与进度]] 更新。
- 当前学习源码仓库为 `expo-learning`，版本基线和代码落地状态以 [[Expo学习计划与进度]] 中的核验记录为准。
