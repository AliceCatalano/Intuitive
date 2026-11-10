import os
import csv
import re
import numpy as np
import scipy.io

GRASP_THRESHOLD = -0.5
OPEN_THRESHOLD = 0.08
MIN_GRASP_DURATION = 1

IE_ROOT  = os.path.expanduser("~/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData")
OUT_ROOT = os.path.expanduser("~/Desktop/Intuitive/DataStructures")


def load_joint_csv(filepath):
    timestamps = []
    positions = []
    with open(filepath, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                t = float(row["t"])
                pos = row.get("position[]", "").strip()
                if pos == "":
                    continue
                timestamps.append(t)
                positions.append(float(pos))
            except (ValueError, KeyError):
                continue
    return np.array(timestamps), np.array(positions)


def load_needle_csv(filepath):
    data = {}
    with open(filepath, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            for key, val in row.items():
                if key not in data:
                    data[key] = []
                try:
                    data[key].append(float(val))
                except (ValueError, TypeError):
                    data[key].append(np.nan)
    for key in data:
        data[key] = np.array(data[key])
    return data


def detect_grasps(timestamps, positions, grasp_threshold=GRASP_THRESHOLD, open_threshold=OPEN_THRESHOLD, min_duration=MIN_GRASP_DURATION):
    grasps = []
    state = "OPEN"
    grasp_start = None
    grasp_idx = None
    for i, (t, pos) in enumerate(zip(timestamps, positions)):
        if state == "OPEN":
            if pos < grasp_threshold:
                state = "CLOSED"
                grasp_start = t
                grasp_idx = i
        elif state == "CLOSED":
            if pos > open_threshold:
                duration = t - grasp_start
                grasps.append({"start_time": grasp_start, "end_time": t, "duration": duration,
                                "start_idx": grasp_idx, "end_idx": i, "valid": duration >= min_duration})
                state = "OPEN"
    if state == "CLOSED":
        duration = timestamps[-1] - grasp_start
        grasps.append({"start_time": grasp_start, "end_time": timestamps[-1], "duration": duration,
                        "start_idx": grasp_idx, "end_idx": len(timestamps) - 1, "valid": duration >= min_duration})
    return grasps


def find_needle_position_at_time(needle_data, t):
    idx = np.argmin(np.abs(needle_data["t"] - t))
    return needle_data["x"][idx], needle_data["y"][idx], needle_data["z"][idx]


def grasps_to_arrays(grasps):
    valid = [g for g in grasps if g["valid"]]
    if not valid:
        return np.array([]), np.array([]), np.array([])
    return (np.array([g["start_time"] for g in valid]),
            np.array([g["end_time"] for g in valid]),
            np.array([g["duration"] for g in valid]))


def save_mat(tL, posL, grasps_L, tR, posR, grasps_R, needle_data, output_path):
    mtml_start, mtml_end, mtml_dur = grasps_to_arrays(grasps_L)
    mtmr_start, mtmr_end, mtmr_dur = grasps_to_arrays(grasps_R)

    grasp_needle_x_mtml = np.array([find_needle_position_at_time(needle_data, t)[0] for t in mtml_start]) if len(mtml_start) > 0 else np.array([])
    grasp_needle_y_mtml = np.array([find_needle_position_at_time(needle_data, t)[1] for t in mtml_start]) if len(mtml_start) > 0 else np.array([])
    grasp_needle_z_mtml = np.array([find_needle_position_at_time(needle_data, t)[2] for t in mtml_start]) if len(mtml_start) > 0 else np.array([])
    grasp_needle_x_mtmr = np.array([find_needle_position_at_time(needle_data, t)[0] for t in mtmr_start]) if len(mtmr_start) > 0 else np.array([])
    grasp_needle_y_mtmr = np.array([find_needle_position_at_time(needle_data, t)[1] for t in mtmr_start]) if len(mtmr_start) > 0 else np.array([])
    grasp_needle_z_mtmr = np.array([find_needle_position_at_time(needle_data, t)[2] for t in mtmr_start]) if len(mtmr_start) > 0 else np.array([])

    scipy.io.savemat(output_path, {
        "mtml_time":            tL,
        "mtml_position":        posL,
        "mtml_grasp_start":     mtml_start,
        "mtml_grasp_end":       mtml_end,
        "mtml_grasp_dur":       mtml_dur,
        "mtmr_time":            tR,
        "mtmr_position":        posR,
        "mtmr_grasp_start":     mtmr_start,
        "mtmr_grasp_end":       mtmr_end,
        "mtmr_grasp_dur":       mtmr_dur,
        "needle_time":          needle_data["t"],
        "needle_x":             needle_data["x"],
        "needle_y":             needle_data["y"],
        "needle_z":             needle_data["z"],
        "needle_qx":            needle_data.get("qx", np.array([])),
        "needle_qy":            needle_data.get("qy", np.array([])),
        "needle_qz":            needle_data.get("qz", np.array([])),
        "needle_qw":            needle_data.get("qw", np.array([])),
        "grasp_needle_x_mtml":  grasp_needle_x_mtml,
        "grasp_needle_y_mtml":  grasp_needle_y_mtml,
        "grasp_needle_z_mtml":  grasp_needle_z_mtml,
        "grasp_needle_x_mtmr":  grasp_needle_x_mtmr,
        "grasp_needle_y_mtmr":  grasp_needle_y_mtmr,
        "grasp_needle_z_mtmr":  grasp_needle_z_mtmr,
    })
    print(f"  Saved {output_path}")


def process_all():
    os.makedirs(OUT_ROOT, exist_ok=True)
    summary = []

    for subject_dir in sorted(os.listdir(IE_ROOT)):
        subject_path = os.path.join(IE_ROOT, subject_dir)
        if not os.path.isdir(subject_path):
            continue

        match = re.match(r'IE(\d+)_SaveData', subject_dir, re.IGNORECASE)
        if not match:
            continue
        subject_num  = int(match.group(1))
        subject_label = f"IE{subject_num:02d}"

        # The 20-repetition folder is IE##_20 inside the subject SaveData folder
        ie20_path = os.path.join(subject_path, f"{subject_label}_20")
        if not os.path.isdir(ie20_path):
            print(f"{subject_label}: no IE_20 folder found, skip")
            continue

        print(f"\n=== {subject_label} ===")

        for rep_dir in sorted(os.listdir(ie20_path)):
            rep_path = os.path.join(ie20_path, rep_dir)
            if not os.path.isdir(rep_path):
                continue

            # Match pattern ie01_4_1_scenario4 through ie01_4_20_scenario4
            match_rep = re.match(r'ie\d+_4_(\d+)_scenario4', rep_dir, re.IGNORECASE)
            if not match_rep:
                continue
            rep_num = int(match_rep.group(1))

            analysis_dir = os.path.join(rep_path, "analysis")
            mtml_path   = os.path.join(analysis_dir, "mtml_joint_state.csv")
            mtmr_path   = os.path.join(analysis_dir, "mtmr_joint_state.csv")
            needle_path = os.path.join(analysis_dir, "needle_rigid_body.csv")

            if not all(os.path.exists(p) for p in [mtml_path, mtmr_path, needle_path]):
                print(f"  Rep{rep_num:02d}: missing CSV files, skip")
                continue

            tL, posL = load_joint_csv(mtml_path)
            tR, posR = load_joint_csv(mtmr_path)
            needle_data = load_needle_csv(needle_path)

            if len(tL) == 0 or len(tR) == 0:
                print(f"  Rep{rep_num:02d}: empty joint data, skip")
                continue

            grasps_L = detect_grasps(tL, posL)
            grasps_R = detect_grasps(tR, posR)

            valid_L = [g for g in grasps_L if g["valid"]]
            valid_R = [g for g in grasps_R if g["valid"]]

            out_filename = f"grasp_Exp_T2_{subject_label}_rep{rep_num:02d}.mat"
            out_path = os.path.join(OUT_ROOT, out_filename)

            save_mat(tL, posL, grasps_L, tR, posR, grasps_R, needle_data, out_path)

            summary.append({
                "subject":      subject_label,
                "rep":          rep_num,
                "mtml_grasps":  len(valid_L),
                "mtmr_grasps":  len(valid_R),
                "mat_file":     out_path
            })
            print(f"  Rep{rep_num:02d}: MTML={len(valid_L)} grasps  MTMR={len(valid_R)} grasps")

    summary_path = os.path.join(OUT_ROOT, "grasp_Exp_T2_summary.csv")
    with open(summary_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["subject", "rep", "mtml_grasps", "mtmr_grasps", "mat_file"])
        writer.writeheader()
        writer.writerows(summary)
    print(f"\nBatch summary saved to {summary_path}")


if __name__ == "__main__":
    process_all()
