#!/bin/bash
# First start, as the user: colcon defaults, ROS 2 workspace and rosdep. Idempotent.
# colcon: --symlink-install to edit a .py without rebuilding, and one package at a time so that memory does not run out
mkdir -p ~/.colcon ~/ros2_ws/src
[ -f ~/.colcon/defaults.yaml ] || cat > ~/.colcon/defaults.yaml <<'YAML'
build:
  symlink-install: true
  executor: sequential
YAML
if [ ! -f ~/ros2_ws/install/setup.bash ]; then
  source /opt/ros/jazzy/setup.bash
  (cd ~/ros2_ws && colcon build >/dev/null)
fi
[ -d ~/.ros/rosdep ] || rosdep update >/dev/null 2>&1
exit 0
