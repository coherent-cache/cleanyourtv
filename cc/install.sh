#!/usr/bin/env bash
# Install a release of this fork on the Acer R4 and keep it as HOME. See cc/README.md.
# Usage: TV=<ip:port> cc/install.sh <tag | path/to.apk> [--theme]
#   --theme  also push cc/themes/acer-r4/config.json; this restarts Home, so only when nobody is watching.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${TV:?set TV=<ip:port>, e.g. TV=192.168.0.128:5555}"
CERT=6aa54312eed97d2571470b692faf43fb43998cae969de984f9cc2d3672e6bbea
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)
HOME_ACT=com.gathin.tvhome/.MainActivity
what="${1:?usage: TV=<ip:port> cc/install.sh <tag | apk> [--theme]}"

if [ -f "$what" ]; then
  apk="$what"
else
  apk="/tmp/cleanyourtv-$what.apk"
  gh release download "$what" --repo coherent-cache/cleanyourtv --pattern '*.apk' --output "$apk" --clobber
fi

signer=$("$BT/apksigner" verify --print-certs "$apk" | sed -n 's/.*SHA-256 digest: //p' | head -1)
[ "$signer" = "$CERT" ] || { echo "signer $signer is not the fork's key; refusing to install" >&2; exit 1; }

adb connect "$TV" >/dev/null
S() { adb -s "$TV" shell "$@" </dev/null | tr -d '\r'; }
adb -s "$TV" install -r "$apk" | tail -1
S pm grant com.gathin.tvhome android.permission.READ_TV_LISTINGS
S cmd package set-home-activity "$HOME_ACT" >/dev/null
home=$(S cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)
[ "$home" = "$HOME_ACT" ] || { echo "HOME resolves to $home, not $HOME_ACT" >&2; exit 1; }
echo "installed $(S dumpsys package com.gathin.tvhome | sed -n 's/.*versionName=//p' | head -1), HOME -> $home"

if [ "${2:-}" = --theme ]; then
  TV_HOST="$TV" tools/theme.sh cc/themes/acer-r4
fi
