#!/bin/sh
set -e

ip rule add fwmark $TPROXY_MARK table $TABLE
ip route add default dev $NETWORK_INTERFACE table $TABLE

iptables -t mangle -N V2RAY
iptables -t mangle -A V2RAY -p udp --dport 53 -j TPROXY --on-port $PORT --tproxy-mark $TPROXY_MARK
iptables -t mangle -A V2RAY -d 127.0.0.1/32 -j RETURN
iptables -t mangle -A V2RAY -d $PRIVATE_NETWORK -j RETURN
iptables -t mangle -A V2RAY -p udp -j TPROXY --on-port $PORT --tproxy-mark $TPROXY_MARK
iptables -t mangle -A V2RAY -p tcp -j TPROXY --on-port $PORT --tproxy-mark $TPROXY_MARK
iptables -t mangle -A PREROUTING -j V2RAY

iptables -t mangle -N V2RAY_MASK
iptables -t mangle -A V2RAY_MASK -j RETURN -m mark --mark $SO_MARK
iptables -t mangle -A V2RAY_MASK -p udp -j MARK --set-mark $TPROXY_MARK
iptables -t mangle -A V2RAY_MASK -p tcp -j MARK --set-mark $TPROXY_MARK
iptables -t mangle -A OUTPUT -j V2RAY_MASK
