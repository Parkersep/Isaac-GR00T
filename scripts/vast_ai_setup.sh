#!/bin/bash
# Vast.ai one-command setup script
# Usage: bash scripts/vast_ai_setup.sh --offer-id <ID> [--hf-token <TOKEN>] [--wandb-key <KEY>] [--disk <GB>]
set -euo pipefail

OFFER_ID=""
HF_TOKEN=""
WANDB_KEY=""
DISK_SIZE="150"
IMAGE="par4ker/gr00t-dev:latest"

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

# Parse instance ID from the create output - look for new_contract field first
INSTANCE_ID=$(echo "$CREATE_OUTPUT" | python3 -c "
import sys, json, re
text = sys.stdin.read()
# Try to parse as JSON or extract the dict portion
try:
    # Find the JSON/dict part of the output
    match = re.search(r'\{.*\}', text)
    if match:
        # Handle Python-style dict (single quotes, True/False)
        d = eval(match.group())
        # new_contract is the instance ID
        print(d.get('new_contract', ''))
except Exception:
    pass
" 2>/dev/null)

# Fallback: try grep for new_contract number
if [ -z "$INSTANCE_ID" ]; then
    INSTANCE_ID=$(echo "$CREATE_OUTPUT" | grep -oP "'new_contract':\s*\K\d+")
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "ERROR: Could not parse instance ID from: $CREATE_OUTPUT"
    exit 1
fi
echo "==> Instance ID: $INSTANCE_ID"

# Wait for instance to have SSH info via 'vastai show instances'
echo "==> Waiting for instance to be ready..."
MAX_RETRIES=40
RETRY_COUNT=0
while true; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -gt "$MAX_RETRIES" ]; then
        echo "ERROR: Timed out waiting for instance after $((MAX_RETRIES * 15))s"
        echo "    Debug: run 'vastai show instances --raw' to check instance state"
        exit 1
    fi

    # Capture stderr separately so it doesn't corrupt JSON
    INSTANCE_INFO=$(vastai show instances --raw 2>/dev/null) || {
        echo "    vastai command failed, retrying in 15s..."
        sleep 15
        continue
    }

    # Parse SSH connection info, printing debug on failure
    read -r SSH_HOST SSH_PORT INST_STATUS < <(echo "$INSTANCE_INFO" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f'JSON_ERR JSON_ERR json_parse_failed', file=sys.stdout)
    sys.exit(0)
for inst in data:
    if str(inst.get('id')) == '$INSTANCE_ID':
        status = inst.get('actual_status', inst.get('status_msg', 'unknown'))
        # Try multiple field names for host
        addr = inst.get('ssh_host') or inst.get('public_ipaddr') or ''
        # Try multiple field names for port
        port = inst.get('ssh_port') or inst.get('direct_port_start') or ''
        # Fallback: parse from ports dict
        if not port:
            ports = inst.get('ports', {})
            if isinstance(ports, dict) and '22/tcp' in ports:
                mapping = ports['22/tcp']
                if isinstance(mapping, list) and mapping:
                    port = mapping[0].get('HostPort', '')
                elif isinstance(mapping, (int, str)):
                    port = str(mapping)
        print(f'{addr} {port} {status}')
        sys.exit(0)
print('NO_MATCH NO_MATCH instance_not_found')
" 2>&1) || true

    # Debug output on first attempt and every 4th retry
    if [ "$RETRY_COUNT" -eq 1 ] || [ $((RETRY_COUNT % 4)) -eq 0 ]; then
        echo "    [debug] host='$SSH_HOST' port='$SSH_PORT' status='$INST_STATUS' (attempt $RETRY_COUNT)"
    fi

    if [ -n "$SSH_HOST" ] && [ -n "$SSH_PORT" ] \
        && [ "$SSH_HOST" != "None" ] && [ "$SSH_PORT" != "None" ] \
        && [ "$SSH_HOST" != "JSON_ERR" ] && [ "$SSH_HOST" != "NO_MATCH" ]; then
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

echo ""
echo "==> Setup complete! Instance ID: $INSTANCE_ID"
echo "    SSH in with:"
echo "    $SSH_CMD"
echo ""
echo "    To destroy when finished:"
echo "    vastai destroy instance $INSTANCE_ID"
