FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COMFY_PORT=8188 \
    FILEBROWSER_PORT=8080 \
    COMFY_BRANCH=master \
    WORKSPACE=/workspace

# Systempakete
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip python3-dev \
    git wget curl ca-certificates rsync \
    ffmpeg libsm6 libxext6 libgl1 \
    && rm -rf /var/lib/apt/lists/*

# App-User + Verzeichnisse
RUN useradd -ms /bin/bash app \
    && mkdir -p /workspace /opt/ComfyUI-template \
    && chown -R app:app /workspace /opt/ComfyUI-template /home/app

USER app
WORKDIR /home/app

# Template ComfyUI für erste Initialisierung
RUN git clone --branch ${COMFY_BRANCH} --depth 1 \
    https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI-template

# Base Requirements im Template installieren
RUN python3 -m venv /opt/ComfyUI-template/venv \
    && /opt/ComfyUI-template/venv/bin/pip install --upgrade pip \
    && /opt/ComfyUI-template/venv/bin/pip install -r /opt/ComfyUI-template/requirements.txt

# Ports & Healthcheck
EXPOSE ${COMFY_PORT} ${FILEBROWSER_PORT}
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=5 \
    CMD curl -fsS "http://127.0.0.1:${COMFY_PORT}" || exit 1

VOLUME ["/workspace"]

USER root
# Filebrowser herunterladen und installieren
RUN curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz -o /tmp/fb.tar.gz \
    && tar -xzf /tmp/fb.tar.gz -C /usr/local/bin filebrowser \
    && chmod +x /usr/local/bin/filebrowser \
    && rm /tmp/fb.tar.gz
# Entrypoint
COPY --chown=app:app entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER app

ENTRYPOINT ["/entrypoint.sh"]