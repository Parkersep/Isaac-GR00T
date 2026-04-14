# G1 SDG Inference Fix — Quaternion Convention Mismatch

## Problem

Arms move to wrong positions during rollout despite good training loss.

Root cause: `convert_dataset.py` (IsaacLab3 locomanipulation SDG pipeline) calls
`Rotation.from_quat(..., scalar_first=True)` on quaternions from Isaac Lab, which are
in **XYZW** order. `scalar_first=True` tells scipy the **first** element is the scalar (w),
i.e. it expects **WXYZ**. So it misreads `[qx, qy, qz, qw]` as `[qw, qx, qy, qz]`.

Example — identity quaternion `[0, 0, 0, 1]` (XYZW):
- Correct read: identity rotation
- With `scalar_first=True`: reads `w=0, x=0, y=0, z=1` → **180° Z rotation**

This affects every pose in the training data (EEF poses, object pose, goal pose).

## Why the Model Still Trains

The mismatch is **self-consistent**. Both `pose_to_transform` and `pose_from_transform` in
`convert_dataset.py` use `scalar_first=True`, so the encoding round-trips correctly:

```
original XYZW → (scalar_first=True encodes wrong) → relative pose → (scalar_first=True decodes wrong) → original XYZW values
```

The model learned the mapping in this "wrong but consistent" space. Training loss converges
because the input→output relationship is internally consistent.

Confirmed by checking `statistics.json` in the checkpoint: `action.left_hand_pose[3]` has
min ≈ 0.667, which makes sense as the w component (cos(half-angle) ≈ 1 for small rotations),
not as qx.

## Why Inference Was Wrong

The original `rollout_policy.py` used `transform_mul`/`transform_inv` from
`isaaclab_mimic.locomanipulation_sdg.transform_utils`, which use `math_utils.matrix_from_quat`
— correct XYZW. This produced different relative poses than training, so the model received
out-of-distribution inputs and produced garbage actions.

## Fix Applied to `rollout_policy.py`

Two helpers added that mirror `convert_dataset.py`'s encoding exactly:

```python
from scipy.spatial.transform import Rotation as ScipyRotation

def _to_sdg_relative_pose(target_pose_xyzw, base_pose_xyzw):
    """Matches convert_dataset.py — intentionally uses scalar_first=True on XYZW data."""
    r_base   = ScipyRotation.from_quat(base_pose_xyzw[3:],   scalar_first=True)
    r_target = ScipyRotation.from_quat(target_pose_xyzw[3:], scalar_first=True)
    r_rel    = r_base.inv() * r_target
    t_rel    = r_base.inv().apply(target_pose_xyzw[:3] - base_pose_xyzw[:3])
    return np.concatenate([t_rel, r_rel.as_quat(scalar_first=True)])

def _from_sdg_relative_pose(relative_pose, base_pose_xyzw):
    """Inverse — output is numerically identical to the original XYZW world pose."""
    r_base  = ScipyRotation.from_quat(base_pose_xyzw[3:],  scalar_first=True)
    r_rel   = ScipyRotation.from_quat(relative_pose[3:],   scalar_first=True)
    r_world = r_base * r_rel
    t_world = r_base.apply(relative_pose[:3]) + base_pose_xyzw[:3]
    return np.concatenate([t_world, r_world.as_quat(scalar_first=True)])
```

- `build_model_input` now calls `_to_sdg_relative_pose` for all 7D state poses.
- `eval_policy` now calls `_from_sdg_relative_pose` for both EEF action poses (columns 0:7, 7:14).
- `base_pose_np_at_inference` is captured once per 16-step window and reused for all action
  decoding steps (fixes a secondary consistency issue where base_pose was re-read each step).
- `--policy_quat_format` flag is now ignored; the scipy encoding is hardcoded to match training.

## Does `convert_dataset.py` Need to Be Fixed?

Not for the current trained model — fixing it now would change the training distribution and
require retraining from scratch.

**If retraining:** fix `convert_dataset.py` by changing `scalar_first=True` → `scalar_first=False`
(or just remove the kwarg, which defaults to False). Then the relative poses will be geometrically
correct. After retraining, update `rollout_policy.py` to use the correct
`transform_mul`/`transform_inv` path instead of the scipy helpers.

## Rollout Terminates Early / Robot Doesn't Reach Second Bench

### Environment termination conditions (from `locomanipulation_g1_env_cfg.py`)

| Name | Trigger |
|---|---|
| `time_out` | 1000 steps (20 s at 50 Hz) |
| `object_dropping` | object height < 0.5 m |
| `object_too_far` | robot–object distance > **1.0 m** ← main culprit |
| `success` | task_done_pick_place |

### Root cause

`object_too_far` fires the moment the robot walks more than 1 m from the steering wheel
without having grasped it. At 50 Hz, a slow walk covers 1 m in well under 2 seconds, so
the episode resets before the robot ever reaches the other bench. It looks like the robot
"doesn't navigate" but is actually being cut off.

### Fix applied to `rollout_policy.py` (`__main__`)

```python
env_cfg.terminations.object_too_far = None   # disable during rollout eval
```

This lets the full episode play out. The `time_out` (1000 steps / 20 s) and `object_dropping`
terminations remain active.

### If the robot still doesn't reach the bench after this fix

The model's `base_velocity` output (action columns 28:31) may be near zero, meaning the
locomotion wasn't learned well enough. Try:

1. **Later checkpoints** — the tutorial recommends evaluating epochs 1000–2000.
2. **More / better training data** — ensure the generated dataset includes full
   navigate phases (`--navigate_step 130` in `generate_data.py`).
3. **Print base_velocity** during rollout to confirm the model is outputting non-zero
   locomotion commands:
   ```python
   print("base_vel:", action[28:31].numpy())
   ```

## GR00T N1.5 vs N1.6

The quaternion bug is in `convert_dataset.py`, not in GR00T itself. It affects whichever model
version is trained on data generated by that script.

- If you trained N1.5 on data from the same `convert_dataset.py`, the same fix to
  `rollout_policy.py` is needed.
- If N1.5 used a different data generation script (e.g. one without the `scalar_first` bug),
  then N1.5 inference would need the original `transform_mul`/`transform_inv` approach —
  **do not** apply the scipy helper fix to an N1.5 model trained on clean data.
- The safest check: look at `statistics.json` in the N1.5 checkpoint. If `action.left_hand_pose[3]`
  (the 4th action component) has min > 0.5, the training data used WXYZ output and needs the fix.
  If min is near 0 (can go negative), the training data used XYZW and does not need it.
