# ROS en Linux con Distrobox

[English](README.md) · **Español**

En Linux, cada entorno es una caja de Distrobox: un contenedor de Podman con su propio Ubuntu que se usa como el propio sistema, con una terminal normal, las ventanas de Gazebo y rviz en el escritorio y la GPU del equipo. Se instala con los mismos scripts que las distros de WSL.

| Caja | Imagen | Home de la caja |
|---|---|---|
| `ros-kinetic` | `ubuntu:16.04` | `~/distrobox/ros-kinetic` |
| `ros-melodic` | `ubuntu:18.04` | `~/distrobox/ros-melodic` |
| `ros-noetic` | `ubuntu:20.04` | `~/distrobox/ros-noetic` |
| `ros-jazzy` | `ubuntu:24.04` | `~/distrobox/ros-jazzy` |

Cada caja tiene su propia home, así que `.bashrc`, el workspace, `~/.ros` y lo que instale `pip` no se mezclan. La home real sigue visible dentro de la caja en la misma ruta.

## Instalación

Necesita `sudo apt install distrobox podman` y, para usar NVIDIA, su controlador ya instalado (`nvidia-smi` funciona). Ejecútalo desde una terminal del escritorio, no por ssh, porque `machine.sh` necesita pantalla para probar la GPU:

```bash
curl -fsSL https://raw.githubusercontent.com/Huxsby/ros-envs/v1.0.2/install.sh | bash -s -- distrobox jazzy
```

### Qué significa el comando

| Parte | Significado |
|---|---|
| `curl` | Descarga el instalador y lo escribe en su salida |
| `-f` | Falla si hay un error HTTP, en vez de pasar la página de error a `bash` |
| `-s` `-S` | Oculta la barra de progreso, pero sigue mostrando los errores |
| `-L` | Sigue las redirecciones |
| `v1.0.2` en la URL | La versión que se descarga. También decide la versión que se instala |
| `\| bash -s` | Ejecuta lo que escribe `curl`, leyendo el script de la entrada estándar |
| `--` | Termina las opciones de `bash`: lo que sigue es para el script |
| `distrobox jazzy` | Orden y entorno: `kinetic`, `melodic`, `noetic` o `jazzy` |

Para leer antes el script, o para usar opciones, trabaja desde un clon:

```bash
git clone https://github.com/Huxsby/ros-envs.git && cd ros-envs
bash install.sh distrobox jazzy --link ~/mi-proyecto
```

### Opciones

| Opción | Obligatoria | Significado |
|---|---|---|
| `kinetic`, `melodic`, `noetic`, `jazzy` | sí | Entorno que se instala. Crea la caja `ros-<entorno>`, como `ros-jazzy` |
| `--link DIR` | no | Enlaza esa carpeta del anfitrión en `~/projects/<nombre>` dentro de la caja y ejecuta `make build` si tiene Makefile |
| `DBX_FLAGS` | no | Variable de entorno con opciones extra para podman: `DBX_FLAGS="--memory 4g" bash install.sh distrobox jazzy` |
| `DISTROBOX_HOMES` | no | Variable de entorno con la carpeta de las homes de las cajas. Por defecto, `~/distrobox` |
| `ROS_ENVS_REF` | no | Variable de entorno con la etiqueta, rama o commit que se descarga cuando no se ejecuta desde un clon |

### Qué hace el script

1. Crea la caja con `--home ~/distrobox/<caja>`, y con `--nvidia` si el anfitrión tiene el controlador.
2. Genera dentro de la caja el idioma del anfitrión.
3. Ejecuta `setup-root.sh` con sudo. En una caja se salta lo propio de WSL: el usuario y la zona horaria vienen del anfitrión.
4. Ejecuta `setup-user.sh`.
5. Con `--link`, enlaza el proyecto y lo compila.

Si se vuelve a ejecutar, reutiliza la caja y repite la instalación sin romper nada. Después entra en la caja y compruébala:

```bash
distrobox enter ros-jazzy
git clone https://github.com/Huxsby/ros-envs.git
bash ros-envs/ros/jazzy/smoke-test.sh    # debe acabar en SMOKE TEST OK
```

## De WSL a Distrobox

| WSL (PowerShell) | Distrobox (terminal de Linux) |
|---|---|
| `wsl -d ROS-Noetic` | `distrobox enter ros-noetic` |
| `wsl -l -v` | `distrobox list` |
| `wsl --terminate ROS-Noetic` | `distrobox stop ros-noetic` |
| `wsl --unregister ROS-Noetic` | `distrobox rm ros-noetic`, y borrar `~/distrobox/ros-noetic` |
| Una distro nueva a partir de otra | `distrobox create --clone ros-noetic --name ros-noetic-prueba` |
| Abrir algo desde el menú de Windows | `distrobox-export --app rviz`, dentro de la caja |

## Rapidez y espacio

Una caja no es una máquina virtual: es un proceso del mismo kernel, con los archivos en el mismo disco y las ventanas en el mismo escritorio. Entrar en una caja arrancada tarda menos de 0,1 s.

| Qué | Tamaño |
|---|---|
| Caja `ros-noetic` instalada | 6 GB |
| Caja `ros-jazzy` instalada | 6 GB |
| Home de cada caja | 4-11 MB |

Instalar una caja llevó 13-15 minutos en un equipo de 2 núcleos, con las descargas incluidas. Estos tamaños se midieron con LaTeX, unos 300 MB, que ya no se instala.

- En Noetic, unos 0,9 GB son un compilador de Fortran (`flang-18`) que entra como paquete recomendado y que nada usa. Para quitarlo: `sudo apt purge flang-18 libflang-18-dev && sudo apt autoremove`.
- `--clone` copia la caja entera. Para tener varias parecidas, ejecuta `podman container commit ros-noetic ros-noetic-base` y crea las demás con `--image ros-noetic-base`, para que compartan capas.
- Para liberar el espacio: `distrobox rm`, `podman image prune` y `rm -rf ~/distrobox/<caja>`.

## GPU

Con gráficos híbridos (Intel + NVIDIA en modo *on-demand*), `ros/machine.sh` prueba NVIDIA con PRIME render offload, después la GPU de Mesa y por último el render por software. Guarda el resultado en la home de la caja. Si cambia el controlador de NVIDIA en el anfitrión, la caja usa el nuevo; vuelve a ejecutar `--save`.

## Editor

1. **Editor del sistema** sobre la carpeta del anfitrión, compilando y lanzando en una terminal de la caja. Es lo más sencillo, pero el autocompletado no ve `/opt/ros`.
2. **Editor dentro de la caja**, que se abre con el ROS de esa caja cargado: instálalo en la caja y ejecuta `distrobox-export --app code`. Ocupa unos 400 MB por caja.

Las extensiones *Remote - WSL* y *Dev Containers* solo funcionan con el VS Code de Microsoft.

## Diferencias con WSL

- **Red y procesos compartidos.** Dos simulaciones de Noetic en dos cajas chocarían en el puerto 11311, igual que en dos distros de WSL, y matar `gzserver` en una caja mata los de las demás.
- **Sin systemd dentro.** Nada de estos entornos lo necesita.
- **`sudo` sin contraseña dentro de la caja**, porque es un contenedor sin root. Lo que se rompa dentro no toca el sistema.
- **El idioma viene del anfitrión.** La caja hereda `LANG` y `create.sh` lo genera con `locale.sh`. Sin eso, `perl` avisa en cada orden y algunos paquetes, como TeX Live, no se instalan.
- **Cortafuegos.** Los cortafuegos como ufw cortan el multicast con el que Gazebo Harmonic encuentra sus propios topics, así que Jazzy fija `GZ_IP=127.0.0.1`.
- **`--pids-limit`.** Distrobox crea las cajas con `--pids-limit=-1`, y podman 4.9 con kernels recientes lo convierte en un límite de 1 proceso (`Cannot fork`). `create.sh` pone `--pids-limit=100000`; recrea con él cualquier caja hecha a mano que falle así.
