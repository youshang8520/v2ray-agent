# v2ray-agent

- 原项目/作者链接：[mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent)
- [感谢 JetBrains 提供的非商业开源软件开发授权](https://www.jetbrains.com/?from=v2ray-agent)


[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Telegram Channel](https://img.shields.io/badge/Telegram-Channel-blue)](https://t.me/v2rayAgentChannel)
[![Telegram Group](https://img.shields.io/badge/Telegram-Group-blue)](https://t.me/technologyshare)
[![Official Website](https://img.shields.io/badge/Website-v2ray--agent.com-blue)](https://www.v2ray-agent.com/)
[![English Version](https://img.shields.io/badge/English-Version-blue)](documents/en/README_EN.md)

Xray-core/sing-box 一键脚本快速安装

## 功能

*   **多核心支持:** 支持 Xray-core 和 sing-box.
*   **多协议支持:** 支持 VLESS, VMess, Trojan, Hysteria2, Tuic, NaiveProxy 等多种协议.
*   **自动TLS:** 自动申请和续订 SSL 证书.
*   **易于管理:** 提供简单的菜单来管理用户、端口和配置.
*   **订阅支持:** 生成和管理订阅链接.
*   **分流管理:** 提供wireguard、IPv6、Socks5、DNS、VMess(ws)、SNI反向代理，可用于解锁流媒体、规避IP验证等作用.
*   **目标域名管理:** 提供域名黑名单管理，可用于禁止访问指定网站.
*   **BT下载管理:** 可用于禁止下载P2P相关内容.
*   **更多内容请访问[官方网站](https://www.v2ray-agent.com/categories/jiao-cheng)、[备用](https://www.592083.com/categories/jiao-cheng)、[X](https://x.com/v2rayagent)**

## 快速开始

### 安装脚本版

本 fork 的脚本版包含 sing-box Socks5/VPNGate 清单分流增强、V2 入站流量隔离、Socks5/WireGuard 共存路由重置，以及 Xray-core / sing-box 的统一协议补装管理。

### 本 fork 增强

- **V2 入站隔离的 Socks5 清单过滤：** V2 节点清单内走 Socks5/AimiliVPN，清单外走 VPS 服务器 IP；规则只匹配 V2 节点入站，不接管 WireGuard/WARP 或其它客户端流量。
- **多 Socks5 出站：** 支持多个 Socks5 代理按清单和优先级分流，并提供清单冲突检查。
- **Socks5/WireGuard 共存重置：** 可清理 Socks5 旧分流和冲突残留，保留 WireGuard/WARP endpoint 与 route。
- **统一协议管理：** 在安装后可为 Xray-core / sing-box 补装、重装、卸载当前脚本已完整支持的协议，账号和订阅统一刷新。

详细说明见：

- [Socks5/WireGuard 共存与协议管理使用说明](documents/socks5_wireguard_protocol_management.md)
- [开发过程与改动点](documents/development_process_socks5_protocol_management.md)

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/youshang8520/v2ray-agent/customize-singbox-socks-routing/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

### 使用

安装后，运行以下命令可再次打开管理菜单:

```
vasma
```

### 安装Docker版
```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/docker_reality.sh" && chmod 700 /root/docker_reality.sh && /root/docker_reality.sh
```

### 使用 

* [Docker Reality 使用说明](https://www.v2ray-agent.com/archives/019e1b57-92b3-70ab-8919-cdf8c0bb4fe9)
 
安装后，运行以下命令可再次打开管理菜单:

```
vasmad
```

## 文档和指南

*   [八合一脚本从入门到精通](https://www.v2ray-agent.com/archives/1710141233)
*   [脚本快速搭建教程](https://www.v2ray-agent.com/archives/1682491479771)
*   [脚本使用注意事项](https://www.v2ray-agent.com/archives/1679931532764)
*   [脚本异常处理](https://www.v2ray-agent.com/archives/1684115970026)   
*   [VPS选购攻略](https://www.v2ray-agent.com/archives/1679975663984)
*   [垃圾VPS大救星，hysteria2最新协议一键搭建](https://www.v2ray-agent.com/archives/1697162969693)
*   [RackNerd低价 联通AS4837套餐，年付10美起](https://www.v2ray-agent.com/archives/racknerdtao-can-zheng-li-nian-fu-10mei-yuan)
*   [搬瓦工优质套餐推荐](https://www.v2ray-agent.com/archives/2023nian-ban-wa-gong-ji-fang-tui-jian)
*   [DMIT优质套餐推荐](https://www.v2ray-agent.com/archives/1679159868033)

## 社区与支持

*   **Telegram:** [频道](https://t.me/v2rayAgentChannel) | [群组](https://t.me/technologyshare)
*   **网站:** [官网](https://www.v2ray-agent.com/) | [备用](https://www.592083.xyz/)
*   **反馈:** [提交 issue](https://github.com/mack-a/v2ray-agent/issues)
*   **X:** [链接](https://x.com/v2rayagent)

## 捐赠

感谢您对开源项目的关注和支持。如果您觉得这个项目对您有帮助，欢迎通过以下方式进行捐赠。

*   [购买VPS捐赠](https://www.v2ray-agent.com/categories/vps)
*   [通过虚拟币向我捐赠](https://www.v2ray-agent.com/1679123834836)

## 许可证

本项根据 [AGPL-3.0 许可证](LICENSE) 授权.
