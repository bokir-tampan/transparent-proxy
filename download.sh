#!/bin/bash
set -e

RUN_CURL="curl -LO -C -"

for filename in tap-windows-9.24.6.zip tap.bat tun.bat vless.json ; do
    $RUN_CURL https://github.com/ChenTanyi/badvpn/releases/download/external/$filename
done

$RUN_CURL https://github.com/ChenTanyi/badvpn/releases/download/latest/badvpn-tun2socks.exe
$RUN_CURL https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-windows-64.zip
