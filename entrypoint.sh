#!/usr/bin/env bash
set -euo pipefail

export WORKSPACE="${WORKSPACE:-/workspace}"
export COMFY_PORT="${COMFY_PORT:-8188}"
export COMFY_DIR="${WORKSPACE}/ComfyUI"
export VENV_DIR="${WORKSPACE}/venv"

echo "==================================="
echo "ComfyUI RunPod Persistent Container"
echo "==================================="
echo "Workspace: ${WORKSPACE}"
echo "ComfyUI:   ${COMFY_DIR}"

# Workspace-Struktur sicherstellen
mkdir -p "${WORKSPACE}"/{storage,backups}

# 1. ComfyUI initialisieren oder aktualisieren
if [ ! -d "${COMFY_DIR}/.git" ]; then
    echo "==> Erste Initialisierung: Kopiere ComfyUI nach ${COMFY_DIR}..."
    cp -r /opt/ComfyUI-template "${COMFY_DIR}"
    
    # Venv auch kopieren für schnelleren Start
    if [ ! -d "${VENV_DIR}" ]; then
        echo "==> Kopiere Python venv..."
        cp -r /opt/ComfyUI-template/venv "${VENV_DIR}"
    fi
else
    echo "==> ComfyUI bereits vorhanden, prüfe auf Updates..."
    cd "${COMFY_DIR}"
    
    # Backup wichtiger Dateien
    if [ -f "${COMFY_DIR}/ui_settings.json" ]; then
        cp "${COMFY_DIR}/ui_settings.json" "${WORKSPACE}/backups/ui_settings.json.bak" 2>/dev/null || true
    fi
    
    # Git Update (optional, kann deaktiviert werden)
    if [ "${AUTO_UPDATE:-true}" = "true" ]; then
        if git diff --quiet && git diff --cached --quiet; then
            echo "   > Prüfe auf Updates..."
            git fetch --depth=1 origin "${COMFY_BRANCH:-master}" || true
            CURRENT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
            LATEST=$(git rev-parse "origin/${COMFY_BRANCH:-master}" 2>/dev/null || echo "unknown")
            
            if [ "${CURRENT}" != "${LATEST}" ] && [ "${CURRENT}" != "unknown" ]; then
                echo "   > Update verfügbar: ${CURRENT:0:7} → ${LATEST:0:7}"
                echo "   > Erstelle Backup..."
                tar -czf "${WORKSPACE}/backups/comfyui-backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
                    --exclude="${COMFY_DIR}/models" \
                    --exclude="${COMFY_DIR}/output" \
                    --exclude="${COMFY_DIR}/input" \
                    "${COMFY_DIR}" 2>/dev/null || true
                
                git reset --hard "origin/${COMFY_BRANCH:-master}"
                echo "   > Update abgeschlossen"
            else
                echo "   > Bereits aktuell"
            fi
        else
            echo "   > Lokale Änderungen gefunden - überspringe Auto-Update"
        fi
    fi
fi

# 2. Python venv initialisieren/aktualisieren
if [ ! -d "${VENV_DIR}" ]; then
    echo "==> Erstelle Python Virtual Environment..."
    python3 -m venv "${VENV_DIR}"
fi

# Aktiviere venv
export PATH="${VENV_DIR}/bin:${PATH}"
export VIRTUAL_ENV="${VENV_DIR}"

# 3. Core-Dependencies aktualisieren
echo "==> Aktualisiere Python-Pakete..."
pip install --upgrade pip setuptools wheel

# ComfyUI Requirements
if [ -f "${COMFY_DIR}/requirements.txt" ]; then
    pip install -r "${COMFY_DIR}/requirements.txt" --upgrade
fi

# 4. ComfyUI-Manager installieren/aktualisieren
echo "==> Installiere/Aktualisiere ComfyUI-Manager..."
MANAGER_DIR="${COMFY_DIR}/custom_nodes/ComfyUI-Manager"
if [ ! -d "${MANAGER_DIR}/.git" ]; then
    git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager "${MANAGER_DIR}" || true
else
    cd "${MANAGER_DIR}"
    git pull || true
fi
[ -f "${MANAGER_DIR}/requirements.txt" ] && pip install -r "${MANAGER_DIR}/requirements.txt" || true

# 5. Custom Nodes Dependencies neu installieren
echo "==> Installiere Dependencies für Custom Nodes..."
for req_file in "${COMFY_DIR}"/custom_nodes/*/requirements.txt; do
    if [ -f "$req_file" ]; then
        node_name=$(basename $(dirname "$req_file"))
        echo "   > Installiere Dependencies für: ${node_name}"
        pip install -r "$req_file" 2>/dev/null || echo "     ! Fehler bei ${node_name} - wird übersprungen"
    fi
done

# 6. Berechtigungen sicherstellen
echo "==> Stelle Berechtigungen sicher..."
# Nur für Verzeichnisse die der User besitzen sollte
for dir in "${COMFY_DIR}/models" "${COMFY_DIR}/output" "${COMFY_DIR}/input" \
           "${COMFY_DIR}/custom_nodes" "${COMFY_DIR}/web/extensions" \
           "${WORKSPACE}/storage" "${WORKSPACE}/backups"; do
    if [ -d "$dir" ]; then
        chmod -R u+rw "$dir" 2>/dev/null || true
    fi
done

# 7. Persistente Konfiguration
echo "==> Konfiguriere persistente Einstellungen..."
mkdir -p "${WORKSPACE}/storage/config"

# Link für user-spezifische Configs
for config in "ui_settings.json" "comfy.settings.json"; do
    if [ -f "${WORKSPACE}/storage/config/${config}" ] && [ ! -f "${COMFY_DIR}/${config}" ]; then
        ln -sf "${WORKSPACE}/storage/config/${config}" "${COMFY_DIR}/${config}"
    elif [ -f "${COMFY_DIR}/${config}" ] && [ ! -f "${WORKSPACE}/storage/config/${config}" ]; then
        cp "${COMFY_DIR}/${config}" "${WORKSPACE}/storage/config/${config}"
        ln -sf "${WORKSPACE}/storage/config/${config}" "${COMFY_DIR}/${config}"
    fi
done

# 8. Workflows-Verzeichnis
echo "==> Konfiguriere Workflows-Speicher..."
mkdir -p "${WORKSPACE}/storage/workflows"
if [ ! -L "${COMFY_DIR}/workflows" ]; then
    if [ -d "${COMFY_DIR}/workflows" ]; then
        # Bestehende Workflows sichern
        cp -r "${COMFY_DIR}/workflows"/* "${WORKSPACE}/storage/workflows/" 2>/dev/null || true
        rm -rf "${COMFY_DIR}/workflows"
    fi
    ln -sfn "${WORKSPACE}/storage/workflows" "${COMFY_DIR}/workflows"
fi

# 9. Extra Modell-Pfade Konfiguration
cat > "${COMFY_DIR}/extra_model_paths.yaml" << EOF
# Zusätzliche Modell-Pfade für ComfyUI
# Automatisch generiert - Änderungen werden überschrieben

comfyui:
    base_path: ${WORKSPACE}/storage/
    
    checkpoints: models/checkpoints/
    clip: models/clip/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    embeddings: models/embeddings/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
EOF

# 10. Startup-Info
echo "==================================="
echo "Startup-Zusammenfassung:"
echo "-----------------------------------"
echo "ComfyUI:    ${COMFY_DIR}"
echo "Venv:       ${VENV_DIR}"
echo "Workflows:  ${WORKSPACE}/storage/workflows"
echo "Models:     ${WORKSPACE}/storage/models"
echo "Backups:    ${WORKSPACE}/backups"
echo "==================================="

# Custom Nodes auflisten
if [ -d "${COMFY_DIR}/custom_nodes" ]; then
    echo "Installierte Custom Nodes:"
    for node in "${COMFY_DIR}"/custom_nodes/*/; do
        if [ -d "$node" ]; then
            echo "  - $(basename "$node")"
        fi
    done
    echo "==================================="
fi

# 11. ComfyUI starten
echo "==> Starte ComfyUI auf Port ${COMFY_PORT}..."
cd "${COMFY_DIR}"

# Mit erweiterten Optionen für bessere Performance
exec python main.py \
    --port "${COMFY_PORT}" \
    --listen 0.0.0.0 \
    --disable-auto-launch \
    ${EXTRA_ARGS:-}