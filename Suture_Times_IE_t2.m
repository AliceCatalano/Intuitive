%% NEEDLE PASSAGE TIMES - IE EXPERTS - TIP ONLY
%  entry_punct = tip crosses entry plane (needle starts inserting)
%  exit_punct  = tip crosses exit plane  (needle tip exits tissue)
%  Uses validated check_square_hit plane-crossing logic from IR script

clear; clc; close all;

% --- Parameters ---
base_path        = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
subjects         = {'IE10'}; % 'IE01','IE02','IE03', 'IE04','IE05','IE07','IE08','IE09','IE10','IE11'
NUM_SUBJECTS     = length(subjects);
NUM_REPETITIONS  = 20;
NUM_SUTURES      = 4;

tip_offset_local = [0.00661780871450901, 0.0069734565913677216, 0.0];

sc = load_scenario_coordinates();

% --- Output matrices ---
% entry_punct: tip crosses entry plane (first contact with tissue)
% exit_punct:  tip crosses exit plane  (tip emerges from tissue)
EntryTimes = nan(NUM_SUBJECTS, NUM_REPETITIONS, NUM_SUTURES);
ExitTimes  = nan(NUM_SUBJECTS, NUM_REPETITIONS, NUM_SUTURES);

fprintf('Processing IE experts (tip-only) from:\n%s\n\n', base_path);

% --- Main loop ---
for s = 1:NUM_SUBJECTS
    subj_name       = subjects{s};
    subj_name_lower = lower(subj_name);
    subj_path       = fullfile(base_path, [subj_name '_SaveData']);
    path2 = fullfile(subj_path, [subj_name '_20']);

    for rep_num = 1:NUM_REPETITIONS

        folder_name = sprintf('%s_4_%d_scenario4',subj_name_lower, rep_num);
        folder_path = fullfile(path2, folder_name);

        if ~isfolder(folder_path)
            fprintf('Soggetto %s | Scenario %d : cartella non trovata, skip.\n', subj_name, rep_num);
            continue;
        end

        csv_file = fullfile(folder_path, 'analysis', 'needle_rigid_body.csv');
        if ~exist(csv_file, 'file')
            fprintf('Soggetto %s | Scenario %d : CSV mancante, skip.\n',subj_name, rep_num);
            continue;
        end

        % Load and clean
        data_csv   = readmatrix(csv_file);
        valid_idx  = all(~isnan(data_csv(:, 2:8)), 2);
        data_clean = data_csv(valid_idx, :);
        if isempty(data_clean), continue; end

        time_vec    = data_clean(:,1) - data_clean(1,1);
        pos_Origin  = data_clean(:,2:4);
        quat_Needle = data_clean(:,5:8);
        nSamples    = size(pos_Origin,1);

        % Compute tip position at every timestep
        pos_TIP = zeros(nSamples, 3);
        for k = 1:nSamples
            R = quat2rotm_ros(quat_Needle(k,:));
            pos_TIP(k,:)= pos_Origin(k,:) + (R * tip_offset_local')';
        end

        % Per-suture detection
        entry_punct = nan(1, NUM_SUTURES);
        exit_punct  = nan(1, NUM_SUTURES);

        for i = 1:NUM_SUTURES
            % Entry: tip crosses entry plane
            sprintf("entry pont %d ", i)
            [hit_en, t_en] = check_square_hit(sc(4).en(i,:), sc(4).en_q(i,:), pos_TIP, time_vec);
            if hit_en
                entry_punct(i) = t_en(1);
            end

            % Exit: tip crosses exit plane
            sprintf("exit pont %d ", i)
            [hit_ex, t_ex] = check_square_hit(sc(4).ex(i,:), sc(4).ex_q(i,:), pos_TIP, time_vec);
            if hit_ex
                exit_punct(i) = t_ex(end);
            end
        end

        % Store
        EntryTimes(s, rep_num, :) = entry_punct;
        ExitTimes(s,  rep_num, :) = exit_punct;

        fprintf(['Soggetto %s | Repetition %d : ' 'entry=[%5.2f %5.2f %5.2f %5.2f]  ' 'exit= [%5.2f %5.2f %5.2f %5.2f]\n'], ...
            subj_name, rep_num, entry_punct(1), entry_punct(2), entry_punct(3), entry_punct(4), ...
            exit_punct(1),  exit_punct(2),  exit_punct(3),  exit_punct(4));
    end
end

% save('DataStructures/NeedlePassageTimes_IE_T2.mat', 'EntryTimes', 'ExitTimes', 'subjects');
% fprintf('\n=== COMPLETATO === Salvato in NeedlePassageTimes_IE_T2.mat\n');


%% FUNCTIONS

function [is_hit, hit_times] = check_square_hit(pos, quat, traj, time_vec)
    R  = quat2rotm_ros(quat);
    N  = R(:,3)';
    U  = R(:,1)';
    V  = R(:,2)';

    is_hit    = false;
    hit_times = [];
    tol_hit   = 0.0035;

    V_diff     = traj - pos;
    dist_plane = V_diff * N';

    % Primary: interpolated plane crossings within lateral tolerance
    crossings = find(dist_plane(1:end-1) .* dist_plane(2:end) <= 0);
    for k = 1:length(crossings)
        idx = crossings(k);
        d1  = dist_plane(idx);
        d2  = dist_plane(idx+1);
        if abs(d1 - d2) < 1e-9
            p_int = traj(idx,:);
            t     = 0;
        else
            t     = d1 / (d1 - d2);
            p_int = traj(idx,:) + t * (traj(idx+1,:) - traj(idx,:));
        end
        dx = dot(p_int - pos, U);
        dy = dot(p_int - pos, V);
        if abs(dx) <= tol_hit && abs(dy) <= tol_hit
            is_hit    = true;
            t_exact   = time_vec(idx) + t * (time_vec(idx+1) - time_vec(idx));
            hit_times = [hit_times, t_exact]; %#ok<AGROW>
        end
    end

    % Fallback: proximity check when no clean crossing found
    if ~is_hit
        close_idx = abs(dist_plane) < 0.0015;
        if any(close_idx)
            pts_close  = V_diff(close_idx,:);
            t_close    = time_vec(close_idx);
            dx_all     = pts_close * U';
            dy_all     = pts_close * V';
            valid      = find(abs(dx_all) <= tol_hit & abs(dy_all) <= tol_hit);
            if ~isempty(valid)
                is_hit    = true;
                hit_times = [hit_times, t_close(valid(end))]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(hit_times)
        hit_times = sort(hit_times)
    end
end

function R = quat2rotm_ros(q)
    qx=q(1); qy=q(2); qz=q(3); qw=q(4);
    R = [1-2*qy^2-2*qz^2,  2*qx*qy-2*qz*qw,  2*qx*qz+2*qy*qw;
         2*qx*qy+2*qz*qw,  1-2*qx^2-2*qz^2,  2*qy*qz-2*qx*qw;
         2*qx*qz-2*qy*qw,  2*qy*qz+2*qx*qw,  1-2*qx^2-2*qy^2];
end

function sc = load_scenario_coordinates()
    sc = struct();
    sc(4).en = [0.016359,0.242116,0.743210;0.020802,0.252170,0.743529;0.021829,0.263208,0.743019;0.020494,0.274311,0.742690];
    sc(4).ex = [0.027382,0.235158,0.744430;0.033549,0.246231,0.744160;0.034950,0.262228,0.743170;0.032506,0.276341,0.743190];
    sc(4).en_q = [-0.435165,0.134335,0.850662,0.262599;-0.454139,0.034238,0.887753,0.066928;0.455301,0.010759,-0.890024,0.021031;0.454421,0.030266,-0.888304,0.059165];
    sc(4).ex_q = [0.433963,-0.138168,0.848313,0.270091;0.445961,-0.092377,0.871766,0.180579;-0.455300,-0.010802,-0.890022,0.021116;-0.447033,-0.087038,-0.873862,0.170143];
end