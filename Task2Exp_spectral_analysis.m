clear; close all; clc;

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';

load(fullfile(base_path,'Task2exit_ps_allExp_struct.mat'));
load(fullfile(base_path,'Task2grasp_ps_allExp_struct.mat'));

subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
nSubj     = length(subjects);
NUM_REPS  = 20;
NUM_POINTS = 4;
NUM_SLOTS  = NUM_REPS * NUM_POINTS;

freq_axis = Task2_exit_allExp{1}.freq;
time_ERS  = Task2_exit_allExp{1}.time;
time_ERD  = Task2_grasp_allExp{1}.time;

ROI.MotorLeft  = [15, 20, 10];
ROI.MotorRight = [13, 19, 9];
ROI.Visual     = [29, 30, 31];
ROI.Frontal    = [4,  5,  6];
roi_names = fieldnames(ROI);
nROI      = numel(roi_names);

fit_lo = find(freq_axis >= 4,  1,'first');
fit_hi = find(freq_axis <= 35, 1,'last');
freq_fit = freq_axis(fit_lo:fit_hi);
nFreqFit = length(freq_fit);
log_f    = log10(freq_fit(:));

t_ERS_s = find(time_ERS >= -2.0, 1,'first');
t_ERS_e = find(time_ERS <=  0.0, 1,'last');
t_ERD_s = find(time_ERD >= -0.5, 1,'first');
t_ERD_e = find(time_ERD <=  1.0, 1,'last');

slot_idx = @(rep,pt) (rep-1)*NUM_POINTS + pt;

% Storage: corrected spectrum per subject per ROI per slot
% [nSubj x nROI x nFreqFit x NUM_SLOTS]
CorrSpec_exit  = nan(nSubj, nROI, nFreqFit, NUM_SLOTS);
CorrSpec_grasp = nan(nSubj, nROI, nFreqFit, NUM_SLOTS);
PeakFreq_exit  = nan(nSubj, nROI, NUM_SLOTS);
PeakFreq_grasp = nan(nSubj, nROI, NUM_SLOTS);
PeakAmp_exit   = nan(nSubj, nROI, NUM_SLOTS);
PeakAmp_grasp  = nan(nSubj, nROI, NUM_SLOTS);

for s = 1:nSubj
    fou_exit  = Task2_exit_allExp{s}.fourierspctrm;
    fou_grasp = Task2_grasp_allExp{s}.fourierspctrm;
    pow_exit  = abs(fou_exit).^2;
    pow_grasp = abs(fou_grasp).^2;

    for r = 1:nROI
        chan_idx = ROI.(roi_names{r});

        for rep = 1:NUM_REPS
            for pt = 1:NUM_POINTS
                slot = slot_idx(rep, pt);

                % --- EXIT ---
                pow_slot = squeeze(nanmean(pow_exit(slot, chan_idx, :, :), 2));
                % [nFreq x nTime] after averaging channels
                if size(pow_slot,1) == 3
                    pow_slot = squeeze(nanmean(pow_exit(slot, chan_idx, :, :), 1));
                    % handle squeeze edge case
                end
                spec = nanmean(pow_slot(:, t_ERS_s:t_ERS_e), 2);
                % [nFreq x 1]
                spec_fit  = spec(fit_lo:fit_hi);
                log_s     = log10(spec_fit(:));
                valid     = ~isnan(log_s) & ~isinf(log_s);
                if sum(valid) < 5, continue; end
                p         = polyfit(log_f(valid), log_s(valid), 1);
                fit_line  = polyval(p, log_f);
                corrected = log_s - fit_line;
                corrected(~valid) = NaN;
                CorrSpec_exit(s, r, :, slot) = corrected;

                [pk_amp, pk_idx] = max(corrected);
                PeakFreq_exit(s, r, slot) = freq_fit(pk_idx);
                PeakAmp_exit(s,  r, slot) = pk_amp;

                % --- GRASP ---
                pow_slot_g = squeeze(nanmean(pow_grasp(slot, chan_idx, :, :), 2));
                if size(pow_slot_g,1) == 3
                    pow_slot_g = squeeze(nanmean(pow_grasp(slot, chan_idx, :, :), 1));
                end
                spec_g    = nanmean(pow_slot_g(:, t_ERD_s:t_ERD_e), 2);
                spec_fit_g = spec_g(fit_lo:fit_hi);
                log_sg    = log10(spec_fit_g(:));
                valid_g   = ~isnan(log_sg) & ~isinf(log_sg);
                if sum(valid_g) < 5, continue; end
                p_g       = polyfit(log_f(valid_g), log_sg(valid_g), 1);
                fit_line_g = polyval(p_g, log_f);
                corr_g    = log_sg - fit_line_g;
                corr_g(~valid_g) = NaN;
                CorrSpec_grasp(s, r, :, slot) = corr_g;

                [pk_amp_g, pk_idx_g] = max(corr_g);
                PeakFreq_grasp(s, r, slot) = freq_fit(pk_idx_g);
                PeakAmp_grasp(s,  r, slot) = pk_amp_g;
            end
        end
    end
    fprintf('Subject %s done\n', subjects{s});
end

save(fullfile(base_path,'Task2_CorrSpec_Experts.mat'), ...
    'CorrSpec_exit','CorrSpec_grasp', 'PeakFreq_exit','PeakFreq_grasp', ...
    'PeakAmp_exit','PeakAmp_grasp','freq_fit','roi_names','subjects');
fprintf('Saved.\n');

%% FIGURE 1: Mean corrected spectrum per subject per ROI
% averaged across all slots — all subjects overlaid — color by subject
% line style by peak band: solid=alpha(8-14) dashed=low-beta(14-20)
colors_subj = lines(nSubj);
epoch_labels = {'Exit epoch','Grasp epoch'};
CorrSpec_list = {CorrSpec_exit, CorrSpec_grasp};

figure('Position',[50 50 1400 800]);
for ep = 1:2
    CS = CorrSpec_list{ep};
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        hold on;
        for s = 1:nSubj
            mean_spec = squeeze(nanmean(CS(s, r, :, :), 4));
            % [nFreqFit x 1]
            if all(isnan(mean_spec)), continue; end

            [~, pk_idx] = max(mean_spec);
            pk_freq     = freq_fit(pk_idx);

            if pk_freq >= 8 && pk_freq <= 14
                ls = '-';   band_str = 'α';
            elseif pk_freq > 14 && pk_freq <= 20
                ls = '--';  band_str = 'β';
            else
                ls = ':';   band_str = '?';
            end

            plot(freq_fit, mean_spec, ls, 'Color', [colors_subj(s,:) 0.85], ...
                'LineWidth', 1.8, 'DisplayName', sprintf('%s (%s=%.1fHz)', subjects{s}, band_str, pk_freq));
            scatter(pk_freq, mean_spec(pk_idx), 60, colors_subj(s,:), 'v','filled','HandleVisibility','off');
        end
        yline(0,'k--','LineWidth',0.8,'HandleVisibility','off');
        xline(8,  'k:','LineWidth',0.8,'HandleVisibility','off');
        xline(14, 'k:','LineWidth',0.8,'HandleVisibility','off');
        xline(20, 'k:','LineWidth',0.8,'HandleVisibility','off');
        yl = ylim;
        text(11, yl(2)*0.92, 'α','FontSize',9,'HorizontalAlignment','center');
        text(17, yl(2)*0.92, 'β','FontSize',9,'HorizontalAlignment','center');
        xlabel('Frequency (Hz)'); ylabel('Corrected power (log)');
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
        legend('Location','northeast','FontSize',6);
        grid on; hold off;
    end
end
sgtitle('Aperiodic-corrected spectrum — all subjects overlaid — solid=alpha peak  dashed=beta peak');

%% FIGURE 2: Peak frequency across repetitions (learning curve)
% averaged across 4 suture points per repetition
figure('Position',[50 50 1400 800]);
for ep = 1:2
    if ep==1, PF = PeakFreq_exit;  else, PF = PeakFreq_grasp; end
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        hold on;
        for s = 1:nSubj
            pf_reps = nan(NUM_REPS,1);
            for rep = 1:NUM_REPS
                slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                vals  = squeeze(PF(s, r, slots));
                pf_reps(rep) = nanmean(vals);
            end
            if all(isnan(pf_reps)), continue; end
            plot(1:NUM_REPS, pf_reps, 'o-', 'Color',[colors_subj(s,:) 0.8], ...
                'LineWidth',1.2,'MarkerSize',4,'DisplayName',subjects{s});
        end
        yline(8,  'k:','LineWidth',0.8,'HandleVisibility','off');
        yline(14, 'k:','LineWidth',0.8,'HandleVisibility','off');
        yline(20, 'k:','LineWidth',0.8,'HandleVisibility','off');
        xlabel('Repetition'); ylabel('Peak freq (Hz)');
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
        xticks(1:NUM_REPS); grid on; hold off;
    end
end
sgtitle('Peak frequency across 20 repetitions — each line = one subject');
legend(subjects,'Location','eastoutside','FontSize',7);

%% FIGURE 3: Peak frequency across suture points
% averaged across all repetitions
figure('Position',[50 50 1400 800]);
for ep = 1:2
    if ep==1, PF = PeakFreq_exit;  else, PF = PeakFreq_grasp; end
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        hold on;
        for s = 1:nSubj
            pf_pts = nan(NUM_POINTS,1);
            for pt = 1:NUM_POINTS
                slots = arrayfun(@(rep) slot_idx(rep,pt), 1:NUM_REPS);
                vals  = squeeze(PF(s, r, slots));
                pf_pts(pt) = nanmean(vals);
            end
            if all(isnan(pf_pts)), continue; end
            plot(1:NUM_POINTS, pf_pts, 'o-', 'Color',[colors_subj(s,:) 0.8], ...
                'LineWidth',1.5,'MarkerSize',6,'DisplayName',subjects{s});
        end
        yline(8,  'k:','LineWidth',0.8,'HandleVisibility','off');
        yline(14, 'k:','LineWidth',0.8,'HandleVisibility','off');
        xlabel('Suture point'); ylabel('Peak freq (Hz)');
        xticks(1:4); xticklabels({'Pt1','Pt2','Pt3','Pt4'});
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
        grid on; hold off;
    end
end
sgtitle('Peak frequency across suture points — averaged across 20 reps');

%% FIGURE 4: Peak amplitude across repetitions (learning effect on peak strength)
figure('Position',[50 50 1400 800]);
for ep = 1:2
    if ep==1, PA = PeakAmp_exit;  else, PA = PeakAmp_grasp; end
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        hold on;
        for s = 1:nSubj
            pa_reps = nan(NUM_REPS,1);
            for rep = 1:NUM_REPS
                slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                vals  = squeeze(PA(s, r, slots));
                pa_reps(rep) = nanmean(vals);
            end
            if all(isnan(pa_reps)), continue; end
            plot(1:NUM_REPS, pa_reps, 'o-', 'Color',[colors_subj(s,:) 0.8], ...
                'LineWidth',1.2,'MarkerSize',4,'DisplayName',subjects{s});
        end
        xlabel('Repetition'); ylabel('Peak amplitude (log)');
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}), 'Interpreter','none','FontSize',8);
        xticks(1:NUM_REPS); grid on; hold off;
    end
end
sgtitle('Peak amplitude across 20 repetitions — higher = stronger oscillatory peak');

%% PRINT SUMMARY TABLE
fprintf('\n=== Mean peak frequency per subject per ROI (Task2, exit epoch) ===\n');
fprintf('%-8s', 'Subject');
for r = 1:nROI, fprintf('  %-12s', roi_names{r}); end
fprintf('\n');
for s = 1:nSubj
    fprintf('%-8s', subjects{s});
    for r = 1:nROI
        vals = squeeze(PeakFreq_exit(s, r, :));
        fprintf('  %-12.1f', nanmean(vals));
    end
    fprintf('\n');
end