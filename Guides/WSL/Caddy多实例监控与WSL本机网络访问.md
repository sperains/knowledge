# Caddy 多实例监控与 WSL 本机网络访问

整理日期：2026-11-02。更新日期：2026-11-03。状态：监控页与后台采集服务已在本机接入，本文记录当前实现及本次确认的排查结论。

监控文件目录：`/home/sperains/.config/caddy/sites/monitor`。该目录不是 Git 仓库，无可用提交基线；实现细节以目录中的 `README.md`、`monitor.py`、`Caddyfile` 和 `index.html` 为准。上一级的 `monitor.caddyfile` 仅保留 `import monitor/Caddyfile`，继续接入主配置已有的 `sites/*.caddyfile` 导入规则。

## 1. 多实例共用管理端口

`caddy run` 启动独立进程，不会自动把配置合并进 systemd 管理的实例，也不等同于给已有进程重载配置。`caddy reload` 会通过管理 API 向接收请求的实例加载完整新配置，不是追加一个站点。

Linux 下 Caddy 的监听器使用 `SO_REUSEPORT`，多个进程可能同时监听 `2019`。本次实际发现 systemd 和手动启动的两个进程共用该管理端口，分别提供三个静态项目和一个反向代理。直接查询 `2019/config/` 时，返回内容会随请求命中的进程变化；这不代表原静态站点配置文件被删除或覆盖。

管理 API 返回的是接收请求的那个实例的配置，不是整台机器所有 Caddy 实例的汇总。因此，单次查询同一个管理地址不足以稳定枚举所有实例，也不能只按 `srv0` 等配置内服务键判断进程身份。

在 WSL 终端检查实例与端口归属：

```sh
pgrep -a -x caddy
systemctl show caddy -p MainPID
sudo ss -ltnp 'sport = :2019'
```

PID 会变化，以当前进程和套接字归属为准。多个实例共用管理端口时，普通 `caddy reload` 或 `caddy stop` 也可能命中不同实例；需要针对特定进程操作时，应先明确目标，独立管理地址可避免此类歧义。本次没有要求用户为每次临时运行登记配置文件或更改管理端口。

## 2. 当前监控实现

| 组件 | 位置与职责 |
| --- | --- |
| 页面 | `http://localhost:2020`，由 `index.html` 实现 |
| Caddy 页面配置 | `monitor/Caddyfile`，由根目录 `monitor.caddyfile` 导入，绑定 `127.0.0.1:2020`，支持 localhost 与 IPv4 回环访问 |
| 浏览器数据接口 | 固定的 `GET /api/instances`，由 Caddy 转发给采集器 |
| 采集器 | `monitor.py`，只监听 `127.0.0.1:2023`，使用 Python 标准库 |
| 系统服务 | `caddy-monitor.service`，以 root 运行并由 systemd 管理 |

页面按实例分组，展示进程名称、PID 和启动时指定的配置文件路径。每组保留端口、项目名称、直接可见的目录或代理地址、类型和“打开”操作。面板自身不进入项目列表和统计。

打开页面时读取一次，之后只通过按钮手动刷新；不定时轮询，也不在切回标签页时刷新。搜索支持实例、端口、项目、域名和目录。页面不再展示“更多”折叠内容、重复端口、内部服务编号等信息。

采集器的归属识别流程：

1. 从 `/proc` 自动发现同一 Linux/WSL 进程与网络命名空间内的 `caddy run` 进程，通过 PID 与进程启动时间组合识别实例，避免 PID 复用后沿用旧缓存。
2. 读取监听套接字，发现候选 TCP 管理地址；对共用地址建立多次新连接。
3. 在请求连接仍有效时，将 `/proc/net/tcp`、`tcp6` 中的已接受连接 inode 与各进程的 `/proc/<pid>/fd` 对照，确认实际接收管理请求的 PID。
4. 读取该连接返回的运行配置，并归入对应进程；配置文件路径只用于识别来源，不代替运行配置数据。

服务以 root 运行，是为了读取其他用户（如 systemd 的 caddy 用户）进程的套接字描述符。采集器只发送 GET 请求，不启动、停止或重载 Caddy。

共用端口的连接分配仍有不确定性，采集有次数和时间上限，不能保证每轮命中全部实例。未读到的实例保留自己的上次配置并标记失败；首次未读到时显示暂无可读配置。某实例失败不覆盖其他实例的数据，已退出的进程会移除。

监控目录内统一保存以下六个文件：

```text
monitor/
├── Caddyfile
├── index.html
├── monitor.py
├── test_monitor.py
├── caddy-monitor.service
└── README.md
```

采集服务的 `ExecStart` 使用 `/usr/bin/python3 /home/sperains/.config/caddy/sites/monitor/monitor.py`。从旧目录迁移时，需要重新安装 unit、执行 `daemon-reload` 并重启采集服务；已有 Caddy 站点配置仍保留在 `sites/` 根目录。

## 3. 安装与维护

以下命令在 WSL 宿主终端执行，不能用隔离工具容器中的进程视图代替宿主进程视图：

```sh
cd /home/sperains/.config/caddy/sites/monitor
sudo install -m 644 caddy-monitor.service /etc/systemd/system/caddy-monitor.service
sudo systemctl daemon-reload
sudo systemctl enable --now caddy-monitor
```

状态、日志与接口检查：

```sh
sudo systemctl status caddy-monitor --no-pager
sudo journalctl -u caddy-monitor -n 30 --no-pager
curl -sS http://127.0.0.1:2023/api/instances
curl -sS http://localhost:2020/api/instances
```

文件修改的生效方式：

- 修改 `index.html`：刷新浏览器即可，无需重载 Caddy。
- 修改 `monitor.py`：重启 `caddy-monitor` 服务，使进程加载新代码。
- 修改 `caddy-monitor.service`：重新安装 unit 文件、执行 `daemon-reload`，再重启采集服务。
- 修改本目录的 `Caddyfile` 或上一级 `monitor.caddyfile`：需要更新面板所在 Caddy 实例的运行配置。主配置 `/etc/caddy/Caddyfile` 已导入 `sites/*.caddyfile`，应加载包含全部站点的主配置，而不是只用面板文件替换整份运行配置。共享管理端口时，必须明确目标实例；本次用携带 `If-Match` 的条件 API 更新只替换面板服务段，原静态站点和反向代理配置保持不变。

### 停用、卸载与移除面板

以下步骤按需在 WSL 终端手动执行。本次只补充操作文档，没有停用服务或删除运行文件。

停用采集器并取消开机启动，保留 unit 和源文件，便于恢复：

```sh
sudo systemctl disable --now caddy-monitor.service
```

恢复时执行 `sudo systemctl enable --now caddy-monitor.service`。

卸载已安装的采集服务：

```sh
sudo systemctl disable --now caddy-monitor.service
sudo rm -f -- /etc/systemd/system/caddy-monitor.service
sudo systemctl daemon-reload
```

卸载后采集器退出并释放 `2023`，`2020` 面板仍由 Caddy 托管，但数据接口会失败。工作区中的服务文件与代码保留，可按安装步骤重新安装。

如果还要移除整个监控面板，先将面板配置移出 `*.caddyfile` 导入范围并校验主配置：

```sh
cd /home/sperains/.config/caddy/sites
mv -- monitor.caddyfile monitor.caddyfile.disabled
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

校验通过后，使主实例重新读取主配置。当前 `caddy.service` 的启动命令使用 `/etc/caddy/Caddyfile`；在多个进程共用 `2019` 时，按服务名重启可以明确目标：

```sh
sudo systemctl restart caddy.service
```

这会短暂中断该服务托管的静态站点，手动启动的 Caddy 进程不随之重启。如果主实例已使用独立管理地址，也可通过 `caddy reload` 的 `--address` 明确目标，以平滑重载代替重启；不能仅凭 `systemctl reload caddy` 的服务名判断 API 请求会命中哪个进程。

确认面板已从运行配置移除、`2020` 不再监听后，可选清理本次新增的源文件：

```sh
cd /home/sperains/.config/caddy/sites
rm -f -- monitor.caddyfile.disabled
rm -rf -- monitor
```

上述清理保留原有 `jd-*.caddyfile`、主配置、Caddy 程序和知识库文档。不要直接删除整个 `sites` 目录。

卸载后的检查：

```sh
systemctl status caddy-monitor.service --no-pager
sudo ss -ltnp '( sport = :2023 or sport = :2020 )'
```

unit 文件移除后，`status` 提示服务不存在是预期结果。仅卸载采集器时应无 `2023` 监听；完整移除面板后，`2020` 也应无监听。

## 4. localhost、回环与 Hyper-V 防火墙

`localhost` 是回环主机名，通常解析到 IPv4 的 `127.0.0.1` 或 IPv6 的 `::1`。它与具体回环 IP 可以指向同一服务，但 HTTP `Host` 不同；Caddy 的域名匹配和网络监听地址是两个层次。本次曾因只匹配 `127.0.0.1` 而使 `localhost:2020` 返回空的 200 响应，后续配置调整为 `:2020` 配合 `bind 127.0.0.1`。

Mirrored 模式支持 Windows 与 WSL 通过 localhost 通信。WSL 默认启用 Hyper-V 防火墙的 `LoopbackEnabled`，允许宿主与 WSL 的本机回环通信，无需逐个新增端口入站规则。因此，本机能访问 `localhost:2020` 并不表示该端口已对局域网开放。

其他设备通过局域网 IP 访问时，服务必须监听可达接口、HTTP Host 必须匹配，且流量符合防火墙规则。已有允许策略时不一定需要新增规则；仅放行端口不会让只绑定 `127.0.0.1` 的面板对局域网开放。Windows 本机通过自身其他 IPv4 地址访问 WSL 时，还涉及 Mirrored 模式的 `hostAddressLoopback`，其默认值为 false；本次未修改该设置或 Hyper-V 防火墙规则。

旧版页面曾将浏览器请求直接转发到 Caddy 管理 API：代理移除了 Origin、Referer，却保留浏览器的 `Sec-Fetch-Mode`，导致来源校验返回 403。旧版通过移除 `Sec-Fetch-*` 修复。当前页面经后台采集器读取管理配置，不再沿用浏览器直转管理 API 的数据链路；该 403 也不是防火墙阻断连接。

## 5. 验证与适用边界

截至整理日期，已完成 Caddy 配置校验、6 项采集器测试、页面交互逻辑检查和连续 3 轮实际接口采集验证。实际读取到两个独立 PID，并稳定将静态项目与反向代理分组；原项目运行配置核对未变。页面和浏览器请求头模拟访问返回 200，写入请求返回 405，管理路径和采集器源码路径返回 404。未做真实浏览器视觉验收。

回归命令：

```sh
cd /home/sperains/.config/caddy/sites/monitor
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v test_monitor
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

当前范围是同一 Linux/WSL 进程与网络命名空间中的 `caddy run` 和可读取的 TCP 管理接口。Windows 进程和其他网络命名空间不在发现范围内；禁用管理 API、Unix 套接字管理或远程 TLS 管理端点的实例可显示为进程，但不能读取其项目配置。仅通过 `CADDY_ADMIN` 环境变量改变默认管理地址的场景尚未验证。

页面展示的是已加载配置，不进行项目可用性探测，也不承担整机所有程序端口的监控职责。独立管理地址仍适用于需要明确重载或停止目标实例的运维场景；当前采集器的 PID 识别只用于只读监控。

## 参考资料

- [Caddy 命令行说明](https://caddyserver.com/docs/command-line)：run、reload、stop 的职责。
- [Caddy 管理 API](https://caddyserver.com/docs/api)：配置读取、更新和条件请求。
- [Caddy v2.11.7 监听器源码](https://github.com/caddyserver/caddy/blob/v2.11.7/listeners.go#L106)：Linux 监听器的 SO_REUSEPORT 说明。
- [Caddy v2.11.7 管理接口源码](https://github.com/caddyserver/caddy/blob/v2.11.7/admin.go#L823)：浏览器请求头与来源校验。
- [微软 Hyper-V 防火墙说明](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/hyper-v-firewall#verify-hyper-v-firewall-settings)：LoopbackEnabled。
- [WSL 网络访问](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking)与[WSL 高级配置](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#experimental-settings)：Mirrored、局域网访问和 hostAddressLoopback。
