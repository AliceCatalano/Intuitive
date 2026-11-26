% claude_Res_SpectraAfterICA.m
% =====================================================================================================
% SPECTRUM OF THE WHOLE RECORDING, 0-100 Hz, of every cleaned dataset, to check that the filtering and the cleaning
% were done correctly.
%   residents : IR_Task/ERDS/IR##_afterICA.set
%   experts   : IE_Task/Task2/IE##Task2_final.set   (INCLUDE_EXPERTS = true, for comparison)
%
% WHAT TO LOOK AT IN THE FIGURES
%   Figure 1  all datasets on top of each other (mean over channels, dB). Red = history says NO 2-40 Hz band-pass,
%             blue = history says band-pass, green dashed = experts. Black thick lines = median of each group.
%             Dashed vertical lines at 2, 40, 45, 50 Hz (the filter edges / the notch / the mains).
%             A correctly band-passed recording falls steeply below 2 Hz and above 40 Hz, with a notch at 45-50 Hz.
%             An unfiltered one stays high above 40 Hz and has a mains peak at 50 Hz.
%   Figure 2  one panel per dataset: grey = every channel, black = mean over channels (same y axis everywhere).
%             Look for single channels far above the others (noisy electrode, line noise) and for peaks at 50 Hz.
%
% WHAT THE TABLE PRINTS (per dataset)
%   history : band-pass 2-40 and notch 45-50 found in EEG.history (yes/NO)
%   min / bnd : duration of the recording, number of 'boundary' events (removed data)
%   ICA     : number of ICA components removed according to the history (pop_subcomp)
%   %bad     : % of 1 s windows (channel x window) with peak-to-peak > PTP_UV microvolts = remaining large artefacts
%   dB values: power in a band relative to 4-35 Hz, in dB (10*log10):
%             <1Hz and 1-2Hz  (drift; low after a 2 Hz high-pass)      45-50Hz (notch)    50-55Hz (mains)
%             60-100Hz  (high frequencies; low after a 40 Hz low-pass)
%   looks   : 'filtered' / 'unfiltered' judged from the 60-100 Hz value (closer to the median of the datasets with a
%             recorded band-pass or of the ones without); a 'MISMATCH' marks a dataset whose spectrum disagrees with its history.
% =====================================================================================================

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));      % claude_figure_right.m
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

%% 1. SETTINGS -----------------------------------------------------------------------------------------
INCLUDE_EXPERTS = true;
WIN_S     = 4;          % Welch window (s) -> 0.25 Hz resolution
FMAX      = 100;        % Hz shown
PTP_UV    = 150;        % peak-to-peak (microvolts) over 1 s above which a channel-window counts as a large artefact
SAVE_FIGS = true;
fig_dir   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_Spectra_AfterICA';
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

groups(1).name = 'residents';  groups(1).path = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/';    groups(1).pattern = 'IR*_afterICA.set';
groups(2).name = 'experts';    groups(2).path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2/';   groups(2).pattern = 'IE*Task2_final.set';
if ~INCLUDE_EXPERTS, groups(2) = []; end

%% 2. COMPUTE ------------------------------------------------------------------------------------------
D = struct('id', {}, 'group', {}, 'hasBP', {}, 'hasNotch', {}, 'minutes', {}, 'nBound', {}, 'nIca', {}, 'pBad', {}, 'f', {}, 'Pch', {});
for g = 1:numel(groups)
    files = dir([groups(g).path groups(g).pattern]);
    fprintf('\n=== %s: %d files ===\n', groups(g).name, numel(files));
    for k = 1:numel(files)
        EEG = pop_loadset('filename', files(k).name, 'filepath', groups(g).path);
        if EEG.trials > 1, warning('%s is epoched, skipped', files(k).name); continue; end
        h  = EEG.history;   fs = EEG.srate;
        d.id       = files(k).name(1:4);   d.group = g;
        d.hasBP    = ~isempty(regexp(h, 'locutoff''\s*,\s*2\s*,\s*''hicutoff''\s*,\s*40', 'once'));
        d.hasNotch = ~isempty(regexp(h, 'locutoff''\s*,\s*45\s*,\s*''hicutoff''\s*,\s*50', 'once'));
        d.minutes  = EEG.pnts / fs / 60;
        d.nBound   = nnz(strcmp({EEG.event.type}, 'boundary'));
        tok = regexp(h, 'pop_subcomp\(\s*EEG\s*,\s*\[([^\]]*)\]', 'tokens');
        d.nIca     = NaN;   if ~isempty(tok), d.nIca = numel(sscanf(tok{end}{1}, '%f')); end   % components removed (last pop_subcomp)
        % fraction of 1 s channel-windows with a large peak-to-peak amplitude
        X = double(EEG.data);   nW = floor(size(X, 2) / fs);
        W = reshape(X(:, 1:nW * fs), size(X, 1), fs, nW);
        ptp = squeeze(max(W, [], 2) - min(W, [], 2));                          % [channel x window]
        d.pBad = 100 * mean(ptp(:) > PTP_UV);
        [f, P] = welch_psd(X', round(WIN_S * fs), round(WIN_S * fs / 2), fs);    % P = [freq x channel]
        keep = f <= FMAX;   d.f = f(keep);   d.Pch = P(keep, :);
        D(end+1) = d; %#ok<SAGROW>
        fprintf('  %s done (%.1f min, %d channels)\n', d.id, d.minutes, size(X, 1));
    end
end
n = numel(D);   f = D(1).f;

%% 3. TABLE --------------------------------------------------------------------------------------------
band = @(d, lo, hi) 10 * log10(mean(mean(d.Pch(d.f >= lo & d.f <= hi, :), 1), 2) / mean(mean(d.Pch(d.f >= 4 & d.f <= 35, :), 1), 2));
B = nan(n, 5);                                                                  % <1, 1-2, 45-50, 50-55, 60-100  (dB vs 4-35 Hz)
for i = 1:n
    B(i, :) = [band(D(i), 0.25, 1), band(D(i), 1, 2), band(D(i), 45, 50), band(D(i), 50, 55), band(D(i), 60, 100)];
end
% judge "looks filtered" from the 60-100 Hz value: closer to the median of the datasets WITH a recorded band-pass or WITHOUT
withBP = [D.hasBP] == 1;   isRes = [D.group] == 1;
mYes = median(B(withBP, 5), 'omitnan');   mNo = median(B(~withBP, 5), 'omitnan');
looks = repmat({'filtered'}, n, 1);   looks(abs(B(:, 5) - mNo) < abs(B(:, 5) - mYes)) = {'unfiltered'};
fprintf('\n%-6s %-9s %-5s %-6s %5s %4s %4s %6s | %7s %7s %7s %7s %8s | %-11s %s\n', 'ID', 'group', 'BP', 'notch', 'min', 'bnd', 'ICA', '%bad', '<1Hz', '1-2Hz', '45-50', '50-55', '60-100', 'looks', '');
fprintf('(dB relative to 4-35 Hz; reference 60-100 Hz: median %.1f dB with recorded band-pass, %.1f dB without)\n', mYes, mNo);
for i = 1:n
    hist = ternary(D(i).hasBP, 'yes', 'NO');
    mis = '';   if (D(i).hasBP && strcmp(looks{i}, 'unfiltered')) || (~D(i).hasBP && strcmp(looks{i}, 'filtered')), mis = '<-- MISMATCH with the history'; end
    fprintf('%-6s %-9s %-5s %-6s %5.1f %4d %4g %6.2f | %7.1f %7.1f %7.1f %7.1f %8.1f | %-11s %s\n', D(i).id, groups([D(i).group]).name, hist, ternary(D(i).hasNotch, 'yes', 'NO'), ...
        D(i).minutes, D(i).nBound, D(i).nIca, D(i).pBad, B(i, :), looks{i}, mis);
end

%% 4. FIGURE 1: ALL DATASETS ON TOP OF EACH OTHER ------------------------------------------------------
f1 = claude_figure_right('Spectra of all cleaned datasets', 1500, 800);   set(f1, 'Color', 'w');   hold on;
col = @(i) ternary(D(i).group == 2, [0.1 0.6 0.2], ternary(D(i).hasBP, [0.2 0.4 0.9], [0.9 0.2 0.2]));
S = nan(n, numel(f));
for i = 1:n
    S(i, :) = 10 * log10(mean(D(i).Pch, 2))';
    plot(f, S(i, :), '-', 'Color', [col(i) 0.55], 'LineWidth', 1);
end
grpMask = {~withBP & isRes, withBP & isRes, ~isRes};   grpCol = {[0.8 0 0], [0 0.2 0.8], [0 0.45 0.1]};
for q = 1:3
    if any(grpMask{q}), plot(f, median(S(grpMask{q}, :), 1), '-', 'Color', grpCol{q}, 'LineWidth', 3.5); end
end
for xv = [2 40 45 50], xline(xv, ':', 'Color', [0.3 0.3 0.3]); end
xlim([0 FMAX]);   grid on;   box on;   xlabel('Frequency (Hz)');   ylabel('Power, mean over channels (dB)');
title('Whole-recording spectrum of every dataset: red = no band-pass in the history, blue = band-pass in the history, green = experts (thick = median of the group)');
if SAVE_FIGS, print(f1, fullfile(fig_dir, 'spectra_all_datasets.png'), '-dpng', '-r110'); end

%% 5. FIGURE 2: ONE PANEL PER DATASET, ALL CHANNELS ----------------------------------------------------
f2 = claude_figure_right('Spectra per dataset, all channels', 1800, 1000);   set(f2, 'Color', 'w');
nc = ceil(sqrt(n * 1.5));   nr = ceil(n / nc);
allDb = cell2mat(arrayfun(@(i) 10 * log10(D(i).Pch(:)), 1:n, 'UniformOutput', false)');   yl = [prctile(allDb, 0.5), prctile(allDb, 99.9)];
for i = 1:n
    subplot(nr, nc, i);   hold on;
    plot(f, 10 * log10(D(i).Pch), '-', 'Color', [0.8 0.8 0.8]);
    plot(f, S(i, :), '-', 'Color', col(i) * 0.7, 'LineWidth', 1.8);
    for xv = [2 40 50], xline(xv, ':', 'Color', [0.4 0.4 0.4]); end
    xlim([0 FMAX]);   ylim(yl);   grid on;   box on;
    title(sprintf('%s (BP %s)', D(i).id, ternary(D(i).hasBP, 'yes', 'NO')), 'FontSize', 9, 'Color', col(i) * 0.7);
end
sgtitle('Spectrum of every channel (grey) and mean over channels (colour) for each dataset; dotted lines at 2, 40, 50 Hz');
if SAVE_FIGS, print(f2, fullfile(fig_dir, 'spectra_per_dataset.png'), '-dpng', '-r110'); end


%% ---------------------------------------------------------------------
function [f, p] = welch_psd(X, winN, nover, fs)
% Welch power spectrum without toolboxes. X = samples x channels. Returns f (Hz), p = [freq x channels].
    w = 0.54 - 0.46 * cos(2 * pi * (0:winN - 1)' / (winN - 1));
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

function o = ternary(c, x, y)
    if c, o = x; else, o = y; end
end
