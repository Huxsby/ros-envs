#!/bin/bash
# Smoke test of ROS Noetic: see ../ros1/smoke-test.sh. Usage: bash smoke-test.sh   (must end in SMOKE TEST OK)
exec bash "$(dirname "$0")/../ros1/smoke-test.sh" noetic "$@"
