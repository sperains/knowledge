# 换电脑不用重配：WSL 环境的备份、验证与迁移

一套用了很久的 WSL 开发环境，通常包含语言运行时、包管理器、Shell 配置、SSH 密钥、项目依赖和本地服务。换电脑时，重新安装 Linux 只是开始，逐项恢复这些配置才是耗时的部分。

WSL 提供了 `wsl --export` 和 `wsl --import`，可以把一份发行版的文件系统导出，再在另一台电脑上恢复。微软也将这组命令列为备份和迁移发行版的推荐方式。[参考：WSL 常见问题](https://learn.microsoft.com/en-us/windows/wsl/faq#how-can-i-back-up-my-wsl-distributions)

本文以 WSL 2 为例，完成三个步骤：导出当前环境，在本机验证备份，最后在新电脑恢复。Ubuntu、Debian 等发行版都可以采用这条流程，命令中的注册名称需要按实际环境替换。

## 先分清备份范围

WSL 发行版内的 Linux 文件和通过挂载访问的 Windows 文件，属于不同的存储范围。

| 内容 | 是否由发行版导出覆盖 |
| --- | --- |
| Linux 用户目录中的配置和项目 | 是，文件需实际存放在该发行版内 |
| `/etc` 中的系统配置，包括 `/etc/wsl.conf` | 是 |
| Linux 内安装的工具、依赖和服务文件 | 是 |
| `/mnt/c`、`/mnt/d` 等 Windows 磁盘中的文件 | 否，需要单独备份 |
| 外接磁盘、网络挂载中的数据 | 否，需要单独备份 |
| Windows 用户目录里的 `.wslconfig` | 否，需要单独复制 |
| Windows Terminal、Windows 端编辑器等应用及配置 | 否，需要另外迁移 |
| 其他 WSL 发行版或 Docker Desktop 管理的数据 | 需要分别确认备份方式 |

比如，项目实际保存在 `/home/devuser/projects` 中，会随该发行版导出；项目保存在 `/mnt/d/projects` 中，则需要另外复制 Windows 的 `D:\projects`。符号链接也要检查其目标，保留链接不等于备份了链接指向的外部数据。

位于发行版内的数据库文件也会进入备份，但导出前应正常停止数据库服务，保证数据一致。备份中可能包含私钥和访问令牌，存放和传输时要保护好。

## 在旧电脑导出环境

以下 `powershell` 代码块在 **Windows PowerShell** 中执行，`bash` 代码块在 **Linux 终端**中执行。

本文使用以下通用示例：

| 项目 | 示例值 |
| --- | --- |
| 原发行版注册名称 | `Ubuntu` |
| Linux 用户名 | `devuser` |
| 备份文件 | `D:\WSL-Backup\Ubuntu-backup.tar` |
| 测试发行版名称 | `WSL-Backup-Test` |
| 正式恢复后的名称 | `Ubuntu-Restored` |

`devuser` 只是示例，请替换成原环境中已有的用户名。D 盘也可以换成其他盘符，后续命令中的路径需要同步调整。备份目录应留出足够空间，恢复测试还需要额外容纳一份解包后的环境。

### 确认发行版名称和用户名

```powershell
wsl --list --verbose
```

`NAME` 列是后续命令使用的注册名称，`VERSION` 列应为 `2`。名称可能是 `Ubuntu`、`Ubuntu-24.04` 或其他值，不要仅凭开始菜单里的名称判断。

查看原环境中的 Linux 用户名：

```powershell
wsl -d Ubuntu whoami
```

如果需要迁移多份发行版，分别导出为不同文件。

### 保存工作，停止服务

先保存文件，正常退出开发工具，停止数据库、开发服务器等需要收尾的服务。在 Linux 终端里执行 `exit` 只会退出当前 Shell，其他进程可能继续运行。

接着在 PowerShell 中创建目录并关闭 WSL：

```powershell
New-Item -ItemType Directory -Force D:\WSL-Backup
wsl --shutdown
```

`shutdown` 会关闭所有正在运行的 WSL 发行版及 WSL 2 虚拟机。如果只想关闭目标发行版，可以改用 `wsl --terminate Ubuntu`。这两种操作都会终止进程，所以正常停止服务应放在它们之前。

### 导出为 TAR 文件

```powershell
wsl --export Ubuntu D:\WSL-Backup\Ubuntu-backup.tar
$LASTEXITCODE
```

等待导出结束，立即查看 `$LASTEXITCODE`。最终显示操作成功且退出码为 `0`，说明命令执行成功；出现失败信息或非零退出码时，应先排查问题。

`$LASTEXITCODE` 记录最近一次外部程序的退出码，运行其他外部命令后可能改变，因此要紧跟导出命令检查。TAR 是 `wsl --export` 的默认格式。[参考：WSL 基本命令](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#export-a-distribution)

后续备份建议在文件名里加日期，保留上一份已验证的备份。不要让一次新导出替代唯一的可用备份。

## 用恢复测试验证备份

备份文件存在、大小合理，只能作为初步检查。更有用的验证是把它导入成一份独立环境，再检查日常工作能否继续。

### 创建测试副本

先检查已有名称：

```powershell
wsl --list --verbose
```

确认没有名为 `WSL-Backup-Test` 的发行版，且 `D:\WSL-Test\Ubuntu` 未被其他环境使用。如果名称已存在，换一个新名称和目录即可。

```powershell
New-Item -ItemType Directory -Force D:\WSL-Test
wsl --import WSL-Backup-Test D:\WSL-Test\Ubuntu D:\WSL-Backup\Ubuntu-backup.tar --version 2
$LASTEXITCODE
```

`--import` 的三个位置参数依次是新发行版名称、环境存放目录、备份文件路径。存放目录用于保存恢复后的 Linux 虚拟磁盘，与 TAR 备份文件是两个独立对象。

导入成功后，按默认用户启动测试环境：

```powershell
wsl -d WSL-Backup-Test --cd ~
```

恢复副本中的自启动服务和定时任务也可能开始运行。如果它们会向外部系统写数据，测试前应安排好网络和服务状态。

### 检查实际工作所需的内容

进入 Linux 后检查用户和目录：

```bash
whoami
ls -la ~
```

如果 `whoami` 输出原来的用户名，默认用户已正确恢复，无需调整。如果输出 `root`，可以按后文“检查 Linux 默认用户”中的方法处理，将命令里的发行版名称换成 `WSL-Backup-Test`。

然后按平时的工作方式验证：

- Shell 提示符、别名和常用环境变量是否正确。
- 项目目录、重要文件和未提交改动是否存在。
- 常用工具能否运行，版本是否符合预期。
- 一个代表性项目能否完成本地检查或构建。
- 本地数据库能否启动并读取所需数据。

工具检查可以使用这些命令，只运行实际安装过的工具：

```bash
git --version
node --version
python3 --version
```

进入实际项目目录后，再通过 `git status` 检查工作区。特别重要的文件，可以在原环境与恢复副本中分别计算 `sha256sum`，比较文件内容。

导入成功、环境能启动，并且关键工作检查通过，就有了这份备份可用于恢复的实际证据。它仍是一份导出时的备份，之后新增的工作需要继续保存。

### 验证后清理副本

测试环境可以保留；需要释放空间时，先在 Linux 终端退出：

```bash
exit
```

在 PowerShell 中核对名称，再删除测试副本：

```powershell
wsl --list --verbose
```

确认目标是 `WSL-Backup-Test` 后执行：

```powershell
wsl --terminate WSL-Backup-Test
wsl --unregister WSL-Backup-Test
```

**`unregister` 会永久删除指定发行版实例及其内部数据，文件不会进入回收站。核对名称后再执行。** 这里删除的是测试副本，原来的 Ubuntu 和 TAR 备份文件都保留。

几个容易混淆的命令，可以放在一起看：

| 命令 | 作用 | 删除内部数据 |
| --- | --- | --- |
| `exit` | 退出当前 Linux Shell | 否 |
| `wsl --terminate 名称` | 关闭指定发行版 | 否 |
| `wsl --shutdown` | 关闭所有 WSL 环境及 WSL 2 虚拟机 | 否 |
| `wsl --unregister 名称` | 删除指定发行版实例 | 是 |

清理时使用 `terminate`，可以让其他 WSL 环境继续运行。删除商店安装的发行版实例后，其 Windows 商店应用本身可能仍然保留。[参考：注销或卸载发行版](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#unregister-or-uninstall-a-linux-distribution)

## 复制备份后，用哈希确认内容一致

恢复测试验证备份能否使用，哈希校验则用于检查复制或存储后文件内容是否变化。

在已验证的原备份上计算 SHA256，并保存到同目录：

```powershell
(Get-FileHash D:\WSL-Backup\Ubuntu-backup.tar -Algorithm SHA256).Hash |
    Set-Content -Encoding ascii D:\WSL-Backup\Ubuntu-backup.tar.sha256
```

把 TAR 和 `.sha256` 文件一起复制到移动硬盘或新电脑。如果新电脑也放在 `D:\WSL-Backup`，执行：

```powershell
$expectedBackupHash = (Get-Content D:\WSL-Backup\Ubuntu-backup.tar.sha256 -Raw).Trim()
$actualBackupHash = (Get-FileHash D:\WSL-Backup\Ubuntu-backup.tar -Algorithm SHA256).Hash
$actualBackupHash -eq $expectedBackupHash
```

输出 `True` 表示内容与记录哈希时一致；输出 `False` 时，应重新复制或排查文件。实际路径不同，需要调整命令。哈希一致不能代替前面的恢复测试。

## 在新电脑恢复环境

### 安装 WSL 组件

新电脑尚未安装 WSL 时，在管理员 PowerShell 中执行：

```powershell
wsl --install --no-distribution
```

按提示重启 Windows。这个命令只安装 WSL 组件，之后直接导入备份。如果已安装 WSL，可以跳过这一步。

本文按新旧电脑 CPU 架构一致的场景说明。跨 x64 与 ARM64 迁移时，需要另外确认发行版和现有二进制程序的兼容性。

### 导入正式环境

完成备份复制和哈希校验，确认磁盘空间充足。本文使用新的名称 `Ubuntu-Restored`，便于与新电脑上可能已有的 Ubuntu 区分。

```powershell
wsl --list --verbose
New-Item -ItemType Directory -Force D:\WSL
```

确认名称未被使用，且 `D:\WSL\Ubuntu-Restored` 是未使用的目录，然后执行：

```powershell
wsl --import Ubuntu-Restored D:\WSL\Ubuntu-Restored D:\WSL-Backup\Ubuntu-backup.tar --version 2
$LASTEXITCODE
```

导入成功后启动：

```powershell
wsl -d Ubuntu-Restored --cd ~
```

重复前面的工具、项目和数据库检查，根据新电脑情况调整盘符、Windows 用户目录、代理地址和其他依赖本机的路径。

需要让直接运行 `wsl` 时进入这份环境，可以在 PowerShell 中设置：

```powershell
wsl --set-default Ubuntu-Restored
```

### 检查 Linux 默认用户

Linux 用户账号和用户目录会随发行版文件系统一起恢复，导入时不需要重新创建用户。默认登录用户是否沿用，则取决于恢复出的默认用户设置。

进入环境后执行：

```bash
whoami
```

如果输出原来的用户名，直接使用即可。原环境的 `/etc/wsl.conf` 如果已包含 `[user]` 和 `default=原用户名`，这项配置也会随备份保留。

只有默认进入 `root`、而希望使用原来的普通用户时，才需要调整。可以先退出 Linux，在 PowerShell 中显式指定原用户启动：

```powershell
wsl -d Ubuntu-Restored -u devuser --cd ~
```

`-u` 指定本次启动使用的用户。需要持久设置时，在恢复出的 Linux 环境中，用有管理员权限的编辑器修改 `/etc/wsl.conf`，保留原有设置，在 `[user]` 节中配置：

```ini
[user]
default=devuser
```

如果已有 `[user]` 节，修改其中的 `default`，避免重复添加。用户名必须已经存在于该发行版中。

保存并退出 Linux 后，在 PowerShell 中重启这一份环境：

```powershell
wsl --terminate Ubuntu-Restored
wsl -d Ubuntu-Restored --cd ~
```

进入后运行 `whoami` 确认默认用户。发行版的默认选择与 Linux 默认用户是两个独立设置。[参考：WSL 用户设置](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#user-settings)

## 补上 Windows 侧配置

WSL 的两个配置文件位置不同：[微软配置文档](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)说明了它们的区别。

| 文件 | 位置 | 作用 |
| --- | --- | --- |
| `wsl.conf` | Linux 内的 `/etc/wsl.conf` | 单个发行版的用户、挂载、启动等设置 |
| `.wslconfig` | Windows 的 `%USERPROFILE%\.wslconfig` | WSL 2 的全局内存、CPU、网络等设置 |

如果旧电脑存在 `.wslconfig`，可以在旧电脑的 PowerShell 中单独复制：

```powershell
if (Test-Path "$env:USERPROFILE\.wslconfig") {
    Copy-Item "$env:USERPROFILE\.wslconfig" D:\WSL-Backup\.wslconfig
}
```

迁移到新电脑后，先检查其中的资源限制和路径，再与新电脑的现有设置合并。如果目标位置没有已有配置，可以复制过去：

```powershell
Copy-Item D:\WSL-Backup\.wslconfig "$env:USERPROFILE\.wslconfig"
```

修改完成后，保存 WSL 中的工作，再用 `wsl --shutdown` 关闭所有环境，下次启动时加载新配置。Windows Terminal、Windows 端编辑器、字体和 Docker Desktop 等工具，也需要分别恢复。

## 遇到 socket 导出提示怎么办

导出过程中可能看到这样的信息，具体路径因程序而异：

```text
bsdtar: ./run/example.sock: pax format cannot archive sockets
```

Unix socket 用于本机进程之间通信，TAR 格式无法保存这类对象。程序退出或系统关闭后，磁盘上可能残留 socket 路径，因此即使关闭过 WSL，也可能看到提示。WSL 官方仓库有同类情况的记录。[参考：socket 导出提示](https://github.com/microsoft/WSL/issues/12454)

这类对象通常由服务启动时重新创建，不需要随备份迁移。遇到提示时，先等待导出结束，检查最终结果和退出码，再通过恢复测试确认备份可用。不要仅凭这一行提示认定整个备份失败，也不要为消除提示删除整个应用配置目录。

## 把备份纳入日常维护

完成首次恢复验证后，可以在升级重要工具、调整系统配置或大幅改变环境时导出一份新备份，用日期区分文件，并至少保留上一份已验证的版本。

完整备份之外，项目代码继续通过 Git 或文件备份保存，常用配置也可以放进配置仓库。这样既能恢复一套现成环境，也能保住两次完整备份之间产生的工作。至少一份备份应放在当前电脑之外。
