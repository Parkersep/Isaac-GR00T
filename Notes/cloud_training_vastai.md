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

# Optional flags:
#   --disk <GB>     disk size in GB (default: 150)
#   --image <IMG>   Docker image (default: par4ker/gr00t-dev:latest)
```

Code is pre-installed in the Docker image. The script creates the instance, installs deps, logs into HF/W&B, and downloads the dataset. Then SSH in and run finetuning.

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

## 6. Download Dataset

### 6a. SO100 finish_sandwich example (v3 → v2 conversion + manual modality.json)

**Run: Remote Docker (Vast.ai instance)**
```bash
uv run --project scripts/lerobot_conversion \
  python scripts/lerobot_conversion/convert_v3_to_v2.py \
  --repo-id izuluaga/finish_sandwich \
  --root examples/SO100/finish_sandwich_lerobot

cp examples/SO100/modality.json \
  examples/SO100/finish_sandwich_lerobot/izuluaga/finish_sandwich/meta/modality.json
```

### 6b. G1 locomanipulation SDG dataset (HF download, no conversion needed)

IsaacLab's `convert_dataset.py` already writes `meta/modality.json`, `info.json`, `episodes.jsonl`, and `tasks.jsonl` — the LeRobot output is complete as-is. Upload once from your workstation (see "Uploading G1 SDG dataset to HF" section below), then on every cloud instance:

**Run: Remote Docker (Vast.ai instance)**
```bash
hf download \
    --repo-type dataset \
    SensoriRobotics/g1_locomanipulation_sdg \
    --local-dir /workspace/datasets/g1_locomanipulation_sdg
```

Then use `--dataset-path /workspace/datasets/g1_locomanipulation_sdg` in the finetune command.

---

## Uploading G1 SDG dataset to HF (one-time, from your workstation)

After running Step 5 of `GR00T_G1_TRAINING.md` (LeRobot conversion), push the output directory to HuggingFace Hub so future cloud instances can pull it in seconds:

**Run: Local (Isaac Lab workstation)**
```bash
# one-time auth (if you haven't)
huggingface-cli login

# upload as a private dataset
huggingface-cli upload \
    --repo-type dataset \
    --private \
    SensoriRobotics/g1_locomanipulation_sdg \
    /home/parker/Nvidia/IsaacLab3/datasets/datasets_train_lerobot
```

First upload sends everything; later uploads send only deltas (git-lfs under the hood). Verify:

```bash
huggingface-cli download --repo-type dataset SensoriRobotics/g1_locomanipulation_sdg \
    --include "meta/*" --local-dir /tmp/verify_hf && cat /tmp/verify_hf/meta/info.json
```

**Size expectations** for ~1000 SDG episodes: `videos/` 10–50 GB (dominant), `data/` <1 GB, `meta/` KB. HF Hub handles this comfortably.
---

## 7. Run Finetuning

### 7a. SO100 finish_sandwich

**Run: Remote Docker (Vast.ai instance)**
```bash
bash examples/SO100/finetune_so100.sh
```

Checkpoints are saved to `/tmp/so100_finetune` by default (set via `--output_dir` in the script).

### 7b. G1 locomanipulation SDG

The SDG dataset from IsaacLab has different state/action column names than the pre-registered `UNITREE_G1` config, so we use `NEW_EMBODIMENT` with a custom modality config at `examples/G1-SDG/g1_sdg_config.py`.

**Run: Remote Docker (Vast.ai instance)**
```bash
python gr00t/experiment/launch_finetune.py \
    --base_model_path nvidia/GR00T-N1.6-3B \
    --dataset_path /workspace/datasets/g1_locomanipulation_sdg \
    --embodiment_tag NEW_EMBODIMENT \
    --modality_config_path examples/G1-SDG/g1_sdg_config.py \
    --output_dir /tmp/g1_finetune \
    --num_gpus 1 \
    --max_steps 20000 \
    --save_steps 5000 \
    --save_total_limit 5 \
    --learning_rate 1e-4 \
    --warmup_ratio 0.05 \
    --weight_decay 1e-5 \
    --global_batch_size 64 \
    --dataloader_num_workers 4 \
    --color_jitter_params brightness 0.3 contrast 0.4 saturation 0.5 hue 0.08 \
    --use_wandb
```

Checkpoints saved to `/tmp/g1_finetune`.

## 8. Copy Checkpoints Off

To copy off all of the checkpoint information to resume training

**Run: Local**
```bash
scp -P <PORT> -r root@<IP>:/tmp/g1_finetune ./checkpoints
```
To copy off only the checkpoints and not the optimizer (faster)

**Run: Local**
```bash
rsync -avz --progress --exclude='optimizer.pt' -e 'ssh -p <PORT>' root@<IP>:/tmp/g1_finetune ./checkpoints
```

## 9. Destroy the Instance

**Run: Local**
```bash
vastai destroy instance <INSTANCE_ID>
```
