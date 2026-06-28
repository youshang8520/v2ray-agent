#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
PROTECT_DEFAULT="22,80,443"

usage() {
    cat <<'EOF'
port-manager - firewall port helper

Usage:
  port-manager.sh                         Open interactive menu
  port-manager.sh list
  port-manager.sh check <port> [tcp|udp]
  port-manager.sh open <port> [tcp|udp]
  port-manager.sh close <port> [tcp|udp] [--force]
  port-manager.sh scan [--close] [--force]
  port-manager.sh free [start] [end] [tcp|udp]

Commands:
  list      Show listening ports and firewall rules.
  check     Check whether a port is listening and allowed by firewall.
  open      Open a firewall port.
  close     Close a firewall port. Protected ports are refused unless --force.
  scan      List allowed ports that are not listening and not protected.
            With --close, close those candidate rules.
  free      Find the first non-listening and firewall-unallowed port in a range. Default: 20000-50000/tcp.

Environment:
  PORT_MANAGER_PROTECT="22,80,443,2053"   Extra protected ports.

Notes:
  - This tool manages firewall rules only; it does not kill processes.
  - 443, 80, SSH ports, and PORT_MANAGER_PROTECT ports are protected by default.
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

need_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        err "please run as root"
        exit 1
    fi
}

valid_proto() {
    [[ "${1:-tcp}" == "tcp" || "${1:-tcp}" == "udp" ]]
}

valid_port() {
    [[ "${1:-}" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

firewall_backend() {
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        echo ufw
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        echo firewalld
    elif command -v iptables >/dev/null 2>&1; then
        echo iptables
    elif command -v nft >/dev/null 2>&1; then
        echo nftables
    else
        echo none
    fi
}

proc_bound_ports() {
    local spec file proto sl local_addr rem_addr state rest port_hex port_dec
    for spec in /proc/net/tcp:tcp /proc/net/tcp6:tcp /proc/net/udp:udp /proc/net/udp6:udp; do
        file=${spec%:*}
        proto=${spec##*:}
        [[ -r "${file}" ]] || continue
        while read -r sl local_addr rem_addr state rest; do
            [[ "${sl}" == "sl" ]] && continue
            if [[ "${proto}" == "tcp" && "${state}" != "0A" ]]; then
                continue
            fi
            port_hex=${local_addr##*:}
            [[ "${port_hex}" =~ ^[0-9A-Fa-f]{4}$ ]] || continue
            port_dec=$((16#${port_hex}))
            (( port_dec > 0 )) && printf '%s/%s\n' "${port_dec}" "${proto}"
        done <"${file}"
    done | sort -u
}

listening_ports() {
    {
        if command -v ss >/dev/null 2>&1; then
            ss -H -lntu | awk '{print $1, $5}' | sed -E 's/.*:([0-9]+)$/\1/' | awk '{print $2"/"$1}'
        elif command -v netstat >/dev/null 2>&1; then
            netstat -lntu | awk 'NR>2 {print tolower($1), $4}' | sed -E 's/.*:([0-9]+)$/\1/' | awk '{print $2"/"$1}'
        fi
        proc_bound_ports
    } | sort -u
}

is_listening() {
    local port=$1 proto=${2:-tcp}
    listening_ports | grep -qx "${port}/${proto}"
}

listening_ports_with_procs() {
    {
        if command -v ss >/dev/null 2>&1; then
            ss -H -lntup | awk '{
                n = split($5, a, ":"); port = a[n]; proto = $1; proc = ""
                for (i = 1; i <= NF; i++) if ($i ~ /users:/) {
                    s = $i; sub(/.*\(\("/, "", s); sub(/".*/, "", s); proc = s; break
                }
                if (port + 0 > 0) print port "/" proto " " proc
            }'
        elif command -v netstat >/dev/null 2>&1; then
            netstat -lntup 2>/dev/null | awk 'NR > 2 {
                n = split($4, a, ":"); port = a[n]; proto = tolower($1)
                split($NF, p, "/"); proc = (length(p) > 1) ? p[2] : ""
                if (port + 0 > 0) print port "/" proto " " proc
            }'
        fi
        proc_bound_ports | awk '{print $1" kernel"}'
    } | awk '
        {
            key=$1; proc=$2
            if (proc=="") proc="unknown"
            if (!(key in seen) || seen[key]=="kernel" || seen[key]=="unknown") seen[key]=proc
        }
        END {for (key in seen) print key, seen[key]}
    ' | sort -t/ -k1,1n -u
}

port_process() {
    local port=$1 proto=$2 key item proc result=""
    key="${port}/${proto}"
    while read -r item proc; do
        [[ "${item}" == "${key}" ]] || continue
        result=${proc:-unknown}
        break
    done < <(listening_ports_with_procs)
    printf '%s\n' "${result}"
}

format_port_owner() {
    local spec=$1 item port proto proc owners=""
    while IFS=/ read -r item proto; do
        [[ -n "${item}" && -n "${proto}" ]] || continue
        [[ "${item}" == *-* ]] && continue
        port=${item}
        if port_spec_contains "${spec}" "${port}" "${proto}"; then
            proc=$(port_process "${port}" "${proto}")
            [[ -n "${proc}" ]] || proc="unknown"
            owners="${owners}${owners:+, }${port}/${proto}:${proc}"
        fi
    done < <(listening_ports)
    if [[ -n "${owners}" ]]; then
        printf 'occupied: %s\n' "${owners}"
    else
        printf 'unused\n'
    fi
}

ssh_ports() {
    local ports=""
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        ports="${ports},$(awk '{print $4}' <<<"${SSH_CONNECTION}")"
    fi
    if [[ -f /etc/ssh/sshd_config ]]; then
        ports="${ports},$(awk 'tolower($1)=="port" {print $2}' /etc/ssh/sshd_config | paste -sd, -)"
    fi
    printf '%s\n' "${ports#,}" | tr ',' '\n' | grep -E '^[0-9]+$' || true
}

protected_ports() {
    {
        printf '%s\n' "${PROTECT_DEFAULT}" | tr ',' '\n'
        printf '%s\n' "${PORT_MANAGER_PROTECT:-}" | tr ',' '\n'
        ssh_ports
    } | grep -E '^[0-9]+$' | sort -n -u
}

is_protected() {
    local port=$1
    protected_ports | grep -qx "${port}"
}

firewall_ports_from_nft() {
    command -v nft >/dev/null 2>&1 || return 0
    nft list ruleset 2>/dev/null | awk '
        /accept/ && /dport/ {
            proto=""
            for (i=1;i<=NF;i++) {
                if ($i=="tcp" || $i=="udp") proto=$i
                if ($i=="dport") {
                    for (j=i+1;j<=NF;j++) {
                        token=$j
                        gsub(/[{},]/, "", token)
                        gsub(/;/, "", token)
                        if (token ~ /^[0-9]+$/ || token ~ /^[0-9]+-[0-9]+$/) print token"/"proto
                        else if (token ~ /^[0-9]+-[0-9]+,$/) {gsub(/,/, "", token); print token"/"proto}
                        if ($(j+1) !~ /^[0-9{},-]+$/ && $(j+1) != ",") break
                    }
                }
            }
        }'
}

firewall_ports() {
    local backend
    backend=$(firewall_backend)
    case "${backend}" in
    ufw)
        {
            ufw status | awk '/ALLOW/ {print $1}' | sed -E 's#^([0-9]+)(/(tcp|udp))?.*#\1/\3#' | awk -F/ '{proto=$2; if (proto=="") proto="tcp"; if ($1 ~ /^[0-9]+$/) print $1"/"proto}'
            firewall_ports_from_nft
        } | sort -u
        ;;
    firewalld)
        {
            firewall-cmd --list-ports | tr ' ' '\n' | grep -E '^[0-9]+(-[0-9]+)?/(tcp|udp)$'
            firewall_ports_from_nft
        } | sort -u
        ;;
    iptables)
        {
            iptables -S INPUT | awk '
                /-j ACCEPT/ {
                    proto="tcp"; port="";
                    for (i=1;i<=NF;i++) {
                        if ($i=="-p") proto=$(i+1);
                        if ($i=="--dport" || $i=="--dports") port=$(i+1);
                    }
                    if (port ~ /^[0-9]+(:[0-9]+)?$/) { gsub(":","-",port); print port"/"proto; port="" }
                    else if (port ~ /^[0-9]+(,[0-9]+)*$/) { n=split(port,a,","); for (k=1;k<=n;k++) print a[k]"/"proto; port="" }
                }'
            firewall_ports_from_nft
        } | sort -u
        ;;
    nftables)
        firewall_ports_from_nft | sort -u
        ;;
    esac
}

port_spec_contains() {
    local spec=$1 port=$2 proto=$3 range p start end spec_proto
    range=${spec%/*}
    spec_proto=${spec##*/}
    [[ "${spec_proto}" == "${proto}" ]] || return 1
    if [[ "${range}" == *-* ]]; then
        start=${range%-*}
        end=${range#*-}
        [[ "${start}" =~ ^[0-9]+$ && "${end}" =~ ^[0-9]+$ ]] || return 1
        (( port >= start && port <= end ))
    else
        p=${range}
        [[ "${p}" =~ ^[0-9]+$ ]] || return 1
        (( port == p ))
    fi
}

is_allowed() {
    local port=$1 proto=${2:-tcp} item
    while IFS= read -r item; do
        [[ -n "${item}" ]] || continue
        if port_spec_contains "${item}" "${port}" "${proto}"; then
            return 0
        fi
    done < <(firewall_ports)
    return 1
}

open_port() {
    local port=$1 proto=${2:-tcp} backend
    need_root
    valid_port "${port}" || { err "invalid port: ${port}"; exit 1; }
    valid_proto "${proto}" || { err "invalid proto: ${proto}"; exit 1; }
    backend=$(firewall_backend)
    case "${backend}" in
    ufw) ufw allow "${port}/${proto}" ;;
    firewalld) firewall-cmd --zone=public --add-port="${port}/${proto}" --permanent && firewall-cmd --reload ;;
    iptables) iptables -I INPUT -p "${proto}" --dport "${port}" -m comment --comment "port-manager ${port}/${proto}" -j ACCEPT; command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save || true ;;
    none) err "no supported firewall backend found"; exit 1 ;;
    esac
    log "opened ${port}/${proto} via ${backend}"
}

close_port() {
    local port=$1 proto=${2:-tcp} force=${3:-} backend
    need_root
    valid_port "${port}" || { err "invalid port: ${port}"; exit 1; }
    valid_proto "${proto}" || { err "invalid proto: ${proto}"; exit 1; }
    if is_protected "${port}" && [[ "${force}" != "--force" ]]; then
        err "${port}/${proto} is protected; use --force if you really want to close it"
        exit 1
    fi
    backend=$(firewall_backend)
    case "${backend}" in
    ufw) ufw delete allow "${port}/${proto}" || true ;;
    firewalld) firewall-cmd --zone=public --remove-port="${port}/${proto}" --permanent || true; firewall-cmd --reload || true ;;
    iptables)
        while iptables -S INPUT | grep -q -- "--dport ${port} .*${proto}\|${proto} .*--dport ${port}"; do
            local rule
            rule=$(iptables -S INPUT | grep -- "--dport ${port}" | grep -- "-p ${proto}" | head -1 || true)
            [[ -z "${rule}" ]] && break
            iptables ${rule/-A/-D} || break
        done
        command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save || true
        ;;
    none) err "no supported firewall backend found"; exit 1 ;;
    esac
    log "closed ${port}/${proto} via ${backend}"
}

cmd_list() {
    log "Firewall backend: $(firewall_backend)"
    log "Protected ports: $(protected_ports | paste -sd, -)"
    log ""
    log "Listening ports:"
    listening_ports_with_procs | awk '{printf "  %-16s %s\n", $1, $2}' || true
    log ""
    log "Firewall allowed ports:"
    firewall_ports | while IFS= read -r item; do
        [[ -n "${item}" ]] || continue
        printf '  %-16s %s\n' "${item}" "$(format_port_owner "${item}")"
    done || true
}

cmd_check() {
    local port=$1 proto=${2:-tcp}
    valid_port "${port}" || { err "invalid port: ${port}"; exit 1; }
    valid_proto "${proto}" || { err "invalid proto: ${proto}"; exit 1; }
    if is_listening "${port}" "${proto}"; then
        proc=$(listening_ports_with_procs | awk -v k="${port}/${proto}" '$1==k {print $2; exit}')
        log "listening: yes  (${proc:-unknown})"
    else
        log "listening: no"
    fi
    if is_allowed "${port}" "${proto}"; then
        log "firewall: open"
    else
        log "firewall: closed or unmanaged"
    fi
    if is_protected "${port}"; then
        log "protected: yes"
    else
        log "protected: no"
    fi
}

cmd_scan() {
    local close=false force=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --close) close=true ;;
        --force) force="--force" ;;
        *) err "unknown option: $1"; exit 1 ;;
        esac
        shift
    done
    local item port proto
    firewall_ports | while IFS=/ read -r port proto; do
        [[ "${port}" == *-* ]] && continue
        [[ -z "${port}" || -z "${proto}" ]] && continue
        if is_protected "${port}" || is_listening "${port}" "${proto}"; then
            continue
        fi
        log "candidate: ${port}/${proto}"
        if [[ "${close}" == "true" ]]; then
            close_port "${port}" "${proto}" "${force}"
        fi
    done
}

cmd_free() {
    local start=${1:-20000} end=${2:-50000} proto=${3:-tcp} port
    valid_port "${start}" || { err "invalid start port"; exit 1; }
    valid_port "${end}" || { err "invalid end port"; exit 1; }
    valid_proto "${proto}" || { err "invalid proto: ${proto}"; exit 1; }
    for ((port=start; port<=end; port++)); do
        if ! is_listening "${port}" "${proto}" && ! is_allowed "${port}" "${proto}"; then
            echo "${port}"
            return 0
        fi
    done
    err "no free ${proto} port found in ${start}-${end}"
    exit 1
}

menu() {
    while true; do
        echo ""
        echo "========== port-manager v${VERSION} =========="
        echo " 1. 查看监听端口 & 防火墙开放端口"
        echo " 2. 检测指定端口"
        echo " 3. 开放端口"
        echo " 4. 关闭端口"
        echo " 5. 扫描空闲但已开放的非保护端口"
        echo " 6. 扫描并关闭空闲但已开放的非保护端口"
        echo " 7. 查找可用空闲端口"
        echo " 8. 查看保护端口列表"
        echo " 0. 退出"
        echo "==========================================="
        read -r -p "请选择 [0-8]: " choice
        echo ""
        case "${choice}" in
        1) ( cmd_list ) || true ;;
        2)
            read -r -p "端口号: " p
            read -r -p "协议 [tcp]: " pr; pr=${pr:-tcp}
            ( cmd_check "${p}" "${pr}" ) || true
            ;;
        3)
            read -r -p "端口号: " p
            read -r -p "协议 [tcp]: " pr; pr=${pr:-tcp}
            ( open_port "${p}" "${pr}" ) || true
            ;;
        4)
            read -r -p "端口号: " p
            read -r -p "协议 [tcp]: " pr; pr=${pr:-tcp}
            if is_protected "${p}"; then
                read -r -p "${p} 是保护端口，确认强制关闭？[y/N]: " confirm
                if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
                    ( close_port "${p}" "${pr}" "--force" ) || true
                else
                    log "已取消"
                fi
            else
                ( close_port "${p}" "${pr}" ) || true
            fi
            ;;
        5) ( cmd_scan ) || true ;;
        6)
            read -r -p "确认关闭所有空闲已开放非保护端口？[y/N]: " confirm
            if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
                ( cmd_scan --close ) || true
            else
                log "已取消"
            fi
            ;;
        7)
            read -r -p "起始端口 [20000]: " s; s=${s:-20000}
            read -r -p "结束端口 [50000]: " e; e=${e:-50000}
            read -r -p "协议 [tcp]: " pr; pr=${pr:-tcp}
            ( cmd_free "${s}" "${e}" "${pr}" ) || true
            ;;
        8) ( log "保护端口: $(protected_ports | paste -sd, -)" ) || true ;;
        0) exit 0 ;;
        *) err "无效选项" ;;
        esac
    done
}

main() {
    if [[ $# -eq 0 ]]; then
        need_root
        menu
        return
    fi
    local cmd=$1
    shift
    case "${cmd}" in
    list) cmd_list ;;
    check) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_check "$@" ;;
    open) [[ $# -ge 1 ]] || { usage; exit 1; }; open_port "$@" ;;
    close) [[ $# -ge 1 ]] || { usage; exit 1; }; close_port "$@" ;;
    scan) cmd_scan "$@" ;;
    free) cmd_free "$@" ;;
    -h|--help|help) usage ;;
    -v|--version|version) echo "${VERSION}" ;;
    *) usage; exit 1 ;;
    esac
}

main "$@"
