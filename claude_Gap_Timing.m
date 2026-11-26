% claude_Gap_Timing.m
% =====================================================================================================
% EXPLORATORY: how close in time are the events of a suture point, in EXPERTS (Task 2) and RESIDENTS?
% Behaviour only (no EEG): answers "how often could grasp / entry / exit contaminate each other?"
%
% Events of one point:  last GRASP  ->  needle ENTRY  ->  needle EXIT   (next point: exit -> next GRASP)
%   GA = entry - grasp    approach          EE = exit - entry    needle passage (needle inside the tissue)
%   GE = exit - grasp     whole point       TR = next grasp - exit  transport to the next point
%
% What "contamination" means here (windows of the existing ERD / ERS analyses)
%   EE < ERS_LEN (2 s)   the entry (= the needle drive) falls INSIDE the exit ERS window [-2 0] s: the "ERS" window is
%                        then mostly the passage movement itself
%   GE < 3 s             the ERD window [-0.5 1] (grasp) and the ERS window [-2 0] (exit) of the SAME point overlap
%   GE < 4 s             the whole epochs overlap: grasp [-0.8 1.5]  and exit [-2.5 0.5]
%   TR < 2 s             ERS / rebound of point p and ERD of point p+1 touch
%
% Figures (saved in DataStructures/Figures_Gap_Timing)
%   1  distributions (ECDF, log time) of GA, EE, GE, TR, experts vs residents, with the window limits
%   2  one dot per subject (median), experts vs residents, with the rank-sum p-value
%   3  TREND across repetitions: EE median and % of short passages, per subject and per group
%   4  threshold sweep: % of points with EE / GE / TR below a threshold (median and IQR across subjects)
%   5  number of short-passage points per suture (repetition): how many sutures are "contaminated"
%   6  EE by suture point (1-4)
%   7  timelines of one expert and one resident (grasp -> entry -> exit of the 4 points, one row per repetition)
% Saves GapTable.mat (the point table, also used by claude_Gap_Spectra.m)
% =====================================================================================================
clear; clc; close all
addpath(fileparts(mfilename('fullpath')));        % claude_figure_right.m, claude_gap_table.m

%% 1. SETTINGS
EXCLUDE_RES = {'IR04'};          % ICA components never removed (as in the topography scripts)
ERS_LEN     = 2.0;               % s, length of the exit ERS window [-2 0]
THR_SHORT   = 2.0;               % s, EE below this = "short passage" (entry inside the ERS window)
THR_GE      = [3 4];             % s, grasp/exit analysis windows | whole epochs overlap
THR_TR      = 2.0;               % s
SAVE_FIGS   = true;
D       = '/home/acatalano/Desktop/Intuitive/DataStructures/';
fig_dir = [D 'Figures_Gap_Timing'];
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
grpName = {'Residents', 'Experts'};   grpCol = [0.85 0.33 0.10; 0.00 0.45 0.74];   % residents orange, experts blue

%% 2. POINT TABLE
T = claude_gap_table(EXCLUDE_RES);
save([D 'GapTable.mat'], 'T', 'THR_SHORT');
ints   = {'GA', 'EE', 'GE', 'TR'};
intLab = {'grasp \rightarrow entry (approach)', 'entry \rightarrow exit (needle passage)', 'grasp \rightarrow exit (whole point)', 'exit \rightarrow next grasp (transport)'};
subjR = unique(T.subj(T.group == 1), 'stable');   subjE = unique(T.subj(T.group == 2), 'stable');

%% 3. TEXT SUMMARY
fprintf('\n================ INTERVALS (s): median [IQR], pooled over points ================\n');
fprintf('%-8s %-24s %-24s %-24s %-24s\n', 'group', 'GA approach', 'EE passage', 'GE whole point', 'TR transport');
for g = [2 1]
    fprintf('%-8s', grpName{g}(1:min(end,8)));
    for k = 1:4
        v = T.(ints{k})(T.group == g);   v = v(isfinite(v));
        fprintf(' %5.2f [%5.2f %5.2f]       ', median(v), prctile(v, 25), prctile(v, 75));
    end
    fprintf('\n');
end
fprintf('\n================ CONTAMINATION: %% of points (pooled) | median over subjects [range] ================\n');
crit = {sprintf('EE < %g s  (entry inside ERS window)', THR_SHORT), 'EE < 1.5 s', sprintf('GE < %g s (ERD & ERS windows overlap)', THR_GE(1)), ...
        sprintf('GE < %g s (epochs overlap)', THR_GE(2)), sprintf('TR < %g s (point p ERS / point p+1 ERD)', THR_TR)};
for c = 1:numel(crit)
    fprintf('%s\n', crit{c});
    for g = [2 1]
        sel = T.group == g;   fl = flag_of(T, c, THR_SHORT, THR_GE, THR_TR);
        [pooled, perS] = frac_by_subject(T, sel, fl);
        fprintf('   %-10s pooled %5.1f %% | per subject median %5.1f %% [%4.1f - %4.1f]  (n subj %d)\n', grpName{g}, 100*pooled, 100*median(perS), 100*min(perS), 100*max(perS), numel(perS));
    end
end

fprintf('\n================ SUTURES (repetitions) WITH >= 1 / >= 2 SHORT PASSAGES (EE < %g s) ================\n', THR_SHORT);
nShortRep = cell(1, 2);
for g = 1:2
    sel = T.group == g;
    [rk, ~, ri] = unique(T(sel, {'subj', 'scenario', 'rep'}), 'rows');
    nShortRep{g} = accumarray(ri, double(T.EE(sel) < THR_SHORT), [height(rk) 1]);
    nPts = accumarray(ri, 1, [height(rk) 1]);
    fprintf('%-10s %4d repetitions | >=1 short: %5.1f %% | >=2 short: %5.1f %% | all points short: %.1f %%\n', grpName{g}, height(rk), ...
        100*mean(nShortRep{g} >= 1), 100*mean(nShortRep{g} >= 2), 100*mean(nShortRep{g} == nPts));
end

fprintf('\n================ EXPERTS vs RESIDENTS, subject medians (rank-sum) ================\n');
M = nan(max(numel(subjR), numel(subjE)), 2, 4);   % subject medians [subject x group x interval]
for k = 1:4
    for g = 1:2
        ss = tern(g == 1, subjR, subjE);
        for s = 1:numel(ss)
            v = T.(ints{k})(T.group == g & strcmp(T.subj, ss{s}));   v = v(isfinite(v));
            if numel(v) >= 5, M(s, g, k) = median(v); end
        end
    end
    a = M(:, 2, k);  b = M(:, 1, k);   a = a(~isnan(a));  b = b(~isnan(b));
    fprintf('%-6s experts %5.2f s (n=%d) | residents %5.2f s (n=%d) | p = %.3f\n', ints{k}, median(a), numel(a), median(b), numel(b), ranksum(a, b));
end

%% 4. FIGURE 1: distributions
f = claude_figure_right('Gap 1 - interval distributions', 1500, 800);   set(f, 'Color', 'w');
lims = {[], THR_SHORT, THR_GE, THR_TR};
for k = 1:4
    ax = subplot(2, 2, k);   hold(ax, 'on');
    for g = [1 2]
        v = sort(T.(ints{k})(T.group == g & isfinite(T.(ints{k}))));
        plot(ax, v, (1:numel(v)) / numel(v), '-', 'Color', grpCol(g, :), 'LineWidth', 2);
    end
    for L = lims{k}, xline(ax, L, ':k'); end
    set(ax, 'XScale', 'log', 'Box', 'off', 'FontSize', 11);   xlim(ax, [0.3 80]);   grid(ax, 'on');
    xlabel(ax, 'seconds (log)');   ylabel(ax, 'cumulative fraction of points');   title(ax, intLab{k});
    if k == 1, legend(ax, grpName, 'Location', 'southeast'); end
end
sgtitle('Timing of the events of a suture point - dotted lines = window limits of the ERD / ERS analyses');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap1_distributions');

%% 5. FIGURE 2: subject medians
f = claude_figure_right('Gap 2 - subject medians', 1500, 480);   set(f, 'Color', 'w');
for k = 1:4
    ax = subplot(1, 4, k);   hold(ax, 'on');
    for g = 1:2
        y = M(:, g, k);   y = y(~isnan(y));
        x = g + 0.18 * (rand(size(y)) - 0.5);
        scatter(ax, x, y, 36, grpCol(g, :), 'filled', 'MarkerFaceAlpha', 0.7);
        plot(ax, g + [-0.3 0.3], median(y) * [1 1], '-', 'Color', grpCol(g, :), 'LineWidth', 3);
    end
    set(ax, 'XLim', [0.5 2.5], 'XTick', 1:2, 'XTickLabel', grpName, 'Box', 'off', 'FontSize', 11);   ylabel(ax, 'median (s)');
    title(ax, intLab{k}, 'FontSize', 10);
end
sgtitle('One dot = one subject (median over his points)');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap2_subject_medians');

%% 6. FIGURE 3: trend across repetitions
f = claude_figure_right('Gap 3 - trend over repetitions', 1500, 760);   set(f, 'Color', 'w');
for g = 1:2
    nRep = tern(g == 1, 10, 20);   ss = tern(g == 1, subjR, subjE);
    medEE = nan(numel(ss), nRep);   fracS = nan(numel(ss), nRep);
    for s = 1:numel(ss)
        for r = 1:nRep
            v = T.EE(T.group == g & strcmp(T.subj, ss{s}) & T.rep == r);
            if numel(v) >= 2, medEE(s, r) = median(v);  fracS(s, r) = mean(v < THR_SHORT); end
        end
    end
    for row = 1:2
        ax = subplot(2, 2, (row - 1) * 2 + g);   hold(ax, 'on');
        Z = tern(row == 1, medEE, fracS * 100);
        plot(ax, 1:nRep, Z', '-', 'Color', [grpCol(g, :) 0.25], 'LineWidth', 0.8);
        plot(ax, 1:nRep, median(Z, 1, 'omitnan'), '-o', 'Color', grpCol(g, :), 'LineWidth', 2.5, 'MarkerFaceColor', grpCol(g, :));
        if row == 1, set(ax, 'YScale', 'log'); yline(ax, THR_SHORT, ':k'); ylabel(ax, 'median EE (s, log)');
        else,        ylabel(ax, sprintf('%% of points with EE < %g s', THR_SHORT)); end
        set(ax, 'Box', 'off', 'FontSize', 11, 'XLim', [0.5 nRep + 0.5]);   xlabel(ax, 'repetition (inside the scenario for residents)');
        title(ax, sprintf('%s (thin = subject, thick = group median)', grpName{g}), 'FontSize', 10);
    end
end
sgtitle('Needle-passage time (entry \rightarrow exit) across repetitions');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap3_trend_repetitions');

%% 7. FIGURE 4: threshold sweep
thr = 0.5:0.25:8;
f = claude_figure_right('Gap 4 - threshold sweep', 1500, 480);   set(f, 'Color', 'w');
sweepVar = {'EE', 'GE', 'TR'};   sweepMark = {THR_SHORT, THR_GE, THR_TR};
for k = 1:3
    ax = subplot(1, 3, k);   hold(ax, 'on');
    for g = 1:2
        ss = tern(g == 1, subjR, subjE);   F = nan(numel(ss), numel(thr));
        for s = 1:numel(ss)
            v = T.(sweepVar{k})(T.group == g & strcmp(T.subj, ss{s}));   v = v(isfinite(v));
            if numel(v) >= 5, F(s, :) = arrayfun(@(t) mean(v < t), thr) * 100; end
        end
        q = prctile(F, [25 50 75], 1);
        fill(ax, [thr fliplr(thr)], [q(1, :) fliplr(q(3, :))], grpCol(g, :), 'FaceAlpha', 0.18, 'EdgeColor', 'none');
        plot(ax, thr, q(2, :), '-', 'Color', grpCol(g, :), 'LineWidth', 2.5);
    end
    for L = sweepMark{k}, xline(ax, L, ':k'); end
    set(ax, 'Box', 'off', 'FontSize', 11);   xlabel(ax, 'threshold (s)');   ylabel(ax, '% of points below the threshold');
    title(ax, sprintf('%s: %s', sweepVar{k}, strrep(intLab{find(strcmp(ints, sweepVar{k}))}, '\rightarrow', '->')), 'FontSize', 10);
    if k == 1, legend(ax, {'', 'Residents', '', 'Experts'}, 'Location', 'southeast'); end
end
sgtitle('How the "contaminated" fraction depends on the threshold (line = median over subjects, band = IQR)');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap4_threshold_sweep');

%% 8. FIGURE 5: short passages per suture
f = claude_figure_right('Gap 5 - short passages per suture', 900, 480);   set(f, 'Color', 'w');
ax = axes;   hold(ax, 'on');
H = zeros(5, 2);
for g = 1:2, H(:, g) = histcounts(nShortRep{g}, -0.5:1:4.5)' / numel(nShortRep{g}) * 100; end
b = bar(ax, 0:4, H);   b(1).FaceColor = grpCol(1, :);   b(2).FaceColor = grpCol(2, :);
set(ax, 'Box', 'off', 'FontSize', 12);   xlabel(ax, sprintf('number of points with EE < %g s in the suture (repetition)', THR_SHORT));   ylabel(ax, '% of sutures');
legend(ax, grpName);   title(ax, 'How many sutures contain short needle passages');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap5_short_per_suture');

%% 9. FIGURE 6: EE by point
f = claude_figure_right('Gap 6 - EE by point', 1100, 480);   set(f, 'Color', 'w');
for g = 1:2
    ax = subplot(1, 2, g);   hold(ax, 'on');   ss = tern(g == 1, subjR, subjE);
    P = nan(numel(ss), 4);
    for s = 1:numel(ss), for p = 1:4
        v = T.EE(T.group == g & strcmp(T.subj, ss{s}) & T.point == p);   if numel(v) >= 3, P(s, p) = median(v); end
    end, end
    plot(ax, 1:4, P', '-', 'Color', [grpCol(g, :) 0.25]);
    plot(ax, 1:4, median(P, 1, 'omitnan'), '-o', 'Color', grpCol(g, :), 'LineWidth', 2.5, 'MarkerFaceColor', grpCol(g, :));
    yline(ax, THR_SHORT, ':k');   set(ax, 'YScale', 'log', 'Box', 'off', 'FontSize', 11, 'XTick', 1:4);
    xlabel(ax, 'suture point');   ylabel(ax, 'median EE (s, log)');   title(ax, grpName{g});
end
sgtitle('Needle passage time by suture point (thin = subject)');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap6_EE_by_point');

%% 10. FIGURE 7: timelines of one expert and one resident
f = claude_figure_right('Gap 7 - timelines', 1500, 700);   set(f, 'Color', 'w');
for g = [2 1]
    sel = find(T.group == g);
    [ck, ~, ci] = unique(T(sel, {'subj', 'scenario'}), 'rows');
    [~, best] = max(accumarray(ci, 1));                                   % subject x scenario with most complete points
    pick = sel(ci == best);   Tp = T(pick, :);
    ax = subplot(1, 2, tern(g == 2, 1, 2));   hold(ax, 'on');
    reps = unique(Tp.rep)';
    for i = 1:numel(reps)
        Tr = Tp(Tp.rep == reps(i), :);   t0 = min(Tr.tGrasp);
        for j = 1:height(Tr)
            fill(ax, [Tr.tGrasp(j) Tr.tEntry(j) Tr.tEntry(j) Tr.tGrasp(j)] - t0, i + [-0.35 -0.35 0.35 0.35], [0.65 0.80 0.95], 'EdgeColor', 'none');
            fill(ax, [Tr.tEntry(j) Tr.tExit(j)  Tr.tExit(j)  Tr.tEntry(j)] - t0, i + [-0.35 -0.35 0.35 0.35], [0.80 0.10 0.10], 'EdgeColor', 'none');
            text(ax, Tr.tGrasp(j) - t0, i, num2str(Tr.point(j)), 'FontSize', 7, 'HorizontalAlignment', 'right');
        end
    end
    set(ax, 'YDir', 'reverse', 'Box', 'off', 'FontSize', 11, 'YTick', 1:numel(reps), 'YTickLabel', reps);
    ylabel(ax, 'repetition');   xlabel(ax, 'seconds from the first grasp of the repetition');
    title(ax, sprintf('%s %s (scenario %d): light = grasp->entry, red = entry->exit', grpName{g}, ck.subj{best}, ck.scenario(best)), 'FontSize', 10);
end
sgtitle('Timeline of the suture points (numbers = point). A red bar shorter than 2 s = entry inside the ERS window');
save_fig(f, SAVE_FIGS, fig_dir, 'Gap7_timelines');
fprintf('\nFigures saved in %s\n', fig_dir);

%% ---------------------------------------------------------------------
function fl = flag_of(T, c, THR_SHORT, THR_GE, THR_TR)
    switch c
        case 1, fl = double(T.EE < THR_SHORT);
        case 2, fl = double(T.EE < 1.5);
        case 3, fl = double(T.GE < THR_GE(1));
        case 4, fl = double(T.GE < THR_GE(2));
        case 5, fl = double(T.TR < THR_TR);
    end
    if c == 5, fl(isnan(T.TR)) = NaN; end          % NaN: transport not available (point 4 or missing next grasp)
end

function [pooled, perS] = frac_by_subject(T, sel, fl)
    ok = sel & ~isnan(fl);   pooled = mean(fl(ok));
    ss = unique(T.subj(ok), 'stable');   perS = nan(numel(ss), 1);
    for s = 1:numel(ss)
        m = ok & strcmp(T.subj, ss{s});
        if nnz(m) >= 5, perS(s) = mean(fl(m)); end
    end
    perS = perS(~isnan(perS));
end

function save_fig(f, doSave, dirName, name)
    if doSave, print(f, fullfile(dirName, [name '.png']), '-dpng', '-r110'); end
end

function out = tern(c, a, b)
    if c, out = a; else, out = b; end
end
