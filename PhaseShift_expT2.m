clear; close all; clc;

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
load(fullfile(base_path, 'Task2exit_Phase_allExpSbj.mat'));
load(fullfile(base_path, 'Task2grasp_Phase_allExpSbj.mat'));

subjects      = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
nSubj         = length(subjects);
NUM_SCENARIOS =20;
NUM_POINTS    = 4;

freq_axis = 2:0.5:40;
nFreq     = length(freq_axis);

time_ERS = -2.5:0.05:0.5;
time_ERD = -0.8:0.05:1.5;

t_ERS_s = find(time_ERS >= -2.0, 1, 'first');
t_ERS_e = find(time_ERS <=  0.0, 1, 'last');
t_ERD_s = find(time_ERD >= -0.5, 1, 'first');
t_ERD_e = find(time_ERD <=  1.0, 1, 'last');

bs = find(freq_axis == 15);
be = find(freq_axis == 25);

ROI.MotorLeft  = [15, 20, 10];
ROI.MotorRight = [13, 19, 9];
ROI.Visual     = [29, 30, 31];
ROI.Frontal    = [4,  5,  6];
roi_names = fieldnames(ROI);
nROI      = numel(roi_names);

% Option A: PLV across subjects [nROI x nFreq x NUM_SCENARIOS x NUM_POINTS]
PLV_exit_groupA        = nan(nROI, nFreq, NUM_SCENARIOS, NUM_POINTS);
PLV_grasp_groupA       = nan(nROI, nFreq, NUM_SCENARIOS, NUM_POINTS);
MeanPhase_exit_groupA  = nan(nROI, nFreq, NUM_SCENARIOS, NUM_POINTS);
MeanPhase_grasp_groupA = nan(nROI, nFreq, NUM_SCENARIOS, NUM_POINTS);

% Option B: PLV within subject across points [nSubj x nROI x nFreq x NUM_SCENARIOS]
PLV_exit_withinB        = nan(nSubj, nROI, nFreq, NUM_SCENARIOS);
PLV_grasp_withinB       = nan(nSubj, nROI, nFreq, NUM_SCENARIOS);
MeanPhase_exit_withinB  = nan(nSubj, nROI, nFreq, NUM_SCENARIOS);
MeanPhase_grasp_withinB = nan(nSubj, nROI, nFreq, NUM_SCENARIOS);

for r = 1:nROI
    chan_idx = ROI.(roi_names{r});
    fprintf('ROI %s\n', roi_names{r});

    for sc = 1:NUM_SCENARIOS

        % --- OPTION A ---
        for pt = 1:NUM_POINTS
            slot = (sc-1)*NUM_POINTS + pt;

            % Exit: [nSubj x 3 x nFreq x nTime_win] -> mean channels -> [nSubj x nFreq x nTime_win]
            ph_exit = squeeze(nanmean(Task2exit_Phase_allSbj(:, slot, chan_idx, :, t_ERS_s:t_ERS_e), 3));
            % PLV at each (freq, time): abs(mean across subjects) -> [nFreq x nTime_win]
            valid = ~isnan(ph_exit(:,1,1));
            if sum(valid) >= 3
                plv_ft = abs(nanmean(ph_exit(valid,:,:), 1));
                % [1 x nFreq x nTime_win] -> average over time -> [nFreq]
                PLV_exit_groupA(r,:,sc,pt) = squeeze(nanmean(plv_ft, 3));
                % mean phase: angle of mean across subjects then time
                mp_ft = angle(nanmean(ph_exit(valid,:,:), 1));
                MeanPhase_exit_groupA(r,:,sc,pt) = squeeze(nanmean(mp_ft, 3));
            end

            % Grasp
            ph_grasp = squeeze(nanmean(Task2grasp_Phase_allSbj(:, slot, chan_idx, :, t_ERD_s:t_ERD_e), 3));
            valid = ~isnan(ph_grasp(:,1,1));
            if sum(valid) >= 3
                plv_ft = abs(nanmean(ph_grasp(valid,:,:), 1));
                PLV_grasp_groupA(r,:,sc,pt) = squeeze(nanmean(plv_ft, 3));
                mp_ft = angle(nanmean(ph_grasp(valid,:,:), 1));
                MeanPhase_grasp_groupA(r,:,sc,pt) = squeeze(nanmean(mp_ft, 3));
            end
        end

        % --- OPTION B ---
        for s = 1:nSubj
            % collect phase at each point: average channels, then average time
            % keep time resolution for PLV computation across points
            ph_exit_pts  = nan(NUM_POINTS, nFreq, t_ERS_e-t_ERS_s+1);
            ph_grasp_pts = nan(NUM_POINTS, nFreq, t_ERD_e-t_ERD_s+1);

            for pt = 1:NUM_POINTS
                slot = (sc-1)*NUM_POINTS + pt;

                tmp = squeeze(nanmean(Task2exit_Phase_allSbj(s, slot, chan_idx, :, t_ERS_s:t_ERS_e), 3));
                % [nFreq x nTime_win]
                if ~all(isnan(tmp(:)))
                    ph_exit_pts(pt,:,:) = tmp;
                end

                tmp = squeeze(nanmean(Task2grasp_Phase_allSbj(s, slot, chan_idx, :, t_ERD_s:t_ERD_e), 3));
                if ~all(isnan(tmp(:)))
                    ph_grasp_pts(pt,:,:) = tmp;
                end
            end

            % PLV across points: abs(mean across points) at each (freq,time), then average time
            valid_exit  = ~isnan(ph_exit_pts(:,1,1));
            valid_grasp = ~isnan(ph_grasp_pts(:,1,1));

            if sum(valid_exit) >= 2
                plv_ft = abs(nanmean(ph_exit_pts(valid_exit,:,:), 1));
                % [1 x nFreq x nTime_win]
                PLV_exit_withinB(s,r,:,sc) = squeeze(nanmean(plv_ft, 3));
                mp_ft = angle(nanmean(ph_exit_pts(valid_exit,:,:), 1));
                MeanPhase_exit_withinB(s,r,:,sc) = squeeze(nanmean(mp_ft, 3));
            end

            if sum(valid_grasp) >= 2
                plv_ft = abs(nanmean(ph_grasp_pts(valid_grasp,:,:), 1));
                PLV_grasp_withinB(s,r,:,sc) = squeeze(nanmean(plv_ft, 3));
                mp_ft = angle(nanmean(ph_grasp_pts(valid_grasp,:,:), 1));
                MeanPhase_grasp_withinB(s,r,:,sc) = squeeze(nanmean(mp_ft, 3));
            end
        end
    end
end

save(fullfile(base_path,'PhaseAnalysis_Task2_Experts.mat'), 'PLV_exit_groupA','PLV_grasp_groupA', ...
    'PLV_exit_withinB','PLV_grasp_withinB', 'MeanPhase_exit_groupA','MeanPhase_grasp_groupA', ...
    'MeanPhase_exit_withinB','MeanPhase_grasp_withinB', 'roi_names','freq_axis','subjects');
fprintf('Saved.\n');

%% FIGURE 1: Group PLV heatmap — beta band — scenario x point
figure('Position',[50 50 1400 700]);
epoch_labels = {'Exit (ERS)','Grasp (ERD)'};
PLV_A_list   = {PLV_exit_groupA, PLV_grasp_groupA};
for ep = 1:2
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        mat = squeeze(nanmean(PLV_A_list{ep}(r, bs:be, :, :), 2));
        imagesc(1:NUM_POINTS, 1:NUM_SCENARIOS, mat, [0 1]);
        colorbar; colormap(hot);
        xlabel('Suture point'); ylabel('Scenario');
        xticks(1:4); xticklabels({'Pt1','Pt2','Pt3','Pt4'});
        yticks(1:6); yticklabels(arrayfun(@(x) sprintf('Scn%d',x),1:6,'UniformOutput',false));
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
    end
end
sgtitle('Group PLV across subjects — beta band — hot=high consistency');

%% FIGURE 2: Within-subject PLV across points per scenario — beta band
figure('Position',[50 50 1400 700]);
PLV_B_list = {PLV_exit_withinB, PLV_grasp_withinB};
for ep = 1:2
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        hold on;
        plv_beta = squeeze(nanmean(PLV_B_list{ep}(:, r, bs:be, :), 3));
        for sc = 1:NUM_SCENARIOS
            vals  = plv_beta(:,sc);
            valid = ~isnan(vals);
            if sum(valid) < 2, continue; end
            scatter(sc*ones(sum(valid),1), vals(valid), 30, [0.6 0.6 0.9], 'filled', 'MarkerFaceAlpha',0.6);
            errorbar(sc, nanmean(vals), nanstd(vals)/sqrt(sum(valid)), 'ko', 'LineWidth',2, 'MarkerFaceColor','k', 'MarkerSize',6);
        end
        xlabel('Scenario'); ylabel('PLV');
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
        xticks(1:6); ylim([0 1]); grid on; hold off;
    end
end
sgtitle('Within-subject PLV across suture points — beta band');

%% FIGURE 3: Mean phase per scenario — polar — beta band
figure('Position',[50 50 1400 700]);
colors_sc  = lines(NUM_SCENARIOS);
Ph_A_list  = {MeanPhase_exit_groupA, MeanPhase_grasp_groupA};

left_vals   = linspace(0.05, 0.75, nROI);
width_val   = 0.18;
height_val  = 0.35;
bottom_vals = [0.57, 0.10];

for ep = 1:2
    for r = 1:nROI
        ax = polaraxes('Position', [left_vals(r), bottom_vals(ep), width_val, height_val]);
        hold(ax, 'on');
        for sc = 1:NUM_SCENARIOS
            ph_beta  = nanmean(nanmean(Ph_A_list{ep}(r, bs:be, sc, :), 2), 4);
            plv_beta = nanmean(nanmean(PLV_A_list{ep}(r, bs:be, sc, :), 2), 4);
            if ~isnan(ph_beta)
                polarplot(ax, [0 ph_beta], [0 plv_beta], 'LineWidth', 2, 'Color', colors_sc(sc,:), 'DisplayName', sprintf('Scn%d',sc));
            end
        end
        title(ax, sprintf('%s\n%s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
        rlim(ax, [0 1]);
        hold(ax, 'off');
    end
end
sgtitle('Mean phase direction — spoke length = PLV — beta band');
legend(arrayfun(@(x) sprintf('Scn%d',x), 1:NUM_SCENARIOS, 'UniformOutput',false), 'Position',[0.92 0.4 0.06 0.2]);

%% STATISTICS
fprintf('\n=== Kruskal-Wallis: within-subject PLV across scenarios ===\n');
fprintf('%-14s  %-12s  %-8s  %-6s\n','ROI','Epoch','p_KW','sig');
for ep = 1:2
    for r = 1:nROI
        plv_beta = squeeze(nanmean(PLV_B_list{ep}(:,r,bs:be,:), 3));
        y = plv_beta(:);
        g = repmat(1:NUM_SCENARIOS, nSubj, 1); g = g(:);
        valid = ~isnan(y);
        if sum(valid) < 6, continue; end
        p_kw = kruskalwallis(y(valid), g(valid), 'off');
        sig_str = ''; if p_kw < 0.05, sig_str = '*'; end; if p_kw < 0.01, sig_str = '**'; end
        fprintf('%-14s  %-12s  %-8.4f  %s\n', roi_names{r}, epoch_labels{ep}, p_kw, sig_str);
    end
end

fprintf('\n=== Friedman: group PLV across suture points ===\n');
fprintf('%-14s  %-12s  %-8s  %-6s\n','ROI','Epoch','p_Fr','sig');
for ep = 1:2
    for r = 1:nROI
        mat = squeeze(nanmean(PLV_A_list{ep}(r, bs:be, :, :), 2));
        valid_rows = ~any(isnan(mat), 2);
        if sum(valid_rows) < 2, continue; end
        p_fr = friedman(mat(valid_rows,:), 1, 'off');
        sig_str = ''; if p_fr < 0.05, sig_str = '*'; end; if p_fr < 0.01, sig_str = '**'; end
        fprintf('%-14s  %-12s  %-8.4f  %s\n', roi_names{r}, epoch_labels{ep}, p_fr, sig_str);
    end
end