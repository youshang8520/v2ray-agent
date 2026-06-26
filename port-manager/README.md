# port-manager

`port-manager.sh` 是独立端口工具，不接管系统端口策略，只提供检查、开放、关闭和空闲端口扫描。

## 一键交互启动

```bash
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/youshang8520/v2ray-agent/customize-singbox-socks-routing/port-manager/port-manager.sh" && chmod 700 /root/port-manager.sh && /root/port-manager.sh
```

执行后直接进入交互菜单，无需任何参数。

## 菜单选项说明

| 编号 | 选项 | 作用 | 影响范围 |
|------|------|------|----------|
| 1 | 查看监听端口 & 防火墙开放端口 | 列出当前系统所有正在监听的端口（进程实际占用），以及防火墙已放行的端口规则 | 只读，不做任何修改 |
| 2 | 检测指定端口 | 输入端口号和协议，查看该端口是否有进程在监听、防火墙是否放行、是否在保护列表中 | 只读 |
| 3 | 开放端口 | 在防火墙中添加放行规则，允许外部访问指定端口 | 修改防火墙规则（ufw/firewalld/iptables），不影响进程 |
| 4 | 关闭端口 | 从防火墙中删除放行规则，阻止外部访问指定端口；保护端口会提示二次确认 | 修改防火墙规则，不会杀死进程，进程仍在运行但外部无法访问 |
| 5 | 扫描空闲已开放端口 | 列出"防火墙已放行 + 当前无进程监听 + 不在保护列表"的端口，即可能是历史遗留的无效规则 | 只读，不做任何修改 |
| 6 | 扫描并关闭空闲已开放端口 | 同选项 5，但扫描完成后会批量删除这些无效防火墙规则；需二次确认 | 批量修改防火墙规则，保护端口不受影响 |
| 7 | 查找可用空闲端口 | 在指定范围内查找第一个当前无进程监听的端口，用于确定新服务可以安全使用哪个端口 | 只读 |
| 8 | 查看保护端口列表 | 显示当前所有受保护的端口（不会被选项 6 关闭，选项 4 关闭时需确认） | 只读 |
| 0 | 退出 | 退出脚本 | — |

> **注意**：本工具只管理防火墙规则，不会终止任何进程。关闭防火墙规则后，若进程仍在运行，本机内部仍可访问该端口。

## 命令行用法（高级）

```bash
./port-manager.sh list
./port-manager.sh check 2053 tcp
./port-manager.sh open 2053 tcp
./port-manager.sh close 2053 tcp
./port-manager.sh scan
./port-manager.sh scan --close
./port-manager.sh free 20000 50000 tcp
```

软链接方式：

```bash
sudo ln -s /root/port-manager.sh /usr/local/bin/port-manager
port-manager list
```

## 保护规则

默认保护：`22`、`80`、`443`、当前 SSH 端口及 `/etc/ssh/sshd_config` 中声明的端口。

额外保护端口：

```bash
PORT_MANAGER_PROTECT="2053,2087" port-manager scan
```

关闭保护端口需 `--force` 或菜单中确认。

## 支持的防火墙

按系统实际启用情况自动选择：`ufw` → `firewalld` → `iptables`。
