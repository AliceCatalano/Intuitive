% Task 1
% function graspExplorer()
% 
% mat_path = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspData';
% 
% entry_points = [0.0955,  0.30307, 0.74432;0.08406, 0.31088, 0.74451;
%                 0.07409, 0.32061, 0.74436;0.06536, 0.33052, 0.74383];
% 
% exit_points  = [0.10243, 0.31008, 0.74469;0.09092, 0.31867, 0.74377;
%                 0.08147, 0.32748, 0.74352;0.07373, 0.33673, 0.74481];
% 
% d = load(mat_path);

function graspExplorer()
% Task 2 (20 repetitions of scenario 4)

data_root = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspData';
subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};

subj_choice = listdlg('PromptString','Select subject:', ...
    'SelectionMode','single','ListString',subjects,'ListSize',[200 200]);
if isempty(subj_choice), return; end
subj_name = subjects{subj_choice};

rep_list = arrayfun(@(x) sprintf('Rep %02d',x), 1:20, 'UniformOutput',false);
rep_choice = listdlg('PromptString','Select repetition:', ...
    'SelectionMode','single','ListString',rep_list,'ListSize',[200 200]);
if isempty(rep_choice), return; end
rep_num = rep_choice;

mat_path = fullfile(data_root, sprintf('grasp_Exp_T2_%s_rep%02d.mat', subj_name, rep_num));
if ~exist(mat_path,'file')
    errordlg(sprintf('File not found:\n%s', mat_path)); return;
end

entry_points = [0.016359,0.242116,0.743210; 0.020802,0.252170,0.743529; 0.021829,0.263208,0.743019; 0.020494,0.274311,0.742690];
exit_points  = [0.027382,0.235158,0.744430; 0.033549,0.246231,0.744160; 0.034950,0.262228,0.743170; 0.032506,0.276341,0.743190];

d = load(mat_path);

t0 = min([d.mtml_time(1), d.mtmr_time(1), d.needle_time(1)]);
mtml_t   = d.mtml_time   - t0;
mtmr_t   = d.mtmr_time   - t0;
needle_t = d.needle_time - t0;
t_end    = max([mtml_t(end), mtmr_t(end), needle_t(end)]);

mtml_grasp_start = d.mtml_grasp_start - t0;
mtml_grasp_end   = d.mtml_grasp_end   - t0;
mtmr_grasp_start = d.mtmr_grasp_start - t0;
mtmr_grasp_end   = d.mtmr_grasp_end   - t0;

needle_x = d.needle_x(:);
needle_y = d.needle_y(:);
needle_z = d.needle_z(:);
mtml_pos = d.mtml_position(:);
mtmr_pos = d.mtmr_position(:);

grasp_nx_ml = d.grasp_needle_x_mtml(:);
grasp_ny_ml = d.grasp_needle_y_mtml(:);
grasp_nz_ml = d.grasp_needle_z_mtml(:);
grasp_nx_mr = d.grasp_needle_x_mtmr(:);
grasp_ny_mr = d.grasp_needle_y_mtmr(:);
grasp_nz_mr = d.grasp_needle_z_mtmr(:);

COLOR_MTML   = [0.557, 0.267, 0.678];
COLOR_MTMR   = [0.902, 0.494, 0.133];
COLOR_NEEDLE = [0.204, 0.596, 0.859];
COLOR_ENTRY  = [0.180, 0.800, 0.443];
COLOR_EXIT   = [0.922, 0.271, 0.271];

pad   = 0.01;
x_all = [needle_x; grasp_nx_ml; grasp_nx_mr; entry_points(:,1); exit_points(:,1)];
y_all = [needle_y; grasp_ny_ml; grasp_ny_mr; entry_points(:,2); exit_points(:,2)];
z_all = [needle_z; grasp_nz_ml; grasp_nz_mr; entry_points(:,3); exit_points(:,3)];
x_lim = [min(x_all) - pad, max(x_all) + pad];
y_lim = [min(y_all) - pad, max(y_all) + pad];
z_lim = [min(z_all) - pad, max(z_all) + pad];
range_max = max([diff(x_lim), diff(y_lim), diff(z_lim)]);
x_lim = mean(x_lim) + [-1, 1] * range_max / 2;
y_lim = mean(y_lim) + [-1, 1] * range_max / 2;
z_lim = mean(z_lim) + [-1, 1] * range_max / 2;

n_needle = numel(needle_x);
cmap     = cool(n_needle);

fig = figure('Name', 'Grasp Explorer', 'NumberTitle', 'off', 'Position', [50, 50, 1600, 900]);

ax_3d   = axes('Parent', fig, 'Position', [0.05, 0.25, 0.40, 0.65]);
ax_mtml = axes('Parent', fig, 'Position', [0.52, 0.68, 0.45, 0.22]);
ax_mtmr = axes('Parent', fig, 'Position', [0.52, 0.42, 0.45, 0.22]);
ax_xyz  = axes('Parent', fig, 'Position', [0.52, 0.16, 0.45, 0.22]);

hold(ax_3d, 'on');
plot3(ax_3d, needle_x, needle_y, needle_z, 'Color', [0.75, 0.75, 0.75], 'LineWidth', 0.5, 'LineStyle', ':');
scatter3(ax_3d, needle_x(1), needle_y(1), needle_z(1), 80, 'g', 'o', 'filled', 'DisplayName', 'Start');
scatter3(ax_3d, entry_points(:,1), entry_points(:,2), entry_points(:,3), 120, 'filled', '^', 'MarkerFaceColor', COLOR_ENTRY, 'MarkerEdgeColor', 'k', 'LineWidth', 1.0, 'DisplayName', 'Entry');
scatter3(ax_3d, exit_points(:,1),  exit_points(:,2),  exit_points(:,3),  120, 'filled', 'v', 'MarkerFaceColor', COLOR_EXIT,  'MarkerEdgeColor', 'k', 'LineWidth', 1.0, 'DisplayName', 'Exit');
for k = 1:size(entry_points, 1)
    text(ax_3d, entry_points(k,1), entry_points(k,2), entry_points(k,3) + 0.003, sprintf('En%d', k), 'Color', COLOR_ENTRY, 'FontSize', 8, 'FontWeight', 'bold');
    text(ax_3d, exit_points(k,1),  exit_points(k,2),  exit_points(k,3)  + 0.003, sprintf('Ex%d', k), 'Color', COLOR_EXIT,  'FontSize', 8, 'FontWeight', 'bold');
end
for k = 1:size(entry_points, 1)
    plot3(ax_3d, [entry_points(k,1), exit_points(k,1)], [entry_points(k,2), exit_points(k,2)], [entry_points(k,3), exit_points(k,3)], '--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.8);
end
xlabel(ax_3d, 'X (m)'); ylabel(ax_3d, 'Y (m)'); zlabel(ax_3d, 'Z (m)');
grid(ax_3d, 'on');
xlim(ax_3d, x_lim); ylim(ax_3d, y_lim); zlim(ax_3d, z_lim);
view(ax_3d, 45, 30);
%legend(ax_3d, 'Location', 'best', 'FontSize', 7);
hold(ax_3d, 'off');

slider     = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', 'Position', [0.05, 0.08, 0.90, 0.04], 'Min', 0, 'Max', t_end, 'Value', 0, 'SliderStep', [1/t_end, 5/t_end]);
time_label = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.44, 0.03, 0.12, 0.03], 'String', 't = 0.00 s', 'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
uicontrol('Parent', fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.05, 0.03, 0.08, 0.03], 'String', 'Play',  'FontSize', 10, 'Callback', @play_cb);
uicontrol('Parent', fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.14, 0.03, 0.08, 0.03], 'String', 'Stop',  'FontSize', 10, 'Callback', @stop_cb);
uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.23, 0.03, 0.06, 0.03], 'String', 'Speed:', 'FontSize', 9, 'HorizontalAlignment', 'right');
speed_box  = uicontrol('Parent', fig, 'Style', 'edit', 'Units', 'normalized', 'Position', [0.30, 0.03, 0.05, 0.03], 'String', '1.0', 'FontSize', 9);

is_playing  = false;
stop_flag   = false;
h_trail     = [];
h_dot       = [];
h_grasps_ml = [];
h_grasps_mr = [];
h_labels    = {};

addlistener(slider, 'Value', 'PostSet', @(~,~) update_plot(slider.Value));
update_plot(0);

    function update_plot(t_now)
        t_now = max(0, min(t_now, t_end));
        set(slider, 'Value', t_now);
        set(time_label, 'String', sprintf('t = %.2f s', t_now));

        current_view = [ax_3d.View(1), ax_3d.View(2)];

        delete(h_trail);
        delete(h_dot);
        delete(h_grasps_ml);
        delete(h_grasps_mr);
        cellfun(@delete, h_labels);
        h_labels = {};

        idx_n = find(needle_t <= t_now);
        idx_L = mtml_t <= t_now;
        idx_R = mtmr_t <= t_now;

        hold(ax_3d, 'on');
        if numel(idx_n) > 1
            h_trail = gobjects(numel(idx_n) - 1, 1);
            for k = 1:numel(idx_n) - 1
                h_trail(k) = plot3(ax_3d, needle_x(idx_n(k:k+1)), needle_y(idx_n(k:k+1)), needle_z(idx_n(k:k+1)), '-', 'Color', [cmap(idx_n(k),:), 0.85], 'LineWidth', 2.0);
            end
        end
        if ~isempty(idx_n)
            h_dot = scatter3(ax_3d, needle_x(idx_n(end)), needle_y(idx_n(end)), needle_z(idx_n(end)), 150, 'w', 'o', 'filled', 'MarkerEdgeColor', COLOR_NEEDLE, 'LineWidth', 2.5);
        end

        h_grasps_ml = gobjects(0);
        for k = 1:length(mtml_grasp_start)
            if mtml_grasp_start(k) <= t_now
                gx = grasp_nx_ml(k); gy = grasp_ny_ml(k); gz = grasp_nz_ml(k);
                if mtml_grasp_end(k) >= t_now
                    h = scatter3(ax_3d, gx, gy, gz, 250, 'o', 'filled', 'MarkerFaceColor', COLOR_MTML, 'MarkerEdgeColor', 'k', 'LineWidth', 2.0);
                    lbl = text(ax_3d, gx, gy, gz + 0.003, sprintf('ML%d ACTIVE', k), 'Color', COLOR_MTML, 'FontSize', 8, 'FontWeight', 'bold');
                else
                    h = scatter3(ax_3d, gx, gy, gz, 120, 'o', 'filled', 'MarkerFaceColor', COLOR_MTML * 0.55, 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
                    lbl = text(ax_3d, gx, gy, gz + 0.003, sprintf('ML%d', k), 'Color', COLOR_MTML * 0.55, 'FontSize', 7);
                end
                h_grasps_ml(end+1) = h;
                h_labels{end+1} = lbl;
            end
        end

        h_grasps_mr = gobjects(0);
        for k = 1:length(mtmr_grasp_start)
            if mtmr_grasp_start(k) <= t_now
                gx = grasp_nx_mr(k); gy = grasp_ny_mr(k); gz = grasp_nz_mr(k);
                if mtmr_grasp_end(k) >= t_now
                    h = scatter3(ax_3d, gx, gy, gz, 250, 's', 'filled', 'MarkerFaceColor', COLOR_MTMR, 'MarkerEdgeColor', 'k', 'LineWidth', 2.0);
                    lbl = text(ax_3d, gx, gy, gz + 0.003, sprintf('MR%d ACTIVE', k), 'Color', COLOR_MTMR, 'FontSize', 8, 'FontWeight', 'bold');
                else
                    h = scatter3(ax_3d, gx, gy, gz, 120, 's', 'filled', 'MarkerFaceColor', COLOR_MTMR * 0.55, 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
                    lbl = text(ax_3d, gx, gy, gz + 0.003, sprintf('MR%d', k), 'Color', COLOR_MTMR * 0.55, 'FontSize', 7);
                end
                h_grasps_mr(end+1) = h;
                h_labels{end+1} = lbl;
            end
        end

        xlim(ax_3d, x_lim); ylim(ax_3d, y_lim); zlim(ax_3d, z_lim);
        view(ax_3d, current_view(1), current_view(2));
        title(ax_3d, sprintf('Needle Trajectory  t = %.2f s', t_now));
        hold(ax_3d, 'off');

        cla(ax_mtml); hold(ax_mtml, 'on');
        plot(ax_mtml, mtml_t, mtml_pos, 'Color', [COLOR_MTML, 0.3], 'LineWidth', 0.8);
        if any(idx_L)
            plot(ax_mtml, mtml_t(idx_L), mtml_pos(idx_L), 'Color', COLOR_MTML, 'LineWidth', 1.5);
        end
        xline(ax_mtml, t_now, 'r', 'LineWidth', 1.5);
        yline(ax_mtml, -0.5, '--k', 'LineWidth', 0.8);
        for k = 1:length(mtml_grasp_start)
            xr = xregion(ax_mtml, mtml_grasp_start(k), mtml_grasp_end(k));
            xr.FaceColor = COLOR_MTML; xr.FaceAlpha = 0.15; xr.EdgeColor = 'none';
        end
        ylabel(ax_mtml, 'rad'); title(ax_mtml, 'MTML Gripper');
        xlim(ax_mtml, [0, t_end]); grid(ax_mtml, 'on'); hold(ax_mtml, 'off');

        cla(ax_mtmr); hold(ax_mtmr, 'on');
        plot(ax_mtmr, mtmr_t, mtmr_pos, 'Color', [COLOR_MTMR, 0.3], 'LineWidth', 0.8);
        if any(idx_R)
            plot(ax_mtmr, mtmr_t(idx_R), mtmr_pos(idx_R), 'Color', COLOR_MTMR, 'LineWidth', 1.5);
        end
        xline(ax_mtmr, t_now, 'r', 'LineWidth', 1.5);
        yline(ax_mtmr, -0.5, '--k', 'LineWidth', 0.8);
        for k = 1:length(mtmr_grasp_start)
            xr = xregion(ax_mtmr, mtmr_grasp_start(k), mtmr_grasp_end(k));
            xr.FaceColor = COLOR_MTMR; xr.FaceAlpha = 0.15; xr.EdgeColor = 'none';
        end
        ylabel(ax_mtmr, 'rad'); title(ax_mtmr, 'MTMR Gripper');
        xlim(ax_mtmr, [0, t_end]); grid(ax_mtmr, 'on'); hold(ax_mtmr, 'off');

        cla(ax_xyz); hold(ax_xyz, 'on');
        plot(ax_xyz, needle_t, needle_x, 'Color', [1, 0.7, 0.7], 'LineWidth', 0.6);
        plot(ax_xyz, needle_t, needle_y, 'Color', [0.7, 1, 0.7], 'LineWidth', 0.6);
        plot(ax_xyz, needle_t, needle_z, 'Color', [0.7, 0.8, 1], 'LineWidth', 0.6);
        if ~isempty(idx_n)
            plot(ax_xyz, needle_t(idx_n), needle_x(idx_n), 'r', 'LineWidth', 1.5);
            plot(ax_xyz, needle_t(idx_n), needle_y(idx_n), 'g', 'LineWidth', 1.5);
            plot(ax_xyz, needle_t(idx_n), needle_z(idx_n), 'b', 'LineWidth', 1.5);
        end
        xline(ax_xyz, t_now, 'r', 'LineWidth', 1.5);
        xlabel(ax_xyz, 'Time (s)'); ylabel(ax_xyz, 'm');
        title(ax_xyz, 'Needle XYZ');
        xlim(ax_xyz, [0, t_end]); grid(ax_xyz, 'on');
        %legend(ax_xyz, 'X', 'Y', 'Z', 'Location', 'northeast', 'FontSize', 7);
        hold(ax_xyz, 'off');

        drawnow limitrate;
    end

    function play_cb(~, ~)
        if is_playing, return; end
        is_playing = true;
        stop_flag  = false;
        speed = str2double(get(speed_box, 'String'));
        if isnan(speed) || speed <= 0, speed = 1.0; end
        dt    = 0.2;
        t_now = get(slider, 'Value');
        while t_now < t_end && ~stop_flag && isvalid(fig)
            t_now = t_now + dt * speed;
            update_plot(t_now);
            pause(dt);
        end
        is_playing = false;
    end

    function stop_cb(~, ~)
        stop_flag  = true;
        is_playing = false;
    end

end