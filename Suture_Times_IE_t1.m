%% NEEDLE PASSAGE TIMES - IE EXPERTS - TIP ONLY
%  entry_punct = tip crosses entry plane (needle starts inserting)
%  exit_punct  = tip crosses exit plane  (needle tip exits tissue)
%  Uses validated check_square_hit plane-crossing logic from IR script

clear; clc; close all;

% --- Parameters ---
base_path        = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
subjects         = {'IE10'}; % 'IE01','IE02','IE03', 'IE04','IE05','IE07','IE08','IE09','IE10','IE11'
NUM_SUBJECTS     = length(subjects);
NUM_SCENARIOS    = 6;
NUM_SUTURES      = 4;

tip_offset_local = [0.00661780871450901, 0.0069734565913677216, 0.0];

sc = load_scenario_coordinates();

% --- Output matrices ---
% entry_punct: tip crosses entry plane (first contact with tissue)
% exit_punct:  tip crosses exit plane  (tip emerges from tissue)
EntryPunctureMatrix = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_SUTURES);
ExitPunctureMatrix  = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_SUTURES);

fprintf('Processing IE experts (tip-only) from:\n%s\n\n', base_path);

% --- Main loop ---
for s = 1:NUM_SUBJECTS
    subj_name       = subjects{s};
    subj_name_lower = lower(subj_name);
    subj_path       = fullfile(base_path, [subj_name '_SaveData']);

    for scenario_num = 1:NUM_SCENARIOS

        folder_name = sprintf('%s_%d_scenario%d',subj_name_lower, scenario_num, scenario_num);
        folder_path = fullfile(subj_path, folder_name);

        if ~isfolder(folder_path)
            fprintf('Soggetto %s | Scenario %d : cartella non trovata, skip.\n', ...
                subj_name, scenario_num);
            continue;
        end

        csv_file = fullfile(folder_path, 'analysis', 'needle_rigid_body.csv');
        if ~exist(csv_file, 'file')
            fprintf('Soggetto %s | Scenario %d : CSV mancante, skip.\n', ...
                subj_name, scenario_num);
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

        %% Compute tip position at every timestep
        pos_TIP = zeros(nSamples, 3);
        for k = 1:nSamples
            R           = quat2rotm_ros(quat_Needle(k,:));
            pos_TIP(k,:)= pos_Origin(k,:) + (R * tip_offset_local')';
        end

        %% Per-suture detection
        entry_punct = nan(1, NUM_SUTURES);
        exit_punct  = nan(1, NUM_SUTURES);

        for i = 1:NUM_SUTURES
            % Entry: tip crosses entry plane
            sprintf("entry pont %d ", i)
            [hit_en, t_en] = check_square_hit(sc(scenario_num).en(i,:), sc(scenario_num).en_q(i,:), ...
                pos_TIP, time_vec);
            if hit_en
                entry_punct(i) = t_en(1);
            end

            % Exit: tip crosses exit plane
            sprintf("exit pont %d ", i)
            [hit_ex, t_ex] = check_square_hit(sc(scenario_num).ex(i,:), sc(scenario_num).ex_q(i,:), ...
                pos_TIP, time_vec);
            if hit_ex
                exit_punct(i) = t_ex(end);
            end
        end

        %% Store
        EntryPunctureMatrix(s, scenario_num, :) = entry_punct;
        ExitPunctureMatrix(s,  scenario_num, :) = exit_punct;

        fprintf(['Soggetto %s | Scenario %d : ' 'entry=[%5.2f %5.2f %5.2f %5.2f]  ' 'exit= [%5.2f %5.2f %5.2f %5.2f]\n'], ...
            subj_name, scenario_num, ...
            entry_punct(1), entry_punct(2), entry_punct(3), entry_punct(4), ...
            exit_punct(1),  exit_punct(2),  exit_punct(3),  exit_punct(4));
    end
end

% save('DataStructures/NeedlePassageTimes_IE.mat', 'EntryPunctureMatrix', 'ExitPunctureMatrix', 'subjects');
% fprintf('\n=== COMPLETATO === Salvato in NeedlePassageTimes_IE.mat\n');


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
    sc(1).en = [0.095507,0.303072,0.744329;0.084056,0.310882,0.744510;0.074079,0.320614,0.744360;0.065357,0.330518,0.743830];
    sc(1).ex = [0.102433,0.310088,0.744690;0.090912,0.318677,0.743770;0.081464,0.327478,0.743529;0.073698,0.336704,0.744788];
    sc(1).en_q = [0.17297,-0.42130,0.33812,0.82356;0.21203,-0.40305,0.41449,0.78789;0.16947,-0.42272,0.33129,0.82633;0.14597,-0.47479,0.25646,0.82914];
    sc(1).ex_q = [-0.17862,0.41893,0.34918,0.81893;-0.20633,0.40600,0.40334,0.79366;-0.17633,0.41990,0.34470,0.82083;-0.14910,0.42071,0.29893,0.84344];
    sc(2).en = [0.085416,0.297240,0.744330;0.080164,0.310067,0.744510;0.077199,0.323685,0.744360;0.075378,0.336756,0.743830];
    sc(2).ex = [0.095062,0.299278,0.744690;0.090180,0.312794,0.743770;0.087144,0.325344,0.743530;0.085747,0.337322,0.744788];
    sc(2).en_q = [0.044476,-0.453251,0.086943,0.886016;0.087140,-0.447013,0.170342,0.873824;0.040722,-0.453603,0.079604,0.886706;0.003232,-0.496722,0.007130,0.867874];
    sc(2).ex_q = [-0.050575,0.452611,0.098865,0.884765;-0.080831,0.448197,0.158009,0.876138;-0.048101,0.452880,0.094028,0.885293;-0.021791,0.445826,0.043687,0.893786];
    sc(3).en = [0.101107,0.311964,0.744788;0.089129,0.310571,0.743529;0.076578,0.307540,0.743770;0.063060,0.302662,0.744690];
    sc(3).ex = [0.100544,0.322333,0.743830;0.087473,0.320516,0.744360;0.073854,0.317556,0.744510;0.061025,0.312308,0.744329];
    sc(3).en_q = [0.299893,0.330605,-0.601221,0.662794;0.286281,0.354200,-0.559624,0.692391;0.259829,0.374036,-0.507915,0.731168;0.284341,0.355759,-0.555831,0.695439];
    sc(3).ex_q = [-0.349009,-0.353462,-0.608740,0.618620;-0.292009,-0.349492,-0.570821,0.683189;-0.254531,-0.377661,-0.497559,0.738254;-0.289105,-0.351898,-0.565145,0.687892];
    sc(4).en = [0.016359,0.242116,0.743210;0.020802,0.252170,0.743529;0.021829,0.263208,0.743019;0.020494,0.274311,0.742690];
    sc(4).ex = [0.027382,0.235158,0.744430;0.033549,0.246231,0.744160;0.034950,0.262228,0.743170;0.032506,0.276341,0.743190];
    sc(4).en_q = [-0.435165,0.134335,0.850662,0.262599;-0.454139,0.034238,0.887753,0.066928;0.455301,0.010759,-0.890024,0.021031;0.454421,0.030266,-0.888304,0.059165];
    sc(4).ex_q = [0.433963,-0.138168,0.848313,0.270091;0.445961,-0.092377,0.871766,0.180579;-0.455300,-0.010802,-0.890022,0.021116;-0.447033,-0.087038,-0.873862,0.170143];
    sc(5).en = [0.092931,0.333463,0.743830;0.083814,0.323921,0.744360;0.074977,0.313143,0.744510;0.068182,0.301063,0.744329];
    sc(5).ex = [0.099811,0.325686,0.744788;0.091288,0.317155,0.743529;0.083334,0.306984,0.743770;0.075768,0.294766,0.744690];
    sc(5).en_q = [-0.213386,-0.448563,-0.371494,0.784377;-0.160861,-0.426073,-0.314453,0.832889;-0.116205,-0.440353,-0.227159,0.860804;-0.157328,-0.427390,-0.307546,0.835464];
    sc(5).ex_q = [0.174516,0.410828,-0.349869,0.823623;0.153904,0.428635,-0.300852,0.837897;0.122400,0.438671,-0.239269,0.857516;0.151559,0.429470,-0.296269,0.839529];
    sc(6).en = [0.033306,0.241285,0.743210;0.026192,0.249664,0.743529;0.016703,0.255397,0.743019;0.006128,0.259032,0.742690];
    sc(6).ex = [0.044371,0.248176,0.744430;0.037090,0.258551,0.744160;0.023301,0.266781,0.743170;0.009534,0.270729,0.743190];
    sc(6).en_q = [0.440049,0.117350,-0.860210,0.229397;0.402952,0.212236,-0.787692,0.414880;0.380033,0.250976,-0.742890,0.490610;0.368925,0.267036,-0.721177,0.522004];
    sc(6).ex_q = [-0.441067,-0.113465,-0.862200,0.221801;-0.426907,-0.158633,-0.834520,0.310098;-0.380009,-0.251012,-0.742844,0.490680;-0.332508,-0.311211,-0.649989,0.608357];
end