# ROS on Linux with Distrobox

**English** · [Español](README.es.md)

On Linux, each environment is a Distrobox box: a Podman container with its own Ubuntu that is used like the system itself, with a normal terminal, Gazebo and rviz windows on the desktop, and the machine's GPU. It is installed by the same scripts as the WSL distros.

| Box | Image | Box home |
|---|---|---|
| `ros-noetic` | `ubuntu:20.04` | `~/distrobox/ros-noetic` |
| `ros-jazzy` | `ubuntu:24.04` | `~/distrobox/ros-jazzy` |

Each box has its own home, so `.bashrc`, the workspace, `~/.ros` and what `pip` installs do not mix. The real home stays visible inside the box at the same path.

## Install

Requires `sudo apt install distrobox podman` and, to use NVIDIA, its driver already installed (`nvidia-smi` works). Run it from a desktop terminal, not over ssh, because `machine.sh` needs a display to try the GPU:

```bash
curl -fsSL https://raw.githubusercontent.com/Huxsby/ros-envs/v1.0.0/install.sh | bash -s -- distrobox noetic
```

To link a project from the host, which also runs `make build` if it has a Makefile, use a clone:

```bash
bash install.sh distrobox noetic --link ~/my-project
```

Running it again reuses the box and repeats the installation without breaking anything. Then enter the box and check it:

```bash
distrobox enter ros-noetic
git clone https://github.com/Huxsby/ros-envs.git && bash ros-envs/ros/noetic/smoke-test.sh
```

## From WSL to Distrobox

| WSL (PowerShell) | Distrobox (Linux terminal) |
|---|---|
| `wsl -d ROS-Noetic` | `distrobox enter ros-noetic` |
| `wsl -l -v` | `distrobox list` |
| `wsl --terminate ROS-Noetic` | `distrobox stop ros-noetic` |
| `wsl --unregister ROS-Noetic` | `distrobox rm ros-noetic`, and delete `~/distrobox/ros-noetic` |
| A new distro from another | `distrobox create --clone ros-noetic --name ros-noetic-test` |
| Open something from the Windows menu | `distrobox-export --app rviz`, inside the box |

## Speed and disk

A box is not a virtual machine: it is a process on the same kernel, with files on the same disk and windows on the same desktop. Entering a running box takes under 0.1 s.

| What | Size |
|---|---|
| Installed `ros-noetic` box | 6 GB |
| Installed `ros-jazzy` box | 6 GB |
| Home of each box | 4-11 MB |

Installing a box took 13-15 minutes on a 2-core machine, including downloads. These sizes were measured with LaTeX, around 300 MB, which is no longer installed.

- On Noetic, about 0.9 GB is a Fortran compiler (`flang-18`) that comes as a recommended package and that nothing uses. To remove it: `sudo apt purge flang-18 libflang-18-dev && sudo apt autoremove`.
- `--clone` copies the whole box. To keep several similar boxes, run `podman container commit ros-noetic ros-noetic-base` and create the others with `--image ros-noetic-base`, so they share layers.
- To free the space: `distrobox rm`, `podman image prune` and `rm -rf ~/distrobox/<box>`.

## GPU

With hybrid graphics (Intel + NVIDIA in on-demand mode), `ros/machine.sh` tries NVIDIA through PRIME render offload, then the Mesa GPU, and then software rendering. It stores the result inside the home of the box. If the NVIDIA driver changes on the host, the box uses the new one; run `--save` again.

## Editor

1. **System editor** on the host folder, building and running in a terminal of the box. This is the simplest option, but autocompletion does not see `/opt/ros`.
2. **Editor inside the box**, which opens with that box's ROS loaded: install it in the box and run `distrobox-export --app code`. It takes about 400 MB per box.

The *Remote - WSL* and *Dev Containers* extensions only work with Microsoft's VS Code.

## Differences from WSL

- **Shared network and processes.** Two Noetic simulations in two boxes would clash on port 11311, just as they would in two WSL distros, and killing `gzserver` in one box kills those of the others.
- **No systemd inside.** Nothing in these environments needs it.
- **Passwordless `sudo` inside the box**, because it is a rootless container. What breaks inside does not touch the system.
- **The language comes from the host.** The box inherits `LANG`, and `create.sh` generates it with `locale.sh`. Without that, `perl` warns on every command and some packages, TeX Live among them, fail to install.
- **Firewall.** Firewalls such as ufw cut the multicast that Gazebo Harmonic uses to find its own topics, so Jazzy sets `GZ_IP=127.0.0.1`.
- **`--pids-limit`.** Distrobox creates boxes with `--pids-limit=-1`, which podman 4.9 on recent kernels turns into a limit of 1 process (`Cannot fork`). `create.sh` sets `--pids-limit=100000`; recreate with it any box made by hand that fails this way.
