# Better ComfyUI

Pre-baked Docker image for running ComfyUI on RunPod. Zero install wait — ComfyUI, PyTorch, and all dependencies are baked into the image so your pod is ready in seconds.

## Deploy on RunPod

[![Regular (CUDA 12.4)](https://img.shields.io/badge/RunPod-Regular%20(CUDA%2012.4)-4B6BDC?style=for-the-badge&logo=docker)](https://runpod.io/console/deploy?template=cndsag8ob0&ref=vfker49t)
[![RTX 5090 (CUDA 12.8)](https://img.shields.io/badge/RunPod-RTX%205090%20(CUDA%2012.8)-1BB91F?style=for-the-badge&logo=docker)](https://runpod.io/console/deploy?template=tm7neqjjww&ref=vfker49t)

| Image | CUDA | PyTorch | For |
|-------|------|---------|-----|
| `madiator2011/better-comfyui:latest` | 12.4 | 2.7.0 | A100, 4090, 3090, etc. |
| `madiator2011/better-comfyui:latest-5090` | 12.8 | 2.7.0 | RTX 5090, 5080, 5070 (Blackwell) |

## What's Included

Pre-installed in the image:
- ComfyUI + Python 3.12 venv
- PyTorch 2.7.0 (stable, pinned)
- ComfyUI-Manager
- ComfyUI-Crystools
- ComfyUI-KJNodes
- FileBrowser, Zasper, SSH

## How It Works

ComfyUI is installed at `/app/ComfyUI` inside the image. Your persistent RunPod volume at `/workspace` holds all your user data:

```
/workspace/
├── models/          → symlinked into ComfyUI/models
├── output/          → symlinked into ComfyUI/output
├── input/           → symlinked into ComfyUI/input
├── custom_nodes/    → symlinked into ComfyUI/custom_nodes
└── comfyui_args.txt → custom launch arguments
```

On startup, symlinks connect your workspace into the pre-baked install. Models, outputs, and custom nodes persist across pod restarts.

## Ports

| Port | Service |
|------|---------|
| 8188 | ComfyUI |
| 8080 | FileBrowser |
| 8048 | Zasper |
| 22   | SSH |

## Custom Launch Arguments

Edit `/workspace/comfyui_args.txt`, one per line:

```
--highvram
--preview-method auto
```

## Adding Custom Nodes

Drop repos into `/workspace/custom_nodes/`:

```bash
cd /workspace/custom_nodes
git clone https://github.com/author/SomeNode.git
```

They'll be symlinked in and their dependencies installed on next startup.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUBLIC_KEY` | — | SSH public key (skips password auth) |
| `UPDATE_COMFYUI` | `false` | Pull latest ComfyUI + nodes on startup |

## Building

```bash
docker buildx bake              # both variants
docker buildx bake regular      # CUDA 12.4
docker buildx bake rtx5090      # CUDA 12.8

TAG=v2.0 docker buildx bake    # custom tag
```

## License

GPLv3
