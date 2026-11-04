#!/bin/bash
# User environment of ROS 1 (.bashrc, catkin_ws, rosdep and machine detection), for Kinetic, Melodic or Noetic. Run
# as the distro's default user. Called through ros/<distro>/setup-user.sh.
# Usage: bash setup-user.sh <kinetic|melodic|noetic>   (from anywhere: it finds ../machine.sh next to it)
set -euo pipefail
DISTRO="${1:-}"
case $DISTRO in kinetic|melodic|noetic) ;; *) echo "usage: setup-user.sh <kinetic|melodic|noetic>" >&2; exit 2 ;; esac
ROS_DIR=$(cd "$(dirname "$0")/.." && pwd)

if ! grep -q "# --- ROS ${DISTRO^} ---" ~/.bashrc; then
  cat >> ~/.bashrc <<BASHRC

# --- ROS ${DISTRO^} ---
source /opt/ros/$DISTRO/setup.bash
[ -f "\$HOME/catkin_ws/devel/setup.bash" ] && source "\$HOME/catkin_ws/devel/setup.bash"
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=localhost
BASHRC
fi
echo "== Machine detection: render and compile jobs"
bash "$ROS_DIR/machine.sh" --save

mkdir -p ~/catkin_ws/src
set +u
source "/opt/ros/$DISTRO/setup.bash"
set -u
echo "== Workspace ~/catkin_ws (packages go in ~/catkin_ws/src)"
# its output only matters if it fails
LOG=$(mktemp)
cd ~/catkin_ws && catkin_make -j"$(bash "$ROS_DIR/machine.sh" --jobs)" >"$LOG" 2>&1 || { cat "$LOG"; exit 1; }
rm -f "$LOG"

echo "== rosdep update"
rosdep update -q --include-eol-distros

echo "== setup-user OK: open a new terminal (or source ~/.bashrc) to load ROS"
