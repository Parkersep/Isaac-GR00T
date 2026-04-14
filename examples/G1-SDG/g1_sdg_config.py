from gr00t.configs.data.embodiment_configs import register_modality_config
from gr00t.data.embodiment_tags import EmbodimentTag
from gr00t.data.types import ModalityConfig


# Modality config for the G1 locomanipulation SDG dataset produced by
# IsaacLab's convert_dataset.py.  Column names come from
# meta/modality.json in the converted dataset.
#
# State (49D total):
#   left_hand_pose            [0:7]   - xyz + quaternion
#   right_hand_pose           [7:14]  - xyz + quaternion
#   left_hand_joint_positions [14:21] - 7 joint angles
#   right_hand_joint_positions[21:28] - 7 joint angles
#   object_pose               [28:35] - xyz + quaternion (env obs)
#   goal_pose                 [35:42] - xyz + quaternion (env obs)
#   end_fixture_pose          [42:49] - xyz + quaternion (env obs)
#
# Action (32D total):
#   left_hand_pose            [0:7]   - target EEF pose (xyz + quaternion)
#   right_hand_pose           [7:14]  - target EEF pose (xyz + quaternion)
#   left_hand_joint_positions [14:21] - target joint positions
#   right_hand_joint_positions[21:28] - target joint positions
#   base_velocity             [28:31] - base velocity command
#   base_height               [31:32] - base height command
#
# No action_configs specified (matches the N1.5 IsaacLab data_config.py which
# used min-max normalization for all action keys without relative/absolute distinction).
# 16-step action horizon matches the IsaacLab SDG pipeline default.

g1_sdg_config = {
    "video": ModalityConfig(
        delta_indices=[0],
        modality_keys=["ego_view"],
    ),
    "state": ModalityConfig(
        delta_indices=[0],
        modality_keys=[
            "left_hand_pose",
            "right_hand_pose",
            "left_hand_joint_positions",
            "right_hand_joint_positions",
            "object_pose",
            "goal_pose",
            "end_fixture_pose",
        ],
    ),
    "action": ModalityConfig(
        delta_indices=list(range(16)),
        modality_keys=[
            "left_hand_pose",
            "right_hand_pose",
            "left_hand_joint_positions",
            "right_hand_joint_positions",
            "base_velocity",
            "base_height",
        ],
    ),
    "language": ModalityConfig(
        delta_indices=[0],
        modality_keys=["annotation.human.action.task_description"],
    ),
}

register_modality_config(g1_sdg_config, embodiment_tag=EmbodimentTag.NEW_EMBODIMENT)
