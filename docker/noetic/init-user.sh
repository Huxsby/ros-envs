#!/bin/bash
# First start, as the user: catkin workspace and rosdep. Idempotent.
mkdir -p ~/catkin_ws/src
if [ ! -f ~/catkin_ws/devel/setup.bash ]; then
  source /opt/ros/noetic/setup.bash
  (cd ~/catkin_ws && catkin_make >/dev/null)
fi
[ -d ~/.ros/rosdep ] || rosdep update --include-eol-distros >/dev/null 2>&1
exit 0
