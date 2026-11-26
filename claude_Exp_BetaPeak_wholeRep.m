% claude_Exp_BetaPeak_wholeRep.m
% =====================================================================================================
% EXPERTS, TASK 1 AND TASK 2: ALPHA AND BETA PEAKS in the motor areas, using the WHOLE repetition
% (not only the event-locked windows of the ERD / ERS analysis). Same method as claude_Res_AlphaBetaPeak_wholeRep.m.
%
% WINDOW OF A REPETITION (a "repetition" = a scenario in Task 1, a repetition in Task 2)
%   from the marker MS<n> (the go; fallback S<n> in Task 1, R<n> in Task 2) to the LAST valid needle exit of it.
%   Task 2: exits = events Ext*_R<n> of  <expert>_Task2_exitERS_events.set
%   Task 1: exits read from DataStructures/ExitERS_Times_IE.mat (seconds after MS) on <expert>Task1_final.set
%   Excluded in the original scripts (no value here): Task 1 IE02 scenarios 1 and 4, IE10 scenario 6;
%           Task 2 IE03 rep 10, IE05 rep 9, IE07 rep 15, IE10 rep 4 (they have no exits).
%   If the window contains 'boundary' events (removed data) it is cut there and the pieces are averaged
%   (pieces shorter than the Welch window are dropped).
%
% HOW THE PEAK IS FOUND (FOOOF, same settings as Task2_fooof.m; helper claude_fooof_peak.m)
%   1. Welch spectrum of every channel (4 s Hamming windows, 50 % overlap), averaged over the channels of the ROI
%      ROIs: MotorLeft, MotorRight and Motor (L+R) = the two together
%   2. FOOOF on the RAW spectrum over 4-35 Hz (it fits the 1/f background and the peaks together)
%   3. PEAK of a band (ALPHA 8-15, BETA 15-25 Hz) = highest FOOOF peak with its centre in the band; none -> NaN
%
% FIGURES (Figures_Exp_BetaPeak/): spectra with the peaks (whole task, per expert), peak frequency across repetitions
% PRINTED: peak of every expert, how many experts have a peak (per band, ROI, repetition).
% =====================================================================================================

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));      % claude_figure_right.m, claude_fooof_peak.m
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;
addpath('/home/acatalano/Documents/MATLAB/fooof_mat/fooof_mat/');       % FOOOF (python wrapper)

%% 1. SETTINGS -----------------------------------------------------------------------------------------
USE_SAVED = true;         % true: use the saved spectra of a task if they exist (skips the slow part); false: recompute
SAVE_FIGS = true;
bands(1).name = 'Alpha';  bands(1).rng = [8 15];
bands(2).name = 'Beta';   bands(2).rng = [15 25];
EDGE_HZ   = 1;            % a peak closer than this to a band edge is flagged '*'
WEAK_PW   = 0.10;         % a peak lower than this (log10 above the aperiodic fit) is flagged '~'
FIT       = [4 35];       % Hz, range fitted by FOOOF and of the spectra shown
WIN_S     = 4;            % Welch window (s)

subjects = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
D        = '/home/acatalano/Desktop/Intuitive/DataStructures/';
fig_dir  = [D 'Figures_Exp_BetaPeak'];
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
ROI(1).name = 'MotorLeft';   ROI(1).ch = [15 20 10];     % same channels as Task12_Exp_ERD_ERS_ROI.m
ROI(2).name = 'MotorRight';  ROI(2).ch = [13 19 9];
ROI(3).name = 'Motor (L+R)'; ROI(3).ch = [ROI(1).ch ROI(2).ch];
nS = numel(subjects);   nR = numel(ROI);   nB = numel(bands);   rngM = reshape([bands.rng], 2, [])';

tasks(1).name = 'Task 1';  tasks(1).nRep = 6;   tasks(1).repName = 'Scenario';    tasks(1).mode = 'matrix';  tasks(1).fallback = 'S%d';
tasks(1).eegDir = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';   tasks(1).eegSuffix = 'Task1_final.set';
tasks(1).exitMat = [D 'ExitERS_Times_IE.mat'];   tasks(1).saved = {[D 'Exp_T1_AlphaPeak_wholeRep.mat'], [D 'Exp_T1_BetaPeak_wholeRep.mat']};
tasks(1).excl = {'IE02', [1 4]; 'IE10', 6};

tasks(2).name = 'Task 2';  tasks(2).nRep = 20;  tasks(2).repName = 'Repetition';  tasks(2).mode = 'events';  tasks(2).fallback = 'R%d';
tasks(2).eegDir = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';                 tasks(2).eegSuffix = '_Task2_exitERS_events.set';
tasks(2).exitMat = '';   tasks(2).saved = {[D 'Exp_T2_AlphaPeak_wholeRep.mat'], [D 'Exp_T2_BetaPeak_wholeRep.mat']};
tasks(2).excl = {};

%% 2. SPECTRUM OF EVERY REPETITION (slow part, saved: the RAW Welch spectra), THEN THE PEAKS ------------------------
for k = 1:numel(tasks)
    T = tasks(k);
    fprintf('\n################ %s ################\n', T.name);
    sv = T.saved(cellfun(@(p) exist(p, 'file') > 0, T.saved));
    if USE_SAVED && ~isempty(sv)
        S = load(sv{1});   PSD = S.PSD;   dur = S.dur;   fAxis = S.fAxis;
        fprintf('Loaded the saved spectra %s\n', sv{1});
    else
        [PSD, dur, fAxis] = compute_psd(T, subjects, ROI(1:2), WIN_S, FIT);
        save(T.saved{1}, 'PSD', 'dur', 'fAxis', 'subjects', 'FIT');
        fprintf('Saved %s\n', T.saved{1});
    end
    if size(PSD, 2) == 2, PSD(:, 3, :, :) = mean(PSD(:, 1:2, :, :), 2); end     % joint motor ROI = mean of the two

    peakRep = nan(nS, nR, nB, T.nRep);   peakAll = nan(nS, nR, nB);   ampAll = nan(nS, nR, nB);   bwAll = nan(nS, nR, nB);   corrAll = nan(nS, nR, numel(fAxis));
    for s = 1:nS
        for r = 1:nR
            for rep = 1:T.nRep
                spec = squeeze(PSD(s, r, rep, :))';
                if ~any(isnan(spec)), o = claude_fooof_peak(fAxis, spec, FIT, rngM);   peakRep(s, r, :, rep) = o.cf; end
            end
            w = dur(s, :);   ok = ~isnan(w);
            if any(ok)
                spec = squeeze(sum(PSD(s, r, ok, :) .* reshape(w(ok), 1, 1, [], 1), 3)) / sum(w(ok));
                o = claude_fooof_peak(fAxis, spec(:)', FIT, rngM);
                peakAll(s, r, :) = o.cf;   ampAll(s, r, :) = o.pw;   bwAll(s, r, :) = o.bw;
                if ~isempty(o.freqs), corrAll(s, r, :) = interp1(o.freqs, o.resid, fAxis, 'linear', NaN); end
            end
        end
        fprintf('  FOOOF done: %s\n', subjects{s});
    end
    tasks(k).fAxis = fAxis;   tasks(k).peakRep = peakRep;   tasks(k).peakAll = peakAll;   tasks(k).ampAll = ampAll;   tasks(k).corrAll = corrAll;

    for b = 1:nB
        fprintf('\n%s: %s PEAK OF EACH EXPERT, WHOLE TASK (FOOOF, range %d-%d Hz; NaN = no peak found)\n', T.name, bands(b).name, bands(b).rng);
        fprintf('each cell: centre Hz (h = height in log10 above the 1/f, w = width in Hz); * = within %g Hz of the band edge, ~ = height < %.2f\n', EDGE_HZ, WEAK_PW);
        fprintf('%-6s %24s %24s %24s\n', 'expert', ROI(1).name, ROI(2).name, ROI(3).name);
        for s = 1:nS
            fprintf('%-6s', subjects{s});
            for r = 1:nR, fprintf(' %24s', pk_str(peakAll(s, r, b), ampAll(s, r, b), bwAll(s, r, b), bands(b).rng, EDGE_HZ, WEAK_PW)); end
            fprintf('\n');
        end
        solid = peakAll(:, :, b) > bands(b).rng(1) + EDGE_HZ & peakAll(:, :, b) < bands(b).rng(2) - EDGE_HZ & ampAll(:, :, b) >= WEAK_PW;
        fprintf('%-6s mean of the peaks found: %.2f / %.2f / %.2f Hz;  peaks found: %d / %d / %d;  SOLID peaks (not edge, not weak): %d / %d / %d of %d experts\n', 'all', ...
            mean(peakAll(:, 1, b), 'omitnan'), mean(peakAll(:, 2, b), 'omitnan'), mean(peakAll(:, 3, b), 'omitnan'), nnz(~isnan(peakAll(:, 1, b))), nnz(~isnan(peakAll(:, 2, b))), nnz(~isnan(peakAll(:, 3, b))), ...
            nnz(solid(:, 1)), nnz(solid(:, 2)), nnz(solid(:, 3)), nS);
        fprintf('       mean of the SOLID peaks only: %.2f / %.2f / %.2f Hz\n', mean(peakAll(solid(:, 1), 1, b), 'omitnan'), mean(peakAll(solid(:, 2), 2, b), 'omitnan'), mean(peakAll(solid(:, 3), 3, b), 'omitnan'));
        fprintf('experts with a peak in each %s:\n%-18s', lower(T.repName), T.repName); fprintf('%4d', 1:T.nRep); fprintf('\n');
        for r = 1:nR, fprintf('%-18s', [bands(b).name ' ' ROI(r).name]); fprintf('%4d', squeeze(sum(~isnan(peakRep(:, r, b, :)), 1))); fprintf('\n'); end
    end
end

%% 3. FIGURE 1: SPECTRA WITH THE PEAKS (one figure per band) -------------------------------------------------
colS = lines(nS);
for b = 1:nB
    f1 = claude_figure_right(['Experts ' bands(b).name ' peak, whole task'], 1800, 900);   set(f1, 'Color', 'w');
    for k = 1:numel(tasks)
        for r = 1:nR
            subplot(numel(tasks), nR, (k - 1) * nR + r);   hold on;
            fA = tasks(k).fAxis;   h = gobjects(nS, 1);
            for s = 1:nS
                h(s) = plot(fA, squeeze(tasks(k).corrAll(s, r, :))', '-', 'Color', colS(s, :), 'LineWidth', 1.2);
                if ~isnan(tasks(k).peakAll(s, r, b)), scatter(tasks(k).peakAll(s, r, b), tasks(k).ampAll(s, r, b), 45, colS(s, :), 'filled', 'MarkerEdgeColor', 'k'); end
            end
            plot(fA, squeeze(mean(tasks(k).corrAll(:, r, :), 1, 'omitnan'))', 'k-', 'LineWidth', 3);
            xlim(FIT);   grid on;   box on;   xlabel('Frequency (Hz)');   ylabel('log10 power minus FOOOF aperiodic fit');
            yl = ylim;   yl = [min(yl(1), -0.3), yl(2)];   ylim(yl);
            pt = patch(bands(b).rng([1 2 2 1]), yl([1 1 2 2]), [0.5 0.5 0.5], 'FaceAlpha', 0.10, 'EdgeColor', 'none');   uistack(pt, 'bottom');
            title(sprintf('%s - %s', tasks(k).name, ROI(r).name), 'FontSize', 11);
            if k == 1 && r == nR, legend(h, subjects, 'Location', 'eastoutside'); end
        end
    end
    sgtitle(sprintf('Experts: spectrum of the whole task minus the FOOOF aperiodic fit. Dot = %s peak (%d-%d Hz), black = mean, grey = band', bands(b).name, bands(b).rng));
    if SAVE_FIGS, print(f1, fullfile(fig_dir, ['Exp_' bands(b).name '_peak_spectra.png']), '-dpng', '-r110'); end
end

%% 4. FIGURE 2: PEAK FREQUENCY ACROSS REPETITIONS (one figure per band) ---------------------------------------
for b = 1:nB
    f2 = claude_figure_right(['Experts ' bands(b).name ' peak across repetitions'], 1800, 950);   set(f2, 'Color', 'w');
    for r = 1:nR
        for k = 1:numel(tasks)
            if k == 1, subplot(nR, 4, (r - 1) * 4 + 1); else, subplot(nR, 4, (r - 1) * 4 + (2:4)); end
            hold on;   nRep = tasks(k).nRep;   offs = linspace(-0.28, 0.28, nS);   h = gobjects(nS, 1);
            for s = 1:nS
                h(s) = scatter((1:nRep) + offs(s), squeeze(tasks(k).peakRep(s, r, b, :))', 30, colS(s, :), 'filled', 'MarkerFaceAlpha', 0.65, 'MarkerEdgeColor', 'none');
            end
            Y = squeeze(tasks(k).peakRep(:, r, b, :));
            errorbar(1:nRep, mean(Y, 1, 'omitnan'), std(Y, 0, 1, 'omitnan'), 'o', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'LineWidth', 1.8, 'CapSize', 10);
            xlim([0.4 nRep + 0.6]);   xticks(1:nRep);   ylim(bands(b).rng + [-1 1]);   grid on;   box on;
            title(sprintf('%s - %s', tasks(k).name, ROI(r).name), 'FontSize', 11);
            if k == 1, ylabel([bands(b).name ' peak frequency (Hz)']); end
            if r == nR, xlabel(tasks(k).repName); end
            if r == 1 && k == 2, legend(h, subjects, 'Location', 'eastoutside'); end
        end
    end
    sgtitle(sprintf('Experts: %s peak frequency (FOOOF, %d-%d Hz) of the whole repetition (dots = experts, black = mean +/- SD)', bands(b).name, bands(b).rng));
    if SAVE_FIGS, print(f2, fullfile(fig_dir, ['Exp_' bands(b).name '_peak_acrossReps.png']), '-dpng', '-r110'); end
end


%% ---------------------------------------------------------------------
function [PSD, dur, fAxis] = compute_psd(T, subjects, ROI, WIN_S, FIT)
% PSD(expert, roi, rep, freq) = Welch spectrum of the whole repetition (MS -> last exit); dur(expert, rep) = seconds used.
    nS = numel(subjects);   nR = numel(ROI);   PSD = [];   dur = nan(nS, T.nRep);   fAxis = [];
    if strcmp(T.mode, 'matrix'), E = load(T.exitMat);   exitM = E.ValidExitPunctureMatrix;   end     % (expert, scenario, point), seconds after MS
    for s = 1:nS
        EEG = pop_loadset('filename', [subjects{s} T.eegSuffix], 'filepath', T.eegDir);
        if EEG.trials > 1, error('%s is epoched, I need the continuous data', subjects{s}); end
        fs = EEG.srate;   types = {EEG.event.type};   lats = [EEG.event.latency];
        bLat = lats(strcmp(types, 'boundary'));   winN = round(WIN_S * fs);
        fprintf('\n=== %s (srate %g Hz, %d channels, %d boundaries) ===\n', subjects{s}, fs, EEG.nbchan, numel(bLat));
        for rep = 1:T.nRep
            % excluded repetitions of the original scripts
            skip = false;
            for e = 1:size(T.excl, 1), if strcmp(subjects{s}, T.excl{e, 1}) && ismember(rep, T.excl{e, 2}), skip = true; end, end
            if skip, fprintf('  rep %02d: excluded in the original scripts\n', rep); continue; end
            % start marker
            i0 = find(strcmp(types, sprintf('MS%d', rep)), 1);
            if isempty(i0), i0 = find(strcmp(types, sprintf(T.fallback, rep)), 1); end
            if isempty(i0), fprintf('  rep %02d: no start marker -> no value\n', rep); continue; end
            t0 = round(lats(i0));
            % end = last valid exit
            if strcmp(T.mode, 'events')
                ext = find(startsWith(types, 'Ext') & endsWith(types, sprintf('_R%02d', rep)));
                if isempty(ext), fprintf('  rep %02d: no exits -> no value\n', rep); continue; end
                t1 = round(max(lats(ext)));
            else
                ex = squeeze(exitM(s, rep, :));
                if all(isnan(ex)), fprintf('  rep %02d: no valid exit time -> no value\n', rep); continue; end
                t1 = min(t0 + round(max(ex) * fs), EEG.pnts);
            end
            if t1 <= t0, fprintf('  rep %02d: last exit before the start marker -> no value\n', rep); continue; end
            edges = [t0, sort(bLat(bLat > t0 & bLat < t1)), t1];                    % cut at the boundaries
            acc = [];   wsum = 0;   used = 0;
            for p = 1:numel(edges) - 1
                a = ceil(edges(p)) + 1;   b = floor(edges(p + 1)) - 1;
                if p == 1, a = t0; end
                if b - a + 1 < winN, continue; end                                  % piece too short
                for r = 1:nR
                    X = double(EEG.data(ROI(r).ch, a:b))';                           % samples x channels
                    [f, pxx, nSeg] = welch_psd(X, winN, round(winN / 2), fs);
                    if isempty(acc), acc = zeros(nR, numel(f)); end
                    acc(r, :) = acc(r, :) + nSeg * mean(pxx, 2)';                    % ROI power, weighted by number of windows
                end
                wsum = wsum + nSeg;   used = used + (b - a + 1) / fs;
            end
            if wsum == 0, fprintf('  rep %02d: no piece long enough -> no value\n', rep); continue; end
            if isempty(PSD), keepF = f >= FIT(1) & f <= FIT(2);   fAxis = f(keepF);   PSD = nan(nS, nR, T.nRep, nnz(keepF)); end
            for r = 1:nR, PSD(s, r, rep, :) = acc(r, keepF) / wsum; end
            dur(s, rep) = used;
        end
        fprintf('  repetitions with a value: %d of %d (mean %.0f s each)\n', nnz(~isnan(dur(s, :))), T.nRep, mean(dur(s, :), 'omitnan'));
    end
end

function [f, p, nSeg] = welch_psd(X, winN, nover, fs)
% Welch power spectrum without toolboxes. X = samples x channels. Returns f (Hz), p = [freq x channels], nSeg = number of windows.
    w = 0.54 - 0.46 * cos(2 * pi * (0:winN - 1)' / (winN - 1));                  % Hamming window
    step = winN - nover;   nSeg = floor((size(X, 1) - nover) / step);
    P = zeros(floor(winN / 2) + 1, size(X, 2));
    for k = 1:nSeg
        seg = X((k - 1) * step + (1:winN), :);
        seg = (seg - mean(seg, 1)) .* w;
        F = fft(seg, winN);
        P = P + abs(F(1:floor(winN / 2) + 1, :)) .^ 2;
    end
    p = P / (nSeg * (w' * w) * fs);
    f = (0:floor(winN / 2))' * fs / winN;
end

function s = pk_str(cf, pw, bw, rng, EDGE_HZ, WEAK_PW)
% text of one table cell: centre (h = height, w = width) and flags
    if isnan(cf), s = 'NaN'; return; end
    fl = '';   if cf <= rng(1) + EDGE_HZ || cf >= rng(2) - EDGE_HZ, fl = [fl '*']; end
    if pw < WEAK_PW, fl = [fl '~']; end
    s = sprintf('%.2f (h%.2f w%.1f)%s', cf, pw, bw, fl);
end
