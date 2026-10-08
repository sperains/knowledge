---
title: 05 company 业务库全表关系图
type: reference
status: current
date: 2026-09-22
updated: 2026-09-22
project: jdec-platform-v1
owner: jdec-platform 项目组
source_repo: jdec-platform-v1
source_ref: "feature/base @ de58bf68"
related:
  - "[[MOC]]"
  - "[[00-项目概览与参与指南]]"
  - "[[03-模块配置子表与列表数据链路]]"
  - "[[02-模块菜单字段权限链路]]"
---

# 05 company 业务库全表关系图

> 核验范围：开发环境 `company` 业务库实际表结构、配置中心 `sys_table_relation` 和当前源码中的表访问逻辑。核验日期为 2026-09-22。`school` 示例项目不在本图范围内。

## 1. 关系图

```mermaid
flowchart LR
  subgraph master[业务主数据表（9 张）]
    info["info<br/>公司主表<br/>PK id"]
    basic_info["basic_info<br/>基本信息<br/>PK id / UK company_id"]
    member["member<br/>组织与人员<br/>PK id"]
    member_contact["member_contact<br/>个人通讯录<br/>PK id"]
    address["address<br/>公司地址<br/>PK id / UK company_id"]
    company_contact["company_contact<br/>公司联系方式<br/>PK id"]
    financial_account["financial_account<br/>银行卡账户<br/>PK id"]
    digital_account["digital_account<br/>电子账户<br/>PK id"]
    credit_rating["credit_rating<br/>信用等级<br/>PK id / UK company_id"]
  end

  subgraph approval[审批运行时表（5 张）]
    approval_business["approval_business<br/>当前审批指针<br/>PK id"]
    approval_chain["approval_chain<br/>审批步骤实例<br/>PK id"]
    approval_chain_button["approval_chain_button<br/>步骤操作按钮<br/>PK id"]
    approval_chain_status["approval_chain_status<br/>步骤状态节点<br/>PK id"]
    approval_version_record["approval_version_record<br/>审批版本记录<br/>PK id"]
  end

  subgraph change[变更与快照表（3 张）]
    module_data_change_content["module_data_change_content<br/>模块数据变更内容<br/>PK id"]
    module_data_field_change_content["module_data_field_change_content<br/>模块字段变更内容<br/>PK id"]
    module_data_snapshot_content["module_data_snapshot_content<br/>模块数据快照内容<br/>PK id"]
  end

  subgraph monitor[监控表（2 张）]
    monitor_log["monitor_log<br/>监控日志<br/>PK id"]
    monitor_operate_index["monitor_operate_index<br/>操作日志索引<br/>PK id"]
  end

  user_menu_header["user_menu_header<br/>用户个性化表头<br/>PK id"]

  %% 配置中心 sys_table_relation 已确认的物理业务关系
  info -->|id = company_id · 1:1| basic_info
  info -->|id = company_id · 1:1| address
  info -->|id = company_id · 1:N| company_contact
  info -->|id = company_id · 1:N| financial_account
  info -->|id = company_id · 1:N| digital_account
  info -->|id = company_id · 1:1| credit_rating
  info -->|id = company_id · 1:N| member
  member -->|id = member_id · 1:N| member_contact

  %% 代码和字段推导出的逻辑关系，不是数据库外键
  info -.->|parent_id · 公司层级自关联| info
  member -.->|parent_id / leader_id · 组织树自关联| member
  approval_business -.->|module_id + record_id| info
  approval_version_record -.->|module_id + record_id| info
  approval_business -.->|serial_number + serial_no| approval_chain
  approval_business -.->|serial_number + serial_no| approval_version_record
  approval_chain_button -.->|pid = approval_chain.id| approval_chain
  approval_chain_status -.->|pid = approval_chain.id| approval_chain
  approval_version_record -.->|source_id · 来源版本| approval_version_record
  monitor_operate_index -.->|log_id = monitor_log.id| monitor_log

  %% 变更快照和表头对模块、业务记录或外部配置的逻辑引用
  module_data_change_content -.->|module_id + data_id · 逻辑引用| info
  module_data_field_change_content -.->|module_id + data_id · 逻辑引用| info
  module_data_snapshot_content -.->|root_module_id + root_table_data_id · 逻辑引用| info
  monitor_operate_index -.->|module_id + data_id · 逻辑引用| info
  user_menu_header -.->|module_id / menu_id / user_id · 跨库逻辑引用| external["配置中心与用户服务<br/>外部逻辑对象，不计入 company 表"]

  classDef masterStyle fill:#e8f3ff,stroke:#377dba,color:#17324d;
  classDef approvalStyle fill:#fff1e6,stroke:#d97706,color:#4a2a05;
  classDef changeStyle fill:#f3e8ff,stroke:#8b5cf6,color:#35135f;
  classDef monitorStyle fill:#eaf8ef,stroke:#3d9660,color:#173d24;
  classDef externalStyle fill:#f3f4f6,stroke:#6b7280,color:#374151;
  class info,basic_info,member,member_contact,address,company_contact,financial_account,digital_account,credit_rating masterStyle;
  class approval_business,approval_chain,approval_chain_button,approval_chain_status,approval_version_record approvalStyle;
  class module_data_change_content,module_data_field_change_content,module_data_snapshot_content changeStyle;
  class monitor_log,monitor_operate_index monitorStyle;
  class external externalStyle;
```

图例：实线表示配置中心 `sys_table_relation` 已确认的业务表关系；虚线表示根据字段语义和源码访问链路整理出的逻辑关系，不代表数据库声明了外键。当前数据库没有声明物理外键。

## 2. 20 张表清单

| 分组 | 表 | 主要职责 | 关系证据 |
|---|---|---|---|
| 主数据 | `info` | 公司主记录和公司层级 | 配置中心主表；`parent_id` 自关联 |
| 主数据 | `basic_info` | 工商资质和基本信息 | `company_id` 唯一关联 `info.id` |
| 主数据 | `member` | 组织与人员节点 | `company_id` 关联 `info.id`；`parent_id`、`leader_id` 形成组织树语义 |
| 主数据 | `member_contact` | 人员联系方式 | `member_id` 关联 `member.id` |
| 主数据 | `address` | 公司地址 | `company_id` 唯一关联 `info.id` |
| 主数据 | `company_contact` | 公司对外联系方式 | `company_id` 关联 `info.id` |
| 主数据 | `financial_account` | 银行卡结算账户 | `company_id` 关联 `info.id` |
| 主数据 | `digital_account` | 电子结算账户 | `company_id` 关联 `info.id` |
| 主数据 | `credit_rating` | 公司信用等级 | `company_id` 唯一关联 `info.id` |
| 审批 | `approval_business` | 当前审批版本和状态指针 | `module_id + record_id` 逻辑关联业务记录 |
| 审批 | `approval_chain` | 单据审批步骤运行时实例 | 通过流水编号、步骤号关联 `approval_business` |
| 审批 | `approval_chain_button` | 当前步骤的通过、驳回等按钮 | `pid` 逻辑指向 `approval_chain.id` |
| 审批 | `approval_chain_status` | 当前步骤和下一步骤状态节点 | `pid` 逻辑指向 `approval_chain.id` |
| 审批 | `approval_version_record` | 审批版本历史 | 通过流水编号关联当前审批；`source_id` 指向来源版本 |
| 变更 | `module_data_change_content` | 模块数据级变更内容 | 通过模块、业务记录和动作编号逻辑关联 |
| 变更 | `module_data_field_change_content` | 模块字段级变更内容 | 通过模块、业务记录和字段编号逻辑关联 |
| 变更 | `module_data_snapshot_content` | 模块数据快照和比对内容 | 通过根模块、根业务记录逻辑关联 |
| 监控 | `monitor_log` | 操作、消息和系统监控日志 | 日志主体表；含模块和业务记录标识 |
| 监控 | `monitor_operate_index` | 按模块和业务记录反查操作日志 | `log_id` 逻辑指向 `monitor_log.id` |
| 表头 | `user_menu_header` | 用户个性化菜单表头 | 通过用户、菜单、模块和项目编号跨库逻辑关联 |

## 3. 已确认的主子表关系

配置中心 `sys_table_relation` 针对 `project_no=company` 返回 8 条关系：

| 主表 | 主字段 | 子表 | 子字段 | 类型 | 说明 |
|---|---|---|---|---|---|
| `info` | `id` | `basic_info` | `company_id` | 1:1 | 工商资质详情 |
| `info` | `id` | `member` | `company_id` | 1:N | 组织与人员架构 |
| `member` | `id` | `member_contact` | `member_id` | 1:N | 个人联系方式 |
| `info` | `id` | `address` | `company_id` | 1:1 | 公司地址 |
| `info` | `id` | `company_contact` | `company_id` | 1:N | 公司联系方式 |
| `info` | `id` | `financial_account` | `company_id` | 1:N | 银行卡账户 |
| `info` | `id` | `digital_account` | `company_id` | 1:N | 电子账户 |
| `info` | `id` | `credit_rating` | `company_id` | 1:1 | 信用等级 |

这些关系由配置中心驱动动态查询和树形装配。实际数据库中没有对应的 `FOREIGN KEY` 约束，关系正确性依赖配置、字段命名、索引和应用层逻辑共同维护。

## 4. 其他逻辑关系说明

### 审批运行时表

审批表不直接保存业务正文。`approval_business` 和 `approval_version_record` 通过 `module_id + record_id` 指向实际业务记录；审批步骤、按钮和状态通过流水编号、流水序号、当前步骤和 `pid` 关联。对于当前 company 样本，模块 `1001` 的业务记录对应 `info` 表记录。

### 变更与快照表

三张变更表通过模块编号、根记录编号、数据编号、动作编号或字段编号表达变更上下文。当前源码和数据库均未发现它们之间或与业务主表之间的物理外键，因此图中使用逻辑虚线；不能把这些字段直接解释为数据库级父子关系。

### 监控表

`monitor_operate_index` 用 `log_id` 建立操作日志索引，业务代码先按模块编号和数据编号查询索引，再回查 `monitor_log` 明细。该关系由代码维护，数据库没有声明外键。

### 用户个性化表头

`user_menu_header` 位于 company 业务库，但其 `user_id`、`menu_id`、`module_id` 和 `project_no` 指向用户服务及配置中心的逻辑对象，不属于 company 内部表关系。图中以外部逻辑对象表示，避免误认为 company 内存在对应的用户、菜单或模块表。

## 5. 核验边界

- 本图覆盖开发环境 `company` 数据库实际发现的 20 张表，不包含 `school` 示例库。
- 关系图同时展示配置中心已确认关系和源码/字段推导关系，线型已经区分确定性。
- 未发现 company 数据库物理外键；不存在配置关系或可靠源码关联的表，不强行补画表间关系。
- 表中字段只记录结构性键名，没有记录业务正文、连接凭据或具体敏感数据。
- 后续如果新增表、修改 `sys_table_relation` 或调整审批运行时结构，应重新核验并更新本图。
