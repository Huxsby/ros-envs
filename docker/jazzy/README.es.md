# ROS 2 Jazzy en el navegador, con Docker

[English](README.md) · **Español**

El entorno de Jazzy (Ubuntu 24.04, Gazebo Harmonic) en un contenedor de un servidor, manejado desde el navegador. Sirve para un dispositivo sin instalación local, como una tableta.

| Servicio | Puerto en el contenedor | Uso |
|---|---|---|
| code-server | 8443 | VS Code en el navegador y terminal |
| noVNC | 6080 | Escritorio: Gazebo, rviz2, rqt |

La carpeta home es un volumen: los repositorios, `ros2_ws`, la sesión de `gh` y las extensiones sobreviven a una imagen nueva. Lo que instale `apt` dentro del contenedor no; se añade al `Dockerfile`.

## Arrancarlo

```bash
git clone https://github.com/Huxsby/ros-envs.git && cd ros-envs/docker/jazzy
cp .env.example .env    # y define CODE_PASSWORD en .env
docker compose up -d
```

| Comando | Qué hace |
|---|---|
| `cp .env.example .env` | Crea el fichero con tus ajustes. Git lo ignora, así que las contraseñas no se suben |
| `docker compose up -d` | Descarga la imagen y arranca el contenedor en segundo plano (`-d`) |
| `docker compose logs -f` | Sigue su salida, para ver por qué no arranca |
| `docker compose down` | Para y elimina el contenedor. El volumen con la home se queda; `down -v` también lo borra |

`CODE_PASSWORD` es obligatoria: sin ella el contenedor no arranca, en vez de dejar code-server abierto a cualquiera. Los dos puertos se publican solo en `127.0.0.1` del servidor.

La imagen es `ghcr.io/huxsby/ros-envs-jazzy`, construida por [`image.yml`](../../.github/workflows/image.yml). Para construirla en local, desde esta carpeta: `docker build -f Dockerfile -t ghcr.io/huxsby/ros-envs-jazzy:latest ..` (el contexto es `docker/`, que guarda en `common/` lo que comparte con Noetic) y `docker compose up -d --pull never`.

| Variable | Por defecto | Significado |
|---|---|---|
| `CODE_PASSWORD` | obligatoria | Contraseña de code-server |
| `VNC_PASSWORD` | vacía | Segunda contraseña para noVNC; solo cuentan 8 caracteres |
| `VNC_GEOMETRY` | `1600x1000` | Tamaño del escritorio |
| `TZ` | `Etc/UTC` | Zona horaria |

Para usar otro nombre de usuario, cambia a la vez `CONTAINER_USER` y el destino del volumen en `docker-compose.yml`, porque deben coincidir.

## Conectarse

Lo más sencillo es un túnel SSH:

```bash
ssh -N -L 8443:localhost:8443 -L 6080:localhost:6080 <usuario>@<servidor>
```

`-L local:host:remoto` reenvía un puerto de tu equipo a uno del servidor, y `-N` no abre una shell remota. Sigue en marcha mientras se usa el túnel.

- VS Code: `http://localhost:8443`
- Escritorio: `http://localhost:6080/vnc.html?autoconnect=1&resize=remote`

Para llegar desde cualquier red, pon un proxy inverso con HTTPS solo delante de code-server y usa una `CODE_PASSWORD` larga y aleatoria. noVNC no necesita dominio propio: se llega por el proxy de puertos de code-server, detrás de su login, en `/proxy/6080/vnc.html?path=proxy/6080/websockify&autoconnect=1&resize=remote`. No confíes solo en `VNC_PASSWORD`, porque 8 caracteres no bastan para exponerlo.

## Primera vez dentro

```bash
git clone https://github.com/Huxsby/ros-envs.git ~/projects/ros-envs
bash ~/projects/ros-envs/ros/jazzy/smoke-test.sh    # debe acabar en SMOKE TEST OK
```

## Uso diario

- **Terminal.** La `bash` de VS Code carga ROS, `ros2_ws` y `DISPLAY=:1`, así que `ros2 launch` funciona sin `source` y las ventanas salen en el escritorio de noVNC.
- **Procesos largos.** Ejecútalos en `tmux`: una terminal del navegador puede cortarse si el dispositivo se bloquea o se cierra la pestaña.
- **Sin GPU.** Todo se renderiza por CPU (llvmpipe). En Gazebo Harmonic eso incluye el láser habitual, `gpu_lidar`, así que la simulación en sí va más lenta que con GPU, no solo su ventana. Lánzala sin interfaz (`gz sim -s`) cuando no necesites verla.
- **Vídeos.** `ffmpeg -f x11grab -video_size 1600x1000 -i :1 video.mp4`, dentro del contenedor.
- **Trabajos de compilación.** `MAKEFLAGS` vale `-j2` en la `bash` del contenedor, porque un `g++` de ROS ocupa 1-2 GB; exporta otro valor para cambiarlo.
- **Límites.** 6 GB de memoria y 3,5 CPU, definidos en `docker-compose.yml`.
