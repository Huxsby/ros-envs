#!/bin/bash
# User step of ROS Noetic: see ../ros1/setup-user.sh. Usage: bash setup-user.sh
exec bash "$(dirname "$0")/../ros1/setup-user.sh" noetic "$@"
