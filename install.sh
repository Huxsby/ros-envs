#!/bin/bash
# Installs a ROS environment. From a clone it uses that clone; piped from curl it downloads a fixed release to a
# temporary folder and deletes it at the end. Nothing of this repository stays on the machine.
# Usage: install.sh ubuntu <distro>                 on the Ubuntu of that distro, already running (asks for sudo)
#        install.sh distrobox <distro> [--link DIR] on a Linux host: a box of that distro (distrobox/create.sh)
#        install.sh root <distro> <user> [time zone]   only the root step (wsl/install.ps1 uses it)
#        install.sh user <distro>                      only the user step (wsl/install.ps1 uses it)
#        distro: kinetic (Ubuntu 16.04), melodic (18.04), noetic (20.04) or jazzy (24.04)
# ROS_ENVS_REF chooses another tag or branch to download.
set -euo pipefail
REPOSITORY=Huxsby/ros-envs
REF=${ROS_ENVS_REF:-v1.0.1}   # updated with each release: see the release steps in README.md

COMMAND=${1:-}
DISTRO=${2:-}
case $DISTRO in kinetic|melodic|noetic|jazzy) ;; *) sed -n '4,9s/^# *//p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null; echo "usage: install.sh <ubuntu|distrobox|root|user> <kinetic|melodic|noetic|jazzy> ..." >&2; exit 2 ;; esac
shift 2

HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd)
if [ -f "$HERE/ros/$DISTRO/setup-root.sh" ]; then
  ROOT=$HERE
else
  # in the real home: a Distrobox box with its own home still sees it at the same path
  CACHE=${XDG_CACHE_HOME:-$HOME/.cache}
  mkdir -p "$CACHE"
  ROOT=$(mktemp -d "$CACHE/ros-envs.XXXXXX")
  trap 'rm -rf "$ROOT"' EXIT
  echo "== Downloading $REPOSITORY $REF"
  curl -fsSL "https://github.com/$REPOSITORY/archive/$REF.tar.gz" | tar -xz -C "$ROOT" --strip-components=1
  chmod -R a+rX "$ROOT"
fi

case $COMMAND in
  ubuntu)
    sudo bash "$ROOT/ros/$DISTRO/setup-root.sh" "$(id -un)"
    bash "$ROOT/ros/$DISTRO/setup-user.sh"
    ;;
  distrobox) bash "$ROOT/distrobox/create.sh" "$DISTRO" "$@" ;;
  root) bash "$ROOT/ros/$DISTRO/setup-root.sh" "$@" ;;
  user) bash "$ROOT/ros/$DISTRO/setup-user.sh" ;;
  *) echo "unknown command: $COMMAND" >&2; exit 2 ;;
esac
