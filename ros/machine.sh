#!/bin/bash
# Detects the machine (CPU, memory and GPU) and chooses how to render and how many compile jobs to use, on WSL or
# on Linux with Distrobox. Shared by Noetic and Jazzy: setup-user.sh runs it on install, and it should be repeated
# after changing machine, GPU driver or .wslconfig. ~/.bashrc loads what it saves.
# Usage: machine.sh                 report, changes nothing
#        machine.sh --help          prints this usage
#        machine.sh --save [GPU]    saves the variables to ~/.config/ros-envs/machine.sh and loads them from ~/.bashrc
#        machine.sh --jobs          prints only the number of compile jobs
#        GPU: auto (default: the first that works of NVIDIA, AMD, Intel) | software | adapter name
set -uo pipefail
SAVED_FILE=$HOME/.config/ros-envs/machine.sh
MODE=report
GPU=auto
usage() { echo "usage: machine.sh [--report | --save [auto|software|NVIDIA|AMD|Intel|...] | --jobs | --help]" >&2; exit 2; }
case "${1:-}" in
  ""|--report) MAX_ARGS=1 ;;
  --save) MODE=save; GPU=${2:-auto}; MAX_ARGS=2 ;;
  --jobs) MODE="jobs"; MAX_ARGS=1 ;;
  -h|--help) sed -n '5,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
  *) usage ;;
esac
# a leftover argument or an option in place of the GPU is a typo: say so instead of ignoring it
[ $# -le "$MAX_ARGS" ] || usage
case $GPU in -*) usage ;; esac

ON_WSL=false
grep -qi microsoft /proc/sys/kernel/osrelease && ON_WSL=true

# --- CPU and memory (on WSL, those of its VM: half of the machine by default; .wslconfig changes it)
CORES=$(nproc)
CPU=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)
MEMORY_GB=$(awk '/^MemTotal/ {printf "%d", $2 / 1048576 + 0.5}' /proc/meminfo)
# A container limit (docker --memory and --cpus, DBX_FLAGS) changes neither /proc/meminfo nor nproc: the cgroup
# holds it. v2 has memory.max and cpu.max, v1 has the files in the else branch. Without a limit they say "max",
# "-1" or a huge number, and the CPU quota and period must both be numbers.
CG=/sys/fs/cgroup
MEMORY_LIMITED=false
CORES_NOTE=
if [ -f "$CG/memory.max" ]; then
  LIMIT_MEM=$(cat "$CG/memory.max" 2>/dev/null)
  read -r LIMIT_QUOTA LIMIT_PERIOD < <(cat "$CG/cpu.max" 2>/dev/null)
else
  LIMIT_MEM=$(cat "$CG/memory/memory.limit_in_bytes" 2>/dev/null)
  LIMIT_QUOTA=$(cat "$CG/cpu/cpu.cfs_quota_us" 2>/dev/null)
  LIMIT_PERIOD=$(cat "$CG/cpu/cpu.cfs_period_us" 2>/dev/null)
fi
if [[ ${LIMIT_MEM:-} =~ ^[0-9]+$ ]]; then
  LIMIT_GB=$(( (LIMIT_MEM / 1048576 + 512) / 1024 ))
  [ "$LIMIT_GB" -ge "$MEMORY_GB" ] || { MEMORY_GB=$LIMIT_GB; MEMORY_LIMITED=true; }
fi
if [[ ${LIMIT_QUOTA:-} =~ ^[0-9]+$ && ${LIMIT_PERIOD:-} =~ ^[1-9][0-9]*$ ]]; then
  LIMIT_CPUS=$((LIMIT_QUOTA / LIMIT_PERIOD))
  [ "$LIMIT_CPUS" -ge 1 ] || LIMIT_CPUS=1
  [ "$LIMIT_CPUS" -ge "$CORES" ] || { CORES=$LIMIT_CPUS; CORES_NOTE=" (container limit)"; }
fi
# Compile jobs: one per core, but at most one per 2 GB, because a ROS g++ takes 1-2 GB. With more, memory runs out
# and WSL (or the Linux OOM killer) kills the build without saying why.
JOBS=$((MEMORY_GB / 2))
[ "$JOBS" -gt "$CORES" ] && JOBS=$CORES
[ "$JOBS" -lt 1 ] && JOBS=1
if [ "$MODE" = jobs ]; then echo "$JOBS"; exit 0; fi

# --- GPU on WSL. Mesa reaches the Windows GPU through the d3d12 driver (/dev/dxg). It does not work on every
# machine: on some Iris Plus integrated GPUs, glxinfo with d3d12 ends in "X Error ... BadValue", and rendering
# has to fall back to software (llvmpipe). That is why it is tried before being used.
# d3d12_on(adapter): prints the device if glxinfo renders with acceleration on that adapter
d3d12_on() {
  local output device
  output=$(env -u LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME="$1" \
    timeout 15 glxinfo -B 2>&1) || return 1
  grep -q 'Accelerated: yes' <<<"$output" || return 1
  device=$(sed -n 's/^ *Device: //p' <<<"$output" | head -1)
  # if the requested adapter does not exist, Mesa uses the default one: check it is the requested one
  grep -qi -- "$1" <<<"$device" || return 1
  echo "$device"
}

# --- GPU on Linux (Distrobox): the box uses the host drivers. With hybrid graphics (Intel + NVIDIA in on-demand
# mode), Intel renders by default and NVIDIA is requested per program with PRIME render offload.
NVIDIA_VARIABLES="__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only"
# linux_on(adapter): prints the device if glxinfo renders with acceleration on that adapter
linux_on() {
  local output device
  if [ "$1" = NVIDIA ]; then
    # shellcheck disable=SC2086
    output=$(env -u LIBGL_ALWAYS_SOFTWARE -u GALLIUM_DRIVER $NVIDIA_VARIABLES timeout 15 glxinfo -B 2>&1) || return 1
  else
    output=$(env -u LIBGL_ALWAYS_SOFTWARE -u GALLIUM_DRIVER timeout 15 glxinfo -B 2>&1) || return 1
  fi
  device=$(sed -n 's/^OpenGL renderer string: //p' <<<"$output" | head -1)
  # the NVIDIA driver does not print "Accelerated: yes" (that is Mesa's): not being llvmpipe is enough
  grep -qiE 'llvmpipe|softpipe' <<<"$device" && return 1
  grep -qi -- "$1" <<<"$device" || return 1
  echo "$device"
}

RENDER=software
ADAPTER=
DEVICE=
REASON=
if [ "$GPU" = software ]; then
  REASON="requested with GPU=software"
elif $ON_WSL && [ ! -e /dev/dxg ]; then
  REASON="WSL does not expose the GPU (/dev/dxg is missing)"
elif $ON_WSL && ! ls /usr/lib/*/dri/d3d12_dri.so >/dev/null 2>&1; then
  # the d3d12 driver arrived in Mesa 21: Ubuntu 20.04 has it, 16.04 and 18.04 do not
  REASON="this Mesa has no d3d12 driver to reach the Windows GPU (Ubuntu 20.04 and later have it)"
elif ! command -v glxinfo >/dev/null; then
  REASON="glxinfo is missing, cannot try the GPU (sudo apt install mesa-utils)"
elif [ -z "${DISPLAY:-}" ]; then
  REASON="no display to try the GPU on; repeat from a desktop terminal"
else
  if [ "$GPU" = auto ]; then candidates=(NVIDIA AMD Intel); else candidates=("$GPU"); fi
  for a in "${candidates[@]}"; do
    if $ON_WSL; then
      if DEVICE=$(d3d12_on "$a"); then RENDER=d3d12; ADAPTER=$a; break; fi
    else
      if DEVICE=$(linux_on "$a"); then RENDER=$([ "$a" = NVIDIA ] && echo nvidia || echo mesa); ADAPTER=$a; break; fi
    fi
  done
  [ "$RENDER" != software ] || REASON="no GPU renders with acceleration: ${candidates[*]}"
fi

CLEAR="LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER MESA_D3D12_DEFAULT_ADAPTER_NAME __NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME __VK_LAYER_NV_optimus"
case $RENDER in
  d3d12)
    VARIABLES="unset $CLEAR
export GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=$ADAPTER"
    SUMMARY="GPU $DEVICE (d3d12)" ;;
  nvidia)
    VARIABLES="unset $CLEAR
export $NVIDIA_VARIABLES"
    SUMMARY="GPU $DEVICE (PRIME render offload)" ;;
  mesa)
    VARIABLES="unset $CLEAR"
    SUMMARY="GPU $DEVICE (Mesa)" ;;
  software)
    VARIABLES="unset $CLEAR
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe"
    SUMMARY="software rendering, llvmpipe ($REASON)" ;;
esac

WHERE=$($ON_WSL && echo "for WSL" || echo "on this machine")
! $MEMORY_LIMITED || WHERE="in this container"
echo "CPU:      ${CPU:-unknown}, $CORES threads$CORES_NOTE"
echo "Memory:   $MEMORY_GB GB $WHERE -> $JOBS compile jobs"
echo "Render:   $SUMMARY"
if $ON_WSL && [ "$MEMORY_GB" -lt 6 ]; then
  echo "Warning:  with under 6 GB, Gazebo and builds are tight: raise memory= in %UserProfile%\\.wslconfig"
fi

if [ "$MODE" = save ]; then
  mkdir -p "$(dirname "$SAVED_FILE")"
  cat >"$SAVED_FILE" <<EOF
# Generated by ros-envs/ros/machine.sh on $(date '+%Y-%m-%d %H:%M'). Do not edit: run machine.sh --save [GPU] again.
# Machine: ${CPU:-unknown CPU}, $CORES threads, $MEMORY_GB GB $WHERE. Render: $SUMMARY
export ROS_ENVS_JOBS=$JOBS
$VARIABLES
EOF
  if ! grep -q '# --- ros-envs machine ---' ~/.bashrc 2>/dev/null; then
    cat >>~/.bashrc <<'BASHRC'
# --- ros-envs machine --- (render and compile jobs: ros/machine.sh --save)
[ -f "$HOME/.config/ros-envs/machine.sh" ] && source "$HOME/.config/ros-envs/machine.sh"
BASHRC
  fi
  echo "Saved:    $SAVED_FILE (loaded by ~/.bashrc: open another terminal or source ~/.bashrc)"
fi
