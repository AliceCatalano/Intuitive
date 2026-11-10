import os
import subprocess
from pathlib import Path

# Base path to the IR_SaveData directory
#base_path = Path("/run/user/1001/gvfs/afp-volume:host=SYNKJK01.local,volume=home/IR_SaveData")
base_path = Path("/run/user/1001/gvfs/afp-volume:host=SYNKJK01.local,user=acatalano,volume=home/IR_SaveData")
FPS = 30

def create_video_from_frames(image_dir: Path, output_video: Path, fps: int = 30):
    """
    Uses ffmpeg to create an MP4 video from a sequence of PNG frames.
    """
    png_files = sorted(image_dir.glob("*.png"))
    if not png_files:
        print(f"  [SKIP] No PNG files found in {image_dir}")
        return

    if output_video.exists():
        print(f"  [SKIP] Video already exists: {output_video}")
        return

    first_file = png_files[0].name
    prefix = first_file.rsplit("_", 1)[0]
    pattern = str(image_dir / f"{prefix}_%06d.png")

    print(f"  [INFO] Pattern : {pattern}")
    print(f"  [INFO] Output  : {output_video}")
    print(f"  [INFO] N frames: {len(png_files)}")

    cmd = [
        "ffmpeg",
        "-y",
        "-framerate", str(fps),
        "-i", pattern,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-preset", "slow",
        str(output_video)
    ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    if result.returncode == 0:
        print(f"  [OK] Video created: {output_video}")
    else:
        print(f"  [ERROR] ffmpeg failed for {image_dir}")
        print(result.stderr.decode())


def process_scenario_dir(scenario_dir: Path):
    """
    Process a single scenario directory that contains an Image_data folder.
    """
    image_data_dir = scenario_dir / "Image_data"

    if not image_data_dir.exists():
        print(f"  [SKIP] No Image_data folder in {scenario_dir}")
        return

    output_video = scenario_dir / f"{scenario_dir.name}_video.mp4"
    create_video_from_frames(image_data_dir, output_video, fps=FPS)


def main():
    # Iterate over subject folders: IR01_SaveData, IR02_SaveData, ...
    subject_dirs = sorted(base_path.glob("IR*_SaveData"))

    if not subject_dirs:
        print(f"No subject directories found in {base_path}")
        return

    print(f"Found {len(subject_dirs)} subjects\n")

    for subject_dir in subject_dirs:
        print(f"\n{'='*60}")
        print(f"[SUBJECT] {subject_dir.name}")

        # All scenario folders are directly inside subject folder
        # e.g. ir02_1_1_scenario1, ir02_3_10_scenario3, etc.
        scenario_dirs = [d for d in subject_dir.iterdir() if d.is_dir()]

        if not scenario_dirs:
            print(f"  [SKIP] No scenario directories found in {subject_dir}")
            continue

        print(f"  Found {len(scenario_dirs)} scenario folders")

        for scenario_dir in scenario_dirs:
            print(f"\n  [SCENARIO] {scenario_dir.name}")
            process_scenario_dir(scenario_dir)

    print(f"\n{'='*60}")
    print("Done!")


if __name__ == "__main__":
    main()
