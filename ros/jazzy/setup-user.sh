#!/bin/bash
# User environment (.bashrc, ros2_ws, colcon, rosdep and machine detection). Run as the distro's default user.
# Usage: bash setup-user.sh   (from anywhere: it finds ../machine.sh next to it)
set -euo pipefail
ROS_DIR=$(cd "$(dirname "$0")/.." && pwd)

if ! grep -q '# --- ROS 2 Jazzy ---' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# --- ROS 2 Jazzy ---
source /opt/ros/jazzy/setup.bash
[ -f "$HOME/ros2_ws/install/setup.bash" ] && source "$HOME/ros2_ws/install/setup.bash"
# nodes are only discovered inside this distro (what ROS_HOSTNAME=localhost did in ROS 1)
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
[ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ] && source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
BASHRC
fi
# same for Gazebo: its discovery uses multicast on the local network and firewalls such as ufw block it, so the
# bridge would see no topics. A separate block so that it also reaches boxes that already exist.
if ! grep -q '^export GZ_IP=' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'
# Gazebo on this machine only (otherwise a firewall cuts its multicast discovery)
export GZ_IP=127.0.0.1
BASHRC
fi
# render (GPU through d3d12 or software) and compile jobs of this machine
bash "$ROS_DIR/machine.sh" --save

# colcon: --symlink-install to edit a .py without rebuilding (like devel/ in catkin) and one package at a time,
# so that memory does not run out with several C++ packages building at once
mkdir -p ~/.colcon
[ -f ~/.colcon/defaults.yaml ] || cat > ~/.colcon/defaults.yaml <<'YAML'
build:
  symlink-install: true
  executor: sequential
YAML

mkdir -p ~/ros2_ws/src
set +u
source /opt/ros/jazzy/setup.bash
set -u
cd ~/ros2_ws && MAKEFLAGS=-j"$(bash "$ROS_DIR/machine.sh" --jobs)" colcon build

rosdep update

echo "== setup-user OK"
