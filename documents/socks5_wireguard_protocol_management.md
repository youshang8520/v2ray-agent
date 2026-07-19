# Socks5/WireGuard 共存与协议管理使用说明

## 功能概览

本 fork 增加了三类能力：

1. V2 节点入站隔离的 Socks5 清单过滤。
2. Socks5/WireGuard 共存路由重置。
3. Xray-core 与 sing-box 的统一协议补装、重装、卸载管理。

目标是让 V2 节点、Socks5/AimiliVPN、WireGuard/WARP、其它客户端和其它分流规则互不抢路由。

## 路由设计

### V2 节点流量

V2 节点入站流量按以下顺序处理：

```text
STUN/WebRTC 泄漏流量 -> reject/drop
清单命中             -> Socks5 / AimiliVPN
清单未命中           -> VPS 服务器 IP / 01_direct_outbound
```

Socks5 过滤规则只匹配 V2 节点入站 tag，不设置全局 `route.final`。因此该功能不会接管 WireGuard/WARP 或其它客户端流量。

### WireGuard/WARP 流量

WireGuard/WARP 的 endpoint 与 route 配置保留在原有文件中。Socks5 清单刷新和重置不会删除：

```text
wireguard_endpoints_IPv4.json
wireguard_endpoints_IPv6.json
wireguard_endpoints_IPv4_route.json
wireguard_endpoints_IPv6_route.json
```

WireGuard/WARP 客户端继续使用自己的规则，与 V2 节点流量隔离。

### 其它客户端和其它分流

由于 Socks5 过滤规则带有 V2 入站 tag 条件，非 V2 入站流量不会命中该规则。其它客户端、DNS 分流、IPv6 分流、WireGuard/WARP 分流不应被 Socks5 清单模式接管。

## Socks5 单清单模式

菜单路径：

```text
分流工具 → Socks5分流 → 单出站
```

首次选择"单出站"时，脚本自动完成出站配置与清单启用，无需额外步骤。已安装后进入管理菜单：

```text
1. 配置出站IP/端口（未安装）/ 重新配置出站IP/端口（已安装）
2. 查看分流规则
3. 维护隐私清单（增删/重置，修改后自动刷新规则）
```

清单维护子菜单：

```text
1. 查看清单
2. 追加清单（自动刷新规则）
3. 替换清单（自动刷新规则）
4. 重置默认清单（自动刷新规则）
5. 使用编辑器维护清单
6. 重新应用规则
```

隐私清单文件为纯文本，一行一条规则，路径为 `/etc/v2ray-agent/socks5_vpngate_routing_list`。选择“追加清单”后，脚本先显示规则类型列表，再要求输入该类型的参数，并自动生成完整清单行；用户不需要手工输入 `DOMAIN-SUFFIX,` 或 `IP-CIDR,...,no-resolve` 前缀。参数会按规则类型校验，域名规则拒绝 IP/URL，IPv4/IPv6 CIDR 拒绝域名和错误地址，IP 规则自动补充固定参数 `no-resolve`。选择“替换清单”后同样逐条选择规则类型和参数，直到完成新清单。

“使用编辑器维护清单”默认调用 `vim`，也可通过 `EDITOR` 环境变量指定其它编辑器。编辑完成后选择“重新应用规则”，脚本会重新解析文件并重载 sing-box；该入口适合批量调整已有清单或录入高级格式。

```bash
EDITOR=vim vim /etc/v2ray-agent/socks5_vpngate_routing_list
# 编辑保存后
/path/to/install.sh
# 在 Socks5 分流菜单中选择“重新应用规则”
```

支持的清单行格式包括：普通域名（按 `domain_suffix` 处理）、`DOMAIN-SUFFIX,example.com`、`DOMAIN-KEYWORD,keyword`、`DOMAIN,example.com`、`DOMAIN-REGEX,^...$`、`IP-CIDR,192.0.2.0/24`、`IP-CIDR6,2001:db8::/32` 以及 `geosite:category-name`。

追加菜单中的规则选择与生成结果示例如下：

```text
选择 `DOMAIN-SUFFIX`，参数 `example.com`，生成 `DOMAIN-SUFFIX,example.com`。
选择 `DOMAIN-KEYWORD`，参数 `stream`，生成 `DOMAIN-KEYWORD,stream`。
选择 `DOMAIN`，参数 `login.example.com`，生成 `DOMAIN,login.example.com`。
选择 `IP-CIDR`，参数 `192.0.2.0/24`，生成 `IP-CIDR,192.0.2.0/24,no-resolve`。
选择 `IP-CIDR6`，参数 `2001:db8::/32`，生成 `IP-CIDR6,2001:db8::/32,no-resolve`。
```

`no-resolve` 会保留在原始清单行中。sing-box 的 `ip_cidr` 本身按 IP/CIDR 匹配，不会对 CIDR 进行域名解析，因此生成 sing-box JSON 时不需要额外的 `no-resolve` 字段；刷新后该规则仍然按 IP/CIDR 生效。追加/替换菜单由脚本生成标准 Clash 行；编辑器入口才需要手工维护完整行。

路由行为：

```text
V2 节点清单内 -> socks5_outbound
V2 节点清单外 -> 01_direct_outbound
WireGuard/WARP -> 保持自身配置
```

## 全局转发模式

菜单路径：

```text
分流工具 → Socks5分流 → 全局转发
```

所有 V2 节点入站流量走 Socks5，不按清单。会删除已有分流规则（含 WireGuard/WARP）。

## 多 Socks5 模式

菜单路径：

```text
分流工具 → Socks5分流 → 多出站
```

管理菜单：

```text
1. 查看代理列表
2. 添加代理
3. 编辑代理
4. 删除代理
5. 维护代理清单（增删/清空，修改后自动刷新规则）
6. 查看分流规则
7. 重新应用规则（手动触发，修改清单已自动刷新无需使用）
8. 检查清单冲突
9. 卸载多 Socks5 配置
```

清单维护子菜单：

```text
1. 查看清单
2. 追加清单（自动刷新规则）
3. 替换清单（自动刷新规则）
4. 清空清单（自动刷新规则）
5. 使用编辑器维护清单
6. 重新应用规则
```

每个 Socks5 代理有独立清单：

```text
/etc/v2ray-agent/socks5_routing_lists/<alias>.list
```

多 Socks5 清单也支持通过维护菜单中的“使用编辑器维护清单”直接修改现有条目；手工编辑路径为 `/etc/v2ray-agent/socks5_routing_lists/<alias>.list`，保存后选择“重新应用规则”。

索引文件：

```text
/etc/v2ray-agent/socks5_outbounds.json
```

刷新后会生成：

```text
socks5_multi_<alias>.json
00_socks5_multi_route.json
```

多 Socks5 规则按优先级从小到大匹配。清单冲突检查可发现同一域名/IP 同时出现在多个代理清单的情况。

## Socks5/WireGuard 共存路由重置

菜单路径：

```text
分流工具 → Socks5分流 → 重置路由共存（修复WireGuard/WARP冲突）
```

重置后重新进入"单出站"或"多出站"以重新应用规则。

用途：

- 清理旧 Socks5 分流残留。
- 清理旧多 Socks5 生成文件。
- 清理旧直连覆盖规则。
- 保留 WireGuard/WARP endpoint 与 route。
- 重建 V2 入站隔离 Socks5 清单规则。

会清理的文件包括：

```text
socks5_01_outbound_route.json
00_socks5_vpngate_list_route.json
10_socks5_direct_route.json
00_socks5_direct_route.json
zz_socks5_ipv4_global_route.json
00_socks5_multi_route.json
00_allow_domain_route.json
socks5_multi_*.json
```

会保留的内容包括：

```text
socks5_outbound.json
/etc/v2ray-agent/socks5_outbounds.json
/etc/v2ray-agent/socks5_routing_lists/
wireguard_endpoints_IPv4.json
wireguard_endpoints_IPv6.json
wireguard_endpoints_IPv4_route.json
wireguard_endpoints_IPv6_route.json
```

该功能不清空系统防火墙，不修改 SSH 端口，不删除证书，不卸载核心。

## 统一协议管理

菜单路径：

```text
主菜单 -> 协议管理
```

功能：

```text
1.查看已安装协议
2.新增/补装协议
3.重装协议
4.卸载协议
5.返回主菜单
```

协议管理根据当前核心自动显示可用协议。

### Xray-core 支持的独立管理协议

```text
0.VLESS+TCP+TLS_Vision
1.VLESS+TLS+WS[仅CDN推荐]
3.VMess+TLS+WS[仅CDN推荐]
4.Trojan+TLS
7.VLESS+Reality+Vision
12.VLESS+Reality+XHTTP
```

Xray-core 中的 WS/VMess/Trojan 类协议依赖 VLESS TCP 前置。独立补装这些协议时会自动带上 VLESS TCP 前置，避免补装后没有外部入口。

### sing-box 支持的独立管理协议

```text
0.VLESS+Vision+TCP
1.VLESS+TLS+WS[仅CDN推荐]
3.VMess+TLS+WS[仅CDN推荐]
4.Trojan+TLS
6.Hysteria2
7.VLESS+Reality+Vision
8.VLESS+Reality+gRPC
9.Tuic
10.Naive
11.VMess+TLS+HTTPUpgrade
13.AnyTLS
```

### 新增/补装协议

新增/补装不会删除已有协议。流程：

1. 选择当前核心支持的协议编号。
2. 可输入多个协议编号，用英文逗号分隔。
3. 脚本复用现有证书、路径、用户配置。
4. 只写入目标协议的 inbound 文件。
5. 重载核心。
6. 统一刷新账号展示和订阅。

示例：

```text
1,10,13
```

表示补装 VLESS+TLS+WS、Naive、AnyTLS。

### 重装协议

重装只删除目标协议配置文件，再重新生成目标协议。其它协议不删除。

适合修改协议端口、Reality 目标、Path 或重建配置。

### 卸载协议

卸载只删除目标协议 inbound 文件，并刷新订阅。不会删除证书、其它协议、WireGuard/WARP 配置或 Socks5 清单。

## 账号管理与订阅

账号管理仍使用原菜单：

```text
主菜单 -> 用户管理
```

新增协议后，账号展示、添加用户、删除用户、订阅生成统一走原有链路。

新增用户时会跨已安装协议检查 UUID、password、email、name、username，避免自由组合后不同协议出现重复账号。

补装、重装、卸载协议后会调用订阅刷新，保证订阅链接包含当前协议集合。

## 推荐使用流程

### 首次安装 Socks5 单出站

1. 打开菜单：`vasma`
2. `11` → `4` → `1`（单出站）
3. 脚本自动提示输入 IP/端口，完成后清单规则自动生效

### 已安装，需修改出站 IP/端口

1. `11` → `4` → `1` → `1`（重新配置出站IP/端口）

### 已安装 sing-box + WireGuard/WARP + Socks5，路由冲突修复

1. 更新脚本。
2. 打开菜单：

```text
vasma
```

3. 执行：`11` → `4` → `6`（重置路由共存）
4. 再进入"单出站"或"多出站"重新应用规则。
5. 测试 V2 客户端：
   - 清单内域名显示 AimiliVPN/Socks5 出口。
   - 清单外域名显示 VPS 服务器 IP。
6. 测试 WireGuard/WARP 客户端：
   - WireGuard/WARP 连接正常。
   - 出口不被 V2 的 Socks5 规则接管。

### 已安装部分协议，需要补装协议

1. 打开：

```text
主菜单 -> 协议管理 -> 新增/补装协议
```

2. 输入协议编号，可多选。
3. 安装完成后查看：

```text
主菜单 -> 用户管理
```

4. 确认订阅中包含新增协议。

## 排错

### WireGuard/WARP 重启后仍不可用

优先检查 sing-box 是否存在旧全局 route 或旧 Socks5 final 抢流量。执行：

```text
分流工具 → Socks5分流 → 重置路由共存（修复WireGuard/WARP冲突）
```

然后检查 WireGuard endpoint/route 文件是否存在。

### V2 清单外没有走 VPS IP

检查 `00_socks5_vpngate_list_route.json` 或 `00_socks5_multi_route.json` 是否包含 V2 入站 fallback：

```json
{
  "inbound": ["VLESSTCP", "VLESSWS", "..."],
  "outbound": "01_direct_outbound"
}
```

如果不存在，重新刷新 Socks5 清单或执行共存路由重置。

### Socks5 清单未生效

检查：

1. 是否已安装 Socks5 出站。
2. 清单文件是否为空。
3. 规则文件是否生成。
4. V2 入站是否有 tag。
5. sing-box 是否成功重启。

旧版 Hysteria2/Trojan 配置可能没有 tag，刷新规则时脚本会自动补齐。

### 正常业务域名 ERR_CONNECTION_CLOSED

部分正常业务域名可能包含与 WebRTC TURN/STUN 相同的普通字符串。防泄漏规则不使用宽泛的 `domain_keyword` 匹配，只保留以下精确匹配：

```text
protocol: stun
(^|\.)stun\.
(^|\.)turn\.
UDP 3478/5349
```

该策略用于避免正常业务域名被误判为 TURN/STUN 泄漏流量。

### 协议补装后订阅没有更新

执行：

```text
主菜单 -> 用户管理
```

确认账号展示正常。必要时重新执行协议管理中的重装目标协议。

### Xray-core 补装 WS/VMess/Trojan 后不可用

Xray 的 WS/VMess/Trojan 依赖 VLESS TCP 前置和 Nginx fallback。补装时脚本会自动带上 VLESS TCP 前置。如果仍不可用，检查：

1. VLESS TCP 入站是否存在。
2. Nginx 是否运行。
3. 域名证书是否存在。
4. CDN Path 是否与订阅一致。
5. Xray error log。

### 不应执行的操作

不要直接清空系统防火墙规则作为常规修复手段。系统防火墙可能包含 SSH、面板、业务端口规则。共存路由问题优先通过 sing-box 路由重置解决。
