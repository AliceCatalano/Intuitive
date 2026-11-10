%% DIAGNOSTIC: visualise needle body vs hole footprint over time for one subject/scenario/point
clear; clc; close all;

% --- Set the case you want to investigate ---
subj_name    = 'IE01';
scenario_num = 1;
point_idx    = 3;      % the suspicious point (punct_en = 0.00)
hole_type    = 'en';   % 'en' or 'ex'

base_path        = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
NEEDLE_ARC_DEG   = 120;
ARC_SIGN         = -1;
N_SAMPLE_PTS     = 60;
tip_offset_local = [0.00661780871450901, 0.0069734565913677216, 0.0];
TOL_LATERAL      = 0.0035;
TOL_DEPTH        = 0.0025;

theta_tip        = atan2(tip_offset_local(2), tip_offset_local(1));
r_eff            = norm(tip_offset_local(1:2));
arc_rad          = deg2rad(NEEDLE_ARC_DEG);
thetas           = linspace(theta_tip, theta_tip + ARC_SIGN*arc_rad, N_SAMPLE_PTS);
needle_pts_local = [r_eff*cos(thetas'), r_eff*sin(thetas'), zeros(N_SAMPLE_PTS,1)];

sc = load_scenario_coordinates();

subj_name_lower = lower(subj_name);
folder_path = fullfile(base_path, [subj_name '_SaveData'], ...
    sprintf('%s_%d_scenario%d', subj_name_lower, scenario_num, scenario_num));
csv_file = fullfile(folder_path, 'analysis', 'needle_rigid_body.csv');

data_csv   = readmatrix(csv_file);
valid_idx  = all(~isnan(data_csv(:,2:8)), 2);
data_clean = data_csv(valid_idx,:);
time_vec   = data_clean(:,1) - data_clean(1,1);
pos_Origin = data_clean(:,2:4);
quat_Needle = data_clean(:,5:8);
nSamples   = size(pos_Origin,1);

needle_world = zeros(nSamples, N_SAMPLE_PTS, 3);
for k = 1:nSamples
    R = quat2rotm_ros(quat_Needle(k,:));
    needle_world(k,:,:) = (R * needle_pts_local')' + pos_Origin(k,:);
end

if strcmp(hole_type,'en')
    hole_pos  = sc(scenario_num).en(point_idx,:);
    hole_quat = sc(scenario_num).en_q(point_idx,:);
else
    hole_pos  = sc(scenario_num).ex(point_idx,:);
    hole_quat = sc(scenario_num).ex_q(point_idx,:);
end

R_hole = quat2rotm_ros(hole_quat);
U = R_hole(:,1)'; V = R_hole(:,2)'; N = R_hole(:,3)';

% Compute distance metrics for every needle sample point, every timestep
min_dz = nan(nSamples,1);
min_dx = nan(nSamples,1);
min_dy = nan(nSamples,1);
in_hole = false(nSamples,1);

for k = 1:nSamples
    pts    = squeeze(needle_world(k,:,:));
    V_diff = pts - hole_pos;
    dz = abs(V_diff * N');
    dx = abs(V_diff * U');
    dy = abs(V_diff * V');

    min_dz(k) = min(dz);
    min_dx(k) = min(dx);
    min_dy(k) = min(dy);
    in_hole(k) = any((dz <= TOL_DEPTH) & (dx <= TOL_LATERAL) & (dy <= TOL_LATERAL));
end

figure('Position',[50 50 1400 800]);

subplot(4,1,1);
plot(time_vec, min_dz, 'b'); hold on;
yline(TOL_DEPTH, 'r--', 'TOL\_DEPTH');
ylabel('min |dz| (m)'); title(sprintf('%s | Scenario %d | Point %d (%s) — depth distance to hole plane', ...
    subj_name, scenario_num, point_idx, hole_type));
grid on;

subplot(4,1,2);
plot(time_vec, min_dx, 'r'); hold on;
yline(TOL_LATERAL, 'r--', 'TOL\_LATERAL');
ylabel('min |dx| (m)'); title('Lateral distance U-axis');
grid on;

subplot(4,1,3);
plot(time_vec, min_dy, 'g'); hold on;
yline(TOL_LATERAL, 'r--', 'TOL\_LATERAL');
ylabel('min |dy| (m)'); title('Lateral distance V-axis');
grid on;

subplot(4,1,4);
plot(time_vec, double(in_hole), 'k', 'LineWidth', 1.5);
ylabel('in\_hole (0/1)'); xlabel('Time (s)');
title('Detection flag — 1 = needle body inside hole footprint');
ylim([-0.1 1.1]); grid on;
% Run this immediately after the diagnostic script, same workspace
fprintf('\n=== SUMMARY for %s Scenario %d Point %d (%s) ===\n', ...
    subj_name, scenario_num, point_idx, hole_type);

fprintf('Total frames: %d, Time range: %.2f - %.2f s\n', ...
    nSamples, time_vec(1), time_vec(end));

fprintf('\nFrames where min_dz < TOL_DEPTH:  %d / %d (%.1f%%)\n', ...
    sum(min_dz < TOL_DEPTH), nSamples, 100*mean(min_dz < TOL_DEPTH));
fprintf('Frames where min_dx < TOL_LATERAL: %d / %d (%.1f%%)\n', ...
    sum(min_dx < TOL_LATERAL), nSamples, 100*mean(min_dx < TOL_LATERAL));
fprintf('Frames where min_dy < TOL_LATERAL: %d / %d (%.1f%%)\n', ...
    sum(min_dy < TOL_LATERAL), nSamples, 100*mean(min_dy < TOL_LATERAL));
fprintf('Frames where ALL three satisfied (in_hole): %d / %d (%.1f%%)\n', ...
    sum(in_hole), nSamples, 100*mean(in_hole));

fprintf('\nFirst in_hole frame: %d (t = %.3f s)\n', ...
    find(in_hole,1,'first'), time_vec(find(in_hole,1,'first')));
fprintf('Last  in_hole frame: %d (t = %.3f s)\n', ...
    find(in_hole,1,'last'),  time_vec(find(in_hole,1,'last')));

% Show all separate detection windows (gaps > 1 frame = separate events)
transitions = diff([0; double(in_hole); 0]);
starts = find(transitions ==  1);
ends   = find(transitions == -1) - 1;
fprintf('\nNumber of separate detection windows: %d\n', numel(starts));
for w = 1:numel(starts)
    fprintf('  Window %d: frames %d-%d, t = %.3f - %.3f s, duration = %.3f s\n', ...
        w, starts(w), ends(w), time_vec(starts(w)), time_vec(ends(w)), ...
        time_vec(ends(w)) - time_vec(starts(w)));
end

% Show min distances at t=0 specifically
fprintf('\nAt frame 1 (t=0): min_dz=%.5f, min_dx=%.5f, min_dy=%.5f, in_hole=%d\n', ...
    min_dz(1), min_dx(1), min_dy(1), in_hole(1));

% Show actual tolerance values used
fprintf('\nTOL_DEPTH=%.5f, TOL_LATERAL=%.5f\n', TOL_DEPTH, TOL_LATERAL);

% Check dz behaviour - is it just barely under threshold from the start?
fprintf('\nmin_dz first 10 frames:\n');
fprintf('  %.5f\n', min_dz(1:min(10,end)));
%% helper functions (copy from main script)
function R = quat2rotm_ros(q)
    qx=q(1); qy=q(2); qz=q(3); qw=q(4);
    R=[1-2*qy^2-2*qz^2, 2*qx*qy-2*qz*qw, 2*qx*qz+2*qy*qw;
       2*qx*qy+2*qz*qw, 1-2*qx^2-2*qz^2, 2*qy*qz-2*qx*qw;
       2*qx*qz-2*qy*qw, 2*qy*qz+2*qx*qw, 1-2*qx^2-2*qy^2];
end

function sc = load_scenario_coordinates()
    sc = struct();
    sc(1).en = [0.095507,0.303072,0.744329; 0.084056,0.310882,0.744510; 0.074079,0.320614,0.744360; 0.065357,0.330518,0.743830];
    sc(1).ex = [0.102433,0.310088,0.744690; 0.090912,0.318677,0.743770; 0.081464,0.327478,0.743529; 0.073698,0.336704,0.744788];
    sc(1).en_q = [0.17297,-0.42130,0.33812,0.82356; 0.21203,-0.40305,0.41449,0.78789; 0.16947,-0.42272,0.33129,0.82633; 0.14597,-0.47479,0.25646,0.82914];
    sc(1).ex_q = [-0.17862,0.41893,0.34918,0.81893; -0.20633,0.40600,0.40334,0.79366; -0.17633,0.41990,0.34470,0.82083; -0.14910,0.42071,0.29893,0.84344];
    sc(2).en = [0.085416,0.297240,0.744330; 0.080164,0.310067,0.744510; 0.077199,0.323685,0.744360; 0.075378,0.336756,0.743830];
    sc(2).ex = [0.095062,0.299278,0.744690; 0.090180,0.312794,0.743770; 0.087144,0.325344,0.743530; 0.085747,0.337322,0.744788];
    sc(2).en_q = [0.044476,-0.453251,0.086943,0.886016; 0.087140,-0.447013,0.170342,0.873824; 0.040722,-0.453603,0.079604,0.886706; 0.003232,-0.496722,0.007130,0.867874];
    sc(2).ex_q = [-0.050575,0.452611,0.098865,0.884765; -0.080831,0.448197,0.158009,0.876138; -0.048101,0.452880,0.094028,0.885293; -0.021791,0.445826,0.043687,0.893786];
    sc(3).en = [0.101107,0.311964,0.744788; 0.089129,0.310571,0.743529; 0.076578,0.307540,0.743770; 0.063060,0.302662,0.744690];
    sc(3).ex = [0.100544,0.322333,0.743830; 0.087473,0.320516,0.744360; 0.073854,0.317556,0.744510; 0.061025,0.312308,0.744329];
    sc(3).en_q = [0.299893,0.330605,-0.601221,0.662794; 0.286281,0.354200,-0.559624,0.692391; 0.259829,0.374036,-0.507915,0.731168; 0.284341,0.355759,-0.555831,0.695439];
    sc(3).ex_q = [-0.349009,-0.353462,-0.608740,0.618620; -0.292009,-0.349492,-0.570821,0.683189; -0.254531,-0.377661,-0.497559,0.738254; -0.289105,-0.351898,-0.565145,0.687892];
    sc(4).en = [0.016359,0.242116,0.743210; 0.020802,0.252170,0.743529; 0.021829,0.263208,0.743019; 0.020494,0.274311,0.742690];
    sc(4).ex = [0.027382,0.235158,0.744430; 0.033549,0.246231,0.744160; 0.034950,0.262228,0.743170; 0.032506,0.276341,0.743190];
    sc(4).en_q = [-0.435165,0.134335,0.850662,0.262599; -0.454139,0.034238,0.887753,0.066928; 0.455301,0.010759,-0.890024,0.021031; 0.454421,0.030266,-0.888304,0.059165];
    sc(4).ex_q = [0.433963,-0.138168,0.848313,0.270091; 0.445961,-0.092377,0.871766,0.180579; -0.455300,-0.010802,-0.890022,0.021116; -0.447033,-0.087038,-0.873862,0.170143];
    sc(5).en = [0.092931,0.333463,0.743830; 0.083814,0.323921,0.744360; 0.074977,0.313143,0.744510; 0.068182,0.301063,0.744329];
    sc(5).ex = [0.099811,0.325686,0.744788; 0.091288,0.317155,0.743529; 0.083334,0.306984,0.743770; 0.075768,0.294766,0.744690];
    sc(5).en_q = [-0.213386,-0.448563,-0.371494,0.784377; -0.160861,-0.426073,-0.314453,0.832889; -0.116205,-0.440353,-0.227159,0.860804; -0.157328,-0.427390,-0.307546,0.835464];
    sc(5).ex_q = [0.174516,0.410828,-0.349869,0.823623; 0.153904,0.428635,-0.300852,0.837897; 0.122400,0.438671,-0.239269,0.857516; 0.151559,0.429470,-0.296269,0.839529];
    sc(6).en = [0.033306,0.241285,0.743210; 0.026192,0.249664,0.743529; 0.016703,0.255397,0.743019; 0.006128,0.259032,0.742690];
    sc(6).ex = [0.044371,0.248176,0.744430; 0.037090,0.258551,0.744160; 0.023301,0.266781,0.743170; 0.009534,0.270729,0.743190];
    sc(6).en_q = [0.440049,0.117350,-0.860210,0.229397; 0.402952,0.212236,-0.787692,0.414880; 0.380033,0.250976,-0.742890,0.490610; 0.368925,0.267036,-0.721177,0.522004];
    sc(6).ex_q = [-0.441067,-0.113465,-0.862200,0.221801; -0.426907,-0.158633,-0.834520,0.310098; -0.380009,-0.251012,-0.742844,0.490680; -0.332508,-0.311211,-0.649989,0.608357];
end