# ROS on WSL

**English** · [Español](README.es.md)

Each environment is its own WSL distro: `ROS-Kinetic`, `ROS-Melodic`, `ROS-Noetic` or `ROS-Jazzy`. They share neither packages nor `~/.bashrc`, and windows open on Windows through WSLg, with no X server.

## Install

Requires WSL 2: `wsl --version` must answer, and `wsl --install --no-distribution` installs it if it does not. Run these two commands in PowerShell, from an ordinary terminal:

```powershell
curl.exe -fLO https://raw.githubusercontent.com/Huxsby/ros-envs/v1.0.2/wsl/install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Distro jazzy -User <linux user> -TimeZone <Area/City>
```

For example, for a user called `alex` in Tokyo:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Distro jazzy -User alex -TimeZone Asia/Tokyo
```

### What the commands mean

| Part | Meaning |
|---|---|
| `curl.exe` | The real curl. In Windows PowerShell, plain `curl` is an alias of `Invoke-WebRequest`, with other options |
| `-f` | Fail on an HTTP error, instead of saving the error page as if it were the script |
| `-L` | Follow redirects |
| `-O` | Save it in the current folder with its remote name, `install.ps1` |
| `v1.0.2` in the URL | The release to download. It also decides the default of `-Ref` |
| `powershell` | Starts a new Windows PowerShell process |
| `-ExecutionPolicy Bypass` | Lets that one process run a downloaded, unsigned script. It does not change the policy of the system |
| `-File .\install.ps1` | The script to run. Everything after it goes to the script |

### Options

| Option | Required | Default | Accepted values | Meaning |
|---|---|---|---|---|
| `-Distro` | yes | | `kinetic`, `melodic`, `noetic`, `jazzy` | Environment to install. It creates the distro `ROS-Kinetic`, `ROS-Melodic`, `ROS-Noetic` or `ROS-Jazzy` |
| `-User` | yes | | Lowercase letters, digits, `_` and `-`, starting with a letter or `_` | Linux user to create, which becomes the default user of the distro |
| `-TimeZone` | no | `Etc/UTC` | A *TZ identifier* from the [list of time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), such as `Europe/Madrid` | Time zone of the distro |
| `-Location` | no | `%UserProfile%\WSL` | Any folder | Where the virtual disk goes, in a subfolder with the name of the distro |
| `-Ref` | no | the release of the script | A tag, branch or commit of this repository | Version to install |
| `-NoPassword` | no | off | No value, it is a switch | Skips the password prompt, for unattended runs. The user then has no `sudo` password: set one later with `wsl -d ROS-Jazzy -u root passwd <user>` |

More examples:

```powershell
# On another disk
.\install.ps1 -Distro jazzy -User alex -Location D:\WSL
# ROS Noetic instead of Jazzy
.\install.ps1 -Distro noetic -User alex
# ROS Melodic, with Ubuntu 18.04 and Python 2.7
.\install.ps1 -Distro melodic -User alex
# The latest code, not a release
.\install.ps1 -Distro jazzy -User alex -Ref main
```

If PowerShell refuses to run the script directly, use the `powershell -ExecutionPolicy Bypass -File` form from above.

### What the script does

1. Stops if a distro with that name already exists. To start over, `wsl --unregister ROS-Jazzy` deletes the whole distro, along with everything inside it.
2. Downloads the official Ubuntu image to a temporary folder, which it deletes at the end.
3. Imports the image as a distro and updates its certificates and `curl`.
4. Runs the root step inside it (`ros/<distro>/setup-root.sh`): the user, its time zone, the repositories and the packages.
5. Restarts the distro and asks for the `sudo` password.
6. Runs the user step (`ros/<distro>/setup-user.sh`): `.bashrc`, machine detection, the workspace and `rosdep`.

### Check it

```powershell
wsl -d ROS-Jazzy
```

```bash
git clone https://github.com/Huxsby/ros-envs.git
bash ros-envs/ros/jazzy/smoke-test.sh # must end in SMOKE TEST OK
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
- **`rosdep update` ignores Kinetic, Melodic or Noetic.** Since they reached end of life, it needs `--include-eol-distros`, which `setup-user.sh` already passes.
- **Kinetic and Melodic render by software.** Their Mesa is older than the `d3d12` driver that reaches the Windows GPU, so `machine.sh` chooses `llvmpipe` and says why. Gazebo 7 and 9 work with it, only slower.
- **Jazzy: nodes are not discovered.** It is usually the daemon on another `ROS_DOMAIN_ID`: `ros2 daemon stop` and try again.
- **Jazzy: laser or black window problems.** Gazebo Harmonic renders with ogre2 and needs OpenGL 3.3 or later. `llvmpipe` always works, though it is slower. To diagnose: `gz sim -v 4 shapes.sdf`.
