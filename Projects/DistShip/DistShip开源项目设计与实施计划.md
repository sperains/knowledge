---
title: DistShip 开源项目设计与实施计划
type: design
status: current
date: 2026-08-12
updated: 2026-08-13
project: DistShip
owner: DistShip 项目组
source_repo: distship
source_ref: "2026-08-12 验收基线"
sources:
  - "https://go.dev/doc/devel/release"
  - "https://github.com/spf13/cobra"
  - "https://github.com/pelletier/go-toml"
  - "https://github.com/charmbracelet/lipgloss"
  - "https://goreleaser.com/"
  - "https://docs.github.com/en/repositories/releasing-projects-on-github"
  - "https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap"
  - "https://specifications.freedesktop.org/basedir/"
  - "https://no-color.org/"
  - "https://semver.org/"
  - "https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations"
related:
  - "[[MOC]]"
  - "[[DistShip实施与发布计划]]"
---

# DistShip 开源项目设计与实施计划

> 当前结论：DistShip 从 `v0.1.0` 起直接使用 Go 实现并发布单一二进制，面向 macOS 和 Linux 上管理自有测试、预发布服务器的个人与小团队开发者；配置、预检查、本地构建、静态产物上传和本机部署历史已经落地并通过一次真实 IPD 部署验收，发布分发链路与第二个静态前端项目验证仍在后续阶段，现有 Bash 脚本只作为需求原型和迁移对照。

## 背景

当前已有一套放在 `~/deploy-web/` 下的个人部署脚本，配置文件与命令放在同一目录。它通过项目预设选择目标，执行本地前端构建，然后使用 SSH 别名和 `rsync` 将构建产物上传到服务器。

当前能力包括：

- 通过项目编号或交互菜单选择部署预设。
- 查看本地项目路径和服务器目录。
- 使用 `--dry-run` 展示部署配置但不执行构建和上传。
- 对 Git 仓库显示当前分支、提交号和工作区状态。
- 执行预设构建命令并检查构建产物目录。
- 创建远端目标目录并增量上传产物。
- 默认不删除服务器上的其他文件。

当前实现仍带有明显的个人工具特征：配置采用竖线分隔文本，命令逻辑集中在单一 Bash 文件中，缺少严格配置校验、部署确认、自动化测试、安装流程和公开文档，因此不适合直接作为稳定开源工具发布。

独立的 Go 实现已经迁入旧 Bash 原型的核心部署能力：使用版本一 TOML 配置管理目标，提供初始化、列表、预检查、部署、配置校验、目标删除和版本命令，并内置中英文界面、自动化测试、本机部署历史与安全边界。Go 版本已经完成一次真实 IPD 测试环境部署，旧 Bash 脚本不再作为公开实现基线。

## 产品定位与边界

### 目标用户

`DistShip` 首先服务于已有 SSH 服务器、需要自行部署静态前端产物的个人开发者和小型研发团队。目标用户熟悉项目构建命令与 SSH 基础配置，但不希望为少量测试环境维护完整的持续部署平台。

### 核心任务

用户需要在本地选择一个预设目标，确认当前分支、工作区和相对上次部署的提交变化，然后完成本地构建与增量上传，并留下可追溯的本机部署记录。

核心路径固定为：选择目标 → 确认代码版本 → 本地构建 → 增量上传 → 记录结果。

### 首版适用边界

`v0.1.0` 明确面向测试和预发布环境，不承诺生产级发布能力。首版使用直接增量覆盖，没有原子切换和自动回滚，且默认不删除远端旧文件；在原子发布、回滚和服务器权威版本协议落地前，不将生产环境部署作为产品承诺。

当前只支持能够在本地完成构建并形成独立静态产物目录的前端项目。DistShip 上传该目录中的文件，不启动应用进程，也不解释前端框架运行时。后端服务、服务端渲染运行时、容器、数据库、进程管理、服务器端构建、服务重启和运行时配置管理均不属于当前产品范围；未来只有出现明确需求并重新设计部署协议后才评估扩展，当前不作兼容承诺。

### 项目命名

- 产品名：`DistShip`。
- 命令名：`distship`。
- 仓库名：`distship`。
- 品牌语：`Build locally. Review changes. Ship safely.`
- 中文表达：本地构建，确认变更，安全发布。

`Dist` 表示待发布的构建产物，不要求产物目录必须命名为 `dist`；`Ship` 表示在确认版本和目标后将产物交付到服务器。名称不绑定宝塔面板、SSH、`rsync` 或 Bash，避免具体实现限制后续演进。

### 品牌表达与产品文案

GitHub 英文简介：

```text
A local-first CLI that previews Git changes, builds web projects, and deploys artifacts to SSH servers.
```

GitHub 中文简介：

```text
一个在部署前展示 Git 变更、本地构建并通过 SSH 发布 Web 产物的命令行工具。
```

README 首屏使用统一表达：

```markdown
# DistShip

Build locally. Review changes. Ship safely.
```

中文 README 可以紧随其后补充：

```text
本地构建，确认变更，安全发布。
```

终端欢迎信息保持简洁：

```text
DistShip

选择要部署的项目和环境
```

完成提示优先使用直接、可理解的操作语言：

```text
✓ 部署成功

  IPD · 测试环境
  c55a1a91 → bt_250:/www/wwwgit/ipd-front
```

英文界面对应使用：

```text
✓ Deployment completed
```

航运隐喻只用于 `DistShip` 名称、品牌语和有限的视觉表达；命令说明、确认提示、错误信息和结果摘要统一使用“构建”“检查”“部署”“上传”等准确术语，避免大量使用 `cargo`、`captain`、`harbor`、`shipment` 等黑话降低理解效率。

## 技术选型

核心目标是便于分发：普通用户下载单一二进制即可运行，不需要安装 Go、Node.js、Python、新版 Bash 或独立配置解析器。

长期技术选型与架构边界见 [[ADR/ADR-001-首版采用Go单二进制并编排系统部署工具]]；本节维护具体技术基线和实施结构。

### 技术基线

| 能力 | 选型 |
| --- | --- |
| 开发语言 | Go 1.26 |
| 命令与参数 | Cobra |
| 配置格式 | TOML |
| 配置解析 | `pelletier/go-toml/v2` |
| 终端排版与颜色 | Lip Gloss |
| 交互确认 | Go 标准库 `bufio` |
| 进程执行 | Go 标准库 `os/exec` |
| 部署历史 | JSON Lines 与 Go 标准库 `encoding/json` |
| 自动化测试 | Go 标准库 `testing` |
| 发布自动化 | GoReleaser 与 GitHub Actions |
| 二进制分发 | GitHub Releases |
| macOS 安装 | Homebrew Tap |

Go 1.26 是首版开发与构建基线，不是用户运行依赖。发布二进制优先使用 `CGO_ENABLED=0` 构建，避免目标机器依赖额外动态库。

### 依赖边界

首版直接依赖控制在以下三项：

- Cobra：提供子命令、参数、帮助、别名和 Shell 补全。
- `pelletier/go-toml/v2`：将版本化 TOML 配置解析为明确的 Go 结构体。
- Lip Gloss：处理中文显示宽度、终端能力检测、颜色降级和分组排版。

首版不引入 Viper、Bubble Tea、Git SDK、SSH SDK、SQLite、依赖注入框架和独立日志框架。配置来源有限，不需要 Viper；交互采用普通命令行流程，不构建全屏 TUI。

### 外部命令边界

DistShip 通过 `os/exec` 调用用户本机已有的命令：

- `git`：只读获取仓库、分支、提交和工作区状态，与用户当前 Git 配置保持一致。
- `ssh`：复用 `~/.ssh/config`、密钥代理、跳板机和主机指纹校验，不读取或管理私钥。
- `rsync`：执行成熟的增量传输，不在 Go 内重复实现同步协议。
- 项目构建工具：按配置调用 `pnpm`、`npm`、`yarn`、`bun` 或其他明确的可执行文件。

构建命令采用参数数组并直接传递给 `os/exec`，不默认经过 Shell 二次解释。确实需要 Shell 表达式时，未来通过显式配置能力单独设计，不能把所有构建命令隐式交给 `sh -c`。

### 平台范围

`v0.1.0` 发布以下目标：

```text
macOS Apple Silicon
macOS Intel
Linux ARM64
Linux x86-64
```

Windows 首版不支持。原因是当前部署协议依赖 Unix 风格路径、权限、SSH 和 `rsync` 行为；Windows 支持需要独立定义路径、命令发现和传输兼容规则，不能仅靠交叉编译声明支持。

工具负责：

- 在本地项目目录执行明确配置的构建命令。
- 检查项目、Git 状态、构建工具、SSH 连接和远端目录。
- 通过用户已有的 SSH 配置连接目标服务器。
- 使用 `rsync` 上传指定产物目录。
- 在执行前展示部署摘要，在执行后报告结果和耗时。

工具不负责：

- 保存或分发密码、私钥和服务器密钥。
- 自动执行 `git pull`、切换分支、合并代码或修改工作区。
- 管理 Nginx、数据库、容器或应用进程。
- 默认清空服务器目录。
- 替代完整的持续集成与持续部署平台。

## 命令协议

已经实现的命令协议：

```bash
distship init [directory]
distship init [directory] --advanced
distship list
distship check ipd:test
distship config validate
distship config remove ipd:test
distship version
```

部署命令统一使用列表中可复制的目标 ID：

```bash
distship deploy ipd:test
distship deploy ipd:test --dry-run
```

职责如下：

- 不带参数的 `distship`：当前显示帮助；进入交互选择并部署仍属于后续阶段。
- `init`：创建首个配置、追加目标或更新已有目标，保存后自动重新读取并校验。
- `list`：以紧凑分组方式列出项目和环境，不依赖中文表格列宽。
- `config remove <target-id>`：预览并删除本地配置目标，不删除项目与服务器文件；删除最后一个目标时归档配置文件。
- `check`：检查本地目录、构建工具、Git 策略、SSH 连接和远端写入条件，但不执行构建、创建目录、上传或写入历史。
- `deploy`：执行预检查、提交范围展示、确认、本地构建、产物校验、增量上传和成功历史记录；模拟模式只展示计划。
- `config validate`：验证配置结构、必填字段、路径和策略值。
- `version`：输出工具版本。

当前已实现的通用选项：

```text
--config <path>   使用指定配置文件
--yes             跳过普通交互确认
--no-color        禁用颜色
--lang            选择 auto、en 或 zh-CN
```

`--dry-run` 已随部署流程实现，只在本地展示计划，不构建、不联网、不写历史。

`show`、`show --commits`、`--quiet`、`--json` 和 Shell 补全作为 `v0.2` 候选能力，不进入 `v0.1.0` 的完成条件。`--yes` 只跳过普通确认，不能绕过分支策略为 `deny`、高风险目标目录或其他硬性安全阻断。

部署目标选择器统一使用 `project:environment`，例如 `ipd:test`。`list` 展示的 ID 必须可以直接复制到删除、检查和部署命令；旧脚本的 `deploy-web ipd-test` 及双参数 `distship config remove ipd test` 均不作为公开兼容接口。

## 配置协议

开源版本目标配置格式为 TOML，按“项目—环境”组织，配置协议从 `version = 1` 开始：

```toml
version = 1

[projects.ipd]
name = "IPD"

[projects.ipd.environments.test]
name = "测试环境"
directory = "/Users/example/projects/ipd"
build = ["pnpm", "build-test"]
artifact = "dist"

[projects.ipd.environments.test.target]
host = "bt_250"
directory = "/www/wwwgit/ipd-front"

[projects.ipd.environments.test.git]
allowed_branches = ["test"]
dirty = "warn"
```

关键约束：

- 构建命令优先使用参数数组，不默认交给 Shell 二次解释。
- SSH 目标允许使用 SSH 别名、域名、IP 或 `user@host`，不保存密码或私钥路径。自定义端口和代理、跳板机等复杂连接选项统一通过 `~/.ssh/config` 配置，避免 SSH 与 `rsync` 行为不一致。
- 本地目录和远端目录必须显式配置。
- Git 脏工作区策略支持 `allow`、`warn` 和 `deny`。
- 未配置 `allowed_branches` 时允许任意分支，但确认页必须给出警告；未配置 `dirty` 时默认使用 `warn`。
- 分离头指针默认警告；当前提交不是本机上次部署提交的后继时，必须按回退或历史分叉加强确认。
- 首版只有一种直接增量覆盖方式，因此不暴露 `strategy` 配置；交互部署默认确认，自动化必须显式使用 `--yes`，因此不持久化 `confirm` 配置。
- 删除同步和原子发布后续按独立协议扩展，不能通过首版保留字段提前承诺。
- 配置协议增加字段时保持向后兼容；破坏兼容性时提升配置版本并提供迁移说明。

### 配置查找顺序

为兼顾标准安装与“命令、配置同目录”的便携模式，按以下顺序查找：

1. `--config` 指定路径。
2. `DISTSHIP_CONFIG` 环境变量。
3. 可执行文件同目录的 `projects.toml`。
4. `${XDG_CONFIG_HOME:-$HOME/.config}/distship/projects.toml`。

禁止自动加载当前工作目录中的同名配置，避免在不可信仓库中误执行构建命令。

### 首次使用与激活路径

新用户的标准路径为：安装 → `distship init` → 创建首个目标 → `distship check` → `distship deploy`。

`distship init [directory]` 支持通过位置参数指定目录、显式传入 `.`，或在当前目录可可靠识别为可构建项目、已有配置目录时自动采用当前目录；无法可靠识别时才提示输入项目路径。目录会在其他问题前完成存在性和类型校验。

快速模式只询问项目 ID、环境 ID、构建命令、SSH 服务器和远端目录；项目名称、环境名称、产物目录、当前 Git 分支和脏工作区策略使用检测结果或安全默认值。`--advanced` 用于配置所有字段。SSH 服务器与远端目录默认分为两个明确问题，同时兼容 `bt_250:/www/site` 快捷输入。

初始化先展示项目类型、包管理器、Git 分支、构建命令和产物目录，只将有可靠依据的检测结果设为默认值。同一本地目录已对应唯一目标时，优先复用该目标的项目与环境 ID；多个目标共用目录时，依次使用当前 Git 分支和 `test` 环境尝试确定唯一默认目标，避免包名变化产生重复配置。

新增目标展示完整预览，更新已有目标展示字段级差异并只确认一次；没有变化时不重写配置。显式传入 `--config` 时写入指定位置，否则写入标准 XDG 配置路径。写入前校验候选配置，写入后重新加载并再次校验；初始化只修改本地配置，不连接服务器。

配置不存在时，其他命令不得只返回文件未找到错误，而应直接提示运行 `distship init`，并展示实际查找过的配置位置。当前创建完成后的下一步提示为 `distship list`；`check` 实现后再将标准激活路径延伸到连接与权限检查。

## MVP 范围与优先级

`v0.1.0` 的 P0 能力仅包括：

- 不带参数的交互选择与部署。
- `init`、`list`、`check`、`deploy`、`config validate`、`config remove` 和 `version`。
- `--config`、`--dry-run`、`--yes`、`--no-color` 和 `--lang`。
- 部署确认页中的 Git 摘要、相对本机上次成功部署的提交变化和本机部署历史。
- 本地构建、SSH 只读预检查、`rsync` 增量上传以及明确的成功或失败结果。

`v0.2` 候选能力包括 `show`、完整提交范围查看、结构化输出、安静模式、Shell 补全、运行日志管理，以及部署历史裁剪和损坏恢复。没有真实用户反馈前，不继续扩大首版范围。

## 终端交互

列表和详情采用分组卡片，不使用依赖中文字符宽度的固定列宽表格：

```text
[1] IPD · 测试环境
    标识：ipd:test
    本地：/Users/example/projects/ipd
    远端：bt_250:/www/wwwgit/ipd-front
    分支：test
```

### 只读部署预检查

`check` 已采用“结论优先、异常展开”的默认信息层级。用户先判断是否具备部署条件，再核对代码来源、部署目标、构建方式和最近提交；成功检查压缩为一行，警告单独展开：

```text
DistShip preflight · ipd:test

✓ READY TO DEPLOY

Source  test @ c55a1a91a · clean
Target  bt_250:/www/wwwgit/ipd-front
Build   pnpm build-test → dist

Recent commits · 3 shown · merges hidden

  refactor(icce): 优化连线中插入图形流程
  a6f0684b1 · 任OvO · 08-12 10:04

  refactor(icce): 收敛富文本标签标识与事件载荷职责
  cdecd076d · 任OvO · 08-12 09:14

  feat(icce): 完善条件编辑数据引用与常量联动
  d709316e8 · 任OvO · 08-11 18:28

Checks  local ✓ · build ✓ · Git ✓ · SSH ✓ · remote ✓

No changes were made.
```

预检查信息遵循以下规则：

- 顶部状态使用 `READY TO DEPLOY`；存在非阻断风险时改为 `READY WITH WARNINGS` 并展开具体警告，不能用成功摘要掩盖风险。
- `Source` 将分支、当前版本短哈希和工作区状态合并为一行；当前版本始终表示实际检查的 `HEAD`，即使它是合并提交也保留哈希用于追溯。
- `Recent commits` 默认最多展示最近 3 条非合并提交，不展示合并提交标题；每条第一行保留完整提交标题，第二行按“短哈希 · 作者 · 月日时分”展示元数据，不解析或改写 Conventional Commit 内容。
- 最近提交只表示当前版本附近的代码记录，不得描述为“本次部署变更”；只有本机部署历史落地并找到可靠基线后，才能展示相对本机上次成功部署的提交范围。
- 正常路径将本地目录、构建工具、Git、SSH 和远端权限结果压缩为一行；工作区改动、分离头指针、非 Git 仓库和远端目录待创建等异常或特殊状态单独说明。
- 底部明确提示未执行任何变更；`check` 不构建、不创建远端目录、不上传且不写部署历史。
- 此布局替代此前按“当前提交、提交内容、作者、时间”逐字段展开的预检查草案，降低成功信息噪声并优先支持部署决策。

### 部署确认与提交范围

`deploy` 已复用预检查的结论优先信息层级，并在真正产生副作用前展示部署目标、代码来源、构建方式和提交范围。当前实现遵循以下规则：

- 有本机成功部署记录时，展示从上次提交到当前提交的变更范围，默认最多显示最近 5 条，同时显示提交总数。
- 没有本机部署记录时明确显示“本机暂无记录”，继续展示最近 3 条非合并提交，不把它们描述为本次增量。
- 默认确认页不展示超过 5 条提交；完整提交范围查看作为 `v0.2` 的 `show --commits` 候选能力，首版可提示用户使用对应的 `git log` 命令自行核对。
- 工作区存在未提交改动时，单独展示修改、新增和删除文件数量，并明确提示这些改动会进入构建产物，但不属于提交日志。
- 当前提交不是上次部署提交的后继时，标记为可能回退或历史分叉，并加强确认。
- 非 Git 仓库不展示伪造的提交信息，只显示“非 Git 仓库”。

Git 脏工作区继续遵循配置中的 `allow`、`warn` 和 `deny` 策略。`warn` 必须二次确认，`deny` 直接拒绝部署；工具只提供修复建议，不自动修改 Git 状态。

颜色只在交互式终端中启用，支持 `--no-color` 和 `NO_COLOR` 环境变量；非交互输出不得混入不可控的 ANSI 转义字符。

### 语言策略

`v0.1.0` 已内置英文和简体中文终端界面。运行时依次根据 `--lang`、`DISTSHIP_LANG`、`LC_ALL`、`LC_MESSAGES` 和 `LANG` 选择语言，无法识别时回退英文；支持值为 `auto`、`en` 和 `zh-CN`。命令、选项和配置字段始终保持英文，公开仓库同时提供英文 `README.md` 和中文 `README.zh-CN.md`。

### 本机部署历史

`v0.1.0` 使用本机部署历史计算“本次部署变更”，保存在：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/distship/history.jsonl
```

每次只有在上传成功后才追加记录，至少保存：

```json
{
  "project": "ipd",
  "environment": "test",
  "host": "bt_250",
  "directory": "/www/wwwgit/ipd-front",
  "branch": "test",
  "commit": "c55a1a91a",
  "dirty": false,
  "deployedAt": "2026-08-12T10:40:00+08:00"
}
```

历史基线按“项目、环境、SSH 目标和服务器目录”共同匹配，避免目标目录调整后错误计算提交范围。

本机历史只代表当前电脑通过 `distship` 完成的最近一次成功部署，不能声明为服务器真实版本。服务器可能由其他电脑、用户或持续集成流程更新；界面必须使用“本机上次部署”这一准确表述。上次部署包含未提交改动时，还需提示该产物无法仅由记录的提交完整还原。

不在静态网站根目录写入公开的部署元数据。后续原子发布具备独立非公开元数据目录后，再设计服务器权威版本和跨设备历史同步。

## 部署流程

```text
读取配置
  → 校验项目与环境
  → 检查本地目录和构建工具
  → 检查 Git 分支与工作区策略
  → 读取本机部署历史并计算提交范围
  → 只读检查 SSH 连接、目标目录或最近存在父目录的权限
  → 展示版本、变更范围和部署摘要并确认
  → 执行本地构建
  → 校验产物目录
  → 目标目录不存在时创建远端目录
  → 使用 rsync 上传
  → 输出结果、提交信息和耗时
  → 上传成功后追加本机部署历史
```

### 命令副作用边界

- `list` 只读取本地配置，不读取 Git，也不访问网络。
- `check` 可以读取本地 Git 并建立 SSH 连接，但不得创建目录或写入远端；目标目录不存在时，只检查最近已存在父目录的可写条件。
- `--dry-run` 只读取本地配置、Git 和本机部署历史，不执行构建、不访问网络、不创建目录、不上传，也不追加历史；结果必须明确标记“远端状态未验证”。
- `deploy` 的远端预检查在最终确认前保持只读；只有用户确认后且本地构建与产物校验成功，才允许创建目标目录和上传文件。
- 失败的构建、目录创建或上传不得写入成功部署历史。

## 安全约束

- 远端目录必须是绝对路径。
- 禁止将 `/`、`/www`、用户主目录等宽泛高风险路径作为部署目标。
- 默认不向 `rsync` 传递 `--delete`。
- 删除同步必须显式配置并要求二次确认，不能由普通 `--yes` 静默绕过。
- `--yes` 不能绕过分支拒绝、高风险路径和其他硬性安全阻断。
- 构建失败、产物缺失、SSH 检查失败或远端权限不足时立即停止。
- 工具不得自动修改 Git 分支、提交和工作区文件。
- 分离头指针必须明确提示；分支不在允许列表时默认拒绝部署。
- 工作区有未提交改动时，确认页必须说明提交日志不能完整代表构建内容。
- 本机部署历史只能作为本机增量提示，禁止冒充服务器权威状态。
- 同一部署目标应使用本地锁避免并发部署。
- 日志不得记录密码、私钥内容、令牌和完整敏感环境变量。
- 配置文件视为可信输入；不自动执行来自当前目录或远端下载的配置。
- 首版直接增量覆盖不是原子发布，不能承诺自动回滚；文档和界面不得把测试、预发布能力包装为生产级安全部署。

## 项目结构

首个开源版本直接使用 Go，并按业务能力拆分：

```text
distship/
├── cmd/
│   ├── root.go
│   ├── init.go
│   ├── init_input.go
│   ├── list.go
│   ├── check.go
│   ├── deploy.go
│   └── config.go
├── internal/
│   ├── build/
│   ├── config/
│   ├── deployment/
│   ├── git/
│   ├── history/
│   ├── preflight/
│   ├── project/
│   ├── i18n/
│   ├── presentation/
│   └── transport/
├── .github/workflows/
│   └── ci.yml
├── go.mod
├── go.sum
├── main.go
├── README.md
├── README.zh-CN.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
└── SECURITY.md
```

模块职责：

- `cmd/`：命令参数解析和用例编排，不直接承载 Git、构建或传输细节。
- `internal/config/`：配置查找、TOML 解析、结构校验和版本兼容。
- `internal/project/`：只读识别项目类型、包管理器、构建命令、产物目录和当前 Git 分支。
- `internal/i18n/`：维护英文、简体中文消息和语言选择优先级。
- `internal/git/`：只读获取分支、提交和工作区状态。
- `internal/preflight/`：统一编排本地依赖、Git、SSH、路径和权限检查。
- `internal/build/`：执行配置中的构建命令并校验产物。
- `internal/deployment/`：维护同一目标的本机部署锁，避免并发部署。
- `internal/transport/`：封装 `ssh` 和 `rsync` 调用以及传输结果。
- `internal/history/`：记录本机成功部署并计算提交范围，不承担服务器版本判断。
- `internal/presentation/`：卡片、颜色、交互选择和确认输出。

禁止建立没有明确业务职责的 `utils`、`helpers` 和 `common` 包。

当前仓库已经建立 `git`、`preflight`、`build`、`deployment`、`transport` 和 `history` 等明确的能力边界。初始化输入与命令参数解析已从主流程拆分，目标 ID、SSH 目标校验和配置深拷贝统一归入配置层；检查与部署命令共享目标解析、摘要和警告展示，部署编排与终端呈现分离，预检查警告使用类型化标识，外部命令统一传递命令上下文。命令层只负责编排，不重复实现构建、传输和历史逻辑。

## 实施与发布历史基线（2026-08-12）

> 本节保留 2026-08-12 形成的实施、质量、分发和发布设计基线，用于追溯方案依据；当前进度、下一步和待定事项统一维护在 [[DistShip实施与发布计划]]。两者冲突时以后者为准。

### 当时实施状态

截至 2026-08-12，配置、预检查和可靠部署主路径已经完成：

- 已建立 Go 1.26 模块、Cobra 命令骨架、版本一 TOML 配置模型和严格未知字段校验。
- 已实现配置查找、原子写入、权限收敛、默认值补全、候选配置与写入后双重校验。
- 已实现 `init`、`list`、`check <target-id>`、`deploy <target-id>`、`config validate`、`config remove <target-id>` 和 `version`，部署命令支持 `--dry-run`。
- 已实现英文与简体中文消息目录、终端语言自动检测、`--lang`、`DISTSHIP_LANG`、`--no-color` 和 `NO_COLOR`。
- 已实现目标 ID、SSH 目标与高风险远端目录校验；删除最后一个目标时将原配置重命名为带时间戳的备份，不直接删除。
- 已提供英文和中文 README、示例配置、许可证、贡献说明、安全策略、变更记录及 macOS/Ubuntu 持续集成。
- `check` 已覆盖本地目录、构建工具、Git 分支与脏工作区策略、当前版本与最近三条非合并提交、SSH 连接和远端目录可写性；远端目录不存在时只检查最近可写父目录，不执行创建。
- `deploy` 已覆盖本机部署历史匹配、提交范围计算、确认、本地构建、产物校验、目标锁、远端目录创建、`rsync` 增量上传、结果摘要和成功历史追加；默认不删除远端额外文件。
- 自动化检查已覆盖单元测试、竞态测试、`go vet`、依赖校验和差异格式检查；真实 IPD 目标已完成只读预检查与完整部署验收，本地和远端入口文件校验值一致，部署前后本地 Git 工作区保持干净。
- 已完成当前部署能力的结构清理：检查和部署共享目标解析与展示逻辑，部署工作流与视图拆分，预检查警告类型化，废弃文案、空分支和不准确错误提示已移除。

尚未实现的能力：

- 不带参数的交互目标选择。
- GoReleaser、正式 Release、Homebrew Tap 和第二个真实项目验证。
- 运行日志、历史裁剪与损坏恢复、原子发布和回滚等已明确延后的增强能力。

### 质量保障基线

#### 自动化检查

- 使用 `go test ./...` 执行单元和集成测试。
- 使用 `go vet ./...` 执行基础静态检查。
- 对输出、配置错误和部署摘要使用表驱动测试与黄金文件测试。
- 使用 GitHub Actions 在 macOS 和 Ubuntu 上运行检查。
- 发布前对四个目标平台执行交叉构建，并至少在 macOS 和 Ubuntu 上运行命令级测试。

#### 关键测试场景

- 配置缺失、字段缺失、重复项目和未知配置版本。
- 路径包含空格、中文和特殊字符。
- 普通分支、脏工作区、分离头指针和非 Git 目录。
- 首次部署、有历史记录、历史提交缺失、回退部署和历史分叉。
- 脏工作区部署记录不能被描述为可由单一提交完整还原。
- 构建成功、构建失败和产物目录缺失。
- SSH 不可达、远端目录无权限和 `rsync` 失败。
- `list` 不读取 Git 和网络，`check` 不写远端，`--dry-run` 不构建、不联网且不写历史。
- 远端目录不存在时，预检查不创建目录，确认且构建成功后才创建。
- `--yes` 不能绕过硬性安全阻断。
- 非交互环境、`NO_COLOR` 和 `--no-color` 输出。
- 高风险远端目录被拒绝。

外部命令统一通过测试替身模拟，自动化测试不得连接真实服务器或修改真实项目。

### 分发与安装设计

#### GitHub Releases

每个正式版本发布以下产物：

```text
distship_Darwin_arm64.tar.gz
distship_Darwin_x86_64.tar.gz
distship_Linux_arm64.tar.gz
distship_Linux_x86_64.tar.gz
checksums.txt
```

GitHub Release 同时提供版本说明、兼容性变化和升级注意事项。GoReleaser 负责交叉构建、归档、校验值和 Release 资产上传，GitHub Actions 由 `vX.Y.Z` 标签触发发布流程。

#### Homebrew Tap

macOS 用户的首选安装入口是 Homebrew Tap：

```bash
brew install <owner>/tap/distship
```

升级方式：

```bash
brew upgrade distship
```

Tap Formula 使用 GitHub Release 产物和 SHA-256 校验值，不在安装时要求用户具备 Go 开发环境。

#### 源码安装

Go 开发者可以使用：

```bash
go install github.com/<owner>/distship@latest
```

源码安装属于补充入口；README 的默认安装方式仍为 Homebrew Tap 和 GitHub Release 二进制下载。

#### 运行依赖

DistShip 二进制本身不要求 Go 运行时。执行部署时只检查：

- `git`、`ssh` 和 `rsync`。
- 当前项目配置指定的构建工具。

依赖缺失时应给出针对当前操作系统的检查建议，但不得未经确认自动安装系统软件。

### 当时发布计划

#### 阶段一：协议与骨架

状态：已完成，包括部署模拟模式。

- 建立独立代码仓库和基础目录。
- 使用 Go 建立可交叉构建的单二进制命令骨架。
- 固化命令子命令、退出码和配置版本。
- 实现 `init` 首次配置引导和配置缺失时的行动提示。
- 提供示例配置、中文说明和最小英文说明。
- 明确 MIT 许可证和安全政策。

完成标准：用户能安装命令、创建首个目标、校验配置、列出项目，并在模拟模式下得到稳定结果。

#### 阶段二：可靠部署

状态：主路径已完成，等待第二个静态前端项目验证。

- 已完成本地、Git、SSH 和远端目录只读预检查。
- 已完成确认流程、构建、增量上传和错误处理。
- 已增加部署锁、耗时和结果摘要。
- 已记录本机成功部署历史，在确认页展示当前提交和本次提交范围。
- 已使用测试替身覆盖成功和失败链路。
- 待迁移第二个构建命令或目录结构不同的静态前端项目。

完成标准：至少两个真实项目的测试或预发布环境可稳定替代当前个人脚本，且默认行为不删除远端文件。

#### 阶段三：开源发布

状态：已建立 macOS 与 Ubuntu 持续集成，其余发布链路待实施。

- 建立 Go 测试、静态检查和跨平台持续集成。
- 使用 GoReleaser 生成四个平台压缩包与校验文件。
- 建立 Homebrew Tap 并验证安装与升级链路。
- 补齐安装、升级、卸载、贡献和安全文档。
- 发布 `v0.1.0`，提供源码归档和校验值。
- 收集真实使用反馈，稳定配置和命令协议。

完成标准：新用户无需安装 Go，通过 Homebrew 或 GitHub Release 获取单一二进制，只需具备 Git、SSH、`rsync` 和项目自身构建工具即可完成测试环境部署。

#### 阶段四：增强能力

- 根据用户反馈评估 `show`、完整提交范围、`--json`、`--quiet` 和 Shell 补全。
- 明确运行日志管理，以及部署历史裁剪、并发写入和损坏恢复规则。
- 评估带版本目录和软链接切换的原子发布。
- 增加发布历史、回滚和旧版本清理策略。
- 评估签名、公证、软件物料清单和更完整的供应链校验。
- 根据明确需求独立评估 Windows 支持。

增强能力不纳入 `v0.1.0` 的完成条件。

### 版本与兼容性

- 从 `v0.1.0` 开始发布，`0.x` 阶段允许迭代协议，但每次破坏性变化必须提供迁移说明。
- 稳定命令、配置和退出码后发布 `v1.0.0`。
- 后续遵循语义化版本：破坏兼容性提升主版本，兼容新增功能提升次版本，兼容修复提升补丁版本。
- Go 内部重构不得无故破坏命令、配置查找顺序和主要退出码。

### 验证与风险

#### 验证方式

- 已使用当前 IPD 测试环境完成首个真实迁移和部署样例，并核对本地与远端入口文件校验值。
- 再选择一个构建命令或目录结构不同的真实项目完成第二次迁移，避免配置模型只适配 IPD。
- 先并行保留现有个人脚本，对比两套工具的构建产物和上传结果。
- 在模拟服务器目录验证增量覆盖、失败停止和不删除默认行为。
- 分别在真实 macOS 和 Linux 环境验证安装、初始化、检查和部署主路径。
- 完成自动化检查后再创建首个公开版本标签。

#### 产品验收指标

- 在项目本身可正常构建且 SSH 已配置的前提下，首次使用者从安装完成到首次测试环境部署成功，目标时间不超过 10 分钟。
- 每次部署确认始终展示项目、环境、分支、当前提交和远端目标，不允许用户在目标不明时确认。
- `list`、`check` 和 `--dry-run` 的副作用边界通过自动化测试固定，任何失败链路都不得追加成功历史。
- `v0.1.0` 发布前至少完成两个真实项目迁移，并在 macOS 与 Linux 上各完成一次真实安装和主路径验证。
- 首版不引入使用行为遥测；上述指标通过发布前任务记录和自测清单验证。

#### 已知风险

- Go 可以解决自身逻辑的分发与跨平台问题，但不能消除用户机器上 Git、SSH、`rsync` 和项目构建工具的版本差异。
- macOS 和 Linux 的系统命令参数、路径与权限行为仍有差异，外部命令适配必须通过真实系统测试验证。
- `rsync` 不同版本的参数支持存在差异，需要明确最小版本和兼容参数集合。
- 用户提供的构建命令本身可以执行任意操作，文档必须明确只加载可信配置。
- 仅做增量覆盖可能残留已删除的旧资源；安全删除与原子发布需要后续独立设计。

### 当时待定事项

- `v0.2` 是否提供 `show`、`--json`、`--quiet` 和 Shell 补全，需要根据首版反馈决定；结构化输出的字段和稳定性承诺尚未定义。
- 退出码规范尚未定义。
- 运行日志默认位置、保留期限和脱敏规则的具体实现尚未确定；运行日志与本机部署历史必须分开管理。
- 本机部署历史的裁剪、并发写入和损坏恢复规则尚未确定。
- 服务器权威版本与跨设备部署历史不纳入首版，后续需要结合原子发布协议设计。
- 原子发布所需的服务器目录结构、软链接权限和回滚协议尚未设计。
- GitHub 仓库所属账号、Go 模块完整路径和 Homebrew Tap 名称尚未确定。
- macOS 二进制签名与公证、发布产物签名和软件物料清单是否纳入 `v0.1.0` 尚未确定。

## 相关文档

- [[MOC|DistShip 项目知识地图]]
- [[DistShip实施与发布计划]]
- [[ADR/ADR-001-首版采用Go单二进制并编排系统部署工具]]

## 外部参考

- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/)：用户级配置、状态和可执行文件目录约定。
- [NO_COLOR](https://no-color.org/)：命令行颜色禁用约定。
- [Semantic Versioning](https://semver.org/)：公开版本兼容性规则。
- [Go Release History](https://go.dev/doc/devel/release)：Go 当前稳定版本与支持周期。
- [Cobra](https://github.com/spf13/cobra)：Go 子命令和参数框架。
- [go-toml](https://github.com/pelletier/go-toml)：TOML 配置解析库。
- [Lip Gloss](https://github.com/charmbracelet/lipgloss)：终端排版、颜色和显示宽度处理。
- [GoReleaser](https://goreleaser.com/)：Go 多平台构建与发布自动化。
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)：版本说明与二进制资产分发。
- [Homebrew Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)：个人 Homebrew 软件源的安装和维护方式。
- [GitHub Actions matrix](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)：跨系统和版本矩阵测试参考。
