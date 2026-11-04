#!/bin/bash
# Prepares the home (persistent volume) and starts desktop, noVNC and code-server with supervisord.
set -e

# Without a password code-server would start open: better not to start (CODE_PASSWORD in .env)
[ -n "$PASSWORD" ] || { echo "ERROR: CODE_PASSWORD is missing" >&2; exit 1; }

# User: its name comes in CONTAINER_USER, it is not in the image. Its home is the volume
U="${CONTAINER_USER:-ros}"
H=/home/$U
id -u "$U" >/dev/null 2>&1 || useradd -M -d "$H" -u 1000 -s /bin/bash -G sudo,video,dialout "$U"
echo "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ros-envs && chmod 440 /etc/sudoers.d/ros-envs
mkdir -p "$H"
export CONTAINER_USER="$U" USER_HOME="$H"

# New home or one from a previous version: load the bashrc of the image, so that it is updated along with it
[ -f "$H/.bashrc" ] || cp /etc/skel/.bashrc "$H/.bashrc"
grep -q '/opt/ros-envs/bashrc' "$H/.bashrc" || echo '[ -f /opt/ros-envs/bashrc ] && source /opt/ros-envs/bashrc' >> "$H/.bashrc"
mkdir -p "$H/projects" "$H/.vnc"
chown "$U:$U" "$H" "$H/.bashrc" "$H/projects" "$H/.vnc"
[ -x /opt/ros-envs/init-user.sh ] && su - "$U" -c /opt/ros-envs/init-user.sh || echo "WARNING: init-user.sh failed"

# VNC: VNC_PASSWORD asks for a password (only 8 characters count); without one, or if it cannot be created, there is
# none: noVNC is already behind the code-server login and Xvnc only listens on localhost
export VNC_SECURITY="-SecurityTypes None"
if [ -n "$VNC_PASSWORD" ]; then
  if echo "$VNC_PASSWORD" | tigervncpasswd -f > "$H/.vnc/passwd"; then
    chown "$U:$U" "$H/.vnc/passwd" && chmod 600 "$H/.vnc/passwd"
    export VNC_SECURITY="-SecurityTypes VncAuth -rfbauth $H/.vnc/passwd"
  else
    echo "WARNING: the VNC password could not be created; the desktop starts without one" >&2
  fi
fi
export VNC_GEOMETRY="${VNC_GEOMETRY:-1600x1000}"

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
