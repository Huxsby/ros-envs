#!/bin/bash
# User, wsl.conf, ROS Noetic, Gazebo 11, libraries and tools. Run as root on a fresh Ubuntu 20.04: a just-imported
# WSL distro, or inside a Distrobox box with sudo, where the user and the time zone come from the host.
# Usage: bash setup-root.sh <user> [time zone]     (time zone on WSL only; default Etc/UTC)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
USER_NAME="${1:?usage: setup-root.sh <user> [time zone]}"
TIME_ZONE="${2:-Etc/UTC}"
[ "$(. /etc/os-release && echo "$VERSION_CODENAME")" = focal ] || { echo "This is not Ubuntu 20.04 (focal)"; exit 1; }

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
apt-get install -y curl ca-certificates gnupg git build-essential mesa-utils python-is-python3

echo "== ROS (ros-apt-source) and GitHub CLI repositories"
# the old ROS GPG key expired in 2025: ros-apt-source installs the new key and the repository list
curl -fsSL -o /tmp/ros-apt-source.deb \
  https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros-apt-source_1.3.0.focal_all.deb
dpkg -i /tmp/ros-apt-source.deb
curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  https://cli.github.com/packages/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update

echo "== ROS Noetic and libraries"
apt-get install -y \
  ros-noetic-desktop-full \
  ros-noetic-smach-ros ros-noetic-smach-viewer ros-noetic-teleop-twist-keyboard \
  python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool python3-catkin-tools \
  python3-numpy python3-pandas python3-matplotlib ffmpeg gh tmux zip \
  shellcheck python3-pyflakes
[ -f /etc/ros/rosdep/sources.list.d/20-default.list ] || rosdep init

echo "== setup-root OK"
