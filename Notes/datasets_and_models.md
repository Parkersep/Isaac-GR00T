# Datasets and Pre-trained Models

## Viewing Datasets

Use the LeRobot visualizer to view any dataset's videos:

https://huggingface.co/spaces/lerobot/visualize_dataset

Just enter the dataset name (e.g. `lerobot/svla_so100_pickplace`).

## Available SO100/SO101 Datasets

| Dataset | Task | Link |
|---------|------|------|
| `lerobot/svla_so100_pickplace` | Pick and place | [Link](https://huggingface.co/datasets/lerobot/svla_so100_pickplace) |
| `lerobot/svla_so100_stacking` | Stacking | [Link](https://huggingface.co/datasets/lerobot/svla_so100_stacking) |
| `lerobot/svla_so100_sorting` | Sorting | [Link](https://huggingface.co/datasets/lerobot/svla_so100_sorting) |
| `lerobot/svla_so101_pickplace` | Pick and place | [Link](https://huggingface.co/datasets/lerobot/svla_so101_pickplace) |
| `youliangtan/so100_strawberry_grape` | Fruit manipulation | [Link](https://huggingface.co/datasets/youliangtan/so100_strawberry_grape) |
| `youliangtan/so101-table-cleanup` | Table cleanup | [Link](https://huggingface.co/datasets/youliangtan/so101-table-cleanup) |

All use 6-DOF action space. Official `lerobot/svla_*` datasets are v3 format (need `convert_v3_to_v2.py`). The `youliangtan/*` datasets are v2.1.

## Pre-trained GR00T Models for SO100/SO101

Download and run inference with `--model-path <model-name> --embodiment-tag NEW_EMBODIMENT`.

### GR00T N1.6 (latest)

| Model | Task | Link |
|---|---|---|
| `aaronsu11/GR00T-N1.6-3B-SO101-FruitPicking` | Fruit picking | [Link](https://huggingface.co/aaronsu11/GR00T-N1.6-3B-SO101-FruitPicking) |
| `tron-robot/gr00t-n1.6-so101-real-with-cosmos` | Real-world + Cosmos augmentation | [Link](https://huggingface.co/tron-robot/gr00t-n1.6-so101-real-with-cosmos) |
| `tshiamor/GR00T-N1.6-mcxcard-so101` | SO-101 manipulation | [Link](https://huggingface.co/tshiamor/GR00T-N1.6-mcxcard-so101) |

### GR00T N1.5

| Model | Task | Link |
|---|---|---|
| `flrs/so101_orange_pick_gr00tn1.5_model` | Pick 3 oranges into bowl (best docs) | [Link](https://huggingface.co/flrs/so101_orange_pick_gr00tn1.5_model) |
| `jtz18/gr00t-so101-finetuned-table-cleanup` | Table cleanup | [Link](https://huggingface.co/jtz18/gr00t-so101-finetuned-table-cleanup) |
| `phospho-app/Rayenghali-gr00t-so101_red_lego_pick_and_place-x2o20` | Lego pick and place | [Link](https://huggingface.co/phospho-app/Rayenghali-gr00t-so101_red_lego_pick_and_place-x2o20) |
| `aravindhs-NV/gr00t-so100-finish-sandwich-10k` | Finish sandwich (NVIDIA) | [Link](https://huggingface.co/aravindhs-NV/gr00t-so100-finish-sandwich-10k) |

### NVIDIA Internal (sim-to-real)

| Model | Task | Link |
|---|---|---|
| `sreetz-nv/groot-so101_teleop_vials_to_tray_*` | Vials to tray (multiple variants) | [Link](https://huggingface.co/sreetz-nv) |
| `liorbenhorin-nv/groot-bimanual-so100-handover-cube-32bs_20000_spark` | Bimanual cube handover | [Link](https://huggingface.co/liorbenhorin-nv/groot-bimanual-so100-handover-cube-32bs_20000_spark) |
