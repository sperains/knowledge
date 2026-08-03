# AI 资源

本目录按“可直接使用的提示词”和“需要 agent 执行的技能”分开管理。

## 目录

- [`prompts/`](prompts/)：面向图像、网页或其他生成任务的提示词模板。文档描述输入变量、完整提示词、负面约束和适用场景，不承担文件读写流程。
- [`skills/`](skills/)：面向 agent 的可执行工作流。每个技能独立成目录，入口统一为 `SKILL.md`，可选增加 `agents/` 和 `references/`。
- [`examples/`](examples/)：提示词生成的可运行示例或视觉参考，不作为技能或提示词入口。

## 选择规则

- 只需要复制一段文字给模型：使用 `prompts/`。
- 需要 agent 搜索、判断、修改文件或执行多步流程：使用 `skills/`。
- 需要查看最终网页或代码效果：使用 `examples/`。

## 跨 agent 约定

技能入口只依赖通用能力：发现文件、搜索、读取、写入和校验。工具名称、模型名称、操作系统路径和厂商 API 应放在适配层，不写死在通用技能正文中。

当前技能：

- [`knowledge-archive`](skills/knowledge-archive/SKILL.md)：在收到明确归档指令后，把对话中的已确认结论同步到知识库。
- [`commit`](skills/commit/SKILL.md)：在收到明确提交请求后，检查改动范围并按项目规范创建 Git 提交。
