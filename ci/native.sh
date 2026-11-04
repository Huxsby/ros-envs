#!/bin/bash
# Installs an environment in a plain Ubuntu container through install.sh, as a normal user, and runs its smoke test.
# Usage (as root, with the repository in /src): bash /src/ci/native.sh kinetic|melodic|noetic|jazzy
set -euo pipefail
DISTRO=${1:?usage: native.sh kinetic|melodic|noetic|jazzy}
apt-get update -qq
apt-get install -y -qq sudo
useradd -m -s /bin/bash -G sudo ci
echo 'ci ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ci
sudo -iu ci bash /src/install.sh ubuntu "$DISTRO"
# gzserver sometimes crashes on start for reasons unrelated to the environment: one retry before failing
sudo -iu ci bash /src/ros/"$DISTRO"/smoke-test.sh || sudo -iu ci bash /src/ros/"$DISTRO"/smoke-test.sh
