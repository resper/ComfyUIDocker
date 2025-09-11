# CUDA Runtime + Ubuntu 22.04 → GPU auf RunPod
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# Nicht-interaktiv
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COMFY_PORT=8188 \
    COMFY_BRANCH=master \
    COMFY_DIR=/opt/ComfyUI \
    WORKSPACE=/workspace

# Systempakete
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip python3-dev \
    git wget curl ca-certificates \
    ffmpeg libsm6 libxext6 libgl1 \
    && rm -rf /var/lib/apt/lists/*

# App-User
RUN useradd -ms /bin/bash app
USER app
WORKDIR /home/app

# Python venv
RUN python3 -m venv /home/app/venv
ENV PATH="/home/app/venv/bin:${PATH}"

# ComfyUI klonen (ohne Modelle)
RUN git clone --branch ${COMFY_BRANCH} --depth 1 https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR}

# Basis-Python-Abhängigkeiten (Core)
WORKDIR ${COMFY_DIR}
RUN pip install --upgrade pip \
    && if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

# Ports & Healthcheck
EXPOSE ${COMFY_PORT}
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${COMFY_PORT}" || exit 1

# Verzeichnisse für Persistenz (werden später gemountet/symlinked)
VOLUME ["/workspace"]

# Entrypoint kopieren
USER root
COPY --chown=app:app entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER app

# Standard-Start
ENTRYPOINT ["/entrypoint.sh"]
