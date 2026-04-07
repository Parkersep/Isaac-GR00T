# Vast.ai Deployment

## Option A: Push Custom Docker Image (slower first time but faster setup on instance)

**Run: Local**
```bash
docker login
docker tag gr00t-dev par4ker/gr00t-dev:latest
docker push par4ker/gr00t-dev:latest
```

Then use `--image par4ker/gr00t-dev:latest` when creating the instance instead of the NVIDIA base image.

---

## Quick Setup (automated) - Skip to step 6 after running script and Instance is loaded

One command to create an instance, wait for it, and set everything up:

**Run: Local**
```bash
bash scripts/vast_ai_setup.sh --offer-id <OFFER_ID> --hf-token <TOKEN> --wandb-key <KEY>
```

This creates the instance, uploads code, installs deps, fixes output dir, logs into HF/W&B, and downloads the dataset. Then SSH in and run finetuning.

---

## Manual Setup (step-by-step)

## 1. Install Vast.ai CLI

**Run: Local**
```bash
pipx install vastai
vastai set api-key <YOUR_API_KEY>
```

## 2. Find and Rent a GPU Instance

**Run: Local**
```bash
# Search for RTX PRO 6000 S instances (48GB VRAM, Blackwell)
vastai search offers 'gpu_name=RTX_PRO_6000_S num_gpus=1 disk_space>=150 inet_down>=200' -o 'dph+'

# Rent one using your pre-built image — OFFER_ID is from the search results above
vastai create instance <OFFER_ID> --image par4ker/gr00t-dev:latest --disk 150
```

## 3. Connect to the Instance

**Run: Local**
```bash
# Get SSH command
vastai ssh-url <INSTANCE_ID>

# SSH in
ssh -p <PORT> root@<IP>
```

## 4. Install Dependencies

**Run: Remote Docker (Vast.ai instance)**
```bash
cd /workspace/gr00t
pip install uv
uv pip install -e ".[dev]"
uv pip install flash-attn --no-build-isolation
```

## 5. Login to HuggingFace and W&B

**Run: Remote Docker (Vast.ai instance)**
```bash
huggingface-cli login
wandb login
```

## 6. Download and Convert Dataset

**Run: Remote Docker (Vast.ai instance)**
```bash
uv run --project scripts/lerobot_conversion \
  python scripts/lerobot_conversion/convert_v3_to_v2.py \
  --repo-id izuluaga/finish_sandwich \
  --root examples/SO100/finish_sandwich_lerobot

cp examples/SO100/modality.json \
  examples/SO100/finish_sandwich_lerobot/izuluaga/finish_sandwich/meta/modality.json
```

## 7. Run Finetuning

**Run: Remote Docker (Vast.ai instance)**
```bash
bash examples/SO100/finetune_so100.sh
```

Checkpoints are saved to `/tmp/so100_finetune` by default (set via `--output_dir` in the script).

## 8. Copy Checkpoints Off

To copy off all of the checkpoint information to resume training

**Run: Local**
```bash
scp -P <PORT> -r root@<IP>:/tmp/so100_finetune ./checkpoints
```
To copy off only the checkpoints and not the optimizer (faster)

**Run: Local**
```bash
rysnc -avz --exclude='optimizer.pt' -e 'ssh -p <port> root@<ip>:/tmp/so100_finetune ./
```

## 9. Destroy the Instance

**Run: Local**
```bash
vastai destroy instance <INSTANCE_ID>
```
