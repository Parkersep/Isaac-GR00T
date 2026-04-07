# Local Docker Setup

## Building the Image

**Run: Local**
```bash
# Run from the Isaac-GR00T repo root
bash docker/build.sh --profile=gr00t-dev
```

## Creating the Container

The Dockerfile creates a `.venv` at `/workspace/gr00t/.venv`, but bind-mounting the host directory shadows it. Unset `VIRTUAL_ENV` to use system Python.

We remove `--rm` so the container persists after you exit (instead of being auto-deleted). We add `--name gr00t` so you can easily refer to it later. Run this once from the **repo root** (`Isaac-GR00T/`) to create the container:

**Run: Local**
```bash
# Run from the Isaac-GR00T repo root (where pyproject.toml lives)
docker run -it --gpus all \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
    --network host \
    -v $(pwd):/workspace/gr00t \
    -e VIRTUAL_ENV= \
    --name gr00t \
    gr00t-dev bash -c "cd /workspace/gr00t && uv pip install --system --break-system-packages -e . && bash"
```

## Managing the Container

**Run: Local**

| Action | Command |
|--------|---------|
| Start & attach | `docker start -ai gr00t` |
| Stop | `docker stop gr00t` |
| Delete (to recreate from scratch) | `docker rm gr00t` |

Files are shared via the bind mount, so edits on your host show up inside the container and vice versa. Everything installed inside the container persists between stop/start.

## Troubleshooting

### FlashAttention2 Error (Blackwell Architecture)

If using Blackwell architecture and getting a FlashAttention2 import error during finetuning:

**Run: Local Docker**
```bash
uv pip install --python .venv/bin/python flash-attn --no-build-isolation
```
