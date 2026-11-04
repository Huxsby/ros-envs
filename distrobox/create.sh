#!/bin/bash
# Creates on Linux, with Distrobox, the equivalent of a WSL distro: the box ros-kinetic (Ubuntu 16.04), ros-melodic
# (18.04), ros-noetic (20.04) or ros-jazzy (24.04), each with its own home in ~/distrobox/<box> so that they share
# neither ~/.bashrc nor what is installed with pip, and installs it with the same setup-root.sh and setup-user.sh as
# the WSL distros.
# Usage: bash distrobox/create.sh kinetic|melodic|noetic|jazzy [--link DIR]   (from the desktop, not over ssh: machine.sh tries the GPU)
#        --link DIR links a project from the host in ~/projects/<name> and, if it has a Makefile, runs make build
#        DBX_FLAGS="--memory 4g" bash distrobox/create.sh noetic   (extra options for podman/docker)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DISTRO=${1:-}
PROJECT=
[ "${2:-}" != --link ] || PROJECT=$(cd "${3:?--link needs a folder}" && pwd)
case $DISTRO in
  kinetic) IMAGE=docker.io/library/ubuntu:16.04 ;;
  melodic) IMAGE=docker.io/library/ubuntu:18.04 ;;
  noetic) IMAGE=docker.io/library/ubuntu:20.04 ;;
  jazzy) IMAGE=docker.io/library/ubuntu:24.04 ;;
  *) sed -n '6,8s/^# *//p' "$0"; exit 2 ;;
esac
BOX=ros-$DISTRO
BOX_HOME=${DISTROBOX_HOMES:-$HOME/distrobox}/$BOX
command -v distrobox >/dev/null || { echo "distrobox is missing: sudo apt install distrobox podman"; exit 1; }

echo "== Box $BOX ($IMAGE), home in $BOX_HOME"
if distrobox list 2>/dev/null | awk -F'|' '{gsub(/ /, "", $2); print $2}' | grep -qx "$BOX"; then
  echo "It already exists and is reused (to start over: distrobox rm $BOX and delete $BOX_HOME)"
else
  options=(--yes --name "$BOX" --image "$IMAGE" --home "$BOX_HOME")
  # with the NVIDIA driver on the host, the box uses its libraries (those of the installed version)
  command -v nvidia-smi >/dev/null && options+=(--nvidia)
  # distrobox sets --pids-limit=-1 ("no limit"), but podman 4.9 on recent kernels turns it into pids.max=1 and the
  # box does not start ("Cannot fork"). An explicit limit comes later and wins; DBX_FLAGS can change it.
  options+=(--additional-flags "--pids-limit=100000 ${DBX_FLAGS:-}")
  distrobox create "${options[@]}"
fi

# inside the box: the host language, passwordless sudo, the user and the time zone
distrobox enter "$BOX" -- sudo bash "$ROOT/distrobox/locale.sh" "${LANG:-}"
distrobox enter "$BOX" -- sudo bash "$ROOT/ros/$DISTRO/setup-root.sh" "$USER"
distrobox enter "$BOX" -- bash "$ROOT/ros/$DISTRO/setup-user.sh"
if [ -n "$PROJECT" ]; then
  # the project stays on the host: it is edited from outside or inside the box
  distrobox enter "$BOX" -- bash -c "mkdir -p ~/projects && ln -sfn '$PROJECT' ~/projects/'$(basename "$PROJECT")'"
  [ ! -f "$PROJECT/Makefile" ] || distrobox enter "$BOX" -- make --no-print-directory -C "$PROJECT" build
fi

echo
echo "== $BOX is ready. To enter: distrobox enter $BOX"
