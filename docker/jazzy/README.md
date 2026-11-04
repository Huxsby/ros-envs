# ROS 2 Jazzy in the browser, with Docker

**English** · [Español](README.es.md)

The Jazzy environment (Ubuntu 24.04, Gazebo Harmonic) in a server container, used from a browser. It suits a machine without a local install, such as a tablet.

| Service | Port in the container | Use |
|---|---|---|
| code-server | 8443 | VS Code in the browser and terminal |
| noVNC | 6080 | Desktop: Gazebo, rviz2, rqt |

The home folder is a volume: repositories, `ros2_ws`, the `gh` session and extensions survive a new image. What `apt` installs inside the container does not; add it to the `Dockerfile`.

## Start it

```bash
git clone https://github.com/Huxsby/ros-envs.git && cd ros-envs/docker/jazzy
cp .env.example .env    # then set CODE_PASSWORD in .env
docker compose up -d
```

| Command | What it does |
|---|---|
| `cp .env.example .env` | Creates the file with your settings. Git ignores it, so the passwords are not uploaded |
| `docker compose up -d` | Downloads the image and starts the container in the background (`-d`) |
| `docker compose logs -f` | Follows its output, to see why it does not start |
| `docker compose down` | Stops and removes the container. The volume with the home stays; `down -v` deletes it too |

`CODE_PASSWORD` is required: without it the container refuses to start, instead of opening code-server to anyone. Both ports are published on `127.0.0.1` of the server only.

The image is `ghcr.io/huxsby/ros-envs-jazzy`, built by [`image.yml`](../../.github/workflows/image.yml). To build it locally, from this folder: `docker build -f Dockerfile -t ghcr.io/huxsby/ros-envs-jazzy:latest ..` (the context is `docker/`, which holds the files shared with Jazzy in `common/`) and `docker compose up -d --pull never`.

| Variable | Default | Meaning |
|---|---|---|
| `CODE_PASSWORD` | required | Password of code-server |
| `VNC_PASSWORD` | empty | Second password for noVNC; only 8 characters count |
| `VNC_GEOMETRY` | `1600x1000` | Desktop size |
| `TZ` | `Etc/UTC` | Time zone |

To use another user name, change both `CONTAINER_USER` and the volume destination in `docker-compose.yml`, because they must match.

## Connect

An SSH tunnel is the simplest way:

```bash
ssh -N -L 8443:localhost:8443 -L 6080:localhost:6080 <user>@<server>
```

`-L local:host:remote` forwards a port of your machine to one of the server, and `-N` opens no remote shell. It keeps running while the tunnel is in use.

- VS Code: `http://localhost:8443`
- Desktop: `http://localhost:6080/vnc.html?autoconnect=1&resize=remote`

To reach it from any network, put an HTTPS reverse proxy in front of code-server only, and use a long random `CODE_PASSWORD`. noVNC does not need its own domain: it can be reached through the code-server port proxy, behind its login, at `/proxy/6080/vnc.html?path=proxy/6080/websockify&autoconnect=1&resize=remote`. Do not rely on `VNC_PASSWORD` alone, since 8 characters are not enough to expose it.

## First time inside

```bash
git clone https://github.com/Huxsby/ros-envs.git ~/projects/ros-envs
bash ~/projects/ros-envs/ros/jazzy/smoke-test.sh    # must end in SMOKE TEST OK
```

## Daily use

- **Terminal.** The `bash` of VS Code loads ROS, `ros2_ws` and `DISPLAY=:1`, so `ros2 launch` works without `source`, and windows open on the noVNC desktop.
- **Long processes.** Run them in `tmux`: a browser terminal can be cut off if the device locks or the tab closes.
- **Without a GPU.** Everything renders on the CPU (llvmpipe). On Gazebo Harmonic that includes the usual laser, `gpu_lidar`, so the simulation itself runs slower than with a GPU, not only its window. Run it without the GUI (`gz sim -s`) when you do not need to watch it.
- **Videos.** `ffmpeg -f x11grab -video_size 1600x1000 -i :1 video.mp4`, inside the container.
- **Compile jobs.** `MAKEFLAGS` is `-j2` in the container's `bash`, because a ROS `g++` takes 1-2 GB; export another value to change it.
- **Limits.** 6 GB of memory and 3.5 CPUs, set in `docker-compose.yml`.
