# AI 资源

本目录按“可直接使用的提示词”和“需要 agent 执行的技能”分开管理。

## 目录

- [`prompts/`](prompts/)：面向图像、网页或其他生成任务的提示词模板。文档描述输入变量、完整提示词、负面约束和适用场景，不承担文件读写流程。
- [`skills/`](skills/)：面向 agent 的可执行工作流。每个技能独立成目录，入口统一为 `SKILL.md`，可选增加 `agents/` 和 `references/`。
- [`examples/`](examples/)：提示词生成的可运行示例或视觉参考，不作为技能或提示词入口。
全局导航见 [[../MOC|知识库总览]]。

## 提示词资料

- [[prompts/codex/Codex模型提示词中文整理|Codex 模型提示词中文整理]]：对用户提供的模型配置快照进行中文语义翻译和版本梳理；[[prompts/codex/Codex模型提示词英文原文去重版|英文原文去重版]]保留可追溯的原文。

## 选择规则

- 只需要复制一段文字给模型：使用 `prompts/`。
- 需要 agent 搜索、判断、修改文件或执行多步流程：使用 `skills/`。
- 需要查看最终网页或代码效果：使用 `examples/`。

## 跨 agent 约定

技能入口只依赖通用能力：发现文件、搜索、读取、写入和校验。工具名称、模型名称、操作系统路径和厂商 API 应放在适配层，不写死在通用技能正文中。

当前技能：

- [`knowledge-archive`](skills/knowledge-archive/SKILL.md)：在收到明确归档指令后，把当前项目或其他工作区对话中的已确认结论同步到配置的中央知识库。
- [`commit`](skills/commit/SKILL.md)：在收到明确提交请求后，检查改动范围并按项目规范创建 Git 提交。
- [`report`](skills/report/SKILL.md)：根据当天的工作记录和本地规则生成或更新开发日报。
- [`monthly-daily-summary`](skills/monthly-daily-summary/SKILL.md)：按自然月汇总开发日报，提炼主题、成果、风险和后续事项。
- [`rewrite`](skills/rewrite/SKILL.md)：润色、改写和审校中英文文稿，并在保留事实与意图的前提下改善表达。
- [`find-simplifications`](skills/find-simplifications/SKILL.md)：审查 ICCE 画布中可由证据支持的删减、合并或收窄机会。
- [`hatch-pet`](skills/hatch-pet/SKILL.md)：创建、修复、校验并打包符合 Codex 规范的动画宠物。
- [`open-source-readme`](skills/open-source-readme/SKILL.md)：基于仓库证据设计、改写或审查开源项目 README。
- [`simplify-coding`](skills/simplify-coding/SKILL.md)：在实现、修复、重构和审查代码时控制关键假设、方案复杂度、改动范围与验证强度。

## 可运行检查

- [`check_knowledge_base.py`](examples/check_knowledge_base.py) 和 [`check_knowledge_base.rb`](examples/check_knowledge_base.rb)：按相同规则检查项目主题文档元信息、ADR 固定结构、项目导航覆盖和 Obsidian 失效链接。Python 版只使用标准库。
- [`check_knowledge_base.sh`](examples/check_knowledge_base.sh)：在有 POSIX Shell 的环境中自动选择可用解释器，优先 Python 3，其次 Ruby，并保留检查脚本的退出码。

在知识库根目录，根据已有工具选择任一命令：

```bash
python3 AI/examples/check_knowledge_base.py
```

```bash
ruby AI/examples/check_knowledge_base.rb
```

在 Linux、WSL 或 macOS 中，也可以自动选择：

```bash
sh AI/examples/check_knowledge_base.sh
```

如果 Windows 中 Python 3 的命令是 `python`，将第一条命令中的 `python3` 替换为 `python`。无需同时安装 Python 和 Ruby。检查结果为失败时应修正文档，不通过更换解释器绕过错误；自动入口也不会在检查失败后切换另一版脚本。
