clear; close all;

mat_path     = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/IE09/';
mat_times    = 'NeedlePassageTimes_IE.mat';
SUBJ_NAME    = 'IE02';
SCENARIO_NUM = 4;
base_path    = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
tip_offset_local = [0.00661780871450901, 0.0069734565913677216, 0.0];

search = dir(fullfile(mat_path, '**', sprintf('grasp_data_scn%d.mat', SCENARIO_NUM)));
if isempty(search), error('No grasp_data_scn%d.mat found', SCENARIO_NUM); end
d = load(fullfile(search(end).folder, search(end).name));

t0       = min([d.mtml_time(1), d.mtmr_time(1), d.needle_time(1)]);
mtml_t   = d.mtml_time   - t0;
mtmr_t   = d.mtmr_time   - t0;
needle_t = d.needle_time - t0;

mtml_grasp_start = d.mtml_grasp_start - t0;
mtml_grasp_end   = d.mtml_grasp_end   - t0;
mtmr_grasp_start = d.mtmr_grasp_start - t0;
mtmr_grasp_end   = d.mtmr_grasp_end   - t0;

COLOR_MTML   = [0.557, 0.267, 0.678];
COLOR_MTMR   = [0.902, 0.494, 0.133];
COLOR_NEEDLE = [0.204, 0.596, 0.859];
GRASP_THRESH = -0.3;
OPEN_THRESH  =  0.1;
COLORS_PT    = lines(4);

loaded = load(mat_times, 'EntryPunctureMatrix', 'ExitPunctureMatrix', 'subjects');
s_idx  = find(strcmp(loaded.subjects, SUBJ_NAME));
if isempty(s_idx), error('Subject %s not found', SUBJ_NAME); end
entry_t = squeeze(loaded.EntryPunctureMatrix(s_idx, SCENARIO_NUM, :))';
exit_t  = squeeze(loaded.ExitPunctureMatrix(s_idx,  SCENARIO_NUM, :))';

subj_lower = lower(SUBJ_NAME);
csv_file   = fullfile(base_path, [SUBJ_NAME '_SaveData'], ...
    sprintf('%s_%d_scenario%d', subj_lower, SCENARIO_NUM, SCENARIO_NUM), ...
    'analysis', 'needle_rigid_body.csv');
data_csv   = readmatrix(csv_file);
valid_idx  = all(~isnan(data_csv(:,2:8)), 2);
data_clean = data_csv(valid_idx, :);
time_vec   = data_clean(:,1) - data_clean(1,1);
pos_Origin = data_clean(:,2:4);
quat_Needle= data_clean(:,5:8);
nSamples   = size(pos_Origin,1);

pos_TIP = zeros(nSamples,3);
for k = 1:nSamples
    R = quat2rotm_ros(quat_Needle(k,:));
    pos_TIP(k,:) = pos_Origin(k,:) + (R * tip_offset_local')';
end

sc        = load_scenario_coordinates();
entry_pts = sc(SCENARIO_NUM).en;
exit_pts  = sc(SCENARIO_NUM).ex;
en_q      = sc(SCENARIO_NUM).en_q;
ex_q      = sc(SCENARIO_NUM).ex_q;
tol_hit   = 0.0035;

scenario_label = sprintf('%s Scenario %d', SUBJ_NAME, SCENARIO_NUM);

%% Figure 1: gripper + needle XYZ
fig1 = figure('Name',['Gripper + Needle - ' scenario_label],'NumberTitle','off','Position',[100 100 1400 900]);

ax1 = subplot(3,1,1); hold on;
plot(mtml_t, d.mtml_position,'Color',COLOR_MTML,'LineWidth',1.0,'DisplayName','MTML position');
yline(GRASP_THRESH,'--r','LineWidth',0.8,'DisplayName',sprintf('Grasp thresh (%.1f)',GRASP_THRESH));
yline(OPEN_THRESH,'--g','LineWidth',0.8,'DisplayName',sprintf('Open thresh (%.1f)',OPEN_THRESH));
ylims = ylim;
for i = 1:length(mtml_grasp_start)
    patch([mtml_grasp_start(i),mtml_grasp_end(i),mtml_grasp_end(i),mtml_grasp_start(i)], ...
        [ylims(1),ylims(1),ylims(2),ylims(2)],COLOR_MTML,'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    xline(mtml_grasp_start(i),'Color',COLOR_MTML,'LineWidth',1.5,'HandleVisibility','off');
    text(mtml_grasp_start(i)+0.5,GRASP_THRESH+0.05,sprintf('ML%d\n%.1fs',i,mtml_grasp_end(i)-mtml_grasp_start(i)),'Color',COLOR_MTML,'FontSize',7,'FontWeight','bold');
end
ylabel('Position (rad)'); title('MTML Gripper');
legend('Location','northeast','FontSize',7); grid on; hold off;

ax2 = subplot(3,1,2); hold on;
plot(mtmr_t, d.mtmr_position,'Color',COLOR_MTMR,'LineWidth',1.0,'DisplayName','MTMR position');
yline(GRASP_THRESH,'--r','LineWidth',0.8,'DisplayName',sprintf('Grasp thresh (%.1f)',GRASP_THRESH));
yline(OPEN_THRESH,'--g','LineWidth',0.8,'DisplayName',sprintf('Open thresh (%.1f)',OPEN_THRESH));
ylims = ylim;
for i = 1:length(mtmr_grasp_start)
    patch([mtmr_grasp_start(i),mtmr_grasp_end(i),mtmr_grasp_end(i),mtmr_grasp_start(i)], ...
        [ylims(1),ylims(1),ylims(2),ylims(2)],COLOR_MTMR,'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    xline(mtmr_grasp_start(i),'Color',COLOR_MTMR,'LineWidth',1.5,'HandleVisibility','off');
    text(mtmr_grasp_start(i)+0.5,GRASP_THRESH+0.05,sprintf('MR%d\n%.1fs',i,mtmr_grasp_end(i)-mtmr_grasp_start(i)),'Color',COLOR_MTMR,'FontSize',7,'FontWeight','bold');
end
ylabel('Position (rad)'); title('MTMR Gripper');
legend('Location','northeast','FontSize',7); grid on; hold off;

ax3 = subplot(3,1,3); hold on;
plot(needle_t, d.needle_x,'r','LineWidth',0.8,'DisplayName','X');
plot(needle_t, d.needle_y,'g','LineWidth',0.8,'DisplayName','Y');
plot(needle_t, d.needle_z,'b','LineWidth',0.8,'DisplayName','Z');
z_max = max(d.needle_z); z_range = z_max - min(d.needle_z);
for i = 1:length(mtml_grasp_start)
    xline(mtml_grasp_start(i),'Color',COLOR_MTML,'LineWidth',1.2,'LineStyle',':','HandleVisibility','off');
    text(mtml_grasp_start(i)+0.2,z_max-0.05*z_range,sprintf('ML%d',i),'Color',COLOR_MTML,'FontSize',7,'FontWeight','bold');
end
for i = 1:length(mtmr_grasp_start)
    xline(mtmr_grasp_start(i),'Color',COLOR_MTMR,'LineWidth',1.2,'LineStyle',':','HandleVisibility','off');
    text(mtmr_grasp_start(i)+0.2,z_max-0.12*z_range,sprintf('MR%d',i),'Color',COLOR_MTMR,'FontSize',7,'FontWeight','bold');
end
for i = 1:4
    if ~isnan(entry_t(i))
        xline(entry_t(i),'-','Color',COLORS_PT(i,:),'LineWidth',1.8,'HandleVisibility','off');
        text(entry_t(i)+0.2,z_max-0.20*z_range,sprintf('En%d',i),'Color',COLORS_PT(i,:),'FontSize',7,'FontWeight','bold');
    end
    if ~isnan(exit_t(i))
        xline(exit_t(i),'--','Color',COLORS_PT(i,:),'LineWidth',1.8,'HandleVisibility','off');
        text(exit_t(i)+0.2,z_max-0.28*z_range,sprintf('Ex%d',i),'Color',COLORS_PT(i,:),'FontSize',7,'FontWeight','bold');
    end
end
xlabel('Time (s)'); ylabel('Position (m)');
title('Needle XYZ + Grasp Events + Detected Entry/Exit times');
legend('Location','northeast','FontSize',7); grid on; hold off;

linkaxes([ax1,ax2,ax3],'x');
sgtitle(scenario_label,'Interpreter','none','FontSize',10,'FontWeight','bold');
linkaxes([ax1,ax2,ax3],'x');

%% Flag short gaps between consecutive same-hand grasps
SHORT_GAP_S = 2.0;

fprintf('\n=== SHORT GAPS BETWEEN CONSECUTIVE SAME-HAND GRASPS (< %.1fs) ===\n', SHORT_GAP_S);

for hand = 1:2
    if hand == 1
        g_start    = mtml_grasp_start;
        g_end      = mtml_grasp_end;
        hand_label = 'MTML';
        ax_hand    = ax1;
    else
        g_start    = mtmr_grasp_start;
        g_end      = mtmr_grasp_end;
        hand_label = 'MTMR';
        ax_hand    = ax2;
    end

    if numel(g_start) < 2, continue; end

    for i = 1:numel(g_start)-1
        gap = g_start(i+1) - g_end(i);
        if gap < SHORT_GAP_S && gap >= 0
            fprintf('  %s: grasp %d end=%.2fs -> grasp %d start=%.2fs  gap=%.3fs\n', ...
                hand_label, i, g_end(i), i+1, g_start(i+1), gap);

            if isvalid(ax_hand)
                hold(ax_hand,'on');
                yl = ylim(ax_hand);
                patch(ax_hand, ...
                    [g_end(i), g_start(i+1), g_start(i+1), g_end(i)], ...
                    [yl(1),    yl(1),         yl(2),         yl(2)], ...
                    [1 0.3 0.3], 'FaceAlpha',0.35, 'EdgeColor','none', 'HandleVisibility','off');
                text(ax_hand, (g_end(i)+g_start(i+1))/2, yl(1)+0.85*diff(yl), ...
                    sprintf('%.2fs', gap), ...
                    'Color',[0.8 0 0], 'FontSize',8, 'FontWeight','bold', ...
                    'HorizontalAlignment','center');
                hold(ax_hand,'off');
            end
        end
    end
end
fprintf('=== END GAP CHECK ===\n');

sgtitle(scenario_label,'Interpreter','none','FontSize',10,'FontWeight','bold');
%% Figure 2: 3D needle + hole planes + grasp markers ON tip trajectory
% fig2 = figure('Name',['3D Needle - ' scenario_label],'NumberTitle','off','Position',[100 100 1100 900]);
% hold on;
% 
% % Thin line: needle origin trajectory from grasp_data file
% num_pts = length(d.needle_x);
% % for i = 1:num_pts-1
% %     plot3(d.needle_x(i:i+1),d.needle_y(i:i+1),d.needle_z(i:i+1), ...
% %         'Color',[COLOR_NEEDLE,0.3],'LineWidth',0.6);
% % end
% 
% % Thick line: tip trajectory from needle_rigid_body.csv (cool colormap = time)
% cmap_t = cool(nSamples);
% for k = 1:nSamples-1
%     plot3(pos_TIP(k:k+1,1),pos_TIP(k:k+1,2),pos_TIP(k:k+1,3), '-','Color',[cmap_t(k,:) 0.85],'LineWidth',2.0);
% end
% 
% scatter3(pos_TIP(1,1),pos_TIP(1,2),pos_TIP(1,3),120,'g','o','filled','DisplayName','Tip Start');
% scatter3(pos_TIP(end,1),pos_TIP(end,2),pos_TIP(end,3),120,'k','x','LineWidth',2,'DisplayName','Tip End');
% 
% % Grasp markers projected onto tip trajectory (same time, tip position)
% if ~isempty(mtml_grasp_start)
%     for i = 1:length(mtml_grasp_start)
%         [~, idx] = min(abs(time_vec - mtml_grasp_start(i)));
%         tip_at_grasp = pos_TIP(idx,:);
%         scatter3(tip_at_grasp(1),tip_at_grasp(2),tip_at_grasp(3), ...
%             200,'o','filled','MarkerFaceColor',COLOR_MTML,'MarkerEdgeColor','k','LineWidth',1.2, ...
%             'DisplayName',sprintf('MTML grasp %d (t=%.1fs)',i,mtml_grasp_start(i)));
%         text(tip_at_grasp(1),tip_at_grasp(2),tip_at_grasp(3)+0.003, ...
%             sprintf('ML%d',i),'Color',COLOR_MTML,'FontSize',8,'FontWeight','bold');
%     end
% end
% 
% if ~isempty(mtmr_grasp_start)
%     for i = 1:length(mtmr_grasp_start)
%         [~, idx] = min(abs(time_vec - mtmr_grasp_start(i)));
%         tip_at_grasp = pos_TIP(idx,:);
%         scatter3(tip_at_grasp(1),tip_at_grasp(2),tip_at_grasp(3), ...
%             200,'s','filled','MarkerFaceColor',COLOR_MTMR,'MarkerEdgeColor','k','LineWidth',1.2, ...
%             'DisplayName',sprintf('MTMR grasp %d (t=%.1fs)',i,mtmr_grasp_start(i)));
%         text(tip_at_grasp(1),tip_at_grasp(2),tip_at_grasp(3)+0.003, ...
%             sprintf('MR%d',i),'Color',COLOR_MTMR,'FontSize',8,'FontWeight','bold');
%     end
% end
% 
% % Hole planes
% for i = 1:4
%     draw_hole_3d(entry_pts(i,:), en_q(i,:), tol_hit, COLORS_PT(i,:), sprintf('En%d',i), true);
%     draw_hole_3d(exit_pts(i,:),  ex_q(i,:), tol_hit, COLORS_PT(i,:), sprintf('Ex%d',i), false);
%     plot3([entry_pts(i,1) exit_pts(i,1)],[entry_pts(i,2) exit_pts(i,2)],[entry_pts(i,3) exit_pts(i,3)], ...
%         '--','Color',[COLORS_PT(i,:) 0.35],'LineWidth',0.8,'HandleVisibility','off');
% end
% 
% % Detected entry and exit positions on tip trajectory
% for i = 1:4
%     if ~isnan(entry_t(i))
%         [~,idx] = min(abs(time_vec - entry_t(i)));
%         scatter3(pos_TIP(idx,1),pos_TIP(idx,2),pos_TIP(idx,3),220,'^','filled', ...
%             'MarkerFaceColor',COLORS_PT(i,:),'MarkerEdgeColor','k','LineWidth',1.5, ...
%             'DisplayName',sprintf('En%d t=%.1fs',i,entry_t(i)));
%     end
%     if ~isnan(exit_t(i))
%         [~,idx] = min(abs(time_vec - exit_t(i)));
%         scatter3(pos_TIP(idx,1),pos_TIP(idx,2),pos_TIP(idx,3),220,'v','filled', ...
%             'MarkerFaceColor',COLORS_PT(i,:),'MarkerEdgeColor','k','LineWidth',1.5, ...
%             'DisplayName',sprintf('Ex%d t=%.1fs',i,exit_t(i)));
%     end
% end
% 
% xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
% title(sprintf('%s — thin=needle origin  thick=tip  ○=MTML grasp  □=MTMR grasp  ▲=entry  ▼=exit', ...
%     scenario_label),'FontSize',8,'Interpreter','none');
% legend('Location','best','FontSize',7);
% colormap(cool); cb = colorbar; cb.Label.String = 'Tip time (early→late)';
% grid on; axis equal; view(45,30); rotate3d on;
% hold off;


function draw_hole_3d(pos, quat, half_size, color, label, filled)
    R = quat2rotm_ros(quat); U=R(:,1)'; V=R(:,2)'; N=R(:,3)';
    corners = [pos+half_size*U+half_size*V; pos-half_size*U+half_size*V;
               pos-half_size*U-half_size*V; pos+half_size*U-half_size*V];
    if filled
        patch(corners(:,1),corners(:,2),corners(:,3),color,'FaceAlpha',0.40, ...
            'EdgeColor',color,'LineWidth',1.5,'HandleVisibility','off');
    else
        patch(corners(:,1),corners(:,2),corners(:,3),color,'FaceAlpha',0.12, ...
            'EdgeColor',color,'LineWidth',1.5,'LineStyle','--','HandleVisibility','off');
    end
    ae = pos + 0.006*N;
    plot3([pos(1) ae(1)],[pos(2) ae(2)],[pos(3) ae(3)],'-','Color',color,'LineWidth',2,'HandleVisibility','off');
    text(pos(1),pos(2),pos(3)+0.004,label,'Color',color,'FontSize',8,'FontWeight','bold');
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