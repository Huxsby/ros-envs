#!/bin/bash
# Root step of ROS Noetic: see ../ros1/setup-root.sh. Usage: bash setup-root.sh <user> [time zone]
exec bash "$(dirname "$0")/../ros1/setup-root.sh" noetic "$@"
