% claude_Res_ChannelCheck.m
% =====================================================================================================
% RESIDENTS: IS A CHANNEL NOISY? Check of the cleaned data (IR_Task/ERDS/IR##_afterICA.set), no raw data needed.
% Question: the right occipital hot spot (O2, also Oz) seen in the topographies comes from IR02, IR09, IR22, IR25
%           (and P4 from IR12): is that channel noisy in those residents, or is it a normal signal?
%
% For every resident and channel (whole recording) it computes
%   power4_35  log10 power 4-35 Hz            overall level of the channel
%   gamma      log10 power 25-35 Hz            muscle / electrode noise lives here
%   line       log10 power 48-52 Hz minus log10 of the mean power at 40-46 and 54-60 Hz   (> 0 = a mains line peak)
%   kurt       kurtosis of the signal          (3 = normal; large = spikes / bursts)
%   corr       median absolute correlation with the other channels   (a broken electrode correlates with nobody)
% and then, for every channel separately, how far each resident is from the other residents (robust z =
% (value - median) / (MAD / 0.6745)). Robust z > 3.5 is marked with *.
%
% OUTPUT
%   console 1 : table of the target channels (CHECK_CH) for every resident, flagged residents marked *
%   console 2 : the strongest resident x channel outliers of the gamma power, over ALL channels
%   figure 1  : heat map residents x channels of the robust z of the gamma power (red = noisier than the others)
%   figure 2  : spectrum of O2 / P4 / Cz of every resident (grey), the flagged residents in colour, median in black
% =====================================================================================================

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));      % claude_figure_right.m
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

%% 1. SETTINGS -----------------------------------------------------------------------------------------
path_ir   = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/';
CHECK_CH  = {'O2', 'Oz', 'P4', 'Cz'};                                                 % channels printed in the tables (Cz = control)
FLAGGED   = {'IR02', 'O2'; 'IR09', 'O2'; 'IR22', 'O2'; 'IR25', 'O2'; 'IR12', 'P4'};    % resident, channel highlighted in figure 2
Z_FLAG    = 3.5;
WIN_S     = 4;
SAVE_FIGS = true;
fig_dir   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ChannelCheck';
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

files = dir([path_ir 'IR*_afterICA.set']);
nS = numel(files);   subjects = arrayfun(@(f) f.name(1:4), files, 'UniformOutput', false);

%% 2. COMPUTE ------------------------------------------------------------------------------------------
metricNames = {'power4_35', 'gamma', 'line', 'kurt', 'corr'};
labelsAll = {};   M = struct();   PSD = struct();   fAxis = [];
for s = 1:nS
    EEG = pop_loadset('filename', files(s).name, 'filepath', path_ir);
    if EEG.trials > 1, error('%s is epoched', subjects{s}); end
    X  = double(EEG.data)';   fs = EEG.srate;   labs = {EEG.chanlocs.labels};
    fprintf('%s: %d channels, %.1f min\n', subjects{s}, numel(labs), size(X, 1) / fs / 60);
    [f, P] = welch_psd(X, round(WIN_S * fs), round(WIN_S * fs / 2), fs);              % P = [freq x channel]
    bandP = @(lo, hi) log10(mean(P(f >= lo & f <= hi, :), 1));
    v.power4_35 = bandP(4, 35);
    v.gamma     = bandP(25, 35);
    v.line      = bandP(48, 52) - log10(mean([mean(P(f >= 40 & f <= 46, :), 1); mean(P(f >= 54 & f <= 60, :), 1)], 1));
    m = mean(X, 1);   v.kurt = mean((X - m) .^ 4, 1) ./ (mean((X - m) .^ 2, 1) .^ 2);
    C = abs(corrcoef(X));   C(1:size(C, 1) + 1:end) = NaN;   v.corr = median(C, 1, 'omitnan');
    for c = 1:numel(labs)
        if ~ismember(labs{c}, labelsAll), labelsAll{end+1} = labs{c}; end %#ok<SAGROW>
    end
    for k = 1:numel(metricNames)
        if ~isfield(M, metricNames{k}), M.(metricNames{k}) = nan(nS, 64); end
        for c = 1:numel(labs), M.(metricNames{k})(s, find(strcmp(labelsAll, labs{c}))) = v.(metricNames{k})(c); end %#ok<FNDSB>
    end
    for c = 1:numel(labs)
        if ~isfield(PSD, 'x'), PSD.x = nan(nS, 64, numel(f)); end
        PSD.x(s, find(strcmp(labelsAll, labs{c})), :) = log10(P(:, c))'; %#ok<FNDSB>
    end
    fAxis = f;
end
nCh = numel(labelsAll);
for k = 1:numel(metricNames), M.(metricNames{k}) = M.(metricNames{k})(:, 1:nCh); end
PSD.x = PSD.x(:, 1:nCh, :);

% robust z of every resident against the other residents, channel by channel
Z = struct();
for k = 1:numel(metricNames)
    A = M.(metricNames{k});   Zk = nan(size(A));
    for c = 1:nCh
        md = median(A(:, c), 'omitnan');   sd = median(abs(A(:, c) - md), 'omitnan') / 0.6745;
        if sd > 0, Zk(:, c) = (A(:, c) - md) / sd; end
    end
    Z.(metricNames{k}) = Zk;
end

%% 3. TABLE OF THE TARGET CHANNELS ---------------------------------------------------------------------
for ci = 1:numel(CHECK_CH)
    c = find(strcmp(labelsAll, CHECK_CH{ci}));
    if isempty(c), fprintf('\nChannel %s not found\n', CHECK_CH{ci}); continue; end
    fprintf('\n===== %s : value (robust z vs the other residents), * = z > %.1f =====\n', CHECK_CH{ci}, Z_FLAG);
    fprintf('%-6s', 'IR'); fprintf('%18s', metricNames{:}); fprintf('\n');
    for s = 1:nS
        fprintf('%-6s', subjects{s});
        for k = 1:numel(metricNames)
            val = M.(metricNames{k})(s, c);   z = Z.(metricNames{k})(s, c);
            if isnan(val), fprintf('%18s', 'removed'); else, fprintf('%18s', sprintf('%.2f (%+.1f)%s', val, z, ternary(abs(z) > Z_FLAG, '*', ' '))); end
        end
        fprintf('\n');
    end
    fprintf('%-6s', 'median'); for k = 1:numel(metricNames), fprintf('%18.2f', median(M.(metricNames{k})(:, c), 'omitnan')); end; fprintf('\n');
end

%% 4. STRONGEST OUTLIERS OVER ALL CHANNELS (gamma power) -----------------------------------------------
Zg = Z.gamma;   tmp = Zg(:);   tmp(isnan(tmp)) = -Inf;   [~, idx] = sort(tmp, 'descend');     % NaN (removed channels) must not come first
fprintf('\n===== 15 strongest resident x channel outliers of the gamma power (25-35 Hz), all channels =====\n');
fprintf('%-6s %-6s %8s %10s %8s %8s\n', 'IR', 'chan', 'z gamma', 'z level', 'z line', 'z kurt');
for i = 1:15
    [s, c] = ind2sub(size(Zg), idx(i));
    fprintf('%-6s %-6s %8.1f %10.1f %8.1f %8.1f\n', subjects{s}, labelsAll{c}, Zg(s, c), Z.power4_35(s, c), Z.line(s, c), Z.kurt(s, c));
end

%% 5. FIGURE 1: HEAT MAP --------------------------------------------------------------------------------
f1 = claude_figure_right('Residents channel check: gamma power robust z', 1500, 800);   set(f1, 'Color', 'w');
imagesc(max(min(Zg, 10), -10));   colormap(jet);   cb = colorbar;   ylabel(cb, 'robust z of gamma power (clipped at +/-10)');
xticks(1:nCh);   xticklabels(labelsAll);   xtickangle(90);   yticks(1:nS);   yticklabels(subjects);
title('Residents: gamma power (25-35 Hz) of every channel compared with the other residents (red = noisier than the others, grey/white = channel removed)');
if SAVE_FIGS, print(f1, fullfile(fig_dir, 'IR_channelcheck_heatmap_gamma.png'), '-dpng', '-r110'); end

%% 6. FIGURE 2: SPECTRA ---------------------------------------------------------------------------------
chs = {'O2', 'P4', 'Cz'};
f2 = claude_figure_right('Residents channel check: spectra', 1700, 550);   set(f2, 'Color', 'w');
cols = lines(size(FLAGGED, 1));
for i = 1:numel(chs)
    ax = subplot(1, 3, i);   hold on;   c = find(strcmp(labelsAll, chs{i}));
    for s = 1:nS, plot(fAxis, squeeze(PSD.x(s, c, :)), '-', 'Color', [0.75 0.75 0.75]); end
    h = []; hn = {};
    for j = 1:size(FLAGGED, 1)
        if ~strcmp(FLAGGED{j, 2}, chs{i}), continue; end
        s = find(strcmp(subjects, FLAGGED{j, 1}));
        h(end+1) = plot(fAxis, squeeze(PSD.x(s, c, :)), '-', 'Color', cols(j, :), 'LineWidth', 1.8); hn{end+1} = FLAGGED{j, 1}; %#ok<SAGROW>
    end
    h(end+1) = plot(fAxis, squeeze(median(PSD.x(:, c, :), 1, 'omitnan')), 'k-', 'LineWidth', 2.5);   hn{end+1} = 'median of residents';
    set(ax, 'XScale', 'log');   xlim([2 45]);   grid on;   box on;   xlabel('Frequency (Hz)');   ylabel('log10 power');
    title(chs{i}, 'FontSize', 12);   legend(h, hn, 'Location', 'southwest');
end
sgtitle('Residents: spectrum of the whole recording (grey = every resident, colour = flagged residents, black = median)');
if SAVE_FIGS, print(f2, fullfile(fig_dir, 'IR_channelcheck_spectra.png'), '-dpng', '-r110'); end


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
