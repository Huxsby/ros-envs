# Contributing

**English** · [Español](CONTRIBUTING.es.md)

Thanks for helping. Issues and pull requests are welcome in English or Spanish.

## Before you start

- **A question or an idea:** open a [discussion](https://github.com/Huxsby/ros-envs/discussions).
- **Something does not work:** open an issue with the bug template. Include the host (WSL 2, Distrobox or Docker), the environment (Noetic or Jazzy), the command you ran and the end of its output, and the result of `bash ros/machine.sh`.
- **A larger change**, such as a new ROS distro or host: open an issue first, so we can agree on the approach before you spend time on it.

Issues labelled [`good first issue`](https://github.com/Huxsby/ros-envs/labels/good%20first%20issue) are small and self-contained.

## What belongs here

Only what serves any ROS project: an environment, its installer, machine detection or a smoke test. Project-specific packages and settings belong in that project. Keep it simple: before adding an option, make sure it is needed and that it can be tested.

## Making a change

1. Fork the repository and create a branch.
2. Make the change, keeping to the style of the surrounding code:
   - Bash with `set -euo pipefail` in the installers.
   - The setup scripts must be safe to run twice.
   - What is shared by Noetic and Jazzy goes in `ros/`. What belongs to one host goes in `wsl/`, `distrobox/` or `docker/`.
   - On Noetic, Python 3.8: no syntax newer than that.
   - Code, comments and messages in English.
3. If you change documentation, change both languages: every `README.md` has a `README.es.md` that must say the same. If you do not write Spanish, say so in the pull request and it will be translated.
4. Check it:
   - `bash -n` and `shellcheck -S warning -e SC1090,SC1091` on every script you touched.
   - If you changed `ros/`, run the smoke test of that environment: `bash ros/<distro>/smoke-test.sh` must end in `SMOKE TEST OK`.
5. Open a pull request that says what changed and why, and how you tested it. CI installs the affected environments from scratch; documentation-only changes skip those jobs.

Never commit secrets: `.env` is ignored, and `.env.example` only holds placeholders. CI runs `gitleaks` on every push.

## Releases

See *Releasing* in the [README](README.md#releasing). Each release adds its section to [CHANGELOG.md](CHANGELOG.md).
