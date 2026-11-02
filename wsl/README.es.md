# ROS en WSL

[English](README.md) · **Español**

Cada entorno es su propia distro de WSL, `ROS-Noetic` o `ROS-Jazzy`. No comparten paquetes ni `~/.bashrc`, y las ventanas salen en Windows mediante WSLg, sin servidor X.

## Instalación

Necesita WSL 2 (`wsl --version`). En PowerShell, desde una terminal normal:

```powershell
curl.exe -fLO https://raw.githubusercontent.com/Huxsby/ros-envs/v1.0.0/wsl/install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Distro noetic -User <usuario de linux> -TimeZone <Area/City>
```

| Opción | Por defecto | Significado |
|---|---|---|
| `-Distro` | obligatoria | `noetic` o `jazzy` |
| `-User` | obligatoria | Usuario de Linux que se crea |
| `-TimeZone` | `Etc/UTC` | Zona horaria de la distro |
| `-Location` | `%UserProfile%\WSL` | Carpeta del disco virtual |
| `-WslVersion` | `2` | Versión de WSL de la distro |
| `-Ref` | la versión fijada | Etiqueta, rama o commit de este repositorio que se instala |
| `-NoPassword` | desactivada | Omite la petición de contraseña, para ejecuciones desatendidas |

Descarga la imagen oficial de Ubuntu, la importa como distro, ejecuta los pasos de root y de usuario y, por el camino, pide la contraseña de `sudo`. Se detiene si ya existe una distro con ese nombre; para empezar de cero, `wsl --unregister ROS-Noetic`, que borra la distro entera.

Después entra en la distro y compruébala:

```bash
gh auth login && gh auth setup-git    # para trabajar con repositorios de GitHub
git clone https://github.com/Huxsby/ros-envs.git && bash ros-envs/ros/noetic/smoke-test.sh
```

## Uso diario

```powershell
wsl -d ROS-Noetic
wsl --terminate ROS-Noetic            # pararla
wsl --export ROS-Noetic copia.tar     # copia de seguridad de la distro entera
```

Mantén el código en el disco ext4 de la distro, no en `/mnt/c`, donde es lento y da problemas con el bit de ejecución y con CRLF.

## Problemas conocidos

- **Comprobar la GPU.** `bash ros/machine.sh` dice qué se usa. A mano, `glxinfo -B | grep -E 'Device|Accelerated'` debe mostrar `D3D12 (...)` y `yes`.
- **Gazebo se abre en negro o se cierra.** Ejecuta `bash ros/machine.sh --save software` y abre otra terminal.
- **Sin pantalla durante la instalación.** `machine.sh` la necesita para probar la GPU: si no hay, deja el render por software y lo dice. Repite `--save` desde una terminal normal.
- **Menos de 6 GB de memoria.** Gazebo y la compilación van justos. Sube `memory=` en `%UserProfile%\.wslconfig`; por defecto, WSL usa la mitad de la memoria del equipo.
- **Avisos de `dbus` durante `apt` en Noetic.** Son normales: esa distro no usa systemd.
- **`rosdep update` ignora Noetic.** Desde que perdió el soporte necesita `--include-eol-distros`, que `setup-user.sh` ya pasa.
- **Jazzy: no se descubren los nodos.** Suele ser el daemon con otro `ROS_DOMAIN_ID`: `ros2 daemon stop` y repetir.
- **Jazzy: problemas con el láser o ventana en negro.** Gazebo Harmonic renderiza con ogre2 y necesita OpenGL 3.3 o posterior. `llvmpipe` funciona siempre, aunque más lento. Para diagnosticar: `gz sim -v 4 shapes.sdf`.
