# Contribuir

[English](CONTRIBUTING.md) · **Español**

Gracias por ayudar. Las issues y los pull requests son bienvenidos en inglés o en castellano.

## Antes de empezar

- **Una pregunta o una idea:** abre una [discusión](https://github.com/Huxsby/ros-envs/discussions).
- **Algo no funciona:** abre una issue con la plantilla de error. Incluye el anfitrión (WSL 2, Distrobox o Docker), el entorno (Noetic o Jazzy), el comando que ejecutaste y el final de su salida, y el resultado de `bash ros/machine.sh`.
- **Un cambio grande**, como una distro de ROS o un anfitrión nuevos: abre antes una issue, para acordar el enfoque antes de que le dediques tiempo.

Las issues con la etiqueta [`good first issue`](https://github.com/Huxsby/ros-envs/labels/good%20first%20issue) son pequeñas e independientes.

## Qué tiene cabida aquí

Solo lo que sirve a cualquier proyecto de ROS: un entorno, su instalador, la detección del equipo o una prueba de humo. Los paquetes y ajustes propios de un proyecto van en ese proyecto. Mantenlo sencillo: antes de añadir una opción, comprueba que hace falta y que se puede probar.

## Hacer un cambio

1. Haz un fork del repositorio y crea una rama.
2. Haz el cambio siguiendo el estilo del código de alrededor:
   - Bash con `set -euo pipefail` en los instaladores.
   - Los scripts de instalación deben poder ejecutarse dos veces sin romper nada.
   - Lo común a Noetic y Jazzy va en `ros/`. Lo de un anfitrión, en `wsl/`, `distrobox/` o `docker/`.
   - En Noetic, Python 3.8: nada de sintaxis posterior.
   - Código, comentarios y mensajes en inglés.
3. Si cambias la documentación, cambia los dos idiomas: cada `README.md` tiene un `README.es.md` que debe decir lo mismo. Si no escribes castellano, dilo en el pull request y se traducirá.
4. Compruébalo:
   - `bash -n` y `shellcheck -S warning -e SC1090,SC1091` en cada script que hayas tocado.
   - Si cambiaste `ros/`, ejecuta la prueba de humo de ese entorno: `bash ros/<distro>/smoke-test.sh` debe acabar en `SMOKE TEST OK`.
5. Abre un pull request que diga qué cambió y por qué, y cómo lo probaste. El CI instala desde cero los entornos afectados; los cambios solo de documentación se saltan esos jobs.

No subas nunca secretos: `.env` está ignorado y `.env.example` solo tiene valores de ejemplo. El CI ejecuta `gitleaks` en cada push.

## Versiones

Ver *Publicar una versión* en el [README](README.es.md#publicar-una-versión). Cada versión añade su apartado a [CHANGELOG.md](CHANGELOG.md).
