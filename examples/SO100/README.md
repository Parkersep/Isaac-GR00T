# Finetuning SO100 Model

This guide shows how to finetune dataset collected from [SO100](https://huggingface.co/docs/lerobot/en/so101) robot, and evaluate the model on the real robot.

**See also:**
- [Local Docker Setup](../../Notes/local_docker_setup.md) — building the image, creating & managing the container
- [Cloud Training (Vast.ai)](../../Notes/cloud_training_vastai.md) — finetuning on rented GPU instances
- [Datasets and Models](../../Notes/datasets_and_models.md) — available datasets and pre-trained checkpoints


## Dataset

To collect the dataset via teleoperation, please refer to the official documentation in lerobot: https://huggingface.co/docs/lerobot/il_robots?teleoperate_so101=Command

**Dataset Path:** [izuluaga/finish_sandwich](https://huggingface.co/datasets/izuluaga/finish_sandwich)

Visualize it with this [link](https://huggingface.co/spaces/lerobot/visualize_dataset?path=%2Fizuluaga%2Ffinish_sandwich%2Fepisode_0)

## Handling the dataset

**Run: Local Docker**
```bash
uv run --project scripts/lerobot_conversion \
  python scripts/lerobot_conversion/convert_v3_to_v2.py \
  --repo-id izuluaga/finish_sandwich \
  --root examples/SO100/finish_sandwich_lerobot
```

Then move the `modality.json` file to the root of the dataset.

**Run: Local Docker**
```bash
cp examples/SO100/modality.json examples/SO100/finish_sandwich_lerobot/izuluaga/finish_sandwich/meta/modality.json
```

## Finetuning

Run the finetuning script using absolute joint positions (feel free to experiment with relative positions):

**Run: Local Docker**
```bash
uv run bash examples/SO100/finetune_so100.sh
```

## Open-Loop Evaluation

Evaluate the finetuned model with the following command:

**Run: Local Docker**
```bash
uv run python gr00t/eval/open_loop_eval.py \
  --dataset-path examples/SO100/finish_sandwich_lerobot/izuluaga/finish_sandwich/ \
  --embodiment-tag NEW_EMBODIMENT \
  --model-path examples/SO100/checkpoints/checkpoint-2000 \
  --traj-ids 0 \
  --action-horizon 16 \
  --steps 400 \
  --save-plot-path /workspace/gr00t/examples/SO100/eval_results/traj_0.jpeg
```

### Evaluation Results

The evaluation produces visualizations comparing predicted actions against ground truth trajectories:

<img src="../../media/open_loop_eval_so100.png" width="800" alt="Open-loop evaluation results showing predicted vs ground truth trajectories" />

## Closed-Loop Evaluation (Physical Robot)

This runs the finetuned model on your real SO100/SO101 robot in a live control loop. It uses a client/server architecture: the **server** loads the model on GPU, and the **client** reads from the robot cameras/joints, sends observations to the server, and streams the predicted actions to the robot motors at 30Hz.

See [eval_so100.py](../../gr00t/eval/real_robot/SO100/eval_so100.py) for the full deployment code using the Policy API.

### 1. Find your robot port and camera indices

Plug in your robot and cameras, then find the correct device paths:

**Run: Local**
```bash
# Find the robot serial port
lerobot-find-port

# Find available cameras (shows device paths like /dev/video2, /dev/video4, etc.)
lerobot-find-cameras opencv
```

Note the port (e.g. `/dev/ttyACM0`) and camera device paths (e.g. `/dev/video2` for front, `/dev/video4` for wrist). Use the device paths, **not** integer indices, in the `--robot.cameras` argument below.

### 2. Install client-side dependencies

The eval client needs LeRobot and a few other packages. Run this once from the repo root:

**Run: Local**
```bash
cd gr00t/eval/real_robot/SO100
uv venv
source .venv/bin/activate
uv pip install -e . --verbose
uv pip install --no-deps -e ../../../../
```

If you get `ModuleNotFoundError: No module named 'scservo_sdk'`, install the Feetech servo SDK:

**Run: Local**
```bash
uv pip install "lerobot[feetech]"
```

### 3. Start the policy server (Terminal 1)

This loads the model onto GPU and serves actions over HTTP. Since Docker uses `--network host`, port 5555 is accessible from the host.

**Run: Local Docker**
```bash
python gr00t/eval/run_gr00t_server.py \
  --model-path examples/SO100/checkpoints/checkpoint-2000 \
  --embodiment-tag NEW_EMBODIMENT \
  --port 5555
```

Wait until you see the server is ready before proceeding.

### 4. Run the eval client (Terminal 2)

This connects to your physical robot and the policy server. Run on the host (not Docker) since it needs USB access to the robot.

**Run: Local**
```bash
cd gr00t/eval/real_robot/SO100
source .venv/bin/activate

python eval_so100.py \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyACM0 \
  --robot.id=my_follower \
  --robot.cameras="{ \
    front: {type: opencv, index_or_path: /dev/video4, width: 640, height: 480, fps: 30}, \
    wrist: {type: opencv, index_or_path: /dev/video2, width: 640, height: 480, fps: 30} \
  }" \
  --policy_host=localhost \
  --policy_port=5555 \
  --lang_instruction="finish the ham cheese olives sandwich" \
  --action_horizon=8
```

Adjust the following to match your setup:
- `--robot.type`: `so100_follower` or `so101_follower`
- `--robot.port`: your serial port from step 1
- `--robot.cameras`: your camera device paths from step 1 (use paths like `/dev/video2`, not integer indices)
- `--lang_instruction`: the task description your model was trained on
- `--action_horizon`: how many steps to execute per inference (8 is a good default)

> **Note:** This CLI uses underscores (`--policy_host`), not hyphens (`--policy-host`).
