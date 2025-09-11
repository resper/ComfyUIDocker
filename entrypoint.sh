#!/usr/bin/env bash
set -euo pipefail

export COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
export WORKSPACE="${WORKSPACE:-/workspace}"
export COMFY_PORT="${COMFY_PORT:-8188}"
export PATH="/home/app/venv/bin:${PATH}"

echo "==> Workspace: ${WORKSPACE}"
mkdir -p "${WORKSPACE}"/{models,output,input,custom_nodes,extensions}

# Symlinks → Persistenz
link_dir () {
  local target="$1"
  local linkpath="$2"
  if [ -e "${linkpath}" ] && [ ! -L "${linkpath}" ]; then
    echo "   > Bestehendes Verzeichnis gefunden: ${linkpath} → nach ${target} verschieben"
    mv "${linkpath}"/* "${target}" 2>/dev/null || true
    rm -rf "${linkpath}"
  fi
  ln -sfn "${target}" "${linkpath}"
}
link_dir "${WORKSPACE}/models"        "${COMFY_DIR}/models"
link_dir "${WORKSPACE}/output"        "${COMFY_DIR}/output"
link_dir "${WORKSPACE}/input"         "${COMFY_DIR}/input"
link_dir "${WORKSPACE}/custom_nodes"  "${COMFY_DIR}/custom_nodes"
link_dir "${WORKSPACE}/extensions"    "${COMFY_DIR}/web/extensions"  # falls Extensions Ordner genutzt wird

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
      # Abhängigkeiten ggf. aktualisieren
      [ -f requirements.txt ] && pip install -r requirements.txt --upgrade || true
    else
      echo "   > Bereits aktuell."
    fi
  else
    echo "   > Lokale Änderungen entdeckt – überspringe Auto-Update."
  fi
fi

# ComfyUI-Manager installieren (falls nicht vorhanden)
echo "==> Stelle ComfyUI-Manager bereit…"
MANAGER_DIR="${COMFY_DIR}/custom_nodes/ComfyUI-Manager"
if [ ! -d "${MANAGER_DIR}/.git" ]; then
  git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager "${MANAGER_DIR}"
fi
# Requirements vom Manager installieren, falls vorhanden
if [ -f "${MANAGER_DIR}/requirements.txt" ]; then
  pip install -r "${MANAGER_DIR}/requirements.txt" || true
fi

# LoRA Manager installieren (falls möglich)
echo "==> Stelle LoRA Manager bereit…"
LORA_DIR="${COMFY_DIR}/custom_nodes/ComfyUI-Lora-Manager"
if [ ! -d "${LORA_DIR}/.git" ]; then
  git clone --depth 1 https://github.com/willmiao/ComfyUI-Lora-Manager "${LORA_DIR}" || true
fi
if [ -f "${LORA_DIR}/requirements.txt" ]; then
  pip install -r "${LORA_DIR}/requirements.txt" || true
fi

# Optionale weitere Pip-Abhängigkeiten (häufige Nodes)
# pip install xformers torch==2.3.1 torchvision --extra-index-url https://download.pytorch.org/whl/cu121

# Start-Flags: --enable-cors-header erleichtert Proxys; --listen für externe Zugriffe
echo "==> Starte ComfyUI auf Port ${COMFY_PORT}…"
cd "${COMFY_DIR}"
exec python main.py \
  --port "${COMFY_PORT}" \
  --listen 0.0.0.0 \
  --auto-launch=False
