# ROS on WSL

**English** · [Español](README.es.md)

Each environment is its own WSL distro, `ROS-Noetic` or `ROS-Jazzy`. They share neither packages nor `~/.bashrc`, and windows open on Windows through WSLg, with no X server.

## Install

Requires WSL 2 (`wsl --version`). In PowerShell, from an ordinary terminal:

```powershell
curl.exe -fLO https://raw.githubusercontent.com/Huxsby/ros-envs/v1.0.0/wsl/install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Distro noetic -User <linux user> -TimeZone <Area/City>
```

| Option | Default | Meaning |
|---|---|---|
| `-Distro` | required | `noetic` or `jazzy` |
| `-User` | required | Linux user to create |
| `-TimeZone` | `Etc/UTC` | Time zone of the distro |
| `-Location` | `%UserProfile%\WSL` | Folder for the virtual disk |
| `-WslVersion` | `2` | WSL version of the distro |
| `-Ref` | the pinned release | Tag, branch or commit of this repository to install |
| `-NoPassword` | off | Skip the password prompt, for unattended runs |

It downloads the official Ubuntu image, imports it as a distro, runs the root and user steps, and asks for the `sudo` password along the way. It stops if a distro with that name already exists; to start over, run `wsl --unregister ROS-Noetic`, which deletes the whole distro.

Then enter the distro and check it:

```bash
gh auth login && gh auth setup-git    # to work with GitHub repositories
git clone https://github.com/Huxsby/ros-envs.git && bash ros-envs/ros/noetic/smoke-test.sh
```

## Daily use

```powershell
wsl -d ROS-Noetic
wsl --terminate ROS-Noetic            # stop it
wsl --export ROS-Noetic backup.tar    # back up the whole distro
```

Keep code on the ext4 disk of the distro, not in `/mnt/c`, where it is slow and has problems with the execute bit and CRLF.

## Known problems

- **Check the GPU.** `bash ros/machine.sh` says what is in use. By hand, `glxinfo -B | grep -E 'Device|Accelerated'` should show `D3D12 (...)` and `yes`.
- **Gazebo opens black or closes.** Run `bash ros/machine.sh --save software` and open another terminal.
- **No display during install.** `machine.sh` needs one to try the GPU: if there is none, it leaves software rendering and says so. Repeat `--save` from a normal terminal.
- **Under 6 GB of memory.** Gazebo and builds run short. Raise `memory=` in `%UserProfile%\.wslconfig`; WSL uses half of the machine's memory by default.
- **`dbus` warnings during `apt` on Noetic.** They are normal: that distro does not use systemd.
- **`rosdep update` ignores Noetic.** Since it reached end of life, it needs `--include-eol-distros`, which `setup-user.sh` already passes.
- **Jazzy: nodes are not discovered.** It is usually the daemon on another `ROS_DOMAIN_ID`: `ros2 daemon stop` and try again.
- **Jazzy: laser or black window problems.** Gazebo Harmonic renders with ogre2 and needs OpenGL 3.3 or later. `llvmpipe` always works, though it is slower. To diagnose: `gz sim -v 4 shapes.sdf`.
