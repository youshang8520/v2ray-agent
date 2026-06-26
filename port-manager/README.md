# port-manager

`port-manager.sh` 是独立端口工具，不接管系统端口策略，只提供检查、开放、关闭和空闲端口扫描。

## 快速用法

把脚本放到任意目录后直接执行：

```bash
chmod +x port-manager.sh
./port-manager.sh list
./port-manager.sh scan
./port-manager.sh open 2053 tcp
./port-manager.sh close 2053 tcp
```

如果想更方便，可以做一个软链接：

```bash
sudo ln -s /path/to/port-manager.sh /usr/local/bin/port-manager
port-manager list
port-manager check 2053 tcp
```

## 常用命令

```bash
port-manager list
port-manager check 2053 tcp
port-manager open 2053 tcp
port-manager close 2053 tcp
port-manager scan
port-manager scan --close
port-manager free 20000 50000 tcp
```

## 保护规则

默认保护：

- `22`
- `80`
- `443`
- 当前 SSH 端口
- `/etc/ssh/sshd_config` 中声明的 SSH 端口

额外保护端口可通过环境变量指定：

```bash
PORT_MANAGER_PROTECT="2053,2087" port-manager scan
```

关闭保护端口需要显式 `--force`。

## 支持的防火墙

按当前系统实际启用情况自动选择：

1. `ufw`
2. `firewalld`
3. `iptables`

`scan` 只把“防火墙已放行、当前没有监听、且不在保护列表”的端口列为候选。
