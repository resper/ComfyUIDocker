# ComfyUI RunPod Docker - Persistent Edition

Ein vollständig persistentes Docker Image für ComfyUI, optimiert für RunPod mit dauerhafter Speicherung von Custom Nodes, Workflows und allen Abhängigkeiten.

## 🎯 Features

- ✅ **Vollständige Persistenz**: ComfyUI, venv, Custom Nodes und alle Dependencies überleben Neustarts
- ✅ **Automatische Updates**: Optional aktivierbare Updates für ComfyUI (deaktivierbar)
- ✅ **Custom Nodes Support**: Alle nachträglich installierten Nodes und deren Dependencies bleiben erhalten
- ✅ **Workflow-Speicherung**: Workflows werden dauerhaft im Volume gespeichert
- ✅ **Backup-System**: Automatische Backups vor Updates
- ✅ **ComfyUI-Manager**: Vorinstalliert für einfache Node-Verwaltung
- ✅ **Optimiert für RunPod**: Speziell für Network Volumes konfiguriert

## 📁 Verzeichnisstruktur

Nach dem ersten Start wird folgende Struktur im `/workspace` Volume erstellt:

```
/workspace/
├── ComfyUI/              # Komplette ComfyUI Installation
│   ├── custom_nodes/     # Custom Nodes
│   ├── models/           # AI Modelle
│   ├── input/            # Input Dateien
│   ├── output/           # Generierte Bilder
│   └── workflows/        # Gespeicherte Workflows (symlink)
├── venv/                 # Python Virtual Environment (persistent!)
├── storage/
│   ├── config/          # Konfigurationsdateien
│   ├── workflows/       # Workflow-Speicher
│   └── models/          # Alternative Model-Location
└── backups/             # Automatische Backups
```

## 🚀 Deployment auf RunPod

### 1. Docker Image bauen und pushen

Das Image wird automatisch über GitHub Actions gebaut. Nach einem Push auf `main`:

```bash
# Image ist verfügbar als:
dockerhub-username/comfyui-runpod:latest
```

### 2. RunPod Template erstellen

1. Gehe zu RunPod > Templates > New Template
2. Konfiguriere:

```yaml
Container Image: dein-dockerhub-username/comfyui-runpod:latest
Container Disk: 10 GB (nur für temporäre Daten)
Volume Disk: 100+ GB (für Models und persistente Daten)
Volume Mount Path: /workspace
Expose HTTP Ports: 8188
```

3. Environment Variables (optional):

```bash
AUTO_UPDATE=true        # ComfyUI Auto-Updates (true/false)
EXTRA_ARGS=--highvram   # Zusätzliche ComfyUI Parameter
```

### 3. Pod starten

1. Erstelle einen Pod mit dem Template
2. Warte ca. 2-3 Minuten für die Initialisierung (nur beim ersten Start)
3. Öffne die ComfyUI Web-UI über den RunPod Proxy Link

## 🛠️ Lokales Testen

```bash
# Mit docker-compose
docker-compose up -d

# Oder direkt mit Docker
docker build -t comfyui-runpod .
docker run -d \
  --gpus all \
  -p 8188:8188 \
  -v $(pwd)/workspace:/workspace \
  comfyui-runpod
```

## 📦 Custom Nodes Installation

### Option 1: Über ComfyUI-Manager (Empfohlen)
1. Öffne ComfyUI Web-UI
2. Klicke auf "Manager" Button
3. Installiere Nodes über die GUI
4. **Nodes und Dependencies bleiben nach Neustart erhalten!**

### Option 2: Manuell via Terminal
```bash
# In RunPod Terminal
cd /workspace/ComfyUI/custom_nodes
git clone https://github.com/user/custom-node-repo
cd custom-node-repo
/workspace/venv/bin/pip install -r requirements.txt
```

## 🔧 Troubleshooting

### "Import Failed" bei Custom Nodes
Sollte mit dieser Version nicht mehr auftreten. Falls doch:

```bash
# Dependencies manuell neu installieren
cd /workspace/ComfyUI
for req in custom_nodes/*/requirements.txt; do
    /workspace/venv/bin/pip install -r "$req" || true
done
```

### Workflows werden nicht gespeichert
Workflows werden jetzt in `/workspace/storage/workflows/` gespeichert. 
Check: `ls -la /workspace/storage/workflows/`

### Performance-Optimierung
Füge Extra-Argumente hinzu:

```bash
# In RunPod Environment Variables:
EXTRA_ARGS=--highvram --use-pytorch-cross-attention
```

## 🔄 Updates

### ComfyUI Updates
- **Automatisch**: Setze `AUTO_UPDATE=true` (Standard)
- **Manuell**: 
  ```bash
  cd /workspace/ComfyUI
  git pull
  /workspace/venv/bin/pip install -r requirements.txt --upgrade
  ```

### Docker Image Update
1. Stoppe den Pod
2. Wechsle zur neuen Image-Version im Template
3. Starte einen neuen Pod (Workspace bleibt erhalten!)

## 📝 Wichtige Hinweise

1. **Erster Start**: Die initiale Einrichtung dauert 2-3 Minuten
2. **Workspace Volume**: Mindestens 50GB empfohlen (für Modelle)
3. **Backups**: Werden automatisch in `/workspace/backups/` erstellt
4. **GPU**: CUDA 12.1 kompatible GPU erforderlich

## 🐛 Known Issues & Fixes

| Problem | Lösung |
|---------|--------|
| Module nicht gefunden | Dependencies neu installieren (siehe Troubleshooting) |
| Keine GPU erkannt | Pod neu starten, GPU-Typ prüfen |
| Out of Memory | `EXTRA_ARGS=--lowvram` setzen |
| Langsame Generation | `EXTRA_ARGS=--highvram` verwenden |

## 📊 Monitoring

```bash
# ComfyUI Logs
docker logs -f comfyui-persistent

# Speichernutzung prüfen
df -h /workspace

# Python Packages auflisten
/workspace/venv/bin/pip list

# Custom Nodes anzeigen
ls -la /workspace/ComfyUI/custom_nodes/
```

## 🤝 Support

Bei Problemen:
1. Prüfe die Logs: `docker logs comfyui-persistent`
2. Stelle sicher, dass `/workspace` korrekt gemountet ist
3. Verifiziere GPU-Zugriff: `nvidia-smi`

## 📜 Lizenz

Dieses Projekt nutzt ComfyUI (GPL-3.0) und verschiedene Custom Nodes mit eigenen Lizenzen.