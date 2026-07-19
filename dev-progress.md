# dev-progress.md

## 2026-07-19 - 任务：扩展 Socks5 隐私清单格式并支持编辑后刷新

### What was done
- 检查 `install.sh` 与 Socks5/WireGuard 文档，确认隐私清单由 `/etc/v2ray-agent/socks5_vpngate_routing_list` 作为单 Socks5 源文件，多 Socks5 使用 `/etc/v2ray-agent/socks5_routing_lists/<alias>.list`。
- 扩展共享清单解析器，支持 Clash 风格 `DOMAIN-SUFFIX`、`DOMAIN-KEYWORD`、`DOMAIN`、`DOMAIN-REGEX`、`IP-CIDR`、`IP-CIDR6`，并保留普通域名、geosite 与 IPv4/IPv6 CIDR 处理。
- 单 Socks5 与多 Socks5 规则生成均输出对应的 sing-box `domain_suffix`、`domain_keyword`、`domain`、`domain_regex`、`ip_cidr` 字段。
- 在两个清单维护菜单中加入“使用编辑器维护清单”和“重新应用规则”；默认编辑器为 `vim`，可由 `EDITOR` 覆盖。
- 文档补充了清单文件路径、手工编辑/刷新命令和支持的规则行格式。

### Testing
- `wsl.exe bash -n /mnt/c/Users/guolei/Documents/v2ray-agent-fork/install.sh` 通过，退出码为 `0`。Windows 直接调用 `bash -n` 会触发仓库脚本的 WSL 环境提示，不作为语法结果。
- 修正 `DOMAIN-REGEX` 解析：保留正则表达式中的逗号，其它 Clash 规则仍忽略第三列策略参数。
- 已完成静态检查：单 Socks5 和多 Socks5 生成链路均读取 `domainKeyword`、`domains` 并写入对应字段；编辑器入口均调用共享的 `editSocks5RoutingListFile`。
- 尚缺：当前 Windows 工作站未提供可直接复用的 Linux `/etc/v2ray-agent` 运行环境，未执行真实 sing-box reload；部署后需在目标机运行规则刷新并用 `jq` 检查生成 JSON。

### Notes
- 改动文件：`install.sh`（解析器、单/多 Socks5 路由和编辑菜单）、`documents/socks5_wireguard_protocol_management.md`（格式和操作说明）、`dev-progress.md`（本轮记录）。
- 回滚方式：恢复上述文件在本轮前的版本；运行时若已生成规则，重新执行旧脚本的 Socks5 规则刷新或删除对应生成文件后重载 sing-box。

## 2026-07-19 - 任务：补充 Clash no-resolve 录入说明

### What was done
- 追加/替换清单入口现在识别带类型前缀的 Clash 规则行，`IP-CIDR,192.0.2.0/24,no-resolve` 会作为一整行写入，不会被逗号拆成三条错误清单。
- 普通域名仍支持使用英文逗号一次追加多个条目；带 `DOMAIN-*`、`IP-CIDR*` 或 `geosite` 前缀的规则要求直接输入完整行。
- `no-resolve` 保留在原始清单文件中；生成 sing-box `ip_cidr` 时只取 CIDR 值。由于 `ip_cidr` 直接按 IP/CIDR 匹配，sing-box 不需要单独的 `no-resolve` 字段。
- 文档增加完整输入示例及该字段在 sing-box 中的等价说明。

### Testing
- `wsl.exe bash -n /mnt/c/Users/guolei/Documents/v2ray-agent-fork/install.sh` 通过，退出码为 `0`。
- `git diff --check` 无实际空白错误。
- 静态确认追加和替换两条路径均调用 `appendSocks5RoutingListInput`，Clash 规则整行保存。

### Notes
- 改动文件：`install.sh`（输入处理、菜单提示和规则解析）、`documents/socks5_wireguard_protocol_management.md`（no-resolve 说明）、`dev-progress.md`（本轮记录）。
- 回滚方式：恢复本轮三项文件；已写入的清单可从备份或 Git 版本恢复，再重新应用 Socks5 规则。

## 2026-07-19 - 任务：改为规则类型选择式清单录入

### What was done
- 追加清单改为先选择 `DOMAIN-SUFFIX`、`DOMAIN-KEYWORD`、`DOMAIN`、`DOMAIN-REGEX`、`IP-CIDR`、`IP-CIDR6` 或 `GEOSITE`，再输入该类型参数。
- 根据所选类型进行参数校验：域名规则调用域名格式检查，IPv4/IPv6 规则分别校验 CIDR 地址和前缀范围，GEOSITE 校验名称字符集。
- `IP-CIDR` 与 `IP-CIDR6` 自动生成带固定参数 `no-resolve` 的完整清单行；用户只输入中间的 CIDR 参数。
- 替换清单改为逐条交互录入，直到用户选择停止；编辑器维护入口保留用于批量和高级格式。
- 文档同步说明“选择类型 -> 输入参数 -> 自动生成规则”的流程。

### Testing
- `wsl.exe bash -n /mnt/c/Users/guolei/Documents/v2ray-agent-fork/install.sh` 通过，退出码为 `0`。
- `git diff --check` 无实际空白错误。
- 静态确认单 Socks5 与多 Socks5 的追加、替换入口均调用 `appendSocks5RoutingRuleInteractive`。
- 尚缺：目标服务器上的真实交互输入和 sing-box 重载验证，需要部署后手工选择每种规则类型进行一次验证。

### Notes
- 改动文件：`install.sh`（交互式规则选择、校验、自动补全和菜单流程）、`documents/socks5_wireguard_protocol_management.md`（交互说明）、`dev-progress.md`（本轮记录）。
- 回滚方式：恢复本轮三个文件；运行时恢复原清单备份后重新执行 Socks5 规则刷新。

## 2026-06-27

### 当前任务：Aimili/VPNGate 增加 PublicVPNList 来源
- 用户说明服务器已安装 `aimili-vpngate`，希望复用已有 Aimili 的 OpenVPN 与四种网卡模式。
- 目标不是在 `socks5-proxy-pool` 中另起 OpenVPN 服务，而是改造 Aimili/VPNGate 相关脚本：让它支持抓取 PublicVPNList 的国家页与节点，而不仅仅从 VPNGate 获取。
- PublicVPNList 页面路径示例：`https://publicvpnlist.com/country/usa/`。
- 页面每行包含：`data-id`、`data-country`、`data-country-name`、`data-host`、`data-ip`、`data-speed`、`data-latency`、`data-port`、`data-proto`、`data-checked-at`，且页面内有 Technical score。
- 需要支持按延迟、速度、Technical score 等字段过滤。

### 待执行
- 阅读现有 Aimili/VPNGate 相关函数，定位抓取、配置生成、网卡模式、本地 SOCKS5 接入流程。
- 设计 PublicVPNList 来源接入点，尽量复用原有 OpenVPN/网卡模式逻辑。
- 修改脚本并验证语法。

## 2026-06-28

### 检查：Socks5 分流是否影响 WireGuard/WARP/其它网络
- 已按当前代码检查 `install.sh` 与相关文档，重点查看 Socks5 单出站、多出站、全局转发、共存重置、WireGuard endpoint/route 生成与清理逻辑。
- 结论：常规“单出站”和“多出站”已做 V2 入站隔离；规则带 `inbound` 条件，只匹配 `singBoxProxyInboundTags()` 中的 V2 节点入站 tag，清单外落到 `01_direct_outbound`，不会用 `route.final` 或全局规则接管 WireGuard/WARP 或其它客户端流量。
- `resetSocks5WireGuardRouteIsolation()` 只清理旧 Socks5/直连覆盖/多 Socks5 生成文件，并明确保留 `wireguard_endpoints_IPv4.json`、`wireguard_endpoints_IPv6.json`、`wireguard_endpoints_IPv4_route.json`、`wireguard_endpoints_IPv6_route.json`。
- 风险点：菜单里的“全局转发”仍是破坏性模式，会删除 WireGuard endpoint/route 与其它分流；界面已有警告“会删除所有已经设置的分流规则，包括 WARP/WireGuard、IPv6 等”。该模式不属于隔离模式。
- 代码层未发现 Socks5 隔离模式写入系统级 `ip rule`/`ip route`/TUN/TPROXY；主要是 sing-box 配置层处理。

### 排查方向：WireGuard 只能 IPv6 握手、IPv4 无法握手
- 判断应从四层分层排查：客户端到 VPS IPv4 UDP 可达性、服务端监听、防火墙/NAT、WireGuard endpoint/AllowedIPs 配置、系统路由/策略路由是否把 UDP 响应发错出口。
- 首要验证是确认 WireGuard 服务端 UDP 端口是否在 IPv4 上监听，外部 IPv4 UDP 包是否到达服务器，以及服务端是否回包。
- 与本项目 Socks5 隔离逻辑的关系：常规 Socks5 隔离不写系统路由，不应阻断 IPv4 握手；若曾使用 Socks5 全局转发或 WireGuard/WARP 全局模式，需要重点检查 sing-box/WARP 配置和系统路由残留。
- 用户现场反馈：`ss -lunp | grep -E 'wg|wireguard'` 和 `iptables -S INPUT | grep 'port'` 没查到端口；`tcpdump` 未安装；`rp_filter` all/default/eth0 均为 `2`；`ip rule` 存在 `32765: from all oif tun0 lookup 100`。下一步应确认实际 WireGuard 是否是内核 wg 服务端还是 sing-box/WARP 客户端 endpoint；若是内核 WireGuard 服务端，必须用 `wg show`/`wg show interfaces` 找 ListenPort，并用 `ss -lun | grep ':端口'` 查 UDP 监听，而不是 grep 进程名。
- 用户补充：`wg show` 有 `listening port`，`ss -lun` 显示端口同时监听 `0.0.0.0` 与 `[::]`；`iptables -S INPUT | grep 端口` 无输出，但 `nft list ruleset` 中存在 `udp dport 端口 ct state { new, untracked } accept`；关闭 rp_filter 后 IPv4 仍不通；`ip route show table 100` 为 `default dev tun0 scope link`，主路由 IPv4 默认仍走 `eth0`；抓包未发现异常，客户端 IPv4 只有发送无接收，IPv6 有双向快速数据。当前更像 IPv4 UDP 到达/回包链路问题：需抓 eth0 上指定客户端 IPv4 与 WG 端口，确认服务器是否收到 IPv4 握手、是否从 eth0 回包；若无入包，查云防火墙/运营商/客户端网络；若有入包无回包，查 INPUT/nft/conntrack/WG peer；若有回包客户端无收包，查上游/安全组/源地址路由。
- 用户抓包确认：IPv4 下服务器 eth0 能收到客户端 UDP handshake initiation（length 148），并立即从服务器公网 IPv4:39232 回 `length 92` handshake response；后续客户端每 5 秒重复发 initiation。`wg show` 能看到该客户端 endpoint/配置；同一 IPv6 配置仅改 endpoint 为 IPv4 后客户端仍收不到服务器包；IPv4 配置连上后 ping WG 网关不通，IPv6 配置可 ping 通。结论更新：客户端不需要公网 IPv4，NAT 客户端可以用 WireGuard；当前服务端已收包并回包，问题基本不在 v2ray-agent/Socks5/服务端监听/服务端防火墙，而在 IPv4 UDP 回包从服务器到客户端 NAT/运营商/本机防火墙路径被丢，或客户端 WireGuard 未收到 handshake response。优先建议换服务端 UDP 监听端口到 443/53/123 等常见端口、换客户端网络对比、查看客户端 WireGuard 日志/抓包。
- 用户反馈：更换 WireGuard UDP 监听端口后 IPv4 正常。结论：故障原因基本确定为原 UDP 端口在 IPv4 路径上被过滤/限速/丢弃，可能发生在客户端侧运营商 NAT、客户端网络防火墙、安全软件、VPS 上游/安全组或中间链路；不是项目 Socks5 隔离逻辑、服务端 WG 配置、服务端监听或 INPUT 防火墙问题。建议长期使用可达性更好的 UDP 端口（如 443/53/123 或实测正常端口），并保持服务端防火墙、云防火墙、客户端 endpoint 端口一致。
- 关于 WireGuard 端口选择：53/123/443 这类常见 UDP 端口通常 NAT/防火墙放行率更高，尤其 UDP 443 常用于 QUIC/HTTP3，UDP 53/123 常用于 DNS/NTP；但常见端口也更容易被全网扫描，且若端口上的流量不像 DNS/NTP，53/123 可能被运营商或网络设备按协议特征限速/拦截。长期建议优先使用 UDP 443 或实测稳定的随机高端口，不建议伪装占用 53/123，除非环境明确只允许这些端口。
- 用户询问文章 `https://www.shuijingwanwq.com/2026/05/04/9689/` 的 WireGuard 多端口方案原理。文章方案核心是让 WG 固定监听 51820，然后用 iptables NAT PREROUTING `REDIRECT --to-port 51820` 把一段 UDP 端口（如 20000:60000）统一重定向到 51820，云防火墙放行整段，客户端 Endpoint 可随意换区间内端口而无需改服务端 WG 配置。该方案是“端口入口映射/快速换端口”，不是协议混淆或真正抗 DPI；会扩大暴露端口面，并可能与其它 UDP 服务冲突。
- 用户询问是否改成纯 IPv6。结论：如果客户端网络长期有稳定 IPv6，纯 IPv6 Endpoint 可绕开 IPv4 NAT/CGNAT/运营商 UDP 端口干扰，通常更干净；但兼容性取决于客户端所在网络是否有 IPv6、IPv6 UDP 是否不被拦、VPS IPv6 路由质量。纯 IPv6 只改变 WG 外层 endpoint 传输路径，不限制隧道内可继续承载 IPv4/IPv6 流量；客户端 Endpoint 使用 `[服务器IPv6]:端口` 格式。
- 用户说明当前配置虽然 Endpoint 看起来是 v4，但客户端填了 v6，实际似乎也是 v6 连接。判断要点：WireGuard 最终外层走 IPv4 还是 IPv6，以客户端 `[Peer] Endpoint` 解析/填写结果与服务端 `wg show` 中该 peer 的 `endpoint` 为准；服务端 peer 配置通常不需要固定 Endpoint，`wg show` 会动态记录客户端来源地址。若客户端 Endpoint 是 `[IPv6]:port` 或域名解析优先 AAAA，则实际就是 IPv6 握手；AllowedIPs 只影响隧道内路由，不决定外层 IPv4/IPv6。
- 用户补充当前是 v4+v6、NAT66。结论：只要客户端实际通过 IPv6 endpoint 握手稳定、隧道内 IPv4/IPv6 访问正常，就无需强行改成纯 IPv6，也无需频繁切换 IPv4 端口；保持当前双栈配置即可。IPv4 端口可作为备用 fallback，只有在无 IPv6 网络或 IPv6 endpoint 异常时再切换到已验证正常的 IPv4 UDP 端口（如 443 或当前可用端口）。
- 用户要求总结 `https://bducds.com/1491/` 与 `https://bducds.com/1464/` 对“想使用 WG 但减少风控几率”的启发。两篇方案分别是 WireGuard+udp2raw（把 WG UDP 包封装成 fake TCP/raw 模式，客户端 WG Endpoint 指向本机 udp2raw 入站，udp2raw 再连服务端并转发到服务端 WG 监听端口；可缓解 UDP 干扰，但需要两端运行 udp2raw、MTU 常需降到约 1200）和 WireGuard over Xray/VLESS（用 Xray dokodemo-door 接本地 WG UDP，再经 VLESS/TCP 隧道转发到远端 WG；隐藏原始 UDP 路径但会引入 TCP-over-TCP/性能损耗与复杂度）。风控降低优先级：IPv6 endpoint/UDP443 可先用；若原生 WG UDP 经常被端口/UDP 干扰，再考虑 udp2raw 或 Xray/VLESS/wstunnel 这类外层封装。
- 用户纠正：`port-manager/port-manager.sh` 需求不是针对 WG 特例检测，而是通用系统深度扫描“端口无绑定/无占用”；用户未安装 WG 但开了同样端口也不应调用 WG 命令报错或依赖具体程序。已按反馈改为通用内核扫描：移除 `wg show interfaces`/`wg show <iface> listen-port` 依赖，新增 `proc_bound_ports()` 读取 `/proc/net/tcp`、`/proc/net/tcp6`、`/proc/net/udp`、`/proc/net/udp6` 解析内核已绑定端口；TCP 只取 LISTEN 状态 `0A`，UDP 取绑定 socket；`listening_ports()` 合并 `ss/netstat` 与 `/proc/net` 结果；`listening_ports_with_procs()` 对 `/proc/net` 补充来源标记为 `kernel`。该方案不依赖具体应用是否安装，目标是判断系统层端口是否已绑定。
- 用户反馈：`Firewall allowed ports` 没有显示，但 `Listening ports` 有显示。判断原因是服务器使用 nftables/iptables-nft，原 `firewall_backend()` 只要存在 iptables 就选 iptables，`firewall_ports()` 只读 `iptables -S INPUT`，而很多发行版实际规则在 nft ruleset 或非 INPUT 链里，导致防火墙开放端口列表为空。已增加 `nftables` 后端和 `firewall_ports_from_nft()`：从 `nft list ruleset` 中解析包含 `accept` 和 `dport` 的 tcp/udp 规则，支持单端口、端口范围、集合；并让 ufw/firewalld/iptables 后端也合并 nft 解析结果，iptables 解析补充 `--dports` 与逗号端口列表。
