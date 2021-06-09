#!/bin/bash
set -e

cd $(dirname $0)

if [[ $(id -u) != 0 ]]; then
    echo "Please run script as root"
    exit 1
fi

# parse argument
args=()
while [[ "$#" -gt 0 ]]; do
    case $1 in 
        -d|--domain) export DOMAIN="$2"; shift ;;
        -di|--domain-ip) DOMAIN_IP="$2"; shift ;;
        -u|--uuid) export UUID="$2"; shift ;;
        -w|--wspath) export WSPATH="$2"; shift ;;
        -x|--proxy) export HTTP_PROXY="$2" HTTPS_PROXY="$2" http_proxy="$2" https_proxy="$2"; shift ;;
        -p|--port) PORT="$2"; shift ;;
        --smark) SO_MARK="$2"; shift ;;
        --tmark) TPROXY_MARK="$2"; shift ;;
        -t|--table) TABLE="$2"; shift ;;
        -ni|--network-interface) NETWORK_INTERFACE="$2"; shift ;;
        --file) FILE_LIMIT="$2"; shift ;;
        --proc) PROC_LIMIT="$2"; shift ;;
        -si|--set-iptables) SET_IPTABLES="1" ;;
        -ui|--unset-iptables) UNSET_IPTABLES="1" ;;
        -sd|--skip-dns) SKIP_DNS="1" ;;
        -or|--only-route) export ONLY_ROUTE="1" ;;
        --debug) set -x ;;
        *) args+=($1) ;;
    esac
    shift
done

set -a
PORT=${PORT:-51082}
SO_MARK=${SO_MARK:-255}
TPROXY_MARK=${TPROXY_MARK:-254}
TABLE=${TABLE:-100}
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"lo"}

if [[ -n "$SKIP_DNS" ]]; then
    DNS_OPTIONS="-j RETURN"
    MASK_DNS_OPTIONS="-j RETURN"
else
    DNS_OPTIONS="-j TPROXY --on-port $PORT --tproxy-mark $TPROXY_MARK"
    MASK_DNS_OPTIONS="-j MARK --set-mark $TPROXY_MARK"
fi

if [[ -n "$DOMAIN_IP" ]]; then
    DOMAIN_DNS_SET="\"$DOMAIN\": \"$DOMAIN_IP\""
    DOMAIN_DNS_QUERY=""
else
    DOMAIN_DNS_SET=""
    DOMAIN_DNS_QUERY="\"$DOMAIN\","
fi
set +a

ALL_ENV='$DOMAIN $DOMAIN_DNS_SET $DOMAIN_DNS_QUERY $UUID $WSPATH $PORT $SO_MARK $TPROXY_MARK $TABLE $NETWORK_INTERFACE $DNS_OPTIONS $MASK_DNS_OPTIONS $ONLY_ROUTE'

if [[ -n "$SET_IPTABLES" ]]; then
    bash <(envsubst "$ALL_ENV" < iptables-set.sh)
    exit 0
fi
if [[ -n "$UNSET_IPTABLES" ]]; then
    bash <(envsubst "$ALL_ENV" < iptables-unset.sh)
    exit 0
fi

if [[ -z "$DOMAIN" || -z "$UUID" ]]; then
    echo "Usage: $0 -d <domain> -u <uuid> [-w <wspath>] [-di <domain_ip>] [-p <port>] [--smark <so_mark>] [--tmark <tproxy_mark>] [-t <table>] [-ni <network_interface>] [--file <file_limit>] [--proc <proc_limit>] [--debug] [--set-iptables] [--unset-iptables] [--skip-dns]"
    exit 1
fi

systemctl stop v2ray || true
systemctl stop transparentproxy || true

bash <(curl -L https://github.com/v2fly/fhs-install-v2ray/raw/master/install-release.sh)

{
    filename="/etc/systemd/system/v2ray.service"
    if [[ -n "$FILE_LIMIT" ]]; then
        if [[ -n $(grep LimitNOFILE= "$filename") ]]; then
            sed -i "s/^LimitNOFILE=.*$/LimitNOFILE=$FILE_LIMIT/g" "$filename"
        else
            sed -i "/^\[Service\]$/a LimitNOFILE=$FILE_LIMIT" "$filename"
        fi
    fi
    if [[ -n "$PROC_LIMIT" ]]; then
        if [[ -n $(grep LimitNPROC= "$filename") ]]; then
            sed -i "s/^LimitNPROC=.*$/LimitNPROC=$PROC_LIMIT/g" "$filename"
        else
            sed -i "/^\[Service\]$/a LimitNPROC=$PROC_LIMIT" "$filename"
        fi
    fi
}

{
    filename="/usr/local/etc/v2ray/config.json"
    envsubst "$ALL_ENV" < config.json > "$filename"
}

{
    filename="/lib/systemd/system/transparentproxy.service"
    mkdir -p $(dirname "$filename")
    cp -f transparentproxy.service "$filename"
}

{
    folder="/etc/transparentproxy"
    mkdir -p "$folder"
    envsubst "$ALL_ENV" < iptables-set.sh > "$folder/iptables-set.sh"
    envsubst "$ALL_ENV" < iptables-unset.sh > "$folder/iptables-unset.sh"
    chmod +x "$folder/iptables-set.sh" "$folder/iptables-unset.sh"
}

systemctl enable v2ray
systemctl start v2ray
systemctl enable transparentproxy
systemctl start transparentproxy
