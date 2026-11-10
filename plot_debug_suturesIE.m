function plot_debug_suturesIE()
%% DIAGNOSTIC: Suture hole geometry + recording synchronisation check
% PART 1: 3D plots of entry/exit hole positions for all 6 scenarios.
% PART 2: For each subject/scenario, compares bag duration, needle CSV duration, MTML/MTMR CSV duration, 
%     and path length against the values stored in summary.json.
% Output: printed table, DESYNC warnings with offset estimates.
% Requires: IE_SaveData folder with analysis/ subfolders containing needle_rigid_body.csv, mtml/mtmr_cp_cartesian_position.csv,
%           and summary.json.

SUBJ_NAME    = 'IE02';
SCENARIO_NUM = 2;

base_path        = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
mat_path         = 'NeedlePassageTimes_IE.mat';
tip_offset_local = [0.00661780871450901, 0.0069734565913677216, 0.0];
tol_hit          = 0.0035;

sc      = load_scenario_coordinates();
loaded = load(mat_path, 'EntryTimes', 'ExitTimes', 'subjects');

subjects = loaded.subjects;

s_idx = find(strcmp(subjects, SUBJ_NAME));
if isempty(s_idx)
    error('Subject %s not found in %s', SUBJ_NAME, mat_path);
end

entry_punct = squeeze(loaded.EntryTimes(s_idx, SCENARIO_NUM, :))';
exit_punct  = squeeze(loaded.ExitTimes(s_idx,  SCENARIO_NUM, :))';

fprintf('\n=== %s Scenario %d (loaded from %s) ===\n', SUBJ_NAME, SCENARIO_NUM, mat_path);
fprintf('entry = [%.2f %.2f %.2f %.2f]\n', entry_punct);
fprintf('exit  = [%.2f %.2f %.2f %.2f]\n\n', exit_punct);

subj_lower  = lower(SUBJ_NAME);
folder_path = fullfile(base_path, [SUBJ_NAME '_SaveData'], ...
    sprintf('%s_%d_scenario%d', subj_lower, SCENARIO_NUM, SCENARIO_NUM));
csv_file    = fullfile(folder_path, 'analysis', 'needle_rigid_body.csv');

data_csv    = readmatrix(csv_file);
valid_idx   = all(~isnan(data_csv(:,2:8)), 2);
data_clean  = data_csv(valid_idx, :);
time_vec    = data_clean(:,1) - data_clean(1,1);
pos_Origin  = data_clean(:,2:4);
quat_Needle = data_clean(:,5:8);
nSamples    = size(pos_Origin,1);
t_end       = time_vec(end);

pos_TIP = zeros(nSamples,3);
for k = 1:nSamples
    R = quat2rotm_ros(quat_Needle(k,:));
    pos_TIP(k,:) = pos_Origin(k,:) + (R * tip_offset_local')';
end

COLORS    = lines(4);
COLOR_TIP = [0.204, 0.596, 0.859];

pad     = 0.008;
x_lim   = [min(pos_TIP(:,1))-pad, max(pos_TIP(:,1))+pad];
y_lim   = [min(pos_TIP(:,2))-pad, max(pos_TIP(:,2))+pad];
z_lim   = [min(pos_TIP(:,3))-pad, max(pos_TIP(:,3))+pad];
rng_val = max([diff(x_lim), diff(y_lim), diff(z_lim)]);
x_lim   = mean(x_lim) + [-1 1]*rng_val/2;
y_lim   = mean(y_lim) + [-1 1]*rng_val/2;
z_lim   = mean(z_lim) + [-1 1]*rng_val/2;

dist_en   = zeros(nSamples,4);
dist_ex   = zeros(nSamples,4);
in_lat_en = false(nSamples,4);
in_lat_ex = false(nSamples,4);

for i = 1:4
    R_en = quat2rotm_ros(sc(SCENARIO_NUM).en_q(i,:));
    N_en = R_en(:,3)'; U_en = R_en(:,1)'; V_en = R_en(:,2)';
    Vd = pos_TIP - sc(SCENARIO_NUM).en(i,:);
    dist_en(:,i)   = Vd * N_en';
    in_lat_en(:,i) = (abs(Vd*U_en') <= tol_hit) & (abs(Vd*V_en') <= tol_hit);

    R_ex = quat2rotm_ros(sc(SCENARIO_NUM).ex_q(i,:));
    N_ex = R_ex(:,3)'; U_ex = R_ex(:,1)'; V_ex = R_ex(:,2)';
    Vd = pos_TIP - sc(SCENARIO_NUM).ex(i,:);
    dist_ex(:,i)   = Vd * N_ex';
    in_lat_ex(:,i) = (abs(Vd*U_ex') <= tol_hit) & (abs(Vd*V_ex') <= tol_hit);
end

fig = figure('Name', sprintf('Inspector — %s Scn%d', SUBJ_NAME, SCENARIO_NUM), ...
    'NumberTitle','off', 'Position', [50 50 1600 900]);

ax_3d  = axes('Parent', fig, 'Position', [0.04 0.22 0.46 0.72]);
ax_dist = gobjects(4,1);
for i = 1:4
    ax_dist(i) = axes('Parent', fig, 'Position', [0.54 0.78-(i-1)*0.22 0.44 0.18]); %#ok<LAXES>
end

hold(ax_3d,'on');
plot3(ax_3d, pos_TIP(:,1), pos_TIP(:,2), pos_TIP(:,3), ...
    'Color',[0.85 0.85 0.85], 'LineWidth',0.5, 'LineStyle',':');
for i = 1:4
    draw_hole(ax_3d, sc(SCENARIO_NUM).en(i,:), sc(SCENARIO_NUM).en_q(i,:), tol_hit, COLORS(i,:), sprintf('En%d',i), true);
    draw_hole(ax_3d, sc(SCENARIO_NUM).ex(i,:), sc(SCENARIO_NUM).ex_q(i,:), tol_hit, COLORS(i,:), sprintf('Ex%d',i), false);
end
for i = 1:4
    if ~isnan(entry_punct(i))
        [~,idx] = min(abs(time_vec - entry_punct(i)));
        scatter3(ax_3d, pos_TIP(idx,1), pos_TIP(idx,2), pos_TIP(idx,3), 180, '^', 'filled', ...
            'MarkerFaceColor', COLORS(i,:), 'MarkerEdgeColor','k', 'LineWidth',1.2, ...
            'DisplayName', sprintf('En%d=%.1fs',i,entry_punct(i)));
    end
    if ~isnan(exit_punct(i))
        [~,idx] = min(abs(time_vec - exit_punct(i)));
        scatter3(ax_3d, pos_TIP(idx,1), pos_TIP(idx,2), pos_TIP(idx,3), 180, 'v', 'filled', ...
            'MarkerFaceColor', COLORS(i,:), 'MarkerEdgeColor','k', 'LineWidth',1.2, ...
            'DisplayName', sprintf('Ex%d=%.1fs',i,exit_punct(i)));
    end
end
xlabel(ax_3d,'X (m)'); ylabel(ax_3d,'Y (m)'); zlabel(ax_3d,'Z (m)');
xlim(ax_3d,x_lim); ylim(ax_3d,y_lim); zlim(ax_3d,z_lim);
grid(ax_3d,'on'); view(ax_3d,45,30);
legend(ax_3d,'Location','best','FontSize',7);
title(ax_3d, sprintf('%s Scn%d (times from saved mat)', SUBJ_NAME, SCENARIO_NUM), 'Interpreter','none');
hold(ax_3d,'off');

for i = 1:4
    ax = ax_dist(i);
    hold(ax,'on');
    plot(ax, time_vec, dist_en(:,i), 'Color', COLORS(i,:), 'LineWidth',1.0, 'DisplayName','Entry plane dist');
    plot(ax, time_vec, dist_ex(:,i), '--', 'Color', COLORS(i,:), 'LineWidth',1.0, 'DisplayName','Exit plane dist');
    shade_regions(ax, time_vec, in_lat_en(:,i) & (abs(dist_en(:,i))<0.005), COLORS(i,:), 0.20);
    shade_regions(ax, time_vec, in_lat_ex(:,i) & (abs(dist_ex(:,i))<0.005), COLORS(i,:), 0.10);
    yline(ax, 0, 'k--', 'LineWidth',0.8);
    if ~isnan(entry_punct(i))
        xline(ax, entry_punct(i), '-', 'Color', COLORS(i,:), 'LineWidth',2.5, ...
            'Label', sprintf('En%.1fs',entry_punct(i)), 'LabelVerticalAlignment','bottom');
    end
    if ~isnan(exit_punct(i))
        xline(ax, exit_punct(i), '-', 'Color', COLORS(i,:)*0.6, 'LineWidth',2.5, ...
            'Label', sprintf('Ex%.1fs',exit_punct(i)), 'LabelVerticalAlignment','top');
    end
    ylabel(ax, sprintf('P%d dist(m)',i));
    xlim(ax, [0 t_end]); grid(ax,'on');
    if i==1
        title(ax,'Plane distances — solid=entry  dashed=exit  shaded=within lat.tol  thick=saved detection');
        legend(ax,'Entry dist','Exit dist','Location','northeast','FontSize',6);
    end
    if i==4, xlabel(ax,'Time (s)'); end
    hold(ax,'off');
end

hold(ax_3d,'on');
h_trail = scatter3(ax_3d, NaN, NaN, NaN, 6, NaN, 'filled', 'HandleVisibility','off');
colormap(ax_3d, cool);
clim(ax_3d, [0 t_end]);
h_dot = scatter3(ax_3d, NaN, NaN, NaN, 200, 'w', 'o', 'filled', ...
    'MarkerEdgeColor', COLOR_TIP, 'LineWidth',2.5, 'HandleVisibility','off');
hold(ax_3d,'off');

h_vline = gobjects(4,1);
for i = 1:4
    hold(ax_dist(i),'on');
    h_vline(i) = xline(ax_dist(i), 0, 'r', 'LineWidth',1.2);
    hold(ax_dist(i),'off');
end

is_playing = false;
stop_flag  = false;

slider = uicontrol('Parent',fig,'Style','slider','Units','normalized', ...
    'Position',[0.04 0.07 0.90 0.04],'Min',0,'Max',t_end,'Value',0, ...
    'SliderStep',[1/t_end, 5/t_end]);
time_label = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[0.44 0.02 0.12 0.03],'String','t = 0.00 s', ...
    'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.04 0.02 0.08 0.03],'String','Play','FontSize',10,'Callback',@play_cb);
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.13 0.02 0.08 0.03],'String','Stop','FontSize',10,'Callback',@stop_cb);
uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[0.22 0.02 0.06 0.03],'String','Speed:','FontSize',9,'HorizontalAlignment','right');
speed_box = uicontrol('Parent',fig,'Style','edit','Units','normalized', ...
    'Position',[0.29 0.02 0.05 0.03],'String','1.0','FontSize',9);

addlistener(slider,'Value','PostSet',@(~,~) update_plot(slider.Value));
update_plot(0);

    function update_plot(t_now)
        t_now = max(0, min(t_now, t_end));
        slider.Value = t_now;
        set(time_label,'String', sprintf('t = %.2f s', t_now));
        idx_now = find(time_vec <= t_now);
        if isempty(idx_now)
            set(h_trail,'XData',NaN,'YData',NaN,'ZData',NaN,'CData',NaN);
            set(h_dot,  'XData',NaN,'YData',NaN,'ZData',NaN);
        else
            set(h_trail,'XData',pos_TIP(idx_now,1),'YData',pos_TIP(idx_now,2), ...
                'ZData',pos_TIP(idx_now,3),'CData',time_vec(idx_now));
            set(h_dot,'XData',pos_TIP(idx_now(end),1),'YData',pos_TIP(idx_now(end),2), ...
                'ZData',pos_TIP(idx_now(end),3));
        end
        for ii = 1:4, h_vline(ii).Value = t_now; end
        drawnow limitrate;
    end

    function play_cb(~,~)
        if is_playing, return; end
        is_playing = true; stop_flag = false;
        speed = str2double(get(speed_box,'String'));
        if isnan(speed)||speed<=0, speed=1.0; end
        dt = 0.05; t_now = slider.Value;
        while t_now < t_end && ~stop_flag && isvalid(fig)
            t_now = t_now + dt*speed;
            update_plot(t_now);
            pause(dt);
        end
        is_playing = false;
    end

    function stop_cb(~,~)
        stop_flag = true; is_playing = false;
    end
end

function draw_hole(ax, pos, quat, half_size, color, label, filled)
    R = quat2rotm_ros(quat); U = R(:,1)'; V = R(:,2)'; N = R(:,3)';
    corners = [pos+half_size*U+half_size*V; pos-half_size*U+half_size*V;
               pos-half_size*U-half_size*V; pos+half_size*U-half_size*V];
    if filled
        patch(ax,corners(:,1),corners(:,2),corners(:,3),color,'FaceAlpha',0.35, ...
            'EdgeColor',color,'LineWidth',1.5,'HandleVisibility','off');
    else
        patch(ax,corners(:,1),corners(:,2),corners(:,3),color,'FaceAlpha',0.10, ...
            'EdgeColor',color,'LineWidth',1.5,'LineStyle','--','HandleVisibility','off');
    end
    ae = pos + 0.006*N;
    plot3(ax,[pos(1) ae(1)],[pos(2) ae(2)],[pos(3) ae(3)],'-','Color',color,'LineWidth',2,'HandleVisibility','off');
    text(ax,pos(1),pos(2),pos(3)+0.004,label,'Color',color,'FontSize',8,'FontWeight','bold');
end

function shade_regions(ax, t, mask, color, alpha_val)
    if ~any(mask), return; end
    yl = ylim(ax);
    tr = diff([0;double(mask);0]); st = find(tr==1); en = find(tr==-1)-1;
    for w = 1:numel(st)
        patch(ax,[t(st(w)) t(min(en(w),numel(t))) t(min(en(w),numel(t))) t(st(w))], ...
            [yl(1) yl(1) yl(2) yl(2)],color,'FaceAlpha',alpha_val,'EdgeColor','none','HandleVisibility','off');
    end
end

function R = quat2rotm_ros(q)
    qx=q(1); qy=q(2); qz=q(3); qw=q(4);
    R=[1-2*qy^2-2*qz^2,2*qx*qy-2*qz*qw,2*qx*qz+2*qy*qw;
       2*qx*qy+2*qz*qw,1-2*qx^2-2*qz^2,2*qy*qz-2*qx*qw;
       2*qx*qz-2*qy*qw,2*qy*qz+2*qx*qw,1-2*qx^2-2*qy^2];
end

function sc = load_scenario_coordinates()
    sc = struct();
    sc(1).en=[0.095507,0.303072,0.744329;0.084056,0.310882,0.744510;0.074079,0.320614,0.744360;0.065357,0.330518,0.743830];
    sc(1).ex=[0.102433,0.310088,0.744690;0.090912,0.318677,0.743770;0.081464,0.327478,0.743529;0.073698,0.336704,0.744788];
    sc(1).en_q=[0.17297,-0.42130,0.33812,0.82356;0.21203,-0.40305,0.41449,0.78789;0.16947,-0.42272,0.33129,0.82633;0.14597,-0.47479,0.25646,0.82914];
    sc(1).ex_q=[-0.17862,0.41893,0.34918,0.81893;-0.20633,0.40600,0.40334,0.79366;-0.17633,0.41990,0.34470,0.82083;-0.14910,0.42071,0.29893,0.84344];
    sc(2).en=[0.085416,0.297240,0.744330;0.080164,0.310067,0.744510;0.077199,0.323685,0.744360;0.075378,0.336756,0.743830];
    sc(2).ex=[0.095062,0.299278,0.744690;0.090180,0.312794,0.743770;0.087144,0.325344,0.743530;0.085747,0.337322,0.744788];
    sc(2).en_q=[0.044476,-0.453251,0.086943,0.886016;0.087140,-0.447013,0.170342,0.873824;0.040722,-0.453603,0.079604,0.886706;0.003232,-0.496722,0.007130,0.867874];
    sc(2).ex_q=[-0.050575,0.452611,0.098865,0.884765;-0.080831,0.448197,0.158009,0.876138;-0.048101,0.452880,0.094028,0.885293;-0.021791,0.445826,0.043687,0.893786];
    sc(3).en=[0.101107,0.311964,0.744788;0.089129,0.310571,0.743529;0.076578,0.307540,0.743770;0.063060,0.302662,0.744690];
    sc(3).ex=[0.100544,0.322333,0.743830;0.087473,0.320516,0.744360;0.073854,0.317556,0.744510;0.061025,0.312308,0.744329];
    sc(3).en_q=[0.299893,0.330605,-0.601221,0.662794;0.286281,0.354200,-0.559624,0.692391;0.259829,0.374036,-0.507915,0.731168;0.284341,0.355759,-0.555831,0.695439];
    sc(3).ex_q=[-0.349009,-0.353462,-0.608740,0.618620;-0.292009,-0.349492,-0.570821,0.683189;-0.254531,-0.377661,-0.497559,0.738254;-0.289105,-0.351898,-0.565145,0.687892];
    sc(4).en=[0.016359,0.242116,0.743210;0.020802,0.252170,0.743529;0.021829,0.263208,0.743019;0.020494,0.274311,0.742690];
    sc(4).ex=[0.027382,0.235158,0.744430;0.033549,0.246231,0.744160;0.034950,0.262228,0.743170;0.032506,0.276341,0.743190];
    sc(4).en_q=[-0.435165,0.134335,0.850662,0.262599;-0.454139,0.034238,0.887753,0.066928;0.455301,0.010759,-0.890024,0.021031;0.454421,0.030266,-0.888304,0.059165];
    sc(4).ex_q=[0.433963,-0.138168,0.848313,0.270091;0.445961,-0.092377,0.871766,0.180579;-0.455300,-0.010802,-0.890022,0.021116;-0.447033,-0.087038,-0.873862,0.170143];
    sc(5).en=[0.092931,0.333463,0.743830;0.083814,0.323921,0.744360;0.074977,0.313143,0.744510;0.068182,0.301063,0.744329];
    sc(5).ex=[0.099811,0.325686,0.744788;0.091288,0.317155,0.743529;0.083334,0.306984,0.743770;0.075768,0.294766,0.744690];
    sc(5).en_q=[-0.213386,-0.448563,-0.371494,0.784377;-0.160861,-0.426073,-0.314453,0.832889;-0.116205,-0.440353,-0.227159,0.860804;-0.157328,-0.427390,-0.307546,0.835464];
    sc(5).ex_q=[0.174516,0.410828,-0.349869,0.823623;0.153904,0.428635,-0.300852,0.837897;0.122400,0.438671,-0.239269,0.857516;0.151559,0.429470,-0.296269,0.839529];
    sc(6).en=[0.033306,0.241285,0.743210;0.026192,0.249664,0.743529;0.016703,0.255397,0.743019;0.006128,0.259032,0.742690];
    sc(6).ex=[0.044371,0.248176,0.744430;0.037090,0.258551,0.744160;0.023301,0.266781,0.743170;0.009534,0.270729,0.743190];
    sc(6).en_q=[0.440049,0.117350,-0.860210,0.229397;0.402952,0.212236,-0.787692,0.414880;0.380033,0.250976,-0.742890,0.490610;0.368925,0.267036,-0.721177,0.522004];
    sc(6).ex_q=[-0.441067,-0.113465,-0.862200,0.221801;-0.426907,-0.158633,-0.834520,0.310098;-0.380009,-0.251012,-0.742844,0.490680;-0.332508,-0.311211,-0.649989,0.608357];
end