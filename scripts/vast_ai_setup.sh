#!/bin/bash
# Vast.ai one-command setup script
# Usage: bash scripts/vast_ai_setup.sh --offer-id <ID> [--hf-token <TOKEN>] [--wandb-key <KEY>] [--disk <GB>]
set -euo pipefail

OFFER_ID=""
HF_TOKEN=""
WANDB_KEY=""
DISK_SIZE="100"
IMAGE="par4ker/gr00t-dev:latest"
LOCAL_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --offer-id) OFFER_ID="$2"; shift 2 ;;
        --hf-token) HF_TOKEN="$2"; shift 2 ;;
        --wandb-key) WANDB_KEY="$2"; shift 2 ;;
        --disk) DISK_SIZE="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

if [ -z "$OFFER_ID" ]; then
    echo "Usage: bash scripts/vast_ai_setup.sh --offer-id <OFFER_ID> [--hf-token <TOKEN>] [--wandb-key <KEY>] [--disk <GB>]"
    exit 1
fi

# Create the instance
echo "==> Creating instance from offer $OFFER_ID (disk: ${DISK_SIZE}GB)..."
CREATE_OUTPUT=$(vastai create instance "$OFFER_ID" --image "$IMAGE" --disk "$DISK_SIZE" 2>&1)
echo "    $CREATE_OUTPUT"

INSTANCE_ID=$(echo "$CREATE_OUTPUT" | grep -oP '\d+' | tail -1)
if [ -z "$INSTANCE_ID" ]; then
    echo "ERROR: Could not parse instance ID from: $CREATE_OUTPUT"
    exit 1
fi
echo "==> Instance ID: $INSTANCE_ID"

# Wait for instance to have SSH info via 'vastai show instances'
echo "==> Waiting for instance to be ready..."
while true; do
    INSTANCE_INFO=$(vastai show instances --raw 2>&1) || true

    SSH_HOST=$(echo "$INSTANCE_INFO" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for inst in data:
    if str(inst.get('id')) == '$INSTANCE_ID':
        addr = inst.get('ssh_host') or inst.get('public_ipaddr', '')
        print(addr)
        break
" 2>/dev/null || true)

    SSH_PORT=$(echo "$INSTANCE_INFO" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for inst in data:
    if str(inst.get('id')) == '$INSTANCE_ID':
        port = inst.get('ssh_port') or inst.get('ports', {}).get('22/tcp', [{}])[0].get('HostPort', '')
        print(port)
        break
" 2>/dev/null || true)

    if [ -n "$SSH_HOST" ] && [ -n "$SSH_PORT" ] && [ "$SSH_HOST" != "None" ] && [ "$SSH_PORT" != "None" ]; then
        break
    fi
    echo "    Instance not ready yet, retrying in 15s..."
    sleep 15
done

echo "==> Host: $SSH_HOST, Port: $SSH_PORT"

# Wait for SSH to actually accept connections
echo "==> Waiting for SSH to accept connections..."
while ! ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -p "$SSH_PORT" "root@$SSH_HOST" "echo ok" &>/dev/null; do
    echo "    SSH not ready yet, retrying in 10s..."
    sleep 10
done

SSH_CMD="ssh -o StrictHostKeyChecking=accept-new -p $SSH_PORT root@$SSH_HOST -L 8080:localhost:8080"
SCP_CMD="scp -o StrictHostKeyChecking=accept-new -P $SSH_PORT"

echo "==> Uploading code to instance..."
$SCP_CMD -r "$LOCAL_REPO_DIR" "root@$SSH_HOST:/workspace/gr00t"

echo "==> Installing uv and dependencies..."
$SSH_CMD "cd /workspace/gr00t && pip install uv && uv pip install -e '.[dev]' && uv pip install flash-attn --no-build-isolation"

if [ -n "$HF_TOKEN" ]; then
    echo "==> Logging into HuggingFace..."
    $SSH_CMD "huggingface-cli login --token $HF_TOKEN"
fi

if [ -n "$WANDB_KEY" ]; then
    echo "==> Logging into W&B..."
    $SSH_CMD "wandb login $WANDB_KEY"
fi

echo "==> Downloading and converting dataset..."
$SSH_CMD "cd /workspace/gr00t && uv run --project scripts/lerobot_conversion python scripts/lerobot_conversion/convert_v3_to_v2.py --repo-id izuluaga/finish_sandwich --root examples/SO100/finish_sandwich_lerobot"
$SSH_CMD "cp /workspace/gr00t/examples/SO100/modality.json /workspace/gr00t/examples/SO100/finish_sandwich_lerobot/izuluaga/finish_sandwich/meta/modality.json"

echo ""
echo "==> Setup complete! Instance ID: $INSTANCE_ID"
echo "    To start finetuning, SSH in and run:"
echo "    $SSH_CMD"
echo "    cd /workspace/gr00t && bash examples/SO100/finetune_so100.sh"
echo ""
echo "    To copy checkpoints off when done:"
echo "    $SCP_CMD -r root@$SSH_HOST:/tmp/so100_finetune ./checkpoints"
echo ""
echo "    To destroy when finished:"
echo "    vastai destroy instance $INSTANCE_ID"
