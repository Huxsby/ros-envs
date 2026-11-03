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
echo "== Machine detection: render and compile jobs"
bash "$ROS_DIR/machine.sh" --save

mkdir -p ~/catkin_ws/src
set +u
source /opt/ros/noetic/setup.bash
set -u
echo "== Workspace ~/catkin_ws (packages go in ~/catkin_ws/src)"
# its output only matters if it fails
LOG=$(mktemp)
cd ~/catkin_ws && catkin_make -j"$(bash "$ROS_DIR/machine.sh" --jobs)" >"$LOG" 2>&1 || { cat "$LOG"; exit 1; }
rm -f "$LOG"

echo "== rosdep update"
rosdep update -q --include-eol-distros

echo "== setup-user OK: open a new terminal (or source ~/.bashrc) to load ROS"
