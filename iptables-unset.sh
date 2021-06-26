#!/bin/bash

ip rule del fwmark $TPROXY_MARK table $TABLE
ip route del local default dev $NETWORK_INTERFACE table $TABLE

iptables -t mangle -D PREROUTING -j DIVERT
iptables -t mangle -F DIVERT
iptables -t mangle -X DIVERT

iptables -t mangle -D PREROUTING -j V2RAY
iptables -t mangle -F V2RAY
iptables -t mangle -X V2RAY

if [[ -z "$ONLY_ROUTE" ]]; then
iptables -t mangle -D OUTPUT -j V2RAY_MASK
iptables -t mangle -F V2RAY_MASK
iptables -t mangle -X V2RAY_MASK
fi
