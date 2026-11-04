# omarchy-bar

Configuración y módulos personalizados para la barra superior (Quickshell / QML) de [Omarchy](https://omarchy.org/).

## Módulos

- **`miner.qml`**: Minero en pixel art reactivo al estado de T3 Code.
  - Cuando hay hilos trabajando (`preparing`/`starting`/`running`/`waiting`), pica una veta de cristal con su pico y su linterna encendida.
  - Cuando todos los hilos terminan, bosteza y se acuesta a dormir en la vagoneta con animación de "zzz".
- **`starfield.qml`**: Fondo de estrellas pixeladas con paralaje y estrellas fugaces.
- **`pixelscenes.qml`**: Escenas rotativas en pixel art (Kirby, Link, Pikachu).

## Instalación

```bash
./scripts/install.sh
omarchy restart shell
```

Qué hace `install.sh` (es idempotente):

1. Enlaza cada `modules/*.qml` en `~/.config/omarchy/bar/modules/`. Si ya existe un archivo distinto,
   lo mueve antes a `~/.config/omarchy/bar/backups/<nombre>.bak.<epoch>`.
2. Con `jq`, añade `{ "id": "miner", "type": "qml", "pixel": 2 }` a `.bar.layout.left` de
   `~/.config/omarchy/shell.json`, justo después de `pixelscenes` (o al final si no está), solo si
   `miner` no existe ya. Antes guarda `shell.json.bak.<epoch>` y escribe de forma atómica (archivo
   temporal + `mv`), conservando modo 600.

`shell.json` no se enlaza: Omarchy lo reescribe de forma atómica (archivo nuevo + renombrar), lo que
reemplazaría el symlink por un archivo normal y se perdería el vínculo con el repo.

## Ajustes del minero (en su entrada de `shell.json`)

| Ajuste | Por defecto | Qué hace |
| --- | --- | --- |
| `pixel` | `2` | Tamaño del píxel de arte (se recorta al alto de la barra). |
| `pollSeconds` | `4` | Cada cuántos segundos consulta T3 Code. |
| `staleMinutes` | `20` | Un hilo activo sin actualizarse en N minutos se considera zombi y no cuenta. |

Detección: consulta de solo lectura a `~/.t3/userdata/statev2.sqlite` con `sqlite3`. Cuenta los hilos
distintos en `preparing`/`starting`/`running`/`waiting` y el tooltip lista sus títulos. Si falta
`sqlite3` o la base, cuenta 0 y el minero duerme. Click sobre el módulo = consultar de nuevo ahora.
La lógica de cuándo trabaja o duerme está en `decideState` dentro de `modules/miner.qml`.

Para quitarlo, borra la entrada `miner` de `shell.json` y ejecuta `omarchy restart shell`.
