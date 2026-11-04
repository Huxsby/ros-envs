# ROS Noetic + Gazebo 11 (Ubuntu 20.04) on a server, with a desktop in the browser (noVNC) and VS Code in the
# browser (code-server). Same package set as ros/ros1/setup-root.sh.
# Build from docker/ (the context shares common/ with the other distros): docker build -f noetic/Dockerfile -t NAME .
FROM osrf/ros:noetic-desktop-full

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# The old key of the ROS repository expired in 2025: drop the list of the image and use ros-apt-source
RUN rm -f /etc/apt/sources.list.d/ros*.list /etc/apt/sources.list.d/ros*.sources \
 && apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
 && curl -fsSL -o /tmp/ros-apt-source.deb https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros-apt-source_1.3.0.focal_all.deb \
 && dpkg -i /tmp/ros-apt-source.deb && rm /tmp/ros-apt-source.deb \
 && curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-desktop-full ros-noetic-smach-ros ros-noetic-smach-viewer ros-noetic-teleop-twist-keyboard \
    python3-catkin-tools python3-numpy python3-pandas python3-matplotlib python-is-python3 ffmpeg \
    git gh sudo less nano tmux build-essential mesa-utils libgl1-mesa-dri \
    tigervnc-standalone-server tigervnc-common novnc websockify openbox xterm supervisor dbus-x11 fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*

# code-server (VS Code in the browser). The installer leaves the .tar.gz in its cache (~100 MB): deleted in the same layer
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local \
 && rm -rf /root/.cache/code-server

# The user (uid 1000) is created by entrypoint.sh on start, named after CONTAINER_USER
RUN mkdir -p /var/log/supervisor

COPY noetic/bashrc noetic/init-user.sh /opt/ros-envs/
COPY common/supervisord.conf /etc/supervisor/conf.d/ros-envs.conf
COPY common/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /opt/ros-envs/init-user.sh

EXPOSE 8443 6080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
