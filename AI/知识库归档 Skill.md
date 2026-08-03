# sync_knowledge Skill

> 内部名称：`knowledge-archive`
> 显示名称：`sync_knowledge`

## 用途

用于在收到明确归档信号后，提炼当前对话中的重要决策、约束、规范和项目结论，并按知识库结构同步归档。

## 触发信号

统一使用：

```text
#归档
```

等价表达包括“归档知识库”和“同步知识库”。普通讨论不会自动触发归档。

## 归档规则

1. 读取知识库目录和相关主题文档，避免重复创建内容。
2. 涉及架构决策时，遵循 [[ADR_RULES]] 的编号、命名和章节要求。
3. 架构取舍、技术选型和长期约束归档到项目 `ADR/`。
4. 稳定的技术方案、目录约定和数据设计归档到架构或规范文档。
5. 项目能力、使用约定和工作流归档到对应项目文档。
6. 未形成最终结论的内容记录为待决事项，不写成正式决策。
7. 优先更新已有文档，不删除历史记录，不自动创建 Git 提交。

## Skill 安装位置

实际 Skill 文件位于：

`/Users/sperains/.codex/skills/knowledge-archive/SKILL.md`

界面元数据位于：

`/Users/sperains/.codex/skills/knowledge-archive/agents/openai.yaml`

## 使用结果

归档完成后需要汇总：

- 提炼出的重要结论
- 新增或更新的知识库文件
- 仍待确认的事项
