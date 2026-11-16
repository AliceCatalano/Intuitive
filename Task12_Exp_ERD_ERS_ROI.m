% Task_ERD_ERS_ROI.m
% Computes beta AND high-alpha ERD, ERS and modulation. Results split by ROI: MotorLeft, MotorRight, Visual, Frontal
% Switch between Task1 (6 scenarios x 4 points = 24 slots) and Task2 (20 reps     x 4 points = 80 slots)
% by commenting/uncommenting the marked sections below

clear, close all
%% TASK SELECTION — comment/uncomment one block

% --- TASK 1 ---
base_path    = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
load(fullfile(base_path, 'Task1grasp_Exp_allSbj.mat'));
load(fullfile(base_path, 'Task1exit_Exp_allSbj.mat'));
grasp_data   = Task1grasp_Exp_allSbj;
exit_data    = Task1exit_Exp_allSbj;
NUM_OUTER    = 6;    % scenarios
outer_label  = 'Scenario';
outer_ticks  = arrayfun(@(x) sprintf('Scn%d',x),  1:6,  'UniformOutput',false);
save_suffix  = 'Task1';

% --- TASK 2 ---
% base_path    = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
% load(fullfile(base_path, 'Task2grasp_Exp_allSbj.mat'));
% load(fullfile(base_path, 'Task2exit_Exp_allSbj.mat'));
% grasp_data   = Task2grasp_Exp_allSbj;
% exit_data    = Task2exit_Exp_allSbj;
% NUM_OUTER    = 20;   % repetitions
% outer_label  = 'Repetition';
% outer_ticks  = arrayfun(@(x) sprintf('Rep%02d',x), 1:20, 'UniformOutput',false);
% save_suffix  = 'Task2';

nSubj      = size(grasp_data, 1);
nSlots     = size(grasp_data, 2);   % 24 or 80
NUM_POINTS = 4;

% ROI definitions
ROI.MotorLeft  = [15, 20, 10];
ROI.MotorRight = [13, 19, 9];
ROI.Visual     = [29, 30, 31];
ROI.Frontal    = [4,  5,  6];
roi_names      = fieldnames(ROI);
nROI           = numel(roi_names);

% Band definitions
% Each row: [fmin fmax label bs_idx be_idx] — indices computed below
BANDS(1).name  = 'Beta';
BANDS(1).fmin  = 15;
BANDS(1).fmax  = 25;
BANDS(2).name  = 'Alpha';
BANDS(2).fmin  = 8;
BANDS(2).fmax  = 15;
nBands         = numel(BANDS);

freq = 2:0.5:40;
for b = 1:nBands
    BANDS(b).bs = find(freq >= BANDS(b).fmin, 1, 'first');
    BANDS(b).be = find(freq <= BANDS(b).fmax, 1, 'last');
end

% Time windows
time_ERD = -0.8:0.05:1.5;
timeERDS = find(time_ERD >= -0.5, 1, 'first');
timeERDE = find(time_ERD <=  1.0, 1, 'last');

time_ERS = -2.5:0.05:0.5;
timeERSS = find(time_ERS >= -2.0, 1, 'first');
timeERSE = find(time_ERS <=  0.0, 1, 'last');

% Output arrays: (nBands x nROI x nSubj x nSlots)
ERD_all = nan(nBands, nROI, nSubj, nSlots);
ERS_all = nan(nBands, nROI, nSubj, nSlots);
Mod_all = nan(nBands, nROI, nSubj, nSlots);

for b = 1:nBands
    bs = BANDS(b).bs;
    be = BANDS(b).be;
    fprintf('\n--- Band: %s (%d-%d Hz) ---\n', BANDS(b).name, BANDS(b).fmin, BANDS(b).fmax);

    for r = 1:nROI
        roi_ch = ROI.(roi_names{r});
        fprintf('  ROI: %s\n', roi_names{r});

        for i = 1:nSubj
            for j = 1:nSlots

                % ERD
                erdPow = squeeze(grasp_data(i, j, roi_ch, :, :));
                % (nROIchan x nFreq x nTime)
                if ~all(isnan(erdPow(:)))
                    roi_mean = squeeze(nanmean(erdPow, 1));   % (nFreq x nTime)
                    ERD_all(b,r,i,j) = min(nanmean(roi_mean(bs:be, timeERDS:timeERDE), 1));
                end

                % ERS
                ersPow = squeeze(exit_data(i, j, roi_ch, :, :));
                if ~all(isnan(ersPow(:)))
                    roi_mean = squeeze(nanmean(ersPow, 1));
                    ERS_all(b,r,i,j) = max(nanmean(roi_mean(bs:be, timeERSS:timeERSE), 1));
                end

                % Modulation
                if ~isnan(ERD_all(b,r,i,j)) && ~isnan(ERS_all(b,r,i,j))
                    Mod_all(b,r,i,j) = abs(ERS_all(b,r,i,j) - ERD_all(b,r,i,j));
                end
            end
        end
    end
end

save(fullfile(base_path, ['ERD_ERS_Modulation_' save_suffix '_ROI_bands.mat']),'ERD_all','ERS_all','Mod_all','roi_names','BANDS','subjects','-v7.3');
fprintf('\n=== SAVED: ERD_ERS_Modulation_%s_ROI_bands.mat ===\n', save_suffix);

%% PLOTS
metrics     = {'ERD','ERS','Modulation'};
data_fields = {ERD_all, ERS_all, Mod_all};
pt_labels   = {'Pt1','Pt2','Pt3','Pt4'};
COLORS_ROI  = lines(nROI);
COLORS_BAND = [0.2 0.4 0.8; 0.8 0.3 0.1];

% Helper: compute shared ylim for a set of values
get_ylim = @(vals) deal( ...
    min(vals(~isnan(vals))) - 0.05*range(vals(~isnan(vals))), ...
    max(vals(~isnan(vals))) + 0.05*range(vals(~isnan(vals))));

for b = 1:nBands
    band_label = BANDS(b).name;

    %% -- Compute ylims PER FIGURE for this band --

    % Figure 1 & 2: collect all values across ROIs for each metric
    ylims_curve = nan(3,2);   % learning curve figure
    ylims_point = nan(3,2);   % per suture point figure
    ylims_heat  = nan(3,2);   % heatmap figure

    for m = 1:3
        D = data_fields{m};

        % All ROI values for this band → used for curve and point figures
        all_vals = squeeze(D(b,:,:,:));
        all_vals = all_vals(:);
        all_vals = all_vals(~isnan(all_vals));
        if ~isempty(all_vals)
            pad = 0.05 * range(all_vals);
            ylims_curve(m,:) = [min(all_vals)-pad, max(all_vals)+pad];
            ylims_point(m,:) = ylims_curve(m,:);
            ylims_heat(m,:)  = ylims_curve(m,:);
        end
    end

    % Figure 4 (band comparison): same idea but across both bands
    ylims_bandcomp = nan(3,2);
    for m = 1:3
        D = data_fields{m};
        all_vals = D(:);   % all bands, all ROIs
        all_vals = all_vals(~isnan(all_vals));
        if ~isempty(all_vals)
            pad = 0.05 * range(all_vals);
            ylims_bandcomp(m,:) = [min(all_vals)-pad, max(all_vals)+pad];
        end
    end

    %% Plot 1: learning curve — rows=ROI, cols=metric
    figure('Name', sprintf('%s — %s — learning curve', save_suffix, band_label), 'Position', [50 50 1400 900]);

    for r = 1:nROI
        for m = 1:3
            subplot(nROI, 3, (r-1)*3 + m);
            hold on;

            D      = data_fields{m};
            D_subj = squeeze(D(b,r,:,:));
            D_3d = reshape(D_subj, nSubj, NUM_POINTS, NUM_OUTER);  D_3d = permute(D_3d, [1 3 2]); ;
            D_out  = squeeze(nanmean(D_3d, 3));
            mn     = nanmean(D_out, 1);
            sd     = nanstd(D_out,  0, 1);

            fill([1:NUM_OUTER, NUM_OUTER:-1:1], ...
                 [mn+sd, fliplr(mn-sd)], ...
                 COLORS_ROI(r,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
            plot(1:NUM_OUTER, mn, 'o-', 'LineWidth', 2.0, 'Color', COLORS_ROI(r,:));


            xlim([0.5, NUM_OUTER+0.5]);
            xticks(1:NUM_OUTER);
            xticklabels(outer_ticks);
            xtickangle(45);
            grid on; box on;

            if r == 1, title(metrics{m}, 'FontSize',11,'FontWeight','bold'); end
            if m == 1, ylabel(roi_names{r}, 'FontSize',10,'FontWeight','bold'); end
            if r == nROI, xlabel(outer_label, 'FontSize',9); end
            hold off;
        end
    sgtitle(sprintf('%s — %s: learning curve (mean ± SD across suture points)', save_suffix, band_label), 'FontSize',13);
    end
    %% Plot 2: per suture point — rows=ROI, cols=metric
    figure('Name', sprintf('%s — %s — per suture point', save_suffix, band_label), ...
        'Position', [50 50 900 900]);

    for r = 1:nROI
        for m = 1:3
            subplot(nROI, 3, (r-1)*3 + m);
            hold on;

            D      = data_fields{m};
            D_subj = squeeze(D(b,r,:,:));
            D_3d = reshape(D_subj, nSubj, NUM_POINTS, NUM_OUTER);  D_3d = permute(D_3d, [1 3 2]); ;
            D_pt   = squeeze(nanmean(D_3d, 2));
            mn     = nanmean(D_pt, 1);
            sd     = nanstd(D_pt,  0, 1);

            fill([1:NUM_POINTS, NUM_POINTS:-1:1], ...
                 [mn+sd, fliplr(mn-sd)], ...
                 COLORS_ROI(r,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
            plot(1:NUM_POINTS, mn, 's-', 'LineWidth', 2.0, 'Color', COLORS_ROI(r,:));

            
            xlim([0.5, NUM_POINTS+0.5]);
            xticks(1:NUM_POINTS); xticklabels(pt_labels);
            grid on; box on;

            if r == 1, title(metrics{m}, 'FontSize',11,'FontWeight','bold'); end
            if m == 1, ylabel(roi_names{r}, 'FontSize',10,'FontWeight','bold'); end
            if r == nROI, xlabel('Suture point', 'FontSize',9); end
            hold off;
        end
    end
    sgtitle(sprintf('%s — %s: per suture point (mean ± SD across %s)', save_suffix, band_label, lower(outer_label)), 'FontSize',13);
     end

    %% Plot 3: heatmaps — rows=ROI, cols=metric
    figure('Name', sprintf('%s — %s — heatmaps', save_suffix, band_label), ...
        'Position', [50 50 1000 900]);

    for r = 1:nROI
        for m = 1:3
            D      = data_fields{m};
            D_subj = squeeze(D(b,r,:,:));
            D_3d = reshape(D_subj, nSubj, NUM_POINTS, NUM_OUTER);  D_3d = permute(D_3d, [1 3 2]); ;
            grid_d = squeeze(nanmean(D_3d, 1));

            subplot(nROI, 3, (r-1)*3 + m);
            imagesc(grid_d);
            colorbar;
            colormap(flipud(hot));
            xticks(1:NUM_POINTS);   xticklabels(pt_labels);
            yticks(1:2:NUM_OUTER);  yticklabels(outer_ticks(1:2:end));
            xlabel('Suture point', 'FontSize',8);

            if r == 1, title(metrics{m}, 'FontSize',11,'FontWeight','bold'); end
            if m == 1, ylabel(roi_names{r}, 'FontSize',10,'FontWeight','bold'); end
        end
    end
    sgtitle(sprintf('%s — %s: heatmaps %s x point',save_suffix, band_label, outer_label), 'FontSize',13);
end

%% Plot 4: Beta vs HighAlpha — rows=ROI, cols=metric
%  ylims shared within this figure only (across both bands)
figure('Name', sprintf('%s — Beta vs HighAlpha', save_suffix), 'Position', [50 50 1400 900]);

ylims_bandcomp = nan(3,2);
for m = 1:3
    D = data_fields{m};
    all_vals = D(:);
    all_vals = all_vals(~isnan(all_vals));
    if ~isempty(all_vals)
        pad = 0.05 * range(all_vals);
        ylims_bandcomp(m,:) = [min(all_vals)-pad, max(all_vals)+pad];
    end
end

for r = 1:nROI
    for m = 1:3
        subplot(nROI, 3, (r-1)*3 + m);
        hold on;

        for b = 1:nBands
            D      = data_fields{m};
            D_subj = squeeze(D(b,r,:,:));
            D_3d = reshape(D_subj, nSubj, NUM_POINTS, NUM_OUTER);  D_3d = permute(D_3d, [1 3 2]); ;
            D_out  = squeeze(nanmean(D_3d, 3));
            mn     = nanmean(D_out, 1);
            sd     = nanstd(D_out,  0, 1);

            fill([1:NUM_OUTER, NUM_OUTER:-1:1], ...
                 [mn+sd, fliplr(mn-sd)], ...
                 COLORS_BAND(b,:), 'FaceAlpha', 0.12, 'EdgeColor', 'none');
            plot(1:NUM_OUTER, mn, 'o-', 'LineWidth', 2.0, ...
                'Color', COLORS_BAND(b,:), 'DisplayName', BANDS(b).name);
        end

        
        xlim([0.5, NUM_OUTER+0.5]);
        xticks(1:NUM_OUTER);
        xticklabels(outer_ticks);
        xtickangle(45);
        grid on; box on;

        if r == 1
            title(metrics{m}, 'FontSize',11,'FontWeight','bold');
            if m == 3, legend('Location','best','FontSize',7); end
        end
        if m == 1, ylabel(roi_names{r}, 'FontSize',10,'FontWeight','bold'); end
        if r == nROI, xlabel(outer_label, 'FontSize',9); end
        hold off;
    end
end
sgtitle(sprintf('%s — Beta vs HighAlpha by ROI (mean ± SD across suture points)', ...
    save_suffix), 'FontSize',13);
