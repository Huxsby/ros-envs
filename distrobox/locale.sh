#!/bin/bash
# The box inherits LANG from the host (e.g. es_ES.UTF-8), but the Ubuntu image only ships C.UTF-8: unless it is
# generated, perl warns on every command and packages that build locale-dependent data, like TeX Live, fail to install.
# Usage (as root inside the box): bash locale.sh "$LANG"
set -euo pipefail
LOCALE=${1:-}
case $LOCALE in ''|C|C.*|POSIX) exit 0 ;; esac
# locale -a lists them as es_ES.utf8
locale -a 2>/dev/null | grep -qix "${LOCALE/UTF-8/utf8}" && exit 0
command -v locale-gen >/dev/null || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq locales; }
locale-gen "$LOCALE"
