# Changelog

Notable changes per version. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- ROS Kinetic (Ubuntu 16.04, Gazebo 7) and ROS Melodic (Ubuntu 18.04, Gazebo 9) environments, with Python 2.7 like their official packages, on WSL 2 (`ROS-Kinetic`, `ROS-Melodic`), Distrobox (`ros-kinetic`, `ros-melodic`) and an existing Ubuntu, each with its smoke test and its CI jobs.
- `--help` (and `-h`) in `install.sh` and `ros/machine.sh`: print the usage and exit with 0.
- The WSL CI job runs the smoke test of each distro after installing it.
- A Jazzy Docker image (`docker/jazzy`, published as `ghcr.io/huxsby/ros-envs-jazzy`) with Gazebo Harmonic, a browser desktop and VS Code, like the Noetic one.

### Changed

- The three ROS 1 environments share their scripts, in `ros/ros1`; `ros/<distro>/*.sh` keep their paths and only call them.
- `wsl/install.ps1` updates the certificates and `curl` of the imported image before downloading the installer.
- On WSL, `ros/machine.sh` says when the Mesa of the distro has no `d3d12` driver, instead of trying every GPU.
- What the two Docker images share (`entrypoint.sh`, `supervisord.conf`) moved to `docker/common`, and the images are built with `docker/` as the context.
- CI builds and smoke-tests both Docker images, and publishes both.
- The WSL CI job shows `wsl.exe` output as plain text instead of UTF-16.

## [v1.0.1] - 2026-11-03

### Changed

- The installer output says what each step does: every user step has a heading, and the end says how to enter and check the distro.
- `rosdep init` no longer advises running `rosdep update`, which the user step already does, and `rosdep update` runs quietly.
- `catkin_make` shows its output only when it fails.
- `wsl/install.ps1` hides the localized messages of `wsl --import` and `wsl --terminate`.
- The smoke tests no longer print SMACH debug lines.

## [v1.0.0] - 2026-11-02

First release.

- ROS Noetic (Ubuntu 20.04, Gazebo 11) and ROS 2 Jazzy (Ubuntu 24.04, Gazebo Harmonic) environments.
- Installers for WSL 2 (`wsl/install.ps1`), Distrobox and an existing Ubuntu (`install.sh`), and a Noetic Docker image with a browser desktop and VS Code (`docker/noetic`).
- Machine detection (`ros/machine.sh`): GPU rendering through d3d12, NVIDIA PRIME or Mesa, with a software fallback, and compile jobs bounded by memory.
- Smoke tests that need no project: Python libraries, a SMACH machine, and a headless simulation where a laser sees a wall and `cmd_vel` moves a robot.
- CI that installs every environment from scratch, per group and weekly, and scans the history for secrets.

[v1.0.1]: https://github.com/Huxsby/ros-envs/compare/v1.0.0...v1.0.1
[v1.0.0]: https://github.com/Huxsby/ros-envs/releases/tag/v1.0.0
