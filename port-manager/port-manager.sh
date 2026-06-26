#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
PROTECT_DEFAULT="22,80,443"

usage() {
    cat <<'EOF'
port-manager - firewall port helper

Usage:
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
  free      Find the first non-listening port in a range. Default: 20000-50000/tcp.

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
    else
        echo none
    fi
}

listening_ports() {
    if command -v ss >/dev/null 2>&1; then
        ss -H -lntu | awk '{print $1, $5}' | sed -E 's/.*:([0-9]+)$/\1/' | awk '{print $2"/"$1}' | sort -u
    elif command -v netstat >/dev/null 2>&1; then
        netstat -lntu | awk 'NR>2 {print tolower($1), $4}' | sed -E 's/.*:([0-9]+)$/\1/' | awk '{print $2"/"$1}' | sort -u
    fi
}

is_listening() {
    local port=$1 proto=${2:-tcp}
    listening_ports | grep -qx "${port}/${proto}"
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

firewall_ports() {
    local backend
    backend=$(firewall_backend)
    case "${backend}" in
    ufw)
        ufw status | awk '/ALLOW/ {print $1}' | sed -E 's#^([0-9]+)(/(tcp|udp))?.*#\1/\3#' | awk -F/ '{proto=$2; if (proto=="") proto="tcp"; if ($1 ~ /^[0-9]+$/) print $1"/"proto}' | sort -u
        ;;
    firewalld)
        firewall-cmd --list-ports | tr ' ' '\n' | grep -E '^[0-9]+(-[0-9]+)?/(tcp|udp)$' | sort -u
        ;;
    iptables)
        iptables -S INPUT | awk '
            /-j ACCEPT/ {
                proto="tcp";
                for (i=1;i<=NF;i++) {
                    if ($i=="-p") proto=$(i+1);
                    if ($i=="--dport") port=$(i+1);
                }
                if (port ~ /^[0-9]+(:[0-9]+)?$/) { gsub(":","-",port); print port"/"proto; port="" }
            }' | sort -u
        ;;
    esac
}

is_allowed() {
    local port=$1 proto=${2:-tcp}
    firewall_ports | grep -Eq "^${port}(/|-)${proto}$|^${port}/${proto}$"
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
    listening_ports | sed 's/^/  /' || true
    log ""
    log "Firewall allowed ports:"
    firewall_ports | sed 's/^/  /' || true
}

cmd_check() {
    local port=$1 proto=${2:-tcp}
    valid_port "${port}" || { err "invalid port: ${port}"; exit 1; }
    valid_proto "${proto}" || { err "invalid proto: ${proto}"; exit 1; }
    if is_listening "${port}" "${proto}"; then
        log "listening: yes"
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
        if ! is_listening "${port}" "${proto}"; then
            echo "${port}"
            return 0
        fi
    done
    err "no free ${proto} port found in ${start}-${end}"
    exit 1
}

main() {
    local cmd=${1:-help}
    shift || true
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
