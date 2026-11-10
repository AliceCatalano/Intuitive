import os
import csv
import numpy as np

IE_ROOT = os.path.expanduser("~/Desktop/Intuitive/Behavioral dVRK Data/IE_SaveData")
analysis_dir = os.path.join(IE_ROOT, "IE01_SaveData", "ie01_1_scenario1", "analysis")

def load_cartesian_csv(filepath):
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

def interp_xyz(source_t, source_data, query_t):
    x = np.interp(query_t, source_t, source_data["x"])
    y = np.interp(query_t, source_t, source_data["y"])
    z = np.interp(query_t, source_t, source_data["z"])
    return np.column_stack([x, y, z])

needle  = load_cartesian_csv(os.path.join(analysis_dir, "needle_rigid_body.csv"))
psm1    = load_cartesian_csv(os.path.join(analysis_dir, "psm1_rigid_body.csv"))
psm2    = load_cartesian_csv(os.path.join(analysis_dir, "psm2_rigid_body.csv"))
mtml    = load_cartesian_csv(os.path.join(analysis_dir, "mtml_cp_cartesian_position.csv"))
mtmr    = load_cartesian_csv(os.path.join(analysis_dir, "mtmr_cp_cartesian_position.csv"))

common_t = needle["t"]

psm1_interp  = interp_xyz(psm1["t"],  psm1,  common_t)
psm2_interp  = interp_xyz(psm2["t"],  psm2,  common_t)
mtml_interp  = interp_xyz(mtml["t"],  mtml,  common_t)
mtmr_interp  = interp_xyz(mtmr["t"],  mtmr,  common_t)
needle_xyz   = np.column_stack([needle["x"], needle["y"], needle["z"]])

for name, arr, t_arr in [("PSM1", psm1, psm1["t"]), ("PSM2", psm2, psm2["t"]), ("MTML", mtml, mtml["t"]), ("MTMR", mtmr, mtmr["t"])]:
    d = load_cartesian_csv(os.path.join(analysis_dir, f"{'psm1' if name=='PSM1' else 'psm2' if name=='PSM2' else 'mtml_cp_cartesian_position' if name=='MTML' else 'mtmr_cp_cartesian_position'}_{'rigid_body' if 'PSM' in name else ''}.csv".replace("_.", ".")))

print("=== COORDINATE RANGES ===")
for label, d in [("PSM1", psm1), ("PSM2", psm2), ("MTML", mtml), ("MTMR", mtmr), ("Needle", needle)]:
    print(f"{label:8s}  x:[{d['x'].min():.3f}, {d['x'].max():.3f}]  y:[{d['y'].min():.3f}, {d['y'].max():.3f}]  z:[{d['z'].min():.3f}, {d['z'].max():.3f}]")

print("\n=== DISTANCE TO NEEDLE ===")
for label, interp in [("PSM1", psm1_interp), ("PSM2", psm2_interp), ("MTML", mtml_interp), ("MTMR", mtmr_interp)]:
    dist = np.linalg.norm(interp - needle_xyz, axis=1)
    print(f"{label:8s}  min={dist.min():.4f}m  max={dist.max():.4f}m  mean={dist.mean():.4f}m")
