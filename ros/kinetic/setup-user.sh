#!/bin/bash
# User step of ROS Kinetic: see ../ros1/setup-user.sh. Usage: bash setup-user.sh
exec bash "$(dirname "$0")/../ros1/setup-user.sh" kinetic "$@"
