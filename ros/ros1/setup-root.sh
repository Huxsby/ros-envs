#!/bin/bash
# User, wsl.conf, ROS 1 with its Gazebo, libraries and tools, for Kinetic, Melodic or Noetic. Run as root on a fresh
# Ubuntu of that distro: a just-imported WSL distro, or inside a Distrobox box with sudo, where the user and the time
# zone come from the host. Called through ros/<distro>/setup-root.sh.
# Usage: bash setup-root.sh <kinetic|melodic|noetic> <user> [time zone]     (time zone on WSL only; default Etc/UTC)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
DISTRO="${1:-}"
USER_NAME="${2:?usage: setup-root.sh <kinetic|melodic|noetic> <user> [time zone]}"
TIME_ZONE="${3:-Etc/UTC}"
# Each distro with its Ubuntu, and the Python its official packages were built for: 2.7 up to Melodic, 3.8 on Noetic.
# Python 2 has its packages named python-*, Python 3 python3-*.
case $DISTRO in
  kinetic) CODENAME=xenial UBUNTU=16.04 PY=python ;;
  melodic) CODENAME=bionic UBUNTU=18.04 PY=python ;;
  noetic) CODENAME=focal UBUNTU=20.04 PY=python3 ;;
  *) echo "usage: setup-root.sh <kinetic|melodic|noetic> <user> [time zone]" >&2; exit 2 ;;
esac
[ "$(. /etc/os-release && echo "$VERSION_CODENAME")" = "$CODENAME" ] || { echo "This is not Ubuntu $UBUNTU ($CODENAME)"; exit 1; }

if grep -qi microsoft /proc/sys/kernel/osrelease; then
  echo "== User and wsl.conf"
  if ! id "$USER_NAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,adm,video,plugdev,dialout "$USER_NAME"
  fi
  cat > /etc/wsl.conf <<CONF
[user]
default=$USER_NAME
CONF
  ln -sf "/usr/share/zoneinfo/$TIME_ZONE" /etc/localtime
  echo "$TIME_ZONE" > /etc/timezone
fi

echo "== Base packages"
apt-get update
apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade
# apt-transport-https: the apt of 16.04 cannot reach https repositories (GitHub CLI) without it.
# python-is-python3 only exists from 20.04: before, python is Python 2, which ROS needs.
BASE=(curl ca-certificates gnupg git build-essential mesa-utils)
case $DISTRO in
  kinetic|melodic) BASE+=(apt-transport-https) ;;
  noetic) BASE+=(python-is-python3) ;;
esac
apt-get install -y "${BASE[@]}"

echo "== ROS and GitHub CLI repositories"
# The old ROS GPG key expired in 2025. ros-apt-source installs the new key and the repository list, but only has
# packages for 20.04 and later; Kinetic and Melodic remain at packages.ros.org, signed with that same key, so the key
# is taken from the package and the list is written here.
curl -fsSL -o /tmp/ros-apt-source.deb \
  https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros-apt-source_1.3.0.focal_all.deb
if [ "$DISTRO" = noetic ]; then
  dpkg -i /tmp/ros-apt-source.deb
else
  rm -rf /tmp/ros-apt-source && dpkg-deb -x /tmp/ros-apt-source.deb /tmp/ros-apt-source
  install -m 644 /tmp/ros-apt-source/usr/share/keyrings/ros-archive-keyring.gpg /usr/share/keyrings/
  echo "deb [signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros/ubuntu $CODENAME main" \
    > /etc/apt/sources.list.d/ros1-latest.list
  rm -rf /tmp/ros-apt-source
fi
rm -f /tmp/ros-apt-source.deb
curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  https://cli.github.com/packages/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update

echo "== ROS ${DISTRO^} and libraries"
# pyflakes checks code of the same Python as ROS: the pyflakes package is Python 2's, python3-pyflakes Python 3's
PYFLAKES=$([ "$PY" = python ] && echo pyflakes || echo python3-pyflakes)
apt-get install -y \
  "ros-$DISTRO-desktop-full" \
  "ros-$DISTRO-smach-ros" "ros-$DISTRO-smach-viewer" "ros-$DISTRO-teleop-twist-keyboard" \
  "$PY-rosdep" "$PY-rosinstall" "$PY-rosinstall-generator" "$PY-wstool" "$PY-catkin-tools" \
  "$PY-numpy" "$PY-pandas" "$PY-matplotlib" ffmpeg gh tmux zip \
  shellcheck "$PYFLAKES"
# its advice to run rosdep update is left out: setup-user.sh does it
[ -f /etc/ros/rosdep/sources.list.d/20-default.list ] || rosdep init >/dev/null

echo "== setup-root OK"
