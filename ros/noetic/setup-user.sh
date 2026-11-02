#!/bin/bash
# User environment (.bashrc, catkin_ws, rosdep and machine detection). Run as the distro's default user.
# Usage: bash setup-user.sh   (from anywhere: it finds ../machine.sh next to it)
set -euo pipefail
ROS_DIR=$(cd "$(dirname "$0")/.." && pwd)

if ! grep -q '# --- ROS Noetic ---' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# --- ROS Noetic ---
source /opt/ros/noetic/setup.bash
[ -f "$HOME/catkin_ws/devel/setup.bash" ] && source "$HOME/catkin_ws/devel/setup.bash"
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=localhost
BASHRC
fi
# render (GPU through d3d12 or software) and compile jobs of this machine
bash "$ROS_DIR/machine.sh" --save

mkdir -p ~/catkin_ws/src
set +u
source /opt/ros/noetic/setup.bash
set -u
cd ~/catkin_ws && catkin_make -j"$(bash "$ROS_DIR/machine.sh" --jobs)"

rosdep update --include-eol-distros

echo "== setup-user OK"
