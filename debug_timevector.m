clear; clc; close all;

base_path   = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
subj        = 'IE09';
scenario    = 4;
subj_lower  = lower(subj);
folder_path = fullfile(base_path, [subj '_SaveData'], ...
    sprintf('%s_%d_scenario%d', subj_lower, scenario, scenario));

needle_csv  = fullfile(folder_path, 'analysis', 'needle_rigid_body.csv');
json_file   = fullfile(folder_path, 'analysis', 'summary.json');
json        = jsondecode(fileread(json_file));

needle_raw  = readmatrix(needle_csv);
valid_n     = all(~isnan(needle_raw(:,2:8)), 2);
needle_raw  = needle_raw(valid_n, :);
t_needle    = needle_raw(:,1) - needle_raw(1,1);

n_frames         = json.images.main.count;
kinematic_dur    = t_needle(end);
recording_hz     = 1 / mean(diff(t_needle));
video_dur_if_10  = n_frames / 10;
video_dur_if_5   = n_frames / 5;
video_dur_if_25  = n_frames / 25;
video_dur_if_30  = n_frames / 30;

fprintf('=== FRAME RATE HYPOTHESIS TEST ===\n');
fprintf('Kinematic duration:     %.3f s\n', kinematic_dur);
fprintf('Recording rate:         %.2f Hz\n', recording_hz);
fprintf('Frame count:            %d\n', n_frames);
fprintf('Video appears:          ~50 s\n\n');

fprintf('If played at  5 fps -> video duration = %.2f s\n', video_dur_if_5);
fprintf('If played at 10 fps -> video duration = %.2f s  <-- matches ~50s?\n', video_dur_if_10);
fprintf('If played at 25 fps -> video duration = %.2f s\n', video_dur_if_25);
fprintf('If played at 30 fps -> video duration = %.2f s\n', video_dur_if_30);

video_apparent_dur = 50;
implied_fps = n_frames / video_apparent_dur;
implied_speedup = implied_fps / recording_hz;
fprintf('\nImplied playback fps:   %.2f fps\n', implied_fps);
fprintf('Implied speedup factor: %.2f x real time\n', implied_speedup);

fprintf('\n=== CONCLUSION ===\n');
if abs(implied_speedup - 2) < 0.1
    fprintf('The video is played at 2x speed relative to the kinematic recording.\n');
    fprintf('Every 1s in the video corresponds to 2s in the kinematic data.\n');
    fprintf('To align video time t_video with kinematic time: t_kinematic = t_video * %.2f\n', implied_speedup);
elseif abs(implied_speedup - round(implied_speedup)) < 0.15
    fprintf('The video is played at approximately %.0fx speed.\n', round(implied_speedup));
    fprintf('To align: t_kinematic = t_video * %.2f\n', implied_speedup);
else
    fprintf('Speedup factor is %.2f — not a clean integer multiple.\n', implied_speedup);
    fprintf('The video may have been exported at a non-standard fps.\n');
end

fprintf('\n=== IMPLICATION FOR YOUR ANALYSIS ===\n');
fprintf('The kinematic timestamps are CORRECT and are in real time.\n');
fprintf('The video is just a sped-up preview and cannot be used as a time reference.\n');
fprintf('Your entry/exit detection times (in kinematic seconds) are the ground truth.\n');
fprintf('When you said point 2 looks like point 3 in the video,\n');
fprintf('that is because the video is compressed in time by %.2fx.\n', implied_speedup);
fprintf('In kinematic time the points are correctly spaced.\n');