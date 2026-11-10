clear; close all; clc;

addpath('/home/acatalano/Documents/MATLAB/fooof_mat/fooof_mat/');

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
beh_path  = '/home/acatalano/Desktop/Intuitive/DataStructures';

load(fullfile(base_path,'Task2exit_ps_allExp_struct.mat'));
load(fullfile(base_path,'Task2grasp_ps_allExp_struct.mat'));
load(fullfile(beh_path,'NeedlePassageTimes_IE_T2.mat'));

subjects   = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
nSubj      = length(subjects);
NUM_REPS   = 20;
NUM_POINTS = 4;
NUM_SLOTS  = NUM_REPS * NUM_POINTS;
slot_idx   = @(rep,pt) (rep-1)*NUM_POINTS + pt;

freq_axis      = Task2_exit_allExp{1}.freq;
freq_axis_even = linspace(freq_axis(1), freq_axis(end), length(freq_axis));
time_ERS       = Task2_exit_allExp{1}.time;
time_ERD       = Task2_grasp_allExp{1}.time;

t_ERS_s = find(time_ERS >= -2.0, 1,'first');
t_ERS_e = find(time_ERS <=  0.0, 1,'last');
t_ERD_s = find(time_ERD >= -0.5, 1,'first');
t_ERD_e = find(time_ERD <=  1.0, 1,'last');

ROI.MotorLeft  = [15, 20, 10];
ROI.MotorRight = [13, 19, 9];
ROI.Visual     = [29, 30, 31];
ROI.Frontal    = [4,  5,  6];
roi_names = fieldnames(ROI);
nROI      = numel(roi_names);

fooof_settings = struct();
fooof_settings.peak_width_limits = [1 12];
fooof_settings.max_n_peaks       = 4;
fooof_settings.min_peak_height   = 0.05;
fooof_settings.peak_threshold    = 2.0;
fooof_settings.aperiodic_mode    = 'fixed';
freq_range = [4 35];

alpha_range = [8  15];
beta_range  = [15 25];

% Storage per epoch type, ROI, subject, slot
% Aperiodic: offset and exponent
% Alpha peak: cf, power, bw
% Beta peak:  cf, power, bw
fields = {'offset','exponent', ...
          'alpha_cf','alpha_pow','alpha_bw', ...
          'beta_cf','beta_pow','beta_bw', ...
          'r_squared'};

for ep = 1:2
    for f = 1:numel(fields)
        if ep==1
            FOOOF_exit.(fields{f})  = nan(nSubj, nROI, NUM_SLOTS);
        else
            FOOOF_grasp.(fields{f}) = nan(nSubj, nROI, NUM_SLOTS);
        end
    end
end

for s = 1:nSubj
    fprintf('Subject %s\n', subjects{s});

    fou_exit  = Task2_exit_allExp{s}.fourierspctrm;
    fou_grasp = Task2_grasp_allExp{s}.fourierspctrm;
    pow_exit  = abs(fou_exit).^2;
    pow_grasp = abs(fou_grasp).^2;

    for r = 1:nROI
        chan_idx = ROI.(roi_names{r});

        for rep = 1:NUM_REPS
            for pt = 1:NUM_POINTS
                slot = slot_idx(rep,pt);

                for ep = 1:2
                    if ep==1
                        pow_data = pow_exit;
                        t_s = t_ERS_s; t_e = t_ERS_e;
                    else
                        pow_data = pow_grasp;
                        t_s = t_ERD_s; t_e = t_ERD_e;
                    end

                    roi_pow = squeeze(nanmean(pow_data(slot, chan_idx, :, :), 2));
                    % [nFreq x nTime]
                    spec    = nanmean(roi_pow(:, t_s:t_e), 2)';
                    % [1 x nFreq]

                    if any(isnan(spec)) || any(spec <= 0)
                        continue;
                    end

                    spec_even = interp1(freq_axis, spec, freq_axis_even, 'linear');

                    try
                        fm = fooof(freq_axis_even, spec_even, freq_range, fooof_settings, false);
                    catch
                        continue;
                    end

                    if ep==1
                        FOOOF_exit.offset(s,r,slot)    = fm.aperiodic_params(1);
                        FOOOF_exit.exponent(s,r,slot)  = fm.aperiodic_params(2);
                        FOOOF_exit.r_squared(s,r,slot) = fm.r_squared;
                    else
                        FOOOF_grasp.offset(s,r,slot)    = fm.aperiodic_params(1);
                        FOOOF_grasp.exponent(s,r,slot)  = fm.aperiodic_params(2);
                        FOOOF_grasp.r_squared(s,r,slot) = fm.r_squared;
                    end

                    if isempty(fm.peak_params), continue; end

                    peaks = fm.peak_params;
                    % peaks: [n x 3] = [cf, power, bw]

                    % alpha peak: highest power peak with cf in alpha range
                    alpha_mask = peaks(:,1) >= alpha_range(1) & peaks(:,1) < alpha_range(2);
                    if any(alpha_mask)
                        alpha_peaks = peaks(alpha_mask,:);
                        [~,best]    = max(alpha_peaks(:,2));
                        if ep==1
                            FOOOF_exit.alpha_cf(s,r,slot)  = alpha_peaks(best,1);
                            FOOOF_exit.alpha_pow(s,r,slot) = alpha_peaks(best,2);
                            FOOOF_exit.alpha_bw(s,r,slot)  = alpha_peaks(best,3);
                        else
                            FOOOF_grasp.alpha_cf(s,r,slot)  = alpha_peaks(best,1);
                            FOOOF_grasp.alpha_pow(s,r,slot) = alpha_peaks(best,2);
                            FOOOF_grasp.alpha_bw(s,r,slot)  = alpha_peaks(best,3);
                        end
                    end

                    % beta peak
                    beta_mask = peaks(:,1) >= beta_range(1) & peaks(:,1) < beta_range(2);
                    if any(beta_mask)
                        beta_peaks = peaks(beta_mask,:);
                        [~,best]   = max(beta_peaks(:,2));
                        if ep==1
                            FOOOF_exit.beta_cf(s,r,slot)  = beta_peaks(best,1);
                            FOOOF_exit.beta_pow(s,r,slot) = beta_peaks(best,2);
                            FOOOF_exit.beta_bw(s,r,slot)  = beta_peaks(best,3);
                        else
                            FOOOF_grasp.beta_cf(s,r,slot)  = beta_peaks(best,1);
                            FOOOF_grasp.beta_pow(s,r,slot) = beta_peaks(best,2);
                            FOOOF_grasp.beta_bw(s,r,slot)  = beta_peaks(best,3);
                        end
                    end
                end
            end
        end
    end
end

save(fullfile(base_path,'Task2_FOOOF_Experts.mat'), 'FOOOF_exit','FOOOF_grasp','roi_names','subjects');
fprintf('Saved Task2_FOOOF_Experts.mat\n');

% BEHAVIORAL DATA: suture duration per rep per point
% ExitTimes and EntryTimes: [nSubj x NUM_REPS x NUM_SUTURES]
% suture_dur(s, rep, pt) = time from entry to exit
suture_dur = ExitTimes - EntryTimes;
% [nSubj x NUM_REPS x NUM_POINTS]

% mean duration per rep (averaged across 4 points)
mean_dur_per_rep = nanmean(suture_dur, 3);
% [nSubj x NUM_REPS]

% FIGURE 1: FOOOF parameters across 20 repetitions per ROI
% one line per subject, 4 panels per row: offset, exponent, alpha_pow, beta_pow
% rows: exit epoch / grasp epoch
param_list   = {'exponent','offset','alpha_pow','beta_pow','alpha_cf','beta_cf'};
param_labels = {'Aperiodic exponent','Aperiodic offset','Alpha power (above ap)','Beta power (above ap)','Alpha center freq (Hz)','Beta center freq (Hz)'};
colors_subj  = lines(nSubj);
epoch_labels = {'Exit epoch','Grasp epoch'};

for r = 1:nROI
    figure('Position',[50 50 1600 900]);
    for ep = 1:2
        if ep==1, FD = FOOOF_exit; else, FD = FOOOF_grasp; end
        for pp = 1:numel(param_list)
            subplot(2, numel(param_list), (ep-1)*numel(param_list)+pp);
            hold on;
            for s = 1:nSubj
                vals_per_rep = nan(NUM_REPS,1);
                for rep = 1:NUM_REPS
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    v = squeeze(FD.(param_list{pp})(s,r,slots));
                    vals_per_rep(rep) = nanmean(v);
                end
                if all(isnan(vals_per_rep)), continue; end
                plot(1:NUM_REPS, vals_per_rep, 'o-', 'Color',[colors_subj(s,:) 0.8], ...
                    'LineWidth',1.2,'MarkerSize',4,'DisplayName',subjects{s});
            end
            xlabel('Repetition'); ylabel(param_labels{pp});
            title(sprintf('%s\n%s', epoch_labels{ep}, param_labels{pp}),'FontSize',8);
            xticks(1:NUM_REPS); grid on; hold off;
        end
    end
    sgtitle(sprintf('FOOOF parameters across 20 reps — ROI: %s', roi_names{r}),'Interpreter','none');
    legend(subjects,'Location','eastoutside','FontSize',7);
end

% FIGURE 2: Spectrum overlay per ROI — all subjects mean
% show mean corrected spectrum (aperiodic removed) per subject
figure('Position',[50 50 1400 700]);
for r = 1:nROI
    subplot(2,4,r);
    hold on;
    chan_idx = ROI.(roi_names{r});
    for s = 1:nSubj
        specs = nan(NUM_SLOTS, length(freq_axis_even));
        for slot = 1:NUM_SLOTS
            pow_s = squeeze(nanmean(abs(Task2_exit_allExp{s}.fourierspctrm(slot,chan_idx,:,:)).^2, 2));
            spec_s = nanmean(pow_s(:,t_ERS_s:t_ERS_e),2)';
            if any(spec_s<=0)||any(isnan(spec_s)), continue; end
            spec_even = interp1(freq_axis, spec_s, freq_axis_even,'linear');
            log_f = log10(freq_axis_even(:));
            log_s = log10(spec_even(:));
            valid = ~isnan(log_s)&~isinf(log_s);
            if sum(valid)<5, continue; end
            p = polyfit(log_f(valid),log_s(valid),1);
            specs(slot,:) = log_s' - polyval(p,log_f)';
        end
        mean_spec = nanmean(specs,1);
        if all(isnan(mean_spec)), continue; end
        [~,pk] = max(mean_spec);
        ls = '-'; if freq_axis_even(pk)>=8&&freq_axis_even(pk)<15, ls='-'; else, ls='--'; end
        plot(freq_axis_even, mean_spec, ls, 'Color',[colors_subj(s,:) 0.85], ...
            'LineWidth',1.5,'DisplayName',sprintf('%s (%.1fHz)',subjects{s},freq_axis_even(pk)));
        scatter(freq_axis_even(pk),mean_spec(pk),60,colors_subj(s,:),'v','filled','HandleVisibility','off');
    end
    xline(8,'k:','HandleVisibility','off'); xline(15,'k:','HandleVisibility','off');
    xline(25,'k:','HandleVisibility','off');
    yline(0,'k--','LineWidth',0.8,'HandleVisibility','off');
    yl = ylim;
    text(11,yl(2)*0.9,'α','FontSize',9,'HorizontalAlignment','center');
    text(20,yl(2)*0.9,'β','FontSize',9,'HorizontalAlignment','center');
    xlabel('Hz'); ylabel('Log power - 1/f'); title(roi_names{r},'Interpreter','none');
    legend('FontSize',6,'Location','northeast'); grid on; hold off;

    subplot(2,4,r+4);
    % same for grasp epoch
    hold on;
    for s = 1:nSubj
        specs = nan(NUM_SLOTS, length(freq_axis_even));
        for slot = 1:NUM_SLOTS
            pow_s = squeeze(nanmean(abs(Task2_grasp_allExp{s}.fourierspctrm(slot,chan_idx,:,:)).^2, 2));
            spec_s = nanmean(pow_s(:,t_ERD_s:t_ERD_e),2)';
            if any(spec_s<=0)||any(isnan(spec_s)), continue; end
            spec_even = interp1(freq_axis, spec_s, freq_axis_even,'linear');
            log_f = log10(freq_axis_even(:));
            log_s = log10(spec_even(:));
            valid = ~isnan(log_s)&~isinf(log_s);
            if sum(valid)<5, continue; end
            p = polyfit(log_f(valid),log_s(valid),1);
            specs(slot,:) = log_s' - polyval(p,log_f)';
        end
        mean_spec = nanmean(specs,1);
        if all(isnan(mean_spec)), continue; end
        [~,pk] = max(mean_spec);
        plot(freq_axis_even, mean_spec, '-', 'Color',[colors_subj(s,:) 0.85], ...
            'LineWidth',1.5,'DisplayName',sprintf('%s (%.1fHz)',subjects{s},freq_axis_even(pk)));
        scatter(freq_axis_even(pk),mean_spec(pk),60,colors_subj(s,:),'v','filled','HandleVisibility','off');
    end
    xline(8,'k:','HandleVisibility','off'); xline(15,'k:','HandleVisibility','off');
    xline(25,'k:','HandleVisibility','off');
    yline(0,'k--','LineWidth',0.8,'HandleVisibility','off');
    xlabel('Hz'); ylabel('Log power - 1/f');
    title(sprintf('%s — Grasp',roi_names{r}),'Interpreter','none');
    legend('FontSize',6,'Location','northeast'); grid on; hold off;
end
sgtitle('Aperiodic-corrected spectrum — solid=alpha dominant  dashed=beta dominant  triangle=peak');

% BEHAVIORAL CORRELATION: FOOOF params vs suture duration
fprintf('\n=== Spearman correlations: FOOOF params vs suture duration ===\n');
fprintf('%-14s  %-12s  %-20s  %-8s  %-8s  %-6s\n','ROI','Epoch','Parameter','r','p','sig');

epoch_labels_short = {'Exit','Grasp'};
for ep = 1:2
    if ep==1, FD=FOOOF_exit; else, FD=FOOOF_grasp; end
    for r = 1:nROI
        for pp = 1:numel(param_list)
            x_all = []; y_all = [];
            for s = 1:nSubj
                for rep = 1:NUM_REPS
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    eeg_val = nanmean(squeeze(FD.(param_list{pp})(s,r,slots)));
                    beh_val = nanmean(suture_dur(s,rep,:),'all');
                    if ~isnan(eeg_val) && ~isnan(beh_val)
                        x_all(end+1) = eeg_val;
                        y_all(end+1) = beh_val;
                    end
                end
            end
            if numel(x_all) < 10, continue; end
            [rv, pv] = corr(x_all(:), y_all(:), 'Type','Spearman');
            sig_str = '';
            if pv < 0.05,  sig_str = '*';  end
            if pv < 0.01,  sig_str = '**'; end
            if pv < 0.001, sig_str = '***';end
            if pv < 0.05
                fprintf('%-14s  %-12s  %-20s  %-8.3f  %-8.4f  %s\n', ...
                    roi_names{r}, epoch_labels_short{ep}, param_list{pp}, rv, pv, sig_str);
            end
        end
    end
end

% PRINT FOOOF SUMMARY TABLE
fprintf('\n=== Mean FOOOF parameters per subject — MotorLeft — exit epoch ===\n');
fprintf('%-8s  %-8s  %-8s  %-8s  %-8s  %-8s  %-8s  %-8s\n', ...
    'Subject','Exp','Offset','AlphaCF','AlphaPow','BetaCF','BetaPow','R2');
r = 1;
for s = 1:nSubj
    exp_v  = nanmean(squeeze(FOOOF_exit.exponent(s,r,:)));
    off_v  = nanmean(squeeze(FOOOF_exit.offset(s,r,:)));
    acf_v  = nanmean(squeeze(FOOOF_exit.alpha_cf(s,r,:)));
    apow_v = nanmean(squeeze(FOOOF_exit.alpha_pow(s,r,:)));
    bcf_v  = nanmean(squeeze(FOOOF_exit.beta_cf(s,r,:)));
    bpow_v = nanmean(squeeze(FOOOF_exit.beta_pow(s,r,:)));
    r2_v   = nanmean(squeeze(FOOOF_exit.r_squared(s,r,:)));
    fprintf('%-8s  %-8.3f  %-8.3f  %-8.2f  %-8.3f  %-8.2f  %-8.3f  %-8.3f\n', ...
        subjects{s}, exp_v, off_v, acf_v, apow_v, bcf_v, bpow_v, r2_v);
end

load(fullfile(base_path,'Task2_FOOOF_Experts.mat'));

slot_idx   = @(rep,pt) (rep-1)*NUM_POINTS + pt;

epoch_labels = {'Exit','Grasp'};
param_list2   = {'exponent','offset','alpha_cf','alpha_pow','alpha_bw','beta_cf','beta_pow','beta_bw'};
param_labels2 = {'Aperiodic exponent','Aperiodic offset','Alpha CF (Hz)','Alpha power','Alpha BW','Beta CF (Hz)','Beta power','Beta BW'};

%%
%  QUESTION 1: WITHIN-SUBJECT CORRELATIONS
%  For each subject separately: does faster rep → different EEG?
%  Uses Spearman across 20 repetitions per subject


fprintf('\n=== Within-subject Spearman: FOOOF params vs mean suture duration ===\n');
fprintf('%-8s  %-14s  %-12s  %-20s  %-8s  %-8s  %-6s\n', ...
    'Subject','ROI','Epoch','Parameter','r','p','sig');

WS_r = nan(nSubj, nROI, 2, numel(param_list2));
WS_p = nan(nSubj, nROI, 2, numel(param_list2));

for s = 1:nSubj
    beh_rep = mean_dur_per_rep(s,:)';
    % [NUM_REPS x 1]

    for r = 1:nROI
        for ep = 1:2
            if ep==1, FD=FOOOF_exit; else, FD=FOOOF_grasp; end

            for pp = 1:numel(param_list2)
                eeg_rep = nan(NUM_REPS,1);
                for rep = 1:NUM_REPS
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    eeg_rep(rep) = nanmean(squeeze(FD.(param_list2{pp})(s,r,slots)));
                end
                valid = ~isnan(eeg_rep) & ~isnan(beh_rep);
                if sum(valid) < 5, continue; end
                [rv, pv] = corr(eeg_rep(valid), beh_rep(valid), 'Type','Spearman');
                WS_r(s,r,ep,pp) = rv;
                WS_p(s,r,ep,pp) = pv;
                if pv < 0.05
                    sig_str = '*';
                    if pv < 0.01,  sig_str = '**';  end
                    if pv < 0.001, sig_str = '***'; end
                    fprintf('%-8s  %-14s  %-12s  %-20s  %-8.3f  %-8.4f  %s\n', ...
                        subjects{s}, roi_names{r}, epoch_labels{ep}, param_list2{pp}, rv, pv, sig_str);
                end
            end
        end
    end
end

% Summary: how many subjects show significant within-subject correlation per param/ROI
fprintf('\n=== Consistency: N subjects significant (p<0.05) per parameter ===\n');
fprintf('%-14s  %-12s  %-20s  %-6s  %-8s\n','ROI','Epoch','Parameter','N_sig','median_r');
for r = 1:nROI
    for ep = 1:2
        for pp = 1:numel(param_list2)
            p_vals = squeeze(WS_p(:,r,ep,pp));
            r_vals = squeeze(WS_r(:,r,ep,pp));
            n_sig  = sum(p_vals < 0.05, 'omitnan');
            if n_sig >= 3
                fprintf('%-14s  %-12s  %-20s  %-6d  %-8.3f\n', ...
                    roi_names{r}, epoch_labels{ep}, param_list2{pp}, n_sig, nanmedian(r_vals));
            end
        end
    end
end

% FIGURE Q1: within-subject r values as heatmap per parameter
figure('Position',[50 50 1600 800]);
for ep = 1:2
    for r = 1:nROI
        subplot(2, nROI, (ep-1)*nROI + r);
        mat = squeeze(WS_r(:,r,ep,:));
        % [nSubj x nParams]
        imagesc(mat, [-1 1]);
        colormap(redblue(256));
        colorbar;
        set(gca,'XTick',1:numel(param_list2),'XTickLabel',param_list2, ...
            'XTickLabelRotation',45,'YTick',1:nSubj,'YTickLabel',subjects,'FontSize',7);
        title(sprintf('%s — %s', roi_names{r}, epoch_labels{ep}),'Interpreter','none','FontSize',8);
        xlabel('Parameter'); ylabel('Subject');
        % mark significant cells with dot
        hold on;
        for s = 1:nSubj
            for pp = 1:numel(param_list2)
                if ~isnan(WS_p(s,r,ep,pp)) && WS_p(s,r,ep,pp) < 0.05
                    plot(pp, s, 'k.', 'MarkerSize',10);
                end
            end
        end
        hold off;
    end
end
sgtitle('Within-subject Spearman r — FOOOF vs suture duration — dots = p<0.05');


%  QUESTION 2: LEARNING CURVES ACROSS 20 REPETITIONS
%  For each param/ROI: does it change linearly across reps?
%  Test with Spearman between rep number and param value
%  Also plot trajectories and fit linear trend


fprintf('\n=== Learning curves: Spearman between rep number and FOOOF param ===\n');
fprintf('%-14s  %-12s  %-20s  %-8s  %-8s  %-6s  %-10s\n', ...
    'ROI','Epoch','Parameter','r','p','sig','direction');

LC_r = nan(nROI, 2, numel(param_list2));
LC_p = nan(nROI, 2, numel(param_list2));

for r = 1:nROI
    for ep = 1:2
        if ep==1, FD=FOOOF_exit; else, FD=FOOOF_grasp; end
        for pp = 1:numel(param_list2)
            vals_rep = nan(nSubj, NUM_REPS);
            for s = 1:nSubj
                for rep = 1:NUM_REPS
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    vals_rep(s,rep) = nanmean(squeeze(FD.(param_list2{pp})(s,r,slots)));
                end
            end
            group_mean = nanmean(vals_rep,1);
            valid = ~isnan(group_mean);
            if sum(valid) < 5, continue; end
            [rv,pv] = corr((1:NUM_REPS)', group_mean(:), 'Type','Spearman');
            LC_r(r,ep,pp) = rv;
            LC_p(r,ep,pp) = pv;
            if pv < 0.05
                sig_str = '*';
                if pv<0.01, sig_str='**'; end
                if pv<0.001, sig_str='***'; end
                dir_str = 'increases'; if rv<0, dir_str='decreases'; end
                fprintf('%-14s  %-12s  %-20s  %-8.3f  %-8.4f  %-6s  %s\n', ...
                    roi_names{r}, epoch_labels{ep}, param_list2{pp}, rv, pv, sig_str, dir_str);
            end
        end
    end
end

% FIGURE Q2a: Learning curves for key parameters — group mean + individual lines
key_params  = {'exponent','alpha_cf','alpha_pow','beta_cf','beta_pow'};
key_labels  = {'Aperiodic exponent','Alpha CF (Hz)','Alpha power','Beta CF (Hz)','Beta power'};

for ep = 1:2
    if ep==1, FD=FOOOF_exit; else, FD=FOOOF_grasp; end
    figure('Position',[50 50 1600 700]);
    for r = 1:nROI
        for kp = 1:numel(key_params)
            subplot(nROI, numel(key_params), (r-1)*numel(key_params)+kp);
            hold on;
            vals_rep = nan(nSubj, NUM_REPS);
            for s = 1:nSubj
                for rep = 1:NUM_REPS
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    vals_rep(s,rep) = nanmean(squeeze(FD.(key_params{kp})(s,r,slots)));
                end
                plot(1:NUM_REPS, vals_rep(s,:), '-', 'Color',[colors_subj(s,:) 0.35], ...
                    'LineWidth',0.8,'HandleVisibility','off');
            end
            gm  = nanmean(vals_rep,1);
            sem = nanstd(vals_rep,0,1) ./ sqrt(sum(~isnan(vals_rep),1));
            fill([1:NUM_REPS, fliplr(1:NUM_REPS)], ...
                [gm+sem, fliplr(gm-sem)], [0.3 0.5 0.9], 'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
            plot(1:NUM_REPS, gm, 'o-','Color',[0.2 0.4 0.8],'LineWidth',2,'MarkerSize',5,'DisplayName','Group mean');
            % linear fit
            valid = ~isnan(gm);
            if sum(valid)>3
                p_fit = polyfit(find(valid), gm(valid), 1);
                plot(1:NUM_REPS, polyval(p_fit,1:NUM_REPS), 'r--','LineWidth',1.5,'HandleVisibility','off');
            end
            if LC_p(r,ep,find(strcmp(param_list2,key_params{kp}))) < 0.05
                rv = LC_r(r,ep,find(strcmp(param_list2,key_params{kp})));
                pv = LC_p(r,ep,find(strcmp(param_list2,key_params{kp})));
                title(sprintf('%s\n%s r=%.2f p=%.3f*',roi_names{r},key_labels{kp},rv,pv),'FontSize',7,'Interpreter','none');
            else
                title(sprintf('%s\n%s',roi_names{r},key_labels{kp}),'FontSize',7,'Interpreter','none');
            end
            xlabel('Rep'); xticks([1 5 10 15 20]);
            grid on; hold off;
        end
    end
    sgtitle(sprintf('Learning curves — %s epoch — blue=group mean±SEM  red=linear trend  thin=individual', epoch_labels{ep}));
end

% FIGURE Q2b: Suture duration learning curve
figure('Position',[50 50 900 400]);
hold on;
for s = 1:nSubj
    plot(1:NUM_REPS, mean_dur_per_rep(s,:), '-', 'Color',[colors_subj(s,:) 0.35], ...
        'LineWidth',0.8,'HandleVisibility','off');
end
gm  = nanmean(mean_dur_per_rep,1);
sem = nanstd(mean_dur_per_rep,0,1) ./ sqrt(nSubj);
fill([1:NUM_REPS fliplr(1:NUM_REPS)],[gm+sem fliplr(gm-sem)], ...
    [0.9 0.4 0.3],'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
plot(1:NUM_REPS, gm,'o-','Color',[0.8 0.2 0.2],'LineWidth',2,'MarkerSize',6,'DisplayName','Group mean');
p_fit = polyfit(1:NUM_REPS, gm, 1);
plot(1:NUM_REPS, polyval(p_fit,1:NUM_REPS),'r--','LineWidth',1.5,'HandleVisibility','off');
[rv,pv] = corr((1:NUM_REPS)', gm(:),'Type','Spearman');
xlabel('Repetition'); ylabel('Mean suture duration (s)');
title(sprintf('Behavioral learning curve — Spearman r=%.2f p=%.3f', rv, pv));
legend('Group mean ± SEM','Location','northeast');
grid on; hold off;

% FIGURE Q2c: First 5 vs Last 5 repetitions comparison
% For each param: compare mean of reps 1-5 vs reps 16-20 across subjects
early_reps = 1:5;
late_reps  = 16:20;

fprintf('\n=== First 5 vs Last 5 reps: Wilcoxon signed-rank ===\n');
fprintf('%-14s  %-12s  %-20s  %-10s  %-10s  %-8s  %-6s\n', ...
    'ROI','Epoch','Parameter','mean_early','mean_late','p','sig');

for ep = 1:2
    if ep==1, FD=FOOOF_exit; else, FD=FOOOF_grasp; end
    for r = 1:nROI
        for pp = 1:numel(param_list2)
            early_vals = nan(nSubj,1);
            late_vals  = nan(nSubj,1);
            for s = 1:nSubj
                e_all = [];
                l_all = [];
                for rep = early_reps
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    e_all(end+1) = nanmean(squeeze(FD.(param_list2{pp})(s,r,slots)));
                end
                for rep = late_reps
                    slots = arrayfun(@(pt) slot_idx(rep,pt), 1:NUM_POINTS);
                    l_all(end+1) = nanmean(squeeze(FD.(param_list2{pp})(s,r,slots)));
                end
                early_vals(s) = nanmean(e_all);
                late_vals(s)  = nanmean(l_all);
            end
            valid = ~isnan(early_vals) & ~isnan(late_vals);
            if sum(valid) < 5, continue; end
            [pv,~] = signrank(early_vals(valid), late_vals(valid));
            if pv < 0.05
                sig_str = '*';
                if pv<0.01, sig_str='**'; end
                if pv<0.001, sig_str='***'; end
                fprintf('%-14s  %-12s  %-20s  %-10.3f  %-10.3f  %-8.4f  %s\n', ...
                    roi_names{r}, epoch_labels{ep}, param_list2{pp}, ...
                    nanmean(early_vals), nanmean(late_vals), pv, sig_str);
            end
        end
    end
end

% FIGURE Q2d: Paired plots early vs late for significant params
figure('Position',[50 50 1400 600]);
plot_idx = 0;
for ep = 1:2
    if ep==1, FD=FOOOF_exit; else, FD=FOOOF_grasp; end
    for r = 1:nROI
        for pp = 1:numel(key_params)
            early_vals = nan(nSubj,1);
            late_vals  = nan(nSubj,1);
            for s = 1:nSubj
                e_all=[]; l_all=[];
                for rep=early_reps
                    slots=arrayfun(@(pt) slot_idx(rep,pt),1:NUM_POINTS);
                    e_all(end+1)=nanmean(squeeze(FD.(key_params{pp})(s,r,slots)));
                end
                for rep=late_reps
                    slots=arrayfun(@(pt) slot_idx(rep,pt),1:NUM_POINTS);
                    l_all(end+1)=nanmean(squeeze(FD.(key_params{pp})(s,r,slots)));
                end
                early_vals(s)=nanmean(e_all);
                late_vals(s)=nanmean(l_all);
            end
            valid=~isnan(early_vals)&~isnan(late_vals);
            if sum(valid)<5, continue; end
            [pv,~]=signrank(early_vals(valid),late_vals(valid));
            if pv>=0.05, continue; end
            plot_idx=plot_idx+1;
            if plot_idx>12, break; end
            subplot(3,4,plot_idx);
            hold on;
            for s=1:nSubj
                if ~valid(s), continue; end
                plot([1 2],[early_vals(s) late_vals(s)],'-','Color',[colors_subj(s,:) 0.5],'LineWidth',1);
                scatter([1 2],[early_vals(s) late_vals(s)],40,colors_subj(s,:),'filled');
            end
            errorbar(1,nanmean(early_vals(valid)),nanstd(early_vals(valid))/sqrt(sum(valid)),'ko','LineWidth',2,'MarkerFaceColor','k','MarkerSize',8);
            errorbar(2,nanmean(late_vals(valid)),nanstd(late_vals(valid))/sqrt(sum(valid)),'ko','LineWidth',2,'MarkerFaceColor','k','MarkerSize',8);
            xlim([0.5 2.5]); xticks([1 2]); xticklabels({'Reps 1-5','Reps 16-20'});
            ylabel(key_labels{pp});
            title(sprintf('%s %s\n%s p=%.3f',roi_names{r},epoch_labels{ep},key_params{pp},pv),'FontSize',7,'Interpreter','none');
            grid on; hold off;
        end
    end
end
sgtitle('Significant early vs late changes — lines=individual subjects  error bars=group mean±SEM');

function cmap = redblue(n)
    r=[linspace(0.2,1,n/2) ones(1,n/2)];
    g=[linspace(0.2,1,n/2) linspace(1,0.2,n/2)];
    b=[ones(1,n/2) linspace(1,0.2,n/2)];
    cmap=[r' g' b'];
end