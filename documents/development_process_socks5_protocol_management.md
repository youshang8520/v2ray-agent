# 开发过程：Socks5/V2 隔离与统一协议管理

## 改造目标

本次改造围绕当前 fork 的实际脚本能力展开，目标包括：

1. 让 V2 节点 Socks5 清单过滤与 WireGuard/WARP、其它客户端、其它分流互不影响。
2. 让 V2 节点实现清单内走 Socks5/AimiliVPN，清单外走 VPS 服务器 IP。
3. 提供安全的 Socks5/WireGuard 共存路由重置能力。
4. 增加安装后的统一协议管理能力，支持 Xray-core 与 sing-box 当前脚本已有完整链路的协议补装、重装、卸载。
5. 保持账号管理和订阅链接统一刷新。
6. 避免主菜单过长，新增能力通过子菜单承载。

## 现状分析

### Socks5 与 WireGuard/WARP 冲突点

原有 Socks5 清单规则容易通过全局 `final` 或全局 route 影响非 V2 流量。对于同时运行 V2 节点和 WireGuard/WARP 的机器，若 Socks5 规则接管全部流量，会导致 WireGuard/WARP 客户端异常，或者 V2 节点清单外流量被 WireGuard 抢走。

### 协议安装方式不足

当前脚本已有任意组合安装，但安装后独立补装/卸载能力不完整：

- Hysteria2、Reality、Tuic 有单独管理入口。
- VLESS WS、VLESS Reality Vision、VLESS Reality gRPC、Naive、AnyTLS 等协议缺少统一补装入口。
- Xray-core 与 sing-box 的协议能力分散在不同函数中。
- 账号展示、添加、删除、订阅生成已有统一链路，应继续复用。

### 可复用实现

当前脚本已有可复用函数：

- `initXrayConfig()`：生成 Xray-core inbound。
- `initSingBoxConfig()`：生成 sing-box inbound。
- `readInstallProtocolType()`：扫描当前已安装协议。
- `showAccounts()`：展示账号并生成订阅本地配置。
- `addUser()`：为已安装协议同步新增账号。
- `removeUser()`：为已安装协议同步删除账号。
- `subscribe false`：刷新订阅。
- `reloadCore()`：重启当前核心。

## 实现内容

### 1. V2 入站隔离规则

新增/改造的核心思路：

```text
Socks5规则只匹配V2节点入站tag
```

V2 入站 tag 由统一函数维护：

```text
singBoxProxyInboundTags()
```

包含当前脚本内可作为 V2 节点入口的 sing-box 协议 tag。

Socks5 单清单和多 Socks5 规则均改为：

```text
inbound in V2 tags AND STUN/WebRTC -> reject/drop
inbound in V2 tags AND 清单命中 -> Socks5
inbound in V2 tags AND 未命中 -> 01_direct_outbound
```

不再设置影响全局的 `route.final`。

### 2. 旧入站 tag 补齐

部分旧 sing-box 配置可能没有 tag，导致无法按 inbound 精确隔离。新增：

```text
ensureSingBoxProxyInboundTags()
```

用于补齐旧 Hysteria2/Trojan 入站 tag：

```text
hysteria2 -> hysteria2
trojan -> trojanTCP
```

### 3. 共存路由重置

新增：

```text
resetSocks5WireGuardRouteIsolation()
```

作用：

- 清理 Socks5 旧路由和冲突文件。
- 保留 Socks5 出站、多 Socks5 索引/清单。
- 保留 WireGuard/WARP endpoint 与 route。
- 自动重建当前 Socks5 隔离规则。
- 重载核心。

该功能只处理 sing-box 配置层，不清空系统防火墙。

### 4. 统一协议元数据

新增协议元数据函数：

```text
protocolName()
protocolConfigFile()
protocolListByCore()
protocolSupported()
protocolNeedsTLS()
protocolNeedsPath()
xrayStandaloneInstallTypes()
showProtocolListByCore()
normalizeProtocolSelection()
```

作用：

- 统一 Xray-core / sing-box 协议编号与名称。
- 统一协议配置文件路径。
- 限制只开放当前脚本已有完整链路的协议。
- 避免新增一堆重复的协议管理函数。

### 5. 独立协议补装

新增：

```text
installSingBoxProtocolStandalone()
installXrayProtocolStandalone()
```

补装流程：

1. 读取当前核心和已安装协议。
2. 复用现有证书、路径、用户配置。
3. 只设置目标协议的 `selectCustomInstallType`。
4. 调用 `initSingBoxConfig custom ... true` 或 `initXrayConfig custom ... true`。
5. 保留未选协议配置。
6. 重载核心。
7. 刷新订阅和账号展示。

Xray-core 的 WS/VMess/Trojan 类协议依赖 VLESS TCP 前置。独立补装时通过：

```text
xrayStandaloneInstallTypes()
```

自动将 `0` 前置加入安装集合。

### 6. Xray 路由保护

`initXrayConfig()` 会重写 `09_routing.json`。为避免独立补装协议时破坏已有 Xray 路由，`installXrayProtocolStandalone()` 在生成配置前备份：

```text
09_routing.json
```

生成目标协议后恢复该文件。

### 7. 协议卸载与重装

新增：

```text
removeProtocolConfig()
handleStandaloneProtocols()
```

行为：

- 卸载只删除目标协议 inbound 文件。
- 重装只先删除目标协议，再按补装流程生成。
- 不删除证书、其它协议、WireGuard/WARP 配置、订阅基础目录。

### 8. 协议管理菜单

新增：

```text
manageProtocols()
```

主菜单只增加：

```text
14.协议管理
```

协议管理子菜单包含：

```text
1.查看已安装协议
2.新增/补装协议
3.重装协议
4.卸载协议
5.返回主菜单
```

具体协议列表进入子菜单后按当前核心动态显示，避免主菜单过长。

### 9. 账号重复检查

新增：

```text
checkProtocolUserValueExists()
```

用于跨已安装 inbound 检查：

- UUID / id / password
- email / name / username

避免自由组合后不同协议出现重复账号。

### 10. TURN/STUN 宽泛关键词误杀修复

发现 `turnstile.mefun.org` 在 VPS 本机可连通，但客户端经 V2 节点访问出现 `ERR_CONNECTION_CLOSED`。原因是 Socks5/V2 入站防泄漏规则中使用了宽泛的 `domain_keyword: ["stun", "turn"]`，业务域名中包含 `turn` 字符串时会被误判为 TURN/WebRTC 流量并被 `reject/drop`。

修复方式：删除宽泛 `domain_keyword` 匹配，仅保留：

```text
protocol: stun
(^|\.)stun\.
(^|\.)turn\.
UDP 3478/5349
```

该修复同时应用于单 Socks5 清单规则和多 Socks5 规则。

## 支持范围

### Xray-core

当前开放当前脚本已有完整安装链路的协议：

```text
0 VLESS TCP Vision
1 VLESS WS TLS
3 VMess WS TLS
4 Trojan TLS
7 VLESS Reality Vision
12 VLESS Reality XHTTP
```

被注释或未完整启用的协议不开放，避免破坏已有功能。

### sing-box

当前开放当前脚本已有完整安装链路的协议：

```text
0 VLESS Vision TCP
1 VLESS WS TLS
3 VMess WS TLS
4 Trojan TLS
6 Hysteria2
7 VLESS Reality Vision
8 VLESS Reality gRPC
9 Tuic
10 Naive
11 VMess HTTPUpgrade
13 AnyTLS
```

## 文件改动点

### install.sh

主要新增/改造点：

- V2 入站隔离函数。
- Socks5 单清单和多 Socks5 规则生成逻辑。
- Socks5/WireGuard 共存路由重置。
- 通用协议元数据函数。
- Xray-core / sing-box 独立协议补装、重装、卸载函数。
- 协议管理菜单。
- 账号跨协议重复检查。
- 主菜单新增 `14.协议管理`。
- Socks5 菜单 UX 重构（见下）。

### Socks5 菜单 UX 重构

调整目标：减少多余选项，操作意图与菜单名称对应，修改后自动刷新，消除重复入口。

具体改动：

- `socks5Routing()` 父菜单将"全局转发"提升至与"单出站""多出站""入站"并列；选"单出站"时，未安装则自动完成配置+启用，已安装直接进管理菜单。
- `socks5OutboundRoutingMenu()` 简化为 3 项：配置/重新配置出站 IP/端口（动态标签）、查看规则、维护清单；去掉"卸载分流规则"和"全局模式"（后者移至父菜单）。
- `manageSingBoxSocks5RoutingList()` 删除重复的"从清单生成/刷新分流规则"（追加/替换/重置已自动刷新）；"重置默认清单"同时自动刷新规则，与父菜单"重置规则"合并为一个入口。
- `socks5MultiOutboundRoutingMenu()` 将"管理代理清单"改名"维护代理清单"；"刷新规则"改名"重新应用规则"并注明手动触发场景。
- `manageSocks5MultiRoutingList()` 删除重复的"从清单生成/刷新分流规则"；追加/替换/清空均注明自动刷新。

### README.md

仅保留 fork 新增能力的简要说明，并链接到详细文档。

### documents/socks5_wireguard_protocol_management.md

详细使用说明，包括：

- 功能入口。
- 路由设计。
- 多 Socks5 使用。
- 共存路由重置。
- 协议管理。
- 账号和订阅。
- 推荐流程。
- 排错。

## 验证内容

开发后需要执行：

```bash
bash -n install.sh
```

以及：

```bash
git diff --check
```

目标 VPS 上建议验证：

1. V2 节点清单内走 Socks5。
2. V2 节点清单外走 VPS IP。
3. WireGuard/WARP 客户端不被 V2 Socks5 规则影响。
4. 协议管理可补装、重装、卸载协议。
5. 用户管理可展示、新增、删除账号。
6. 订阅链接刷新后包含当前协议集合。
7. 已有 Hysteria2、Reality、Tuic、WireGuard/WARP 配置不被补装其它协议破坏。

## 设计约束

- 不清空系统防火墙。
- 不删除非目标协议。
- 不删除 WireGuard/WARP 配置。
- 不开放当前脚本中注释或未完整实现的协议。
- 菜单入口保持简洁，复杂列表放入子菜单。
