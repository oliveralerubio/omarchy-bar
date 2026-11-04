#!/usr/bin/env bash
# Instala los módulos del bar de Omarchy (enlaces simbólicos) y registra el minero en shell.json.
# Es idempotente: se puede ejecutar las veces que haga falta.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cfg="$HOME/.config/omarchy"
modules_dir="$cfg/bar/modules"
backups_dir="$cfg/bar/backups"
epoch="$(date +%s)"

mkdir -p "$modules_dir" "$backups_dir"

# ---------------------------------------------------------------- 1) módulos QML
shopt -s nullglob
for src in "$repo"/modules/*.qml; do
  name="$(basename "$src")"
  dest="$modules_dir/$name"

  if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
    echo "ok       $name (ya enlazado)"
    continue
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ ! -L "$dest" ] && cmp -s "$src" "$dest"; then
      rm -f "$dest"                       # idéntico al del repo: no hace falta copia
    else
      mv "$dest" "$backups_dir/$name.bak.$epoch"
      echo "respaldo $name -> bar/backups/$name.bak.$epoch"
    fi
  fi

  ln -s "$src" "$dest"
  echo "enlazado $name"
done

# ---------------------------------------------------------------- 2) shell.json (nunca como symlink)
# Omarchy reescribe shell.json de forma atómica; un symlink se rompería en la primera escritura.
shell="$cfg/shell.json"
if [ ! -f "$shell" ]; then
  echo "aviso: no existe $shell; no se registra el minero en el layout." >&2
elif ! command -v jq >/dev/null 2>&1; then
  echo "aviso: falta jq; añade a mano { \"id\": \"miner\", \"type\": \"qml\", \"pixel\": 2 } en .bar.layout.left" >&2
else
  shell="$(readlink -f "$shell")"
  if jq -e 'any(.. | objects; .id? == "miner")' "$shell" >/dev/null; then
    echo "ok       miner ya está en shell.json"
  else
    cp -p "$shell" "$shell.bak.$epoch"
    tmp="$(mktemp "$shell.tmp.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    jq '
      { "id": "miner", "type": "qml", "pixel": 2 } as $m
      | (.bar.layout.left // []) as $l
      | ($l | map((try .id catch null) == "pixelscenes") | index(true)) as $i
      | .bar.layout.left = (if $i == null then $l + [$m] else $l[:$i + 1] + [$m] + $l[$i + 1:] end)
    ' "$shell" > "$tmp"
    jq -e . "$tmp" >/dev/null             # valida antes de reemplazar
    chmod 600 "$tmp"
    mv "$tmp" "$shell"
    trap - EXIT
    echo "añadido miner a shell.json (respaldo: shell.json.bak.$epoch)"
  fi
fi

echo
echo "Listo. Ejecuta: omarchy restart shell"
