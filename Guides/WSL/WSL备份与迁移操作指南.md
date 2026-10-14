# WSL 备份与迁移操作指南

整理日期：2026-10-14。

本文用于备份当前 WSL 开发环境，在本机验证恢复结果，以及换电脑后导入环境。文中的示例对应本次讨论的 Ubuntu 环境，备份文件放在 `E:\WSL-Backup`。

## 1. 环境与操作约定

本次已确认的 Linux 环境是 Ubuntu 26.04.1 LTS、WSL 2，Linux 用户名为 `sperains`。发行版在 Windows 中的注册名称以 `wsl --list --verbose` 的实际输出为准，本文按 `Ubuntu` 举例。

| 项目 | 本文示例 |
| --- | --- |
| 原发行版注册名称 | `Ubuntu` |
| Linux 用户名 | `sperains` |
| 备份文件 | `E:\WSL-Backup\Ubuntu-backup.tar` |
| 验证用发行版名称 | `Ubuntu-Backup-Test` |
| 验证环境存放目录 | `E:\WSL-Test\Ubuntu` |
| 新电脑正式环境存放目录 | `E:\WSL\Ubuntu` |

所有标为 `powershell` 的命令都在 **Windows PowerShell** 中执行；标为 `bash` 的命令在 **WSL 的 Linux 终端**中执行。示例路径可以调整，但后续命令中的名称和路径要对应。新电脑没有 E 盘时，改用实际存在的盘符。

本文记录操作步骤，不代表已经完成了备份验证。实际结果需要按第 4 节检查。

## 2. 备份范围

`wsl --export` 导出的是指定发行版的 Linux 文件系统。安装在这份 Ubuntu 内的软件、用户目录和系统配置会随备份迁移。

| 内容 | 是否随 Ubuntu 导出 |
| --- | --- |
| `/home/sperains` 下的配置、项目、未提交改动 | 是，前提是文件实际存放在该发行版内 |
| `/etc` 下的配置，包括 `/etc/wsl.conf` | 是 |
| Linux 内安装的开发工具、依赖和服务文件 | 是 |
| `/mnt/c`、`/mnt/d`、`/mnt/e` 下的 Windows 文件 | 否，需要单独备份 |
| 外接磁盘、网络挂载和其他外部文件系统的数据 | 否，需要单独备份 |
| Windows 用户目录中的 `.wslconfig` | 否，需要单独复制 |
| Windows Terminal、Windows 端编辑器及其设置 | 否，需要单独迁移 |
| Docker Desktop 或其他 WSL 发行版的数据 | 不由本次 Ubuntu 导出覆盖，需要分别确认和备份 |

如果项目目录是指向 Windows 磁盘的符号链接，链接可能保留，但链接指向的数据需要另行备份。位于这份 Ubuntu 文件系统中的数据库文件也在导出范围内；为保证数据一致，导出前应正常停止数据库服务。

备份可能包含 SSH 私钥、访问令牌和其他凭据，应保存在受保护的位置。至少保留一份在当前电脑之外，避免电脑或磁盘损坏时同时失去环境和备份。

## 3. 在旧电脑导出备份

### 3.1 查看发行版名称

在 Windows PowerShell 中执行：

```powershell
wsl --list --verbose
```

核对 `NAME` 列中的名称和 `VERSION` 列中的版本。本文后续导出命令使用 `Ubuntu`，如果实际名称是 `Ubuntu-26.04`，需要替换。

如果有多份需要迁移的发行版，应分别导出为不同文件。

### 3.2 保存工作并正常结束应用

导出前保存编辑中的文件，退出正在运行的 Codex、开发服务器和其他应用；如果有数据库或需要正常收尾的服务，先使用其正常停止方式。

在 Linux 终端执行 `exit` 只是退出当前 Shell，后台服务或其他终端可能仍在运行，因此还需要下一步关闭 WSL。

### 3.3 创建目录并关闭 WSL

在 Windows PowerShell 中执行：

```powershell
New-Item -ItemType Directory -Force E:\WSL-Backup
wsl --shutdown
```

`wsl --shutdown` 会关闭所有运行中的 WSL 发行版和 WSL 2 虚拟机。它会中断其中的进程，但保留磁盘上的文件。关闭后不要重新打开 Ubuntu，等导出完成再启动。

也可以执行 `wsl --terminate Ubuntu`，只关闭需要导出的 Ubuntu；本文使用 `shutdown`，便于在迁移前统一停止 WSL 环境。

### 3.4 执行导出并检查结果

```powershell
wsl --export Ubuntu E:\WSL-Backup\Ubuntu-backup.tar
$LASTEXITCODE
```

导出期间等待命令结束，不要中断。`$LASTEXITCODE` 应在导出结束后立即查看，避免被之后运行的其他外部命令覆盖。

显示“操作成功完成”且退出码为 `0`，说明本次导出命令成功。若退出码非零或出现最终失败信息，保留输出并排查，不要直接把该文件当作已验证的备份。

查看文件大小和修改时间：

```powershell
Get-Item E:\WSL-Backup\Ubuntu-backup.tar | Select-Object FullName, Length, LastWriteTime
```

文件存在且大小合理可以作为初步检查；确认能够恢复，需要执行第 4 节。

后续再次备份时，建议使用日期文件名，比如 `Ubuntu-backup-2026-10-14.tar`，保留上一份已验证的备份。后文的路径也要替换成新的文件名。

### 3.5 单独备份 Windows 侧的 WSL 配置

如果 Windows 用户目录里存在 `.wslconfig`，执行：

```powershell
if (Test-Path "$env:USERPROFILE\.wslconfig") {
    Copy-Item "$env:USERPROFILE\.wslconfig" E:\WSL-Backup\.wslconfig
}
```

`.wslconfig` 控制 WSL 2 的全局设置，比如内存、CPU 和网络相关选项。它在 Windows 侧，与 Linux 内的 `/etc/wsl.conf` 是两个不同文件。换电脑后需要根据新电脑资源和路径检查其内容。

## 4. 在本机验证备份

最直接的验证方式是导入一份临时环境，实际启动并检查。测试环境需要额外磁盘空间，不能只按 TAR 文件大小预留空间，还要容纳解包后的文件系统和运行时新增数据。

### 4.1 导入为独立的测试环境

先检查名称是否已经存在：

```powershell
wsl --list --verbose
```

确认列表中没有 `Ubuntu-Backup-Test`，且 `E:\WSL-Test\Ubuntu` 未被其他环境使用。如果已存在，可以使用另一个新名称和目录，不要为了腾出名称直接删除不明环境。

执行：

```powershell
New-Item -ItemType Directory -Force E:\WSL-Test
wsl --import Ubuntu-Backup-Test E:\WSL-Test\Ubuntu E:\WSL-Backup\Ubuntu-backup.tar --version 2
$LASTEXITCODE
```

参数含义如下：

| 参数 | 含义 |
| --- | --- |
| `Ubuntu-Backup-Test` | 新建发行版的注册名称 |
| `E:\WSL-Test\Ubuntu` | 导入后的 Linux 虚拟磁盘存放目录 |
| `E:\WSL-Backup\Ubuntu-backup.tar` | 用于恢复的备份文件 |
| `--version 2` | 使用 WSL 2 |

这里会建立独立的测试副本，保留原来的 Ubuntu 和 TAR 文件。测试时不需要把它设为默认发行版，使用 `-d Ubuntu-Backup-Test` 指定即可。

### 4.2 启动测试环境

```powershell
wsl -d Ubuntu-Backup-Test --cd /home/sperains
```

恢复副本启动时，原有的自启动服务也可能启动。如果配置了向外部系统写数据的定时任务或服务，应在启动前考虑测试时的网络和服务安排。

进入 Linux 后执行：

```bash
whoami
cat /etc/wsl.conf
ls -la /home/sperains
```

当前环境的 `/etc/wsl.conf` 已确认包含：

```ini
[boot]
systemd=true

[user]
default=sperains
```

正常情况下，`whoami` 应输出 `sperains`。

### 4.3 检查常用配置、工具和项目

按平时的工作方式检查这些内容：

- Shell 提示符、常用别名和环境变量是否正常。
- 项目目录、重要文件和未提交改动是否存在。
- 常用工具能否运行，版本是否符合预期。
- 进入常用项目，执行一次熟悉的本地检查或构建。
- 如果有数据库，确认服务能启动并读取需要的数据。

比如检查工具时可以执行以下命令，仅运行实际安装过的工具：

```bash
git --version
node --version
python3 --version
```

检查项目时，先进入实际项目目录，再执行：

```bash
git status
```

对于特别重要的文件，可以与原环境中的对应文件分别计算 `sha256sum`，比较内容是否一致。测试通过后仍应保留备份文件。

### 4.4 判断验证是否通过

记录以下结果：

- [ ] 导入操作成功，退出码为 `0`。
- [ ] 测试环境可以正常启动，默认用户正确。
- [ ] 重要配置和项目文件存在。
- [ ] 常用工具可以运行。
- [ ] 代表性项目检查或构建通过，相关数据库数据可读取。

这些检查可以验证备份能否满足实际恢复需求。文件大小、TAR 目录列表或单独的哈希值，都不能代替恢复后的使用检查。

## 5. 验证后清理测试环境

可以继续保留测试环境；需要释放空间时，再进行清理。

在测试环境的 Linux 终端中退出：

```bash
exit
```

回到 Windows PowerShell，先核对名称：

```powershell
wsl --list --verbose
```

确认目标是验证用的 `Ubuntu-Backup-Test` 后执行：

```powershell
wsl --terminate Ubuntu-Backup-Test
wsl --unregister Ubuntu-Backup-Test
```

**`unregister` 会永久删除指定发行版实例及其内部文件，数据不会进入回收站。执行前务必核对名称，不要把测试名称改成原来的 `Ubuntu`。**

| 命令 | 作用 | 是否删除发行版内部数据 |
| --- | --- | --- |
| `exit` | 退出当前 Linux Shell | 否 |
| `wsl --terminate Ubuntu-Backup-Test` | 关闭指定测试环境 | 否 |
| `wsl --shutdown` | 关闭所有 WSL 环境及 WSL 2 虚拟机 | 否 |
| `wsl --unregister Ubuntu-Backup-Test` | 删除指定测试环境 | 是 |

这里用 `terminate`，是因为只需要停止测试环境，原来的 Ubuntu 可以继续使用。`shutdown` 也能关闭测试环境，但会同时中断其他 WSL 环境中的工作。

正确执行上述清理命令后，原来的 `Ubuntu` 和 `E:\WSL-Backup\Ubuntu-backup.tar` 都会保留。`unregister` 删除的是本机注册的发行版实例；通过微软商店安装的发行版应用本身可能仍然存在。

## 6. 复制备份并校验内容

在已验证的备份文件上计算 SHA256：

```powershell
Get-FileHash E:\WSL-Backup\Ubuntu-backup.tar -Algorithm SHA256
```

可以把哈希值写到同目录，随备份一起保存：

```powershell
(Get-FileHash E:\WSL-Backup\Ubuntu-backup.tar -Algorithm SHA256).Hash |
    Set-Content -Encoding ascii E:\WSL-Backup\Ubuntu-backup.tar.sha256
```

将 TAR、哈希文件以及需要迁移的 `.wslconfig` 复制到移动硬盘或其他受保护的备份位置。复制完以后，对目标位置的 TAR 再执行 `Get-FileHash`，比较两个哈希值。

新电脑上，如果备份和哈希文件仍放在 `E:\WSL-Backup`，可以执行：

```powershell
$expectedBackupHash = (Get-Content E:\WSL-Backup\Ubuntu-backup.tar.sha256 -Raw).Trim()
$actualBackupHash = (Get-FileHash E:\WSL-Backup\Ubuntu-backup.tar -Algorithm SHA256).Hash
$actualBackupHash -eq $expectedBackupHash
```

输出 `True` 表示与记录哈希时的文件内容一致；输出 `False` 时，先重新复制或排查备份文件，不要继续恢复。哈希用于发现复制或存储后的内容变化；恢复测试用于验证备份是否可用。

## 7. 在新电脑导入正式环境

### 7.1 安装 WSL

在新电脑的 **管理员 PowerShell** 中执行：

```powershell
wsl --install --no-distribution
```

按提示重启 Windows。这个命令安装 WSL 组件，后续直接导入已有备份即可。如果新电脑已装好 WSL，可以跳过安装。

检查状态：

```powershell
wsl --version
wsl --status
```

本文按新旧电脑均为 x86_64 的迁移场景编写。若新电脑是 ARM 架构，不能直接假定原有 x86_64 工具和二进制文件都能正常运行，需要另行确认兼容性。

### 7.2 准备文件和目录

把备份复制到新电脑并完成第 6 节的哈希校验。检查可用磁盘空间，以及现有发行版名称：

```powershell
wsl --list --verbose
New-Item -ItemType Directory -Force E:\WSL
```

确认没有名为 `Ubuntu` 的现有发行版，且 `E:\WSL\Ubuntu` 未被其他环境使用。如果名称已存在，可用 `Ubuntu-Restored` 等新名称导入，后续命令同步替换。无需先删除现有发行版。

### 7.3 导入并启动

```powershell
wsl --import Ubuntu E:\WSL\Ubuntu E:\WSL-Backup\Ubuntu-backup.tar --version 2
$LASTEXITCODE
```

确认导入成功后再执行：

```powershell
wsl --set-default Ubuntu
wsl -d Ubuntu --cd /home/sperains
```

`--set-default` 设置以后直接运行 `wsl` 时使用的发行版；它与 Linux 默认用户名是两个不同设置。

在新电脑重复第 4 节的工具和项目检查。检查 Windows 盘符、用户名目录、挂载路径、代理地址和其他依赖本机的配置，根据新电脑实际情况调整。

### 7.4 恢复 Windows 侧配置

如果备份了 `.wslconfig`，先查看其内容，并检查新电脑是否已有自己的配置。根据新电脑的内存、CPU、网络设置和路径修改或合并，确认后再放到 Windows 用户目录中。

对于 Windows 用户目录下没有现有 `.wslconfig` 的情况，可以执行：

```powershell
Copy-Item E:\WSL-Backup\.wslconfig "$env:USERPROFILE\.wslconfig"
```

配置修改后，先保存 WSL 内的工作，再执行：

```powershell
wsl --shutdown
wsl -d Ubuntu --cd /home/sperains
```

Windows Terminal、Windows 端编辑器、Docker Desktop 及相关 Windows 工具还需要分别安装或恢复设置。

## 8. 常见问题

### 8.1 导出提示 `pax format cannot archive sockets`

本次遇到的提示是：

```text
bsdtar: ./home/sperains/.codex/app-server-daemon/daemon-updater.sock: pax format cannot archive sockets
```

已检查该路径对应 Unix socket，用于进程之间通信。TAR 格式不能归档这种文件，因此会提示无法保存它。WSL 官方仓库也有同类导出提示的记录，见 [Export Warning/Error](https://github.com/microsoft/WSL/issues/12454)。

直接关闭 WSL 会终止进程，socket 文件可能来不及清理；正常退出应用可以减少这类残留，但仅凭这个提示不能确认它一定由非正常退出导致。

socket 通常在程序启动时重新创建，不需要随备份迁移。它与旁边保存配置或记录的普通文件是不同对象。不要因此删除整个 `.codex` 目录。

遇到这个提示时，先等待导出结束，检查最终结果和退出码，再按第 4 节验证恢复。即使进度继续增长，也只能说明导出仍在进行，不能代替最终成功判断。

### 8.2 导入后默认进入 root

先确认恢复出的用户是否存在。在 Windows PowerShell 中显式指定用户：

```powershell
wsl -d Ubuntu -u sperains --cd /home/sperains
```

如果需要修正默认用户，在该发行版中用有管理员权限的编辑器修改 `/etc/wsl.conf`，保留现有配置，并在 `[user]` 节中设置：

```ini
[user]
default=sperains
```

避免重复添加 `[user]` 节。保存并退出后，在 PowerShell 中执行：

```powershell
wsl --terminate Ubuntu
wsl -d Ubuntu --cd /home/sperains
```

如果修复的是测试环境，以上命令中的名称应替换成 `Ubuntu-Backup-Test`。本次原环境已配置默认用户，正常导出和导入后应保留这项设置。

### 8.3 项目目录存在，但文件打不开

检查目录是否指向 `/mnt/c` 等 Windows 挂载位置，或依赖外部磁盘。导出保留发行版内的文件，外部数据仍需单独迁移。新电脑的盘符或 Windows 用户名不同，也可能使旧路径失效。

### 8.4 导入提示名称已存在

使用 `wsl --list --verbose` 确认现有名称，为恢复副本选择新名称和未使用的目录即可。不要为解决名称冲突直接执行 `unregister`，除非已经确认要删除那份环境及其数据。

### 8.5 删除测试环境后还能恢复吗

只要 TAR 备份仍然完整，就可以重新 `wsl --import`。删除测试环境后产生的新增文件和改动不会自动写回原 TAR；如果需要保留这些内容，应在删除前另行备份或重新导出。

## 9. 后续备份安排

完成首次恢复验证后，每次大幅调整开发环境时再导出一份，用日期区分文件，至少保留上一份已验证备份。项目代码仍按平时的 Git 或文件备份方式保存，降低两次完整备份之间丢失工作内容的风险。

本文现保存在知识库的 `Guides/WSL/` 目录中。如果知识库实际位于该 Ubuntu 的文件系统内，以后导出时也会随文件系统进入备份。此前已经导出的 TAR 不会自动包含后来新增的文档，可将本指南单独复制到备份目录。

## 参考资料

- [微软：WSL 基本命令](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)
- [微软：WSL 高级配置，`.wslconfig` 与 `wsl.conf`](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [WSL 官方仓库：socket 导出提示记录](https://github.com/microsoft/WSL/issues/12454)
