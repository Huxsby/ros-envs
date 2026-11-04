# ROS 2 Jazzy + Gazebo Harmonic (Ubuntu 24.04) on a server, with a desktop in the browser (noVNC) and VS Code in the
# browser (code-server). Same package set as ros/jazzy/setup-root.sh.
# Build from docker/ (the context shares common/ with the other distros): docker build -f jazzy/Dockerfile -t NAME .
FROM osrf/ros:jazzy-desktop-full

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
 && curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    ros-jazzy-desktop-full ros-jazzy-ros-gz ros-dev-tools \
    ros-jazzy-executive-smach ros-jazzy-smach-ros \
    ros-jazzy-yasmin ros-jazzy-yasmin-ros ros-jazzy-yasmin-viewer \
    ros-jazzy-teleop-twist-keyboard ros-jazzy-tf-transformations \
    python3-numpy python3-pandas python3-matplotlib python3-opencv python-is-python3 ffmpeg \
    git gh sudo less nano tmux zip shellcheck python3-pyflakes build-essential mesa-utils libgl1-mesa-dri libxml2-utils \
    tigervnc-standalone-server tigervnc-tools novnc websockify openbox xterm supervisor dbus-x11 fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*

# code-server (VS Code in the browser). The installer leaves the .tar.gz in its cache (~100 MB): deleted in the same layer
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local \
 && rm -rf /root/.cache/code-server

# ubuntu:24.04 ships a user "ubuntu" with uid 1000: it goes. The user (uid 1000) is created by entrypoint.sh on start,
# named after CONTAINER_USER
RUN userdel -r ubuntu 2>/dev/null; mkdir -p /var/log/supervisor

COPY jazzy/bashrc jazzy/init-user.sh /opt/ros-envs/
COPY common/supervisord.conf /etc/supervisor/conf.d/ros-envs.conf
COPY common/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /opt/ros-envs/init-user.sh

EXPOSE 8443 6080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
