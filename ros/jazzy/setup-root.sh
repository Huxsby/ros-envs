#!/bin/bash
# User, wsl.conf, ROS 2 Jazzy with Gazebo Harmonic, SMACH, libraries and tools. Run as root on a fresh Ubuntu 24.04:
# a just-installed WSL distro, or inside a Distrobox box with sudo, where the user, its groups and the time zone
# come from the host.
# Usage: bash setup-root.sh <user> [time zone]     (time zone on WSL only; default Etc/UTC)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
USER_NAME="${1:?usage: setup-root.sh <user> [time zone]}"
TIME_ZONE="${2:-Etc/UTC}"
[ "$(. /etc/os-release && echo "$VERSION_CODENAME")" = noble ] || { echo "This is not Ubuntu 24.04 (noble)"; exit 1; }

if grep -qi microsoft /proc/sys/kernel/osrelease; then
  echo "== User and wsl.conf"
  if ! id "$USER_NAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,adm,video,render,plugdev,dialout "$USER_NAME"
  fi
  # render: /dev/dri/renderD128 belongs to that group on 24.04
  usermod -aG video,render "$USER_NAME"
  # systemd is on in the Ubuntu 24.04 WSL image: it stays as Canonical leaves it
  cat > /etc/wsl.conf <<CONF
[boot]
systemd=true

[user]
default=$USER_NAME
CONF
  ln -sf "/usr/share/zoneinfo/$TIME_ZONE" /etc/localtime
  echo "$TIME_ZONE" > /etc/timezone
fi
# ROS 2 needs a UTF-8 locale (the image ships C.UTF-8)
locale | grep -q 'LANG=.*UTF-8' || update-locale LANG=C.UTF-8

echo "== Base packages"
apt-get update
apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade
apt-get install -y software-properties-common curl ca-certificates gnupg git build-essential \
  mesa-utils libxml2-utils python-is-python3
add-apt-repository -y universe

echo "== ROS 2 (ros2-apt-source) and GitHub CLI repositories"
curl -fsSL -o /tmp/ros2-apt-source.deb \
  https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros2-apt-source_1.3.0.noble_all.deb
dpkg -i /tmp/ros2-apt-source.deb
curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  https://cli.github.com/packages/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update

echo "== ROS 2 Jazzy, Gazebo Harmonic and libraries"
# desktop-full already brings Gazebo Harmonic (ros_gz_sim, ros_gz_bridge), rviz2 and cv_bridge. Gazebo Classic and
# gazebo_ros_pkgs do not exist on Jazzy. SMACH does (executive_smach), but smach_viewer has no ROS 2 version:
# yasmin_viewer (in the browser) takes its place.
apt-get install -y \
  ros-jazzy-desktop-full ros-jazzy-ros-gz ros-dev-tools \
  ros-jazzy-executive-smach ros-jazzy-smach-ros \
  ros-jazzy-yasmin ros-jazzy-yasmin-ros ros-jazzy-yasmin-viewer \
  ros-jazzy-teleop-twist-keyboard ros-jazzy-tf-transformations \
  python3-numpy python3-pandas python3-matplotlib python3-opencv ffmpeg gh tmux zip \
  shellcheck python3-pyflakes
# its advice to run rosdep update is left out: setup-user.sh does it
[ -f /etc/ros/rosdep/sources.list.d/20-default.list ] || rosdep init >/dev/null

echo "== setup-root OK"
