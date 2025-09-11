#!/usr/bin/env bash
set -euo pipefail

export COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
export WORKSPACE="${WORKSPACE:-/workspace}"
export COMFY_PORT="${COMFY_PORT:-8188}"
export PATH="/home/app/venv/bin:${PATH}"

echo "==> Workspace: ${WORKSPACE}"
# Zielverzeichnisse für Persistenz sicherstellen
mkdir -p "${WORKSPACE}"/{models,output,input,custom_nodes,extensions}

# Hilfsfunktion: robustes Linken inkl. Eltern-Ordner
safe_link_dir () {
  local target="$1"     # z. B. /workspace/models
  local linkpath="$2"   # z. B. /opt/ComfyUI/models

  # Elternordner des Linkpfads anlegen (z. B. /opt/ComfyUI/web)
  mkdir -p "$(dirname "${linkpath}")"

  # Falls am Linkpfad ein echtes Verzeichnis/Datei liegt, Inhalte in target migrieren
  if [ -e "${linkpath}" ] && [ ! -L "${linkpath}" ]; then
    echo "   > Bestehendes Verzeichnis gefunden: ${linkpath} → nach ${target} verschieben"
    mkdir -p "${target}"
    # Inhalte (falls vorhanden) rüberziehen; Fehler ignorieren, wenn leer
    mv "${linkpath}"/* "${target}" 2>/dev/null || true
    rm -rf "${linkpath}"
  fi
  ln -sfn "${target}" "${linkpath}"
}

# Core-Ordner verlinken (immer sicher)
safe_link_dir "${WORKSPACE}/models"        "${COMFY_DIR}/models"
safe_link_dir "${WORKSPACE}/output"        "${COMFY_DIR}/output"
safe_link_dir "${WORKSPACE}/input"         "${COMFY_DIR}/input"
safe_link_dir "${WORKSPACE}/custom_nodes"  "${COMFY_DIR}/custom_nodes"

# Frontend-Extensions NUR linken, wenn es in dieser ComfyUI-Version ein web/ gibt
if [ -d "${COMFY_DIR}/web" ] || [ ! -e "${COMFY_DIR}/web" ]; then
  # web/ ggf. anlegen, damit der Symlink erstellt werden kann
  mkdir -p "${COMFY_DIR}/web"
  safe_link_dir "${WORKSPACE}/extensions"    "${COMFY_DIR}/web/extensions"
else
  echo "   > Hinweis: Kein 'web/'-Ordner gefunden – überspringe Extensions-Link."
fi

# Auf neueste ComfyUI-Version aktualisieren (wenn sauberer Git-Tree)
echo "==> Prüfe auf neue ComfyUI-Version…"
cd "${COMFY_DIR}"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git diff --quiet && git diff --cached --quiet; then
    git fetch --depth=1 origin "${COMFY_BRANCH:-master}" || true
    CURRENT=$(git rev-parse HEAD)
    LATEST=$(git rev-parse "origin/${COMFY_BRANCH:-master}")
    if [ "${CURRENT}" != "${LATEST}" ]; then
      echo "   > Update gefunden: ${CURRENT:0:7} → ${LATEST:0:7}"
      git reset --hard "origin/${COMFY_BRANCH:-master}"
      [ -f requirements.txt ] && pip install -r requirements.txt --upgrade || true
    else
      echo "   > Bereits aktuell."
    fi
  else
    echo "   > Lokale Änderungen entdeckt – überspringe Auto-Update."
  fi
fi

# ComfyUI-Manager
echo "==> Stelle ComfyUI-Manager bereit…"
MANAGER_DIR="${COMFY_DIR}/custom_nodes/ComfyUI-Manager"
if [ ! -d "${MANAGER_DIR}/.git" ]; then
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager "${MANAGER_DIR}" || true
fi
[ -f "${MANAGER_DIR}/requirements.txt" ] && pip install -r "${MANAGER_DIR}/requirements.txt" || true

# LoRA Manager
echo "==> Stelle LoRA Manager bereit…"
LORA_DIR="${COMFY_DIR}/custom_nodes/ComfyUI-Lora-Manager"
if [ ! -d "${LORA_DIR}/.git" ]; then
  git clone --depth 1 https://github.com/willmiao/ComfyUI-Lora-Manager "${LORA_DIR}" || true
fi
[ -f "${LORA_DIR}/requirements.txt" ] && pip install -r "${LORA_DIR}/requirements.txt" || true

# Start
echo "==> Starte ComfyUI auf Port ${COMFY_PORT}…"
cd "${COMFY_DIR}"
exec python main.py \
  --port "${COMFY_PORT}" \
  --listen 0.0.0.0 \
  --auto-launch=False
