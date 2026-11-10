from rosbags.rosbag1 import Reader

bag_path = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData/IE02_SaveData/ie02_2_scenario2/Kinematic_data/ie02_2_scenario2_synchronized_data.bag'

with Reader(bag_path) as reader:

    start = reader.start_time / 1e9
    end   = reader.end_time   / 1e9
    print(f"Bag start (abs): {start:.6f}")
    print(f"Bag end   (abs): {end:.6f}")
    print(f"Bag duration:    {end - start:.3f} s")
    print()

    # Compare with what the CSV uses as t0
    # From MATLAB: t0 = 1762782207.090 (mtml_time(1))
    # That is exactly bag start time - confirmed
    t0_csv = 1762782207.090271
    print(f"CSV t0 matches bag start: {abs(t0_csv - start) < 0.01}")
    print()

    # JSON entry times for IE11 Scn2 (raw from JSON before any correction)
    json_raw_entry = {0: 103.105, 1: 128.950, 2: 163.160, 3: 185.800}
    print("=== JSON raw entry times vs bag reference ===")
    for hole, t_json in json_raw_entry.items():
        t_abs = t_json  # is this already absolute ROS time?
        t_rel_from_bag = t_json - start
        print(f"  Hole {hole}: json_raw={t_json:.3f}  rel_from_bag_start={t_rel_from_bag:.3f}s")

    print()
    print("=== If JSON times are absolute ROS timestamps ===")
    # Check: are they in the range [bag_start, bag_end]?
    for hole, t_json in json_raw_entry.items():
        in_range = start <= t_json <= end
        print(f"  Hole {hole}: {t_json:.3f}  in_bag_range={in_range}")

    print()
    print("=== If we add bag_start to JSON times ===")
    for hole, t_json in json_raw_entry.items():
        t_abs_candidate = t_json + start
        t_rel = t_abs_candidate - start
        print(f"  Hole {hole}: json+bag_start={t_abs_candidate:.3f}  rel={t_rel:.3f}s")
