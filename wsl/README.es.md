# ROS en WSL

[English](README.md) · **Español**

Cada entorno es su propia distro de WSL: `ROS-Kinetic`, `ROS-Melodic`, `ROS-Noetic` o `ROS-Jazzy`. No comparten paquetes ni `~/.bashrc`, y las ventanas salen en Windows mediante WSLg, sin servidor X.

## Instalación

Necesita WSL 2: `wsl --version` debe responder y, si no lo hace, `wsl --install --no-distribution` lo instala. Ejecuta estos dos comandos en PowerShell, desde una terminal normal:

```powershell
curl.exe -fLO https://raw.githubusercontent.com/Huxsby/ros-envs/v1.0.1/wsl/install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Distro jazzy -User <usuario de linux> -TimeZone <Area/City>
```

Por ejemplo, para un usuario llamado `alex` en Tokio:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Distro jazzy -User alex -TimeZone Asia/Tokyo
```

### Qué significan los comandos

| Parte | Significado |
|---|---|
| `curl.exe` | El curl de verdad. En Windows PowerShell, `curl` a secas es un alias de `Invoke-WebRequest`, con otras opciones |
| `-f` | Falla si hay un error HTTP, en vez de guardar la página de error como si fuera el script |
| `-L` | Sigue las redirecciones |
| `-O` | Lo guarda en la carpeta actual con su nombre remoto, `install.ps1` |
| `v1.0.1` en la URL | La versión que se descarga. También decide el valor por defecto de `-Ref` |
| `powershell` | Arranca un proceso nuevo de Windows PowerShell |
| `-ExecutionPolicy Bypass` | Permite a ese proceso ejecutar un script descargado y sin firmar. No cambia la política del sistema |
| `-File .\install.ps1` | El script que se ejecuta. Todo lo que va detrás es para el script |

### Opciones

| Opción | Obligatoria | Por defecto | Valores admitidos | Significado |
|---|---|---|---|---|
| `-Distro` | sí | | `kinetic`, `melodic`, `noetic`, `jazzy` | Entorno que se instala. Crea la distro `ROS-Kinetic`, `ROS-Melodic`, `ROS-Noetic` o `ROS-Jazzy` |
| `-User` | sí | | Minúsculas, dígitos, `_` y `-`, empezando por una letra o `_` | Usuario de Linux que se crea, y que pasa a ser el de la distro por defecto |
| `-TimeZone` | no | `Etc/UTC` | Un *TZ identifier* de la [lista de zonas horarias](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), como `Europe/Madrid` | Zona horaria de la distro |
| `-Location` | no | `%UserProfile%\WSL` | Cualquier carpeta | Dónde va el disco virtual, en una subcarpeta con el nombre de la distro |
| `-Ref` | no | la versión del script | Una etiqueta, rama o commit de este repositorio | Versión que se instala |
| `-NoPassword` | no | desactivada | Sin valor, es un interruptor | Omite la petición de contraseña, para ejecuciones desatendidas. El usuario se queda sin contraseña de `sudo`: se pone después con `wsl -d ROS-Jazzy -u root passwd <usuario>` |

Más ejemplos:

```powershell
# En otro disco
.\install.ps1 -Distro jazzy -User alex -Location D:\WSL
# ROS Noetic en vez de Jazzy
.\install.ps1 -Distro noetic -User alex
# ROS Melodic, con Ubuntu 18.04 y Python 2.7
.\install.ps1 -Distro melodic -User alex
# El código más reciente, no una versión publicada
.\install.ps1 -Distro jazzy -User alex -Ref main
```

Si PowerShell no permite ejecutar el script directamente, usa la forma `powershell -ExecutionPolicy Bypass -File` de arriba.

### Qué hace el script

1. Se detiene si ya existe una distro con ese nombre. Para empezar de cero, `wsl --unregister ROS-Jazzy` borra la distro entera, con todo lo que tenga dentro.
2. Descarga la imagen oficial de Ubuntu a una carpeta temporal, que borra al terminar.
3. Importa la imagen como distro y actualiza sus certificados y `curl`.
4. Ejecuta dentro el paso de root (`ros/<distro>/setup-root.sh`): el usuario, su zona horaria, los repositorios y los paquetes.
5. Reinicia la distro y pide la contraseña de `sudo`.
6. Ejecuta el paso de usuario (`ros/<distro>/setup-user.sh`): `.bashrc`, detección del equipo, el workspace y `rosdep`.

### Comprobarlo

```powershell
wsl -d ROS-Jazzy
```

```bash
git clone https://github.com/Huxsby/ros-envs.git
bash ros-envs/ros/jazzy/smoke-test.sh # debe acabar en SMOKE TEST OK
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
- **`rosdep update` ignora Kinetic, Melodic o Noetic.** Desde que perdieron el soporte necesita `--include-eol-distros`, que `setup-user.sh` ya pasa.
- **Kinetic y Melodic renderizan por software.** Su Mesa es anterior al controlador `d3d12` que llega a la GPU de Windows, así que `machine.sh` elige `llvmpipe` y dice por qué. Gazebo 7 y 9 funcionan con él, solo que más lentos.
- **Jazzy: no se descubren los nodos.** Suele ser el daemon con otro `ROS_DOMAIN_ID`: `ros2 daemon stop` y repetir.
- **Jazzy: problemas con el láser o ventana en negro.** Gazebo Harmonic renderiza con ogre2 y necesita OpenGL 3.3 o posterior. `llvmpipe` funciona siempre, aunque más lento. Para diagnosticar: `gz sim -v 4 shapes.sdf`.
