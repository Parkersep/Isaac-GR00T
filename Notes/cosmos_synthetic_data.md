# NVIDIA Cosmos Synthetic Data Pipeline

## Overview

NVIDIA Cosmos is a platform of generative **World Foundation Models (WFMs)** for Physical AI. It solves the data bottleneck in robot training — NVIDIA demonstrated generating **780K synthetic trajectories (equivalent to 9 months of human demos) in 11 hours**.

### Core Components

| Component | Purpose |
|-----------|---------|
| Cosmos Tokenizer | Neural video/image tokenizer (up to 2048x compression) |
| Cosmos Predict (1, 2, 2.5) | Predicts future world states as video from multimodal inputs |
| Cosmos Transfer (1, 2.5) | Conditional sim-to-real visual transfer |
| Cosmos Reason (1, 2) | VLM for physics understanding, data curation, and evaluation |
| Cosmos Curator / Evaluator | Automated filtering, scoring, and deduplication of generated data |

## Pipeline A: GR00T-Mimic (Specialist — scale existing skills)

```
Real Demos → Isaac Sim (randomize objects/lighting/positions)
           → Cosmos Transfer (sim renders → photorealistic video)
           → Train GR00T
             [actions come from sim ground truth — preserved through transfer]
```

1. Collect a small set of real teleoperated demonstrations
2. Generate variations in Isaac Sim/Omniverse (randomize objects, lighting, positions)
3. Cosmos Transfer converts sim renders (segmentation maps, depth maps, edges) into photorealistic video
4. Actions come from simulation ground truth (preserved through the visual transfer)
5. Train GR00T on the augmented dataset

## Pipeline B: GR00T-Dreams / DreamGen (Generalist — create new skills/environments)

```
Real Demos → Post-train Cosmos Predict-2 (LoRA fine-tune on your robot data)
           → Generate "dream" videos (from 1 starting image + text prompt)
           → Inverse Dynamics Model (extracts pseudo-actions from video frames)
           → Cosmos Reason + Evaluator (filter/curate)
           → Train GR00T
```

1. Collect minimal real demonstrations for one task in one environment
2. Post-train Cosmos Predict-2 on your robot data using LoRA
3. Generate "dream" videos from a single starting image + text instruction for new tasks/environments
4. Apply an **Inverse Dynamics Model (IDM)** — a Diffusion Transformer with flow matching — to extract "pseudo-actions" (neural trajectories) from the generated video frames
5. Filter/curate with Cosmos Reason and Cosmos Evaluator
6. Train GR00T on real data + synthetic neural trajectories

## Key Insight: Cosmos Generates Video Only, Not Actions

- **Mimic**: Actions are ground-truth from physics simulation. Cosmos Transfer only makes the visuals photorealistic while preserving robot motion and joint trajectories.
- **Dreams**: An IDM takes pairs of video frames (frame_t, frame_{t+H}) and predicts the action sequence between them. These "pseudo-actions" are noisier than sim ground truth but enable generalization to entirely new tasks.

## Key Repos

| Repo | Purpose |
|------|---------|
| [NVIDIA/GR00T-Dreams](https://github.com/NVIDIA/GR00T-Dreams) | DreamGen end-to-end blueprint |
| [nvidia-cosmos/cosmos-predict2.5](https://github.com/nvidia-cosmos/cosmos-predict2.5) | Latest world prediction model |
| [nvidia-cosmos/cosmos-transfer2.5](https://github.com/nvidia-cosmos/cosmos-transfer2.5) | Latest sim-to-real transfer |
| [nvidia-cosmos/cosmos-transfer1](https://github.com/nvidia-cosmos/cosmos-transfer1) | Original transfer model |
| [nvidia-cosmos/cosmos-cookbook](https://github.com/nvidia-cosmos/cosmos-cookbook) | Post-training scripts and recipes |
| [NVIDIA/Cosmos-Tokenizer](https://github.com/NVIDIA/Cosmos-Tokenizer) | Video/image tokenization |

## Key HuggingFace Models

| Model | Purpose |
|-------|---------|
| `nvidia/Cosmos-Predict2-14B-Sample-GR00T-Dreams-GR1` | Predict-2 fine-tuned for GR1 dream generation |
| `nvidia/Cosmos-Transfer1-7B` | Sim-to-real visual transfer |
| `nvidia/Cosmos-Reason2-8B` | Physics understanding and data curation |
| `tron-robot/gr00t-n1.6-so101-real-with-cosmos` | Community SO101 model with Cosmos augmentation |

## Connection to This Codebase

Cosmos-Reason-2B is already the **VLM backbone** of GR00T N1.6 — it's the Eagle model at `gr00t/model/modules/eagle_backbone.py`. The vendored model lives at `gr00t/model/modules/nvidia/Eagle-Block2A-2B-v2/`.

## References

- [DreamGen Paper (arXiv:2505.12705)](https://arxiv.org/abs/2505.12705)
- [NVIDIA Cosmos Platform](https://www.nvidia.com/en-us/ai/cosmos/)
- [NVIDIA Cosmos Docs](https://docs.nvidia.com/cosmos/latest/introduction.html)
- [GR00T-Dreams Post-training Guide](https://docs.nvidia.com/cosmos/latest/predict2/post-training_video2world/groot-dreams.html)
- [Scale Synthetic Data with Cosmos WFMs (NVIDIA Blog)](https://developer.nvidia.com/blog/scale-synthetic-data-and-physical-ai-reasoning-with-nvidia-cosmos-world-foundation-models/)
- [Enhance Robot Learning with Synthetic Trajectory Data (NVIDIA Blog)](https://developer.nvidia.com/blog/enhance-robot-learning-with-synthetic-trajectory-data-generated-by-world-foundation-models/)
- [Building Generalist Humanoid Capabilities with GR00T N1.6 (NVIDIA Blog)](https://developer.nvidia.com/blog/building-generalist-humanoid-capabilities-with-nvidia-isaac-gr00t-n1-6-using-a-sim-to-real-workflow/)
