clear; clc; close all;

base_path = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
subjects  = {'IE02'};

sc = load_scenario_coordinates();
COLORS = lines(4);

%% PART 1: 3D plot of suture points for every scenario

figure('Name','Suture point positions per scenario','Position',[50 50 1400 900]);
for scenario_num = 1:6
    subplot(2,3,scenario_num);
    hold on; grid on; axis equal;
    title(sprintf('Scenario %d', scenario_num));
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');

    for i = 1:4
        en = sc(scenario_num).en(i,:);
        ex = sc(scenario_num).ex(i,:);

        scatter3(en(1), en(2), en(3), 120, COLORS(i,:), '^', 'filled','DisplayName', sprintf('En%d',i));
        scatter3(ex(1), ex(2), ex(3), 120, COLORS(i,:), 'v', 'filled','DisplayName', sprintf('Ex%d',i));

        text(en(1), en(2), en(3)+0.002, sprintf('En%d',i), ...
            'Color', COLORS(i,:), 'FontSize', 8, 'FontWeight', 'bold');
        text(ex(1), ex(2), ex(3)-0.002, sprintf('Ex%d',i), ...
            'Color', COLORS(i,:), 'FontSize', 8, 'FontWeight', 'bold');

        plot3([en(1) ex(1)], [en(2) ex(2)], [en(3) ex(3)], '--', ...
            'Color', [COLORS(i,:) 0.4], 'LineWidth', 0.8);
    end

    all_pts = [sc(scenario_num).en; sc(scenario_num).ex];
    pad = 0.005;
    xlim([min(all_pts(:,1))-pad, max(all_pts(:,1))+pad]);
    ylim([min(all_pts(:,2))-pad, max(all_pts(:,2))+pad]);
    zlim([min(all_pts(:,3))-pad, max(all_pts(:,3))+pad]);
    view(45, 30);
end
sgtitle('Entry (^) and Exit (v) hole positions — same color = same suture point');

%% PART 2: Duration and synchronisation check

fprintf('\n=== DURATION AND SYNCHRONISATION CHECK ===\n');
fprintf('%-6s  %-4s  %-12s  %-12s  %-12s  %-12s  %-10s  %-10s  %-8s\n', ...
    'Subj','Scn','bag_dur(s)','needle_dur(s)','mtml_dur(s)','mtmr_dur(s)', ...
    'needle_m','json_m','|path_diff|');

TOL_SYNC = 0.5;   % seconds: warn if any duration differs by more than this

for s = 1:length(subjects)
    subj_name       = subjects{s};
    subj_name_lower = lower(subj_name);
    subj_path       = fullfile(base_path, [subj_name '_SaveData']);

    for scenario_num = 1:6
        folder_name = sprintf('%s_%d_scenario%d', subj_name_lower, scenario_num, scenario_num);
        folder_path = fullfile(subj_path, folder_name);

        json_file   = fullfile(folder_path, 'analysis', 'summary.json');
        needle_csv  = fullfile(folder_path, 'analysis', 'needle_rigid_body.csv');
        mtml_csv    = fullfile(folder_path, 'analysis', 'mtml_cp_cartesian_position.csv');
        mtmr_csv    = fullfile(folder_path, 'analysis', 'mtmr_cp_cartesian_position.csv');

        if ~exist(json_file,'file') || ~exist(needle_csv,'file')
            continue;
        end

        json_str = fileread(json_file);
        json     = jsondecode(json_str);

        bag_dur_json    = json.metrics.bag.duration_s;
        needle_dur_json = json.metrics.needle.duration_s;
        path_len_json   = json.metrics.needle.path_len_m;
        mtml_dur_json   = json.metrics.mtml_cp.duration_s;
        mtmr_dur_json   = json.metrics.mtmr_cp.duration_s;

        needle_data = readmatrix(needle_csv);
        valid_n     = all(~isnan(needle_data(:,2:8)), 2);
        needle_data = needle_data(valid_n, :);
        if size(needle_data,1) < 2, continue; end

        t_needle = needle_data(:,1);
        pos_n    = needle_data(:,2:4);

        needle_dur_csv = t_needle(end) - t_needle(1);

        diffs    = diff(pos_n, 1, 1);
        path_len_csv = sum(sqrt(sum(diffs.^2, 2)));

        mtml_dur_csv = NaN;
        if exist(mtml_csv,'file')
            mtml_data = readmatrix(mtml_csv);
            valid_m   = all(~isnan(mtml_data(:,2:4)), 2);
            mtml_data = mtml_data(valid_m, :);
            if size(mtml_data,1) >= 2
                mtml_dur_csv = mtml_data(end,1) - mtml_data(1,1);
            end
        end

        mtmr_dur_csv = NaN;
        if exist(mtmr_csv,'file')
            mtmr_data = readmatrix(mtmr_csv);
            valid_m   = all(~isnan(mtmr_data(:,2:4)), 2);
            mtmr_data = mtmr_data(valid_m, :);
            if size(mtmr_data,1) >= 2
                mtmr_dur_csv = mtmr_data(end,1) - mtmr_data(1,1);
            end
        end

        path_diff = abs(path_len_csv - path_len_json);

        dur_ok = abs(needle_dur_csv - bag_dur_json) < TOL_SYNC && ...
                 (isnan(mtml_dur_csv) || abs(mtml_dur_csv - bag_dur_json) < TOL_SYNC) && ...
                 (isnan(mtmr_dur_csv) || abs(mtmr_dur_csv - bag_dur_json) < TOL_SYNC);

        flag = '';
        if ~dur_ok
            flag = '  <-- DESYNC';
        end

        fprintf('%-6s  %-4d  %-12.3f  %-12.3f  %-12.3f  %-12.3f  %-10.4f  %-10.4f  %-8.4f%s\n', ...
            subj_name, scenario_num, ...
            bag_dur_json, needle_dur_csv, mtml_dur_csv, mtmr_dur_csv, ...
            path_len_csv, path_len_json, path_diff, flag);

        if ~dur_ok
            fprintf('  -> bag=%.3f  needle_csv=%.3f  mtml_csv=%.3f  mtmr_csv=%.3f\n', ...
                bag_dur_json, needle_dur_csv, mtml_dur_csv, mtmr_dur_csv);

            t0_bag    = json.metrics.bag.start_s;
            t0_needle = t_needle(1);
            offset    = t0_needle - t0_bag;
            fprintf('  -> bag_start=%.3f  needle_t0=%.3f  offset=%.3f s\n', ...
                t0_bag, t0_needle, offset);

            if abs(offset) > TOL_SYNC
                fprintf('  -> OFFSET > %.1fs: needle recording starts %.3fs after bag\n', ...
                    TOL_SYNC, offset);
                fprintf('     Valid needle window in bag time: [%.3f, %.3f] s\n', ...
                    offset, offset + needle_dur_csv);
            end
        end
    end
end

fprintf('\n=== CHECK COMPLETE ===\n');
fprintf('Flagged rows marked with <-- DESYNC\n');
fprintf('For desynced trials: use bag start_s as absolute t=0\n');
fprintf('Needle valid window = [needle_t0 - bag_start, needle_t0 - bag_start + needle_duration]\n');
fprintf('Any entry/exit detection outside this window should be rejected\n');


function sc = load_scenario_coordinates()
    sc = struct();
    sc(1).en   = [0.095507,0.303072,0.744329; 0.084056,0.310882,0.744510; 0.074079,0.320614,0.744360; 0.065357,0.330518,0.743830];
    sc(1).ex   = [0.102433,0.310088,0.744690; 0.090912,0.318677,0.743770; 0.081464,0.327478,0.743529; 0.073698,0.336704,0.744788];
    sc(1).en_q = [0.17297,-0.42130,0.33812,0.82356; 0.21203,-0.40305,0.41449,0.78789; 0.16947,-0.42272,0.33129,0.82633; 0.14597,-0.47479,0.25646,0.82914];
    sc(1).ex_q = [-0.17862,0.41893,0.34918,0.81893; -0.20633,0.40600,0.40334,0.79366; -0.17633,0.41990,0.34470,0.82083; -0.14910,0.42071,0.29893,0.84344];
    sc(2).en   = [0.085416,0.297240,0.744330; 0.080164,0.310067,0.744510; 0.077199,0.323685,0.744360; 0.075378,0.336756,0.743830];
    sc(2).ex   = [0.095062,0.299278,0.744690; 0.090180,0.312794,0.743770; 0.087144,0.325344,0.743530; 0.085747,0.337322,0.744788];
    sc(2).en_q = [0.044476,-0.453251,0.086943,0.886016; 0.087140,-0.447013,0.170342,0.873824; 0.040722,-0.453603,0.079604,0.886706; 0.003232,-0.496722,0.007130,0.867874];
    sc(2).ex_q = [-0.050575,0.452611,0.098865,0.884765; -0.080831,0.448197,0.158009,0.876138; -0.048101,0.452880,0.094028,0.885293; -0.021791,0.445826,0.043687,0.893786];
    sc(3).en   = [0.101107,0.311964,0.744788; 0.089129,0.310571,0.743529; 0.076578,0.307540,0.743770; 0.063060,0.302662,0.744690];
    sc(3).ex   = [0.100544,0.322333,0.743830; 0.087473,0.320516,0.744360; 0.073854,0.317556,0.744510; 0.061025,0.312308,0.744329];
    sc(3).en_q = [0.299893,0.330605,-0.601221,0.662794; 0.286281,0.354200,-0.559624,0.692391; 0.259829,0.374036,-0.507915,0.731168; 0.284341,0.355759,-0.555831,0.695439];
    sc(3).ex_q = [-0.349009,-0.353462,-0.608740,0.618620; -0.292009,-0.349492,-0.570821,0.683189; -0.254531,-0.377661,-0.497559,0.738254; -0.289105,-0.351898,-0.565145,0.687892];
    sc(4).en   = [0.016359,0.242116,0.743210; 0.020802,0.252170,0.743529; 0.021829,0.263208,0.743019; 0.020494,0.274311,0.742690];
    sc(4).ex   = [0.027382,0.235158,0.744430; 0.033549,0.246231,0.744160; 0.034950,0.262228,0.743170; 0.032506,0.276341,0.743190];
    sc(4).en_q = [-0.435165,0.134335,0.850662,0.262599; -0.454139,0.034238,0.887753,0.066928; 0.455301,0.010759,-0.890024,0.021031; 0.454421,0.030266,-0.888304,0.059165];
    sc(4).ex_q = [0.433963,-0.138168,0.848313,0.270091; 0.445961,-0.092377,0.871766,0.180579; -0.455300,-0.010802,-0.890022,0.021116; -0.447033,-0.087038,-0.873862,0.170143];
    sc(5).en   = [0.092931,0.333463,0.743830; 0.083814,0.323921,0.744360; 0.074977,0.313143,0.744510; 0.068182,0.301063,0.744329];
    sc(5).ex   = [0.099811,0.325686,0.744788; 0.091288,0.317155,0.743529; 0.083334,0.306984,0.743770; 0.075768,0.294766,0.744690];
    sc(5).en_q = [-0.213386,-0.448563,-0.371494,0.784377; -0.160861,-0.426073,-0.314453,0.832889; -0.116205,-0.440353,-0.227159,0.860804; -0.157328,-0.427390,-0.307546,0.835464];
    sc(5).ex_q = [0.174516,0.410828,-0.349869,0.823623; 0.153904,0.428635,-0.300852,0.837897; 0.122400,0.438671,-0.239269,0.857516; 0.151559,0.429470,-0.296269,0.839529];
    sc(6).en   = [0.033306,0.241285,0.743210; 0.026192,0.249664,0.743529; 0.016703,0.255397,0.743019; 0.006128,0.259032,0.742690];
    sc(6).ex   = [0.044371,0.248176,0.744430; 0.037090,0.258551,0.744160; 0.023301,0.266781,0.743170; 0.009534,0.270729,0.743190];
    sc(6).en_q = [0.440049,0.117350,-0.860210,0.229397; 0.402952,0.212236,-0.787692,0.414880; 0.380033,0.250976,-0.742890,0.490610; 0.368925,0.267036,-0.721177,0.522004];
    sc(6).ex_q = [-0.441067,-0.113465,-0.862200,0.221801; -0.426907,-0.158633,-0.834520,0.310098; -0.380009,-0.251012,-0.742844,0.490680; -0.332508,-0.311211,-0.649989,0.608357];
end