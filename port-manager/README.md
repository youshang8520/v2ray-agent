# port-manager

`port-manager.sh` 是独立端口工具，不接管系统端口策略，只提供检查、开放、关闭和空闲端口扫描。

## 一键交互启动

```bash
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/youshang8520/v2ray-agent/customize-singbox-socks-routing/port-manager/port-manager.sh" && chmod 700 /root/port-manager.sh && /root/port-manager.sh
```

执行后直接进入交互菜单，无需任何参数。

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
