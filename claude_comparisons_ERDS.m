% claude_comparisons_ERDS.m
% EXPERTS: does the ERS decrease with repetitions (Task 2) because the ERS event
% happens at a different time (faster task)?
%
% 0) when do the ERS events occur (seconds from the trial start = MS marker)
% 1) does timing change with repetition?          (plots, then optional tests)
% 2) is ERS related to timing, and does timing explain the repetition trend?
%    (plots, then optional mixed models)
%
% PLOTS FIRST: with RUN_STATS = false (default) only descriptive figures are made.
% Look at them, then set RUN_STATS = true to run the tests.
%
% ERS metric: ERS_all from ERD_ERS_Modulation_Task2_ROI_bands.mat (max over time of
% the ROI-mean normalised band power in [-2, 0] s before the exit).
% PLOTS follow the expert scripts: raw ERS, mean +/- SD across subjects
% (PLOT_LOG = true switches them to the log scale).
% The TESTS (section 4) use LERS = log10(1 + ERS) (= log10 of power relative to the
% subject mean), because the raw values are heavy tailed and bounded below by -1.
%
% Timing variables, all in seconds, all relative to the trial start (MS):
%   exitT   exit time of the suture point  (= when the ERS event is taken)
% Slot convention (experts, Task 2): slot = (rep-1)*4 + point.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % so claude_figure_right.m is found

dataDir = '/home/acatalano/Desktop/Intuitive/DataStructures/';
X1 = load([dataDir 'ExitERS_Times_IE.mat']);        % ValidExitPunctureMatrix [subj x 6 scn x 4 pt]
X2 = load([dataDir 'ExitERS_Times_IE_T2.mat']);     % ValidExitTimes          [subj x 20 rep x 4 pt]
E2 = load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');
                                                    % ERS_all [band x ROI x subj x 80 slots]

SAVE_FIGS = true;
fig_dir   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_Experts_ERStiming';
RUN_STATS = true;      % true: also run the tests (section 4) after looking at the plots
SEL       = [1 1; 1 2]; % [band roi] combinations for the scatter figures (1=Beta, 2=Alpha; ROI 1=MotorLeft 2=MotorRight)

if ~isequal(X2.subjects(:), E2.subjects(:))
    error('Subject lists differ between the timing files and the ERS file');
end
subjects = E2.subjects;   roi_names = E2.roi_names;   BANDS = E2.BANDS;
NR = 20;  NP = 4;
exitT = X2.ValidExitTimes;                     % [subj x rep x pt]
nS = size(exitT, 1);
nB = size(E2.ERS_all, 1);   nROI = size(E2.ERS_all, 2);

%% 0) when do the ERS events occur? (seconds from trial start)
fprintf('=== ERS EVENT TIMES (seconds from the trial start, MS) ===\n');
describe_times('TASK 1 (6 scenarios)',  X1.ValidExitPunctureMatrix);
describe_times('TASK 2 (20 repetitions)', exitT);

rng(1);                                                 % reproducible jitter
grpOf = @(r) 1 + (r > 5) + (r > 15);                    % 1 early (1-5), 2 mid (6-15), 3 late (16-20)
GCOL  = [0.15 0.35 0.75; 0.55 0.55 0.55; 0.85 0.25 0.15];
GLAB  = {'reps 1-5', 'reps 6-15', 'reps 16-20'};

% --- Task 2: every ERS event = one dot; row 1 shows WHICH repetition it comes from,
%     row 2 compares the time distribution of early / mid / late repetitions
claude_figure_right('ERS event times (Task 2)', 1500, 800);
edges = 0:10:ceil(max(exitT(:)) / 10) * 10;
Rmat  = repmat(1:NR, nS, 1);
for p = 1:NP
    subplot(1, NP, p); hold on;
    x = exitT(:,:,p);   m = ~isnan(x);
    scatter(x(m), Rmat(m) + 0.3*(rand(nnz(m),1) - 0.5), 16, Rmat(m), 'filled', 'MarkerFaceAlpha', 0.75);
    plot(mean(x, 1, 'omitnan'), 1:NR, 'k-', 'LineWidth', 2);              % mean per repetition
    xline(2, ':', 'Color', [0.35 0.35 0.35]);
    colormap(gca, parula);caxis([1 NR]);
    xlim([0 edges(end)]); ylim([0.5 NR+0.5]); yticks(1:2:NR); grid on; box on;
    title(sprintf('Task 2 - point %d', p));
    if p == 1, ylabel('repetition (dot = one ERS event, black = mean)'); end
   if p == NP, cb = colorbar; cb.Label.String = 'repetition'; end 

    % subplot(2, NP, NP + p); hold on;
    % hl = gobjects(1, 3);
    % for g = 1:3
    %     v = exitT(:, grpOf(1:NR) == g, p);   v = v(~isnan(v));
    %     hl(g) = histogram(v, edges, 'Normalization', 'probability', 'DisplayStyle', 'stairs', ...
    %         'EdgeColor', GCOL(g,:), 'LineWidth', 2);
    %     xline(mean(v), '--', 'Color', GCOL(g,:), 'LineWidth', 1.5);
    % end
    % xlim([0 edges(end)]); grid on; box on;
    % xlabel('exit time from trial start (s)');
    % if p == 1, ylabel('fraction of events'); legend(hl, GLAB, 'Location', 'northeast'); end
end
sgtitle('Task 2: when the ERS event is taken, and in which repetitions (black line = mean per repetition, dotted line = 2 s)');
save_fig(SAVE_FIGS, fig_dir, 'fig0_ERS_event_times_Task2');

% --- Task 1: the 6 "repetitions" are different scenarios, so they are shown by scenario
A1 = X1.ValidExitPunctureMatrix;   nSc1 = size(A1, 2);
claude_figure_right('ERS event times (Task 1)', 1500, 420);
Rm1 = repmat(1:nSc1, size(A1, 1), 1);
for p = 1:NP
    subplot(1, NP, p); hold on;
    x = A1(:,:,p);   m = ~isnan(x);
    scatter(x(m), Rm1(m) + 0.3*(rand(nnz(m),1) - 0.5), 16, [0.3 0.5 0.8], 'filled', 'MarkerFaceAlpha', 0.75);
    plot(mean(x, 1, 'omitnan'), 1:nSc1, 'k-', 'LineWidth', 2);
    xline(2, ':', 'Color', [0.35 0.35 0.35]);
    xlim([0 ceil(max(A1(:)) / 10) * 10]); ylim([0.5 nSc1+0.5]); yticks(1:nSc1); grid on; box on;
    title(sprintf('Task 1 - point %d', p)); xlabel('exit time from trial start (s)');
    if p == 1, ylabel('scenario (dot = one ERS event, black = mean)'); end
end
sgtitle('Task 1: when the ERS event is taken in each scenario (scenarios differ in difficulty; black line = mean, dotted line = 2 s)');
save_fig(SAVE_FIGS, fig_dir, 'fig0b_ERS_event_times_Task1');

%% ERS as log ratio, [band roi subj rep pt]
ERS5 = permute(reshape(E2.ERS_all, nB, nROI, nS, NP, NR), [1 2 3 5 4]);
ratio = 1 + ERS5;           % power relative to the subject mean (>0 by construction)
ratio(ratio <= 0) = NaN;
L5    = log10(ratio);           % used by the TESTS (section 4)

% what the PLOTS show: as in the expert scripts, raw normalised ERS, mean +/- SD across subjects
PLOT_LOG = false;               % true: plot log10(1+ERS) instead
if PLOT_LOG, Y5 = L5;   ylab = 'log10(1+ERS)';
else,        Y5 = ERS5; ylab = 'ERS (normalised power)';
end

COLP = lines(NP);
repAx = 1:NR;

%% 1) timing vs repetition
claude_figure_right('Timing vs repetition', 800, 450);
hold on;
h = gobjects(1, NP);
for p = 1:NP
    h(p) = group_curve(repAx, squeeze(exitT(:,:,p)), COLP(p,:));
end
legend(h, arrayfun(@(p) sprintf('Pt%d', p), 1:NP, 'UniformOutput', false), 'Location', 'northeast');
ylabel('Exit time from trial start (s)');
xlim([0.5 NR+0.5]); xticks(1:2:NR); grid on; box on; xlabel('Repetition');
sgtitle('Task 2 timing vs repetition (mean across subjects, shaded = SD)');
save_fig(SAVE_FIGS, fig_dir, 'fig1_timing_vs_repetition');

%% 2a) ERS vs repetition, with the mean exit time overlaid
claude_figure_right('ERS vs repetition', 1500, 650);
exitSubjRep = squeeze(mean(exitT, 3, 'omitnan'));      % [subj x rep]
for b = 1:nB
    for r = 1:nROI
        subplot(nB, nROI, (b-1)*nROI + r); hold on;
        M = squeeze(mean(Y5(b,r,:,:,:), 5, 'omitnan'));   % [subj x rep], mean over the 4 points
        for s = 1:nS, plot(repAx, M(s,:), '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.5); end
        yyaxis left
        group_curve(repAx, M, [0.15 0.35 0.75]);
        ylabel(ylab);
        yyaxis right
        plot(repAx, mean(exitSubjRep, 1, 'omitnan'), '--', 'Color', [0.8 0.3 0.1], 'LineWidth', 1.5);
        ylabel('mean exit time (s)');
        xlim([0.5 NR+0.5]); xticks(1:3:NR); grid on; box on;
        title(sprintf('%s %s', BANDS(b).name, roi_names{r}));
        if b == nB, xlabel('Repetition'); end
    end
end
sgtitle('Task 2: ERS (blue mean +/- SD across subjects, single subjects in grey) and mean exit time (orange dashed) vs repetition');
save_fig(SAVE_FIGS, fig_dir, 'fig2_ERS_vs_repetition');

%% 2c) motor areas (left, right, joined) next to the timing change
%  rows    : MotorLeft | MotorRight | Motor = mean of the two ROIs (same slot)
%  column 1: ERS vs repetition        (blue mean +/- SD over subjects, single subjects grey,
%                                      orange dashed = mean exit time on the right axis)
%  column 2: modulation vs repetition (same, with the same exit-time line)
%  column 3: ERS vs mean exit time, one dot per repetition (colour = repetition number),
%            with a least-squares line. No statistics or text are drawn on the plots.
MOTOR_BANDS = [1 2];                                   % 1 = Beta, 2 = Alpha
AREAS    = {1, 2, [1 2]};
areaName = {'MotorLeft', 'MotorRight', 'Motor (left+right mean)'};
Mod5     = permute(reshape(E2.Mod_all, nB, nROI, nS, NP, NR), [1 2 3 5 4]);
metData  = {Y5, Mod5};
metLab   = {ylab, 'Modulation |ERS-ERD|'};
metTit   = {'ERS', 'Modulation'};
meanExit = mean(exitSubjRep, 1, 'omitnan');            % mean exit time per repetition (over subjects and points)
for b = MOTOR_BANDS
    claude_figure_right(sprintf('Motor areas vs timing - %s', BANDS(b).name), 1500, 950);
    for a = 1:3
        Mm = cell(1, 2);
        for m = 1:2
            X  = squeeze(mean(metData{m}(b, AREAS{a}, :, :, :), 2));     % [subj x rep x pt]; joined = mean of the 2 ROIs
            Mm{m} = squeeze(mean(X, 3, 'omitnan'));                       % [subj x rep], mean over the 4 points
            subplot(3, 3, (a-1)*3 + m); hold on;
            for s = 1:nS, plot(repAx, Mm{m}(s,:), '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.5); end
            yyaxis left;   group_curve(repAx, Mm{m}, [0.15 0.35 0.75]);  ylabel(metLab{m});
            yyaxis right;  plot(repAx, meanExit, '--', 'Color', [0.8 0.3 0.1], 'LineWidth', 1.5);  ylabel('mean exit time (s)');
            xlim([0.5 NR+0.5]); xticks(1:3:NR); grid on; box on;
            title(sprintf('%s | %s %s', areaName{a}, BANDS(b).name, metTit{m}));
            if a == 3, xlabel('Repetition'); end
        end

        subplot(3, 3, (a-1)*3 + 3); hold on;
        yE = mean(Mm{1}, 1, 'omitnan');                                         % group mean ERS per repetition
        ok = ~isnan(yE) & ~isnan(meanExit);
        scatter(meanExit(ok), yE(ok), 45, repAx(ok), 'filled');
        colormap(gca, parula); caxis([1 NR]);
        pf = polyfit(meanExit(ok), yE(ok), 1);   xx = [min(meanExit(ok)) max(meanExit(ok))];
        plot(xx, polyval(pf, xx), 'k-', 'LineWidth', 1.5);
        grid on; box on; xlabel('mean exit time (s)'); ylabel([metLab{1} ' (mean over subjects)']);
        title(sprintf('%s | %s ERS vs exit time (dots = repetitions)', areaName{a}, BANDS(b).name));
        if a == 1, cb = colorbar; cb.Label.String = 'repetition'; end
    end
    sgtitle(sprintf('%s: motor areas next to the timing change (blue = mean +/- SD over subjects, grey = subjects, orange dashed = mean exit time)', BANDS(b).name));
    save_fig(SAVE_FIGS, fig_dir, sprintf('fig2c_motor_areas_vs_timing_%s', BANDS(b).name));
end

%% 2b) ERS vs timing, colour = repetition group
[Sg, Rg, Pg] = ndgrid(1:nS, 1:NR, 1:NP);
grp  = 1 + (Rg > 5) + (Rg > 15);                         % 1 early (1-5), 2 mid (6-15), 3 late (16-20)
GCOL = [0.15 0.35 0.75; 0.55 0.55 0.55; 0.85 0.25 0.15];
GLAB = {'reps 1-5', 'reps 6-15', 'reps 16-20'};
xs   = {exitT};   xn = {'exit time from trial start (s)'};
claude_figure_right('ERS vs timing', 700, 450*size(SEL,1));
for c = 1:size(SEL, 1)
    b = SEL(c,1);  r = SEL(c,2);
    y = reshape(Y5(b,r,:,:,:), nS, NR, NP);
    for k = 1:numel(xs)
        subplot(size(SEL,1), numel(xs), (c-1)*numel(xs) + k); hold on;
        for g = 1:3
            m = grp == g & ~isnan(y) & ~isnan(xs{k});
            scatter(xs{k}(m), y(m), 10, GCOL(g,:), 'filled', 'MarkerFaceAlpha', 0.25);
        end
        hm = gobjects(1, 3);
        for g = 1:3
            m = grp == g & ~isnan(y) & ~isnan(xs{k});
            [bx, by] = binned_mean(xs{k}(m), y(m), 6);
            hm(g) = plot(bx, by, '-o', 'Color', GCOL(g,:), 'LineWidth', 2.2, 'MarkerFaceColor', GCOL(g,:));
        end
        yl = prctile(y(~isnan(y)), [1 99]);   ylim(yl + [-0.05 0.05] * diff(yl));   % clip the axis to 1-99 percentile (heavy tails)
        grid on; box on; xlabel(xn{k}); ylabel(ylab);
        title(sprintf('%s %s', BANDS(b).name, roi_names{r}));
        if c == 1 && k == numel(xs), legend(hm, GLAB, 'Location', 'best'); end
    end
end
sgtitle('Task 2: ERS vs timing (dots = slots, lines = binned means; blue early, grey mid, red late; y axis clipped to 1-99 percentile)');
save_fig(SAVE_FIGS, fig_dir, 'fig3_ERS_vs_timing');

%% 3) preview of the mediation question: ERS vs repetition WITHIN exit-time terciles
%  terciles of exit time are computed inside each subject x point, so that
%  point/subject differences in speed do not define them
T3 = nan(nS, NR, NP);
for s = 1:nS
    for p = 1:NP
        x = squeeze(exitT(s,:,p));  ok = ~isnan(x);
        if nnz(ok) < 6, continue; end
        rk = nan(size(x));  rk(ok) = tiedrank(x(ok)) / (nnz(ok) + 1);
        T3(s,:,p) = discretize(rk, [0 1/3 2/3 1]);
    end
end
TCOL = [0.1 0.6 0.3; 0.9 0.6 0.1; 0.6 0.2 0.6];
claude_figure_right('ERS vs repetition within exit-time terciles', 1100, 420*size(SEL,1));
for c = 1:size(SEL, 1)
    b = SEL(c,1);  r = SEL(c,2);
    y = reshape(Y5(b,r,:,:,:), nS, NR, NP);
    subplot(size(SEL,1), 2, (c-1)*2 + 1); hold on;
    nTab = zeros(3, 3);
    for t = 1:3
        mn = nan(1,3);  sd = nan(1,3);
        for g = 1:3
            m = T3 == t & grp == g & ~isnan(y);
            nTab(t,g) = nnz(m);
            % one value per subject (mean of that subject's slots in the cell), then mean +/- SD across subjects
            sv = nan(nS, 1);
            for s = 1:nS
                ms = m & (Sg == s);
                if nnz(ms) >= 2, sv(s) = mean(y(ms)); end
            end
            if nnz(~isnan(sv)) >= 3, mn(g) = mean(sv, 'omitnan');  sd(g) = std(sv, 'omitnan'); end
        end
        errorbar((1:3) + (t-2)*0.08, mn, sd, '-o', 'Color', TCOL(t,:), 'LineWidth', 2, 'MarkerFaceColor', TCOL(t,:));
    end
    xlim([0.5 3.5]); xticks(1:3); xticklabels(GLAB); grid on; box on;
    ylabel([ylab '  (mean \pm SD across subjects)']);
    title(sprintf('%s %s', BANDS(b).name, roi_names{r}));
    legend({'fastest third', 'middle third', 'slowest third'}, 'Location', 'best');
    subplot(size(SEL,1), 2, (c-1)*2 + 2);
    imagesc(nTab); colorbar; xticks(1:3); xticklabels(GLAB); yticks(1:3); yticklabels({'fastest','middle','slowest'});
    for t = 1:3, for g = 1:3, text(g, t, num2str(nTab(t,g)), 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold'); end, end
    title('slots per cell (overlap of timing across repetitions)');
end
sgtitle('If the repetition effect lives inside each timing tercile, timing alone does not explain it');
save_fig(SAVE_FIGS, fig_dir, 'fig4_ERS_vs_repetition_within_timing_terciles');

if ~RUN_STATS
    fprintf('\nPlots done. Set RUN_STATS = true to run the tests (section 4).\n');
    return;
end

%% 4) TESTS (needs the Statistics and Machine Learning Toolbox)
% 4a) does timing change with repetition?  per subject Spearman rho (rep vs value),
%     per point; then sign-rank test of the subject rhos against 0.
fprintf('\n=== 4a) TIMING vs REPETITION (Spearman rho per subject, signrank across subjects) ===\n');
timing = {exitT};   names = {'exit time'};
for k = 1:numel(timing)
    rho = nan(nS, NP);
    for s = 1:nS
        for p = 1:NP
            v = squeeze(timing{k}(s,:,p))';  ok = ~isnan(v);
            if nnz(ok) >= 6, rho(s,p) = corr(repAx(ok)', v(ok), 'Type', 'Spearman'); end
        end
    end
    fprintf('%-22s', names{k});
    for p = 1:NP
        v = rho(:,p);  v = v(~isnan(v));
        fprintf('  Pt%d: median rho %5.2f (p=%.3f, n=%d)', p, median(v), signrank(v), numel(v));
    end
    fprintf('\n');
end

% 4b) ERS ~ repetition with and without timing (mixed models, random intercept for subject)
fprintf('\n=== 4b) ERS ~ repetition, WITHOUT and WITH timing (z-scored predictors) ===\n');
zs = @(v) (v - mean(v, 'omitnan')) ./ std(v, 'omitnan');
for b = 1:nB
    for r = 1:nROI
        y = reshape(L5(b,r,:,:,:), nS, NR, NP);
        tbl = table(y(:), Rg(:), Sg(:), Pg(:), exitT(:), ...
            'VariableNames', {'LERS', 'rep', 'subj', 'pt', 'exitT'});
        tbl = tbl(~any(isnan(tbl{:, {'LERS','rep','exitT'}}), 2), :);
        if height(tbl) < 60, fprintf('%s %s: too few slots (%d)\n', BANDS(b).name, roi_names{r}, height(tbl)); continue; end
        tbl.subj = categorical(tbl.subj);  tbl.pt = categorical(tbl.pt);
        tbl.rep_z = zs(tbl.rep);  tbl.exit_z = zs(tbl.exitT);

        m0 = fitlme(tbl, 'LERS ~ rep_z + pt + (1|subj)');
        m1 = fitlme(tbl, 'LERS ~ rep_z + pt + exit_z + (1|subj)');
        c0 = m0.Coefficients;  c1 = m1.Coefficients;
        i0 = strcmp(c0.Name, 'rep_z');  i1 = strcmp(c1.Name, 'rep_z');
        ie = strcmp(c1.Name, 'exit_z');
        b0 = c0.Estimate(i0);  b1 = c1.Estimate(i1);
        fprintf('%-5s %-10s n=%4d | rep effect without timing: %+.4f (p=%.4f) | with timing: %+.4f (p=%.4f) | change %+.0f%% | exit_z %+.4f (p=%.4f)\n', ...
            BANDS(b).name, roi_names{r}, height(tbl), b0, c0.pValue(i0), b1, c1.pValue(i1), ...
            100*(b1-b0)/abs(b0), c1.Estimate(ie), c1.pValue(ie));
    end
end
fprintf(['\nReading: if the repetition coefficient moves toward 0 when timing is added, timing carries part of the\n' ...
         'repetition trend; if it stays, the trend is not explained by exit time.\n']);

%% 5) OUTLIER CHECK: do extreme values drive the repetition effect?
%  Subject level : subject mean ERS (over repetitions and points) flagged with
%                  - robust z  (median / MAD), |z| > 3.5
%                  - leave-one-out z (distance from mean/SD of the OTHER subjects), |z| > 3
%                  (with n subjects a plain 3-SD rule can never flag anyone: max z = (n-1)/sqrt(n))
%  Slot level    : |z| > 3 relative to the subject's own mean/SD, on log10(1+ERS)
%  Impact        : repetition effect of  LERS ~ rep + point + (1|subject)  refitted
%                  (i) on all slots, (ii) without the slot outliers, (iii) with the slot outliers
%                  winsorised at +/-3 SD, (iv) leaving out each subject in turn.
%                  rep is scaled with a FIXED scale (rep-10.5)/5.766 so that coefficients are comparable.
%  The figure shows the subject means; red = flagged subject. No text is drawn on it.
fprintf('\n=== 5) OUTLIER CHECK (max possible |z| of one value among %d subjects = %.2f) ===\n', nS, (nS-1)/sqrt(nS));
chkAreas = {1, 2, 3, 4, [1 2]};
chkNames = [roi_names(:)', {'Motor (L+R)'}];
for b = 1:nB
    claude_figure_right(sprintf('Outlier check, subject means - %s', BANDS(b).name), 1600, 450);
    for a = 1:numel(chkAreas)
        Xs  = squeeze(mean(ERS5(b, chkAreas{a}, :, :, :), 2));            % [subj x rep x pt], raw ERS
        rat = 1 + Xs;  rat(rat <= 0) = NaN;  Ls = log10(rat);             % log10(1+ERS)

        % ---- subject level
        subRaw = squeeze(mean(mean(Xs, 3, 'omitnan'), 2, 'omitnan'));      % [subj x 1]
        mz   = robust_z(subRaw);   lz = loo_z(subRaw);
        flag = abs(mz) > 3.5 | abs(lz) > 3;
        subplot(1, numel(chkAreas), a); hold on;
        jit = 0.08 * randn(nS, 1);
        scatter(1 + jit(~flag), subRaw(~flag), 45, [0.15 0.35 0.75], 'filled');
        scatter(1 + jit(flag),  subRaw(flag),  70, [0.85 0.2 0.2],  'filled');
        yline(mean(subRaw) + 3*std(subRaw), '--', 'Color', [0.5 0.5 0.5]);
        yline(mean(subRaw) - 3*std(subRaw), '--', 'Color', [0.5 0.5 0.5]);
        md = median(subRaw);  sc = median(abs(subRaw - md)) / 0.6745;
        yline(md + 3.5*sc, ':', 'Color', [0.85 0.2 0.2]);  yline(md - 3.5*sc, ':', 'Color', [0.85 0.2 0.2]);
        xlim([0.5 1.5]); xticks([]); grid on; box on; ylabel('subject mean ERS');
        title(sprintf('%s | %s', BANDS(b).name, chkNames{a}));

        % ---- slot level (within-subject z on the log scale)
        mu_s = mean(Ls, [2 3], 'omitnan');   sd_s = std(reshape(Ls, nS, []), 0, 2, 'omitnan');
        Zs   = (Ls - mu_s) ./ sd_s;
        isOut = abs(Zs) > 3;
        nOutSub = squeeze(sum(sum(isOut, 3), 2));
        Lw = Ls;   up = mu_s + 3*sd_s + zeros(size(Ls));   lo = mu_s - 3*sd_s + zeros(size(Ls));
        Lw(Zs > 3) = up(Zs > 3);   Lw(Zs < -3) = lo(Zs < -3);

        % ---- impact on the repetition effect
        mkT = @(L) table(L(:), (Rg(:) - 10.5) / 5.766, categorical(Pg(:)), categorical(Sg(:)), Sg(:), ...
            'VariableNames', {'LERS', 'rep_z', 'pt', 'subj', 'sid'});
        T_all = mkT(Ls);   T_all = T_all(~isnan(T_all.LERS), :);
        T_no  = mkT(Ls);   T_no.LERS(isOut(:)) = NaN;   T_no = T_no(~isnan(T_no.LERS), :);
        T_win = mkT(Lw);   T_win = T_win(~isnan(T_win.LERS), :);
        [b1, p1] = fit_rep(T_all);   [b2, p2] = fit_rep(T_no);   [b3, p3] = fit_rep(T_win);
        bl = nan(nS, 1);   pl = nan(nS, 1);
        for s = 1:nS, [bl(s), pl(s)] = fit_rep(T_all(T_all.sid ~= s, :)); end

        fprintf('\n%-5s %-12s\n', BANDS(b).name, chkNames{a});
        if any(flag)
            fprintf('   flagged subjects (raw subject mean): %s\n', strjoin(arrayfun(@(i) sprintf('%s (robust z %+.1f, leave-one-out z %+.1f)', ...
                subjects{i}, mz(i), lz(i)), find(flag)', 'UniformOutput', false), '; '));
        else
            fprintf('   flagged subjects (raw subject mean): none\n');
        end
        fprintf('   slot outliers (|z|>3 within subject, log scale): %d of %d (%.1f%%) | per subject: %s\n', ...
            nnz(isOut), nnz(~isnan(Ls)), 100*nnz(isOut)/nnz(~isnan(Ls)), mat2str(nOutSub(:)'));
        fprintf('   repetition effect | all slots %+.4f (p=%.3f) | without slot outliers %+.4f (p=%.3f) | winsorised %+.4f (p=%.3f)\n', b1, p1, b2, p2, b3, p3);
        [~, iWorst] = max(pl);   [~, iBest] = min(pl);
        fprintf('   leave-one-subject-out | coefficient %+.4f to %+.4f | p from %.3f (without %s) to %.3f (without %s) | significant (p<.05) in %d of %d refits\n', ...
            min(bl), max(bl), min(pl), subjects{iBest}, max(pl), subjects{iWorst}, nnz(pl < 0.05), nnz(~isnan(pl)));
    end
    sgtitle(sprintf('%s: subject means of ERS (red = flagged; dashed grey = mean +/- 3 SD, dotted red = median +/- 3.5 robust SD)', BANDS(b).name));
    save_fig(SAVE_FIGS, fig_dir, sprintf('fig5_outlier_check_%s', BANDS(b).name));
end
fprintf(['\nReading: if the coefficient and p-value stay similar without outliers / winsorised, and when each subject is\n' ...
         'left out, outliers do not drive the repetition effect; a large change on removing one subject means that subject does.\n']);

%% 6) FIRST vs LAST repetitions, as in the paper, and the link with the timing change
%  Per expert and per metric (ERS, modulation; region x band):
%    - each repetition = mean over its events (Pt1-4);  first = mean of reps 1-3, last = mean of reps 18-20
%    - Shapiro-Wilk on the paired differences (last - first):
%         p >= 0.05 -> paired t-test      p < 0.05 -> Wilcoxon signed-rank
%    - mean +/- SD over experts for first and last
%    - Holm correction across the region x band tests of the same metric
%    - the same for the TOTAL COMPLETION TIME of the repetition (behavioural dataset, the paper's measure:
%      about 102 -> 67 s) and, as a check, for the exit time of Pt4 (EEG pipeline).
%      (The mean of the 4 cumulative exit times is NOT used: it is not a completion time.)
%  Step 2 (extension): per expert  dEEG = last - first  and  dTime = last - first of the time variable
%    - Shapiro-Wilk on both deltas: both normal -> Pearson, otherwise Spearman
%    - Holm correction across all region x band x metric correlations
%  Values are the raw normalised ERS and modulation (as in the paper). Nothing is written on the plots.
FIRST = 1:3;   LAST = 18:20;   ALPHA = 0.05;
INCLUDE_JOINED_MOTOR = false;                 % true: add "Motor (L+R)" = mean of left and right as a 5th region
regions  = {1, 2, 3, 4};   regNames = roi_names(:)';
if INCLUDE_JOINED_MOTOR, regions{end+1} = [1 2];   regNames{end+1} = 'Motor (L+R)'; end
nReg  = numel(regions);
mdata = {ERS5, Mod5};   mname = {'ERS', 'Modulation'};
fl    = @(V) deal(mean(V(:, FIRST), 2, 'omitnan'), mean(V(:, LAST), 2, 'omitnan'));

Fv = nan(nS, nB, nReg, 2);   Lv = nan(nS, nB, nReg, 2);              % first / last per expert
for b = 1:nB
    for r = 1:nReg
        for m = 1:2
            X = squeeze(mean(mdata{m}(b, regions{r}, :, :, :), 2));   % [subj x rep x pt]
            V = squeeze(mean(X, 3, 'omitnan'));                       % [subj x rep]: one value per repetition
            [Fv(:,b,r,m), Lv(:,b,r,m)] = fl(V);
        end
    end
end

% ---- time variables --------------------------------------------------------------------------
% completion time: performanceMatrix_IE_metrics20, data_matrix = [20 repetitions x 4 metrics x 10 experts],
% metric 1 = time to complete the task (s). Expert order is assumed to be the same as in the EEG files and is
% checked below against the Pt4 exit time.
P20   = load('/home/acatalano/Desktop/Intuitive/Path Length, Time, ERD, ERS/performanceMatrix_IE_metrics20 1.mat');
tComp = squeeze(P20.data_matrix(:, 1, :))';                           % [subj x rep]
tPt4  = squeeze(exitT(:, :, 4));                                      % [subj x rep]: exit of the last suture point
timeNames = {'completion time (behavioural dataset)', 'exit time of Pt4 (EEG pipeline)'};
timeShort = {'completion', 'Pt4'};
[FtC, LtC] = fl(tComp);   [Ft4, Lt4] = fl(tPt4);
Ftv = {FtC, Ft4};   Ltv = {LtC, Lt4};

% consistency check of the pipeline: completion time vs Pt4 exit time, per expert, over repetitions
rAgree = nan(nS, 1);   dAgree = nan(nS, 1);
for s = 1:nS
    okA = ~isnan(tComp(s,:)) & ~isnan(tPt4(s,:));
    if nnz(okA) >= 4
        rAgree(s) = corr(tComp(s,okA)', tPt4(s,okA)');   dAgree(s) = mean(tComp(s,okA) - tPt4(s,okA));
    end
end
fprintf('\n=== time variables: completion time (behavioural) vs Pt4 exit time (EEG pipeline), per expert ===\n');
fprintf('correlation over repetitions: %s | mean(completion - Pt4) per expert (s): %s\n', mat2str(round(rAgree', 3)), mat2str(round(dAgree', 1)));
if min(rAgree) < 0.8
    warning('Low agreement between completion time and Pt4 exit time for some expert: check that the expert order is the same in both files');
end

%% 6a) first vs last
fprintf('\n=== 6a) FIRST (reps %d-%d) vs LAST (reps %d-%d): mean +- SD over experts; Shapiro-Wilk on the paired differences\n', ...
    FIRST(1), FIRST(end), LAST(1), LAST(end));
fprintf('        (p >= %.2f -> paired t-test, otherwise Wilcoxon signed-rank); Holm across region x band within each metric ===\n', ALPHA);
RES = cell(nB, nReg, 2);
for b = 1:nB, for r = 1:nReg, for m = 1:2
    RES{b,r,m} = claude_paired_first_last(Fv(:,b,r,m), Lv(:,b,r,m), ALPHA);
end, end, end
for m = 1:2
    pv = nan(nB, nReg);
    for b = 1:nB, for r = 1:nReg, pv(b,r) = RES{b,r,m}.p; end, end
    padj = reshape(claude_holm_adjust(pv(:)), nB, nReg);
    fprintf('\n--- %s ---\n', mname{m});
    for b = 1:nB
        for r = 1:nReg
            Q = RES{b,r,m};
            fprintf('%-5s %-12s n=%2d | first %8.3f +- %6.3f | last %8.3f +- %6.3f | Shapiro-Wilk p=%.3f -> %-8s | p=%.4f | p(Holm)=%.4f\n', ...
                BANDS(b).name, regNames{r}, Q.n, Q.mFirst, Q.sdFirst, Q.mLast, Q.sdLast, Q.swP, Q.test, Q.p, padj(b,r));
        end
    end
end
fprintf('\n--- Time (seconds); the paper reports about 102 -> 67 s for the completion time ---\n');
for tv = 1:2
    Qt = claude_paired_first_last(Ftv{tv}, Ltv{tv}, ALPHA);
    fprintf('%-42s n=%2d | first %7.2f +- %6.2f | last %7.2f +- %6.2f | Shapiro-Wilk p=%.3f -> %-8s | p=%.4f\n', ...
        timeNames{tv}, Qt.n, Qt.mFirst, Qt.sdFirst, Qt.mLast, Qt.sdLast, Qt.swP, Qt.test, Qt.p);
end

% paired plots (grey lines = single experts, black square = mean)
for b = 1:nB
    claude_figure_right(sprintf('First vs last - %s', BANDS(b).name), 800, 230*nReg);
    for r = 1:nReg
        for m = 1:2
            subplot(nReg, 2, (r-1)*2 + m);
            paired_panel(Fv(:,b,r,m), Lv(:,b,r,m), sprintf('%s | %s', regNames{r}, mname{m}), mname{m});
        end
    end
    sgtitle(sprintf('%s: first (reps %d-%d) vs last (reps %d-%d) repetitions, one line per expert', ...
        BANDS(b).name, FIRST(1), FIRST(end), LAST(1), LAST(end)));
    save_fig(SAVE_FIGS, fig_dir, sprintf('fig6a_first_vs_last_%s', BANDS(b).name));
end
claude_figure_right('First vs last - time', 800, 420);
for tv = 1:2
    subplot(1, 2, tv);
    paired_panel(Ftv{tv}, Ltv{tv}, timeNames{tv}, 'seconds');
end
save_fig(SAVE_FIGS, fig_dir, 'fig6a_first_vs_last_time');

%% 6b) is the EEG change related to the timing change?
%  One block per time variable (completion time = primary, as in the paper; Pt4 exit = check).
%  The least-squares line is drawn ONLY in panels tested with Pearson. Spearman panels have no line, because an
%  ordinary least-squares line would not match a rank-based test (one fast expert can pull it strongly).
fprintf('\n=== 6b) dEEG vs dTime across experts (last - first); Shapiro-Wilk on both deltas: both normal -> Pearson, otherwise Spearman ===\n');
for tv = 1:2
    dT = Ltv{tv} - Ftv{tv};                                           % [subj x 1], last - first of the time variable
    fprintf('\n--- time variable: %s | change per expert (s): %s ---\n', timeNames{tv}, mat2str(round(dT', 1)));
    nTest = nB * nReg * 2;   corrP = nan(nTest, 1);   corrInfo = cell(nTest, 1);   k = 0;
    claude_figure_right(sprintf('dEEG vs dTime - %s', timeShort{tv}), 1500, 230*nReg);
    for r = 1:nReg
        for b = 1:nB
            for m = 1:2
                k = k + 1;
                dE = Lv(:,b,r,m) - Fv(:,b,r,m);
                ok = ~isnan(dE) & ~isnan(dT);
                if nnz(ok) < 4, corrInfo{k} = sprintf('%-5s %-12s %-10s too few pairs (%d)', BANDS(b).name, regNames{r}, mname{m}, nnz(ok)); continue; end
                [~, pSE] = claude_shapiro_wilk(dE(ok));   [~, pST] = claude_shapiro_wilk(dT(ok));
                if pSE >= ALPHA && pST >= ALPHA, ctype = 'Pearson'; else, ctype = 'Spearman'; end
                [rc, pc] = corr(dT(ok), dE(ok), 'Type', ctype);
                corrP(k) = pc;
                corrInfo{k} = sprintf('%-5s %-12s %-10s n=%2d | Shapiro-Wilk p: dEEG %.3f, dTime %.3f -> %-8s | r=%+.2f | p=%.4f', ...
                    BANDS(b).name, regNames{r}, mname{m}, nnz(ok), pSE, pST, ctype, rc, pc);
                subplot(nReg, nB*2, (r-1)*nB*2 + (b-1)*2 + m); hold on;
                scatter(dT(ok), dE(ok), 45, [0.15 0.35 0.75], 'filled');
                if strcmp(ctype, 'Pearson')                            % line only where it matches the test
                    pf = polyfit(dT(ok), dE(ok), 1);   xx = [min(dT(ok)) max(dT(ok))];
                    plot(xx, polyval(pf, xx), 'k-', 'LineWidth', 1.2);
                end
                xline(0, ':', 'Color', [0.6 0.6 0.6]);   yline(0, ':', 'Color', [0.6 0.6 0.6]);
                grid on; box on; xlabel(sprintf('\\Delta %s, last - first (s)', timeShort{tv})); ylabel(['\Delta ' mname{m}]);
                title(sprintf('%s | %s %s', regNames{r}, BANDS(b).name, mname{m}));
            end
        end
    end
    sgtitle(sprintf('Change from first to last repetitions: EEG vs %s (one dot per expert; line = least squares, only where Pearson was used)', timeNames{tv}));
    save_fig(SAVE_FIGS, fig_dir, sprintf('fig6b_dEEG_vs_dTime_%s', timeShort{tv}));
    padjC = claude_holm_adjust(corrP);
    for k = 1:nTest
        if isnan(corrP(k)), fprintf('%s\n', corrInfo{k}); else, fprintf('%s | p(Holm)=%.4f\n', corrInfo{k}, padjC(k)); end
    end
end
fprintf('\n(Holm family for 6a: the region x band tests of each metric; for 6b: all %d correlations of each time variable.)\n', nB * nReg * 2);

%% 6c) execution time of each POINT, from the exit of the previous point
%  The exit times are CUMULATIVE from the trial start (MS): Pt4 is (almost) the total time, i.e. the SUM of the four
%  point times. The execution time of a point is therefore  exit(p) - exit(p-1)  (Pt1: exit(1), from the start).
%  It is NaN when either exit is missing (no interval spanning two points is created).
%  This shows which points carry the speed-up, which the cumulative Pt4 time cannot.
durP = nan(size(exitT));
durP(:,:,1) = exitT(:,:,1);
for p = 2:NP, durP(:,:,p) = exitT(:,:,p) - exitT(:,:,p-1); end
FD = nan(nS, NP);   LD = nan(nS, NP);
for p = 1:NP, [FD(:,p), LD(:,p)] = fl(squeeze(durP(:,:,p))); end
QD = cell(NP, 1);   pD = nan(NP, 1);
for p = 1:NP, QD{p} = claude_paired_first_last(FD(:,p), LD(:,p), ALPHA);   pD(p) = QD{p}.p; end
pDadj = claude_holm_adjust(pD);
fprintf('\n=== 6c) execution time of each point (s): first (reps %d-%d) vs last (reps %d-%d), mean +- SD over experts; Holm across the 4 points ===\n', ...
    FIRST(1), FIRST(end), LAST(1), LAST(end));
for p = 1:NP
    Q = QD{p};
    fprintf('Pt%d%s n=%2d | first %6.1f +- %5.1f | last %6.1f +- %5.1f | Shapiro-Wilk p=%.3f -> %-8s | p=%.4f | p(Holm)=%.4f\n', ...
        p, ternary_str(p == 1, ' (from trial start)', '                   '), Q.n, Q.mFirst, Q.sdFirst, Q.mLast, Q.sdLast, Q.swP, Q.test, Q.p, pDadj(p));
end
dPt = mean(LD - FD, 1, 'omitnan');                                            % mean change last - first per point
fprintf('mean change per point (s): %s | sum %.1f s | share of the total speed-up: %s %%\n', ...
    mat2str(round(dPt, 1)), sum(dPt), mat2str(round(100 * dPt / sum(dPt))));
fprintf('for reference, mean change of the cumulative Pt4 time: %.1f s (should equal the sum when all four exits exist)\n', ...
    mean(Lt4 - Ft4, 'omitnan'));
claude_figure_right('First vs last - execution time per point', 1100, 380);
for p = 1:NP
    subplot(1, NP, p);
    paired_panel(FD(:,p), LD(:,p), sprintf('Pt%d execution time', p), 'seconds');
end
save_fig(SAVE_FIGS, fig_dir, 'fig6c_first_vs_last_point_times');
%% 6d) duration of each point vs repetition (each point timed from the previous exit)
S   = load(fullfile('/home/acatalano/Desktop/Intuitive/DataStructures', 'ExitERS_Times_IE_T2.mat'));
ex  = S.ValidExitTimes;                                   % [10 x 20 x 4], seconds from the go marker
prv = cat(3, zeros(size(ex,1), size(ex,2)), ex(:,:,1:3));
dur = ex - prv;                                           % NaN if this exit or the previous one is missing
dur(:,:,5) = ex(:,:,4);                                   % total = go -> exit Pt4
lab = {'go \rightarrow Pt1','Pt1 \rightarrow Pt2','Pt2 \rightarrow Pt3','Pt3 \rightarrow Pt4','Total'};
claude_figure_right('Duration of each point vs repetition', 1500, 330);
for p = 1:5
    subplot(1,5,p); hold on;
    plot(1:20, dur(:,:,p)', '-', 'Color', [0.8 0.8 0.8]);                     % single experts
    m = mean(dur(:,:,p), 1, 'omitnan');  sd = std(dur(:,:,p), 0, 1, 'omitnan');
    errorbar(1:20, m, sd, 'k-o', 'MarkerFaceColor', 'k', 'MarkerSize', 4, 'LineWidth', 1.2);
    n = sum(~isnan(dur(:,:,p)), 1);
    title(sprintf('%s (n = %d–%d)', lab{p}, min(n), max(n)));
    xlabel('Repetition'); if p == 1, ylabel('Duration (s)'); end
    xlim([0.5 20.5]); grid on; box off;
end
save_fig(SAVE_FIGS, fig_dir, 'fig6d_point_duration_vs_repetition');



%% ---------------------------------------------------------------------
%  Local functions
%% ---------------------------------------------------------------------
function R = claude_paired_first_last(f, l, alphaSW)
    % paired comparison of two columns: Shapiro-Wilk on the differences, then paired t-test or Wilcoxon signed-rank
    ok = ~isnan(f) & ~isnan(l);   f = f(ok);   l = l(ok);   d = l - f;
    R = struct('n', numel(d), 'mFirst', mean(f), 'sdFirst', std(f), 'mLast', mean(l), 'sdLast', std(l), ...
               'swW', NaN, 'swP', NaN, 'test', 'n/a', 'p', NaN);
    if R.n < 3, return; end
    [R.swW, R.swP] = claude_shapiro_wilk(d);
    if ~isnan(R.swP) && R.swP >= alphaSW
        [~, R.p] = ttest(l, f);     R.test = 't-test';
    else
        R.p = signrank(l, f);       R.test = 'Wilcoxon';
    end
end

function paired_panel(f, l, ttl, ylab)
    hold on;
    for s = 1:numel(f), plot([1 2], [f(s) l(s)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8); end
    scatter(ones(size(f)),   f, 40, [0.4 0.6 0.9], 'filled');
    scatter(2*ones(size(l)), l, 40, [0.0 0.2 0.6], 'filled');
    plot(1, mean(f, 'omitnan'), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
    plot(2, mean(l, 'omitnan'), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
    xlim([0.5 2.5]); xticks([1 2]); xticklabels({'First 1-3', 'Last 18-20'});
    grid on; box on; title(ttl); ylabel(ylab);
end

function adj = claude_holm_adjust(p)
    % Holm step-down adjusted p-values (NaN ignored)
    p = p(:);   adj = nan(size(p));
    [ps, idx] = sort(p);                     % NaN sorted last
    ok = ~isnan(ps);   n = nnz(ok);
    if n == 0, return; end
    a = cummax(ps(ok) .* (n:-1:1)');         % (m - i + 1) * p_(i), made monotone
    a = min(a, 1);
    tmp = nan(size(ps));   tmp(ok) = a;
    adj(idx) = tmp;
end

function [W, p] = claude_shapiro_wilk(x)
    % Shapiro-Wilk test, Royston (1992) approximation (n = 3...2000).
    % Checked against the SciPy reference example (n = 11: W = 0.7888, p = 0.0067).
    x = sort(x(~isnan(x(:))));   n = numel(x);   W = NaN;   p = NaN;
    if n < 3 || x(end) - x(1) == 0, return; end
    m  = norminv(((1:n)' - 0.375) / (n + 0.25));
    mm = sum(m.^2);   c = m / sqrt(mm);   u = 1 / sqrt(n);
    a  = zeros(n, 1);
    if n == 3
        a = [-sqrt(0.5); 0; sqrt(0.5)];
    else
        an  = c(n)   + polyval(fliplr([0 0.221157 -0.147981 -2.071190 4.434685 -2.706056]), u);
        an1 = c(n-1) + polyval(fliplr([0 0.042981 -0.293762 -1.752461 5.682633 -3.582633]), u);
        if n > 5
            phi = (mm - 2*m(n)^2 - 2*m(n-1)^2) / (1 - 2*an^2 - 2*an1^2);
            a(3:n-2) = m(3:n-2) / sqrt(phi);
            a(n) = an;   a(1) = -an;   a(n-1) = an1;   a(2) = -an1;
        else
            phi = (mm - 2*m(n)^2) / (1 - 2*an^2);
            a(2:n-1) = m(2:n-1) / sqrt(phi);
            a(n) = an;   a(1) = -an;
        end
    end
    W = (a' * x)^2 / sum((x - mean(x)).^2);
    y = log(1 - W);
    if n == 3
        p = max(0, 6/pi * (asin(sqrt(W)) - asin(sqrt(0.75))));
    elseif n <= 11
        gam = -2.273 + 0.459*n;
        if y >= gam, p = 1e-99; return; end
        y  = -log(gam - y);
        mu = polyval(fliplr([0.5440 -0.39978 0.025054 -0.0006714]), n);
        sg = exp(polyval(fliplr([1.3822 -0.77857 0.062767 -0.0020322]), n));
        p  = 1 - normcdf((y - mu) / sg);
    else
        xx = log(n);
        mu = polyval(fliplr([-1.5861 -0.31082 -0.083751 0.0038915]), xx);
        sg = exp(polyval(fliplr([-0.4803 -0.082676 0.0030302]), xx));
        p  = 1 - normcdf((y - mu) / sg);
    end
end

function out = ternary_str(c, x, y)
    if c, out = x; else, out = y; end
end

function z = robust_z(x)
    % modified z-score: 0.6745 * (x - median) / MAD
    md = median(x, 'omitnan');   s = median(abs(x - md), 'omitnan');
    if s == 0, z = zeros(size(x)); else, z = 0.6745 * (x - md) / s; end
end

function z = loo_z(x)
    % leave-one-out z: distance of each value from the mean/SD of the OTHER values
    n = numel(x);   z = nan(n, 1);
    for i = 1:n
        o = x([1:i-1, i+1:n]);
        z(i) = (x(i) - mean(o, 'omitnan')) / std(o, 'omitnan');
    end
end

function [b, p] = fit_rep(tbl)
    % repetition coefficient of  LERS ~ rep_z + pt + (1|subj)
    try
        m = fitlme(tbl, 'LERS ~ rep_z + pt + (1|subj)');
        c = m.Coefficients;   i = strcmp(c.Name, 'rep_z');
        b = c.Estimate(i);    p = c.pValue(i);
    catch
        b = NaN;  p = NaN;
    end
end

function describe_times(label, A)
    fprintf('\n--- %s: [subject x %d x point], seconds from MS ---\n', label, size(A,2));
    fprintf('%-8s %5s %8s %8s %7s %7s %7s %8s %7s\n', 'point', 'n', 'median', 'mean', 'min', 'p5', 'p95', 'max', '<2 s');
    for p = 0:size(A,3)
        if p == 0, v = A(:); nm = 'all'; else, v = reshape(A(:,:,p), [], 1); nm = sprintf('Pt%d', p); end
        v = v(~isnan(v));
        fprintf('%-8s %5d %8.1f %8.1f %7.1f %7.1f %7.1f %8.1f %7d\n', nm, numel(v), median(v), mean(v), ...
            min(v), prctile(v,5), prctile(v,95), max(v), nnz(v < 2));
    end
    fprintf('(<2 s: the ERS window [-2, 0] s would reach back before the trial start)\n');
end

function h = group_curve(x, M, col)
    % M = [subject x x]: mean across subjects with a +/- SD band (as in the expert plots)
    mn = mean(M, 1, 'omitnan');
    sd = std(M, 0, 1, 'omitnan');
    ok = ~isnan(mn) & ~isnan(sd);
    if ~any(ok), h = plot(NaN, NaN, 'Color', col); return; end
    xv = x(ok);
    fill([xv fliplr(xv)], [mn(ok)+sd(ok) fliplr(mn(ok)-sd(ok))], col, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    h = plot(xv, mn(ok), '-o', 'Color', col, 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', col);
end

function [bx, by] = binned_mean(x, y, nb)
    bx = []; by = [];
    if numel(x) < nb * 5, return; end
    edges = unique(prctile(x, linspace(0, 100, nb + 1)));
    for k = 1:numel(edges) - 1
        if k < numel(edges) - 1, m = x >= edges(k) & x < edges(k+1); else, m = x >= edges(k) & x <= edges(k+1); end
        if nnz(m) >= 5, bx(end+1) = mean(x(m)); by(end+1) = mean(y(m)); end %#ok<AGROW>
    end
end

function save_fig(doSave, figDir, name)
    if ~doSave, return; end
    if ~exist(figDir, 'dir'), mkdir(figDir); end
    saveas(gcf, fullfile(figDir, [name '.png']));
end
