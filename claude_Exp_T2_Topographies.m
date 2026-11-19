% claude_Exp_T2_Topographies.m
% =====================================================================================================
% EXPERTS (IE), TASK 2: scalp topographies of 4 frequency bands.
%   4 figures (Theta, Alpha, Beta, Gamma), each with 3 heads:
%       head 1 = FIRST repetition      head 2 = LAST repetition      head 3 = MEAN of all the repetitions
%   Each head = mean over the experts of the (normalised) band power in the time window, one value per channel.
%   The 3 heads of a figure share the same colour scale, so they can be compared by eye.
%
% HOW A VALUE IS BUILT (same rules as Task_Exp_ClusterFirstLast.m)
%   - data: Task2_norm_exit_allExp.mat (exit-locked = ERS) or Task2_norm_grasp_allExp.mat (grasp-locked = ERD),
%           already normalised, powspctrm = [80 slots x channel x freq x time], slot = (rep-1)*4 + point
%   - a repetition is USABLE if at least MIN_POINTS of its 4 points have data
%   - FIRST = earliest usable repetition, LAST = latest usable repetition, MEAN = mean over ALL usable repetitions
%   - value of a repetition = mean over its usable points, over the band's frequencies, over the time window
%   - experts with fewer than 2 usable repetitions are left out of ALL three heads (so the heads use the same experts)
%
% STEPS
%   1. load the data and the channel positions
%   2. for each expert: find usable repetitions, first, last, build one value per channel for the 3 conditions
%   3. average over experts -> one map per condition (printed: n experts, which reps were used)
%   4. plot, one figure per band (each figure has its own colour scale)
%   5. SAME colour scale for both events (grasp ERD + exit ERS) and all 4 bands: 4 figures, one per quarter of the screen
% =====================================================================================================

clear; close all; clc;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;
addpath('/home/acatalano/Desktop/Intuitive');            % claude_figure_right.m

% ---- settings you can change ----
WHICH      = 'grasp';      % 'exit' = ERS (exit-locked, window -2 to 0 s)   |   'grasp' = ERD (grasp-locked, window -0.5 to 1 s)
MIN_POINTS = 2;           % usable points needed (out of 4) to accept a repetition
SAVE_FIGS  = true;

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
fig_dir   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_Exp_Topographies';
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
NUM_REPS = 20;   NUM_POINTS = 4;   TOL = 1e-6;

bands       = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 15; 15 25; 25 35];
if strcmp(WHICH, 'exit'), file = 'Task2_norm_exit_allExp.mat';  win = [-2.0 0.0];  label = 'ERS (exit-locked)';
else,                     file = 'Task2_norm_grasp_allExp.mat'; win = [-0.5 1.0];  label = 'ERD (grasp-locked)'; end
condNames = {'First repetition', 'Last repetition', 'Mean of all repetitions'};

%% 1. LOAD THE CHANNEL POSITIONS ----------------------------------------------------------------------
EEG_ref = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');   % channel positions

%% 2. ONE VALUE PER CHANNEL, PER EXPERT AND CONDITION --------------------------------------------------
% build_maps (function at the end of the file) loads the data of one event and returns
% V{b}(s, k, :) : band b, expert s, condition k (1 first, 2 last, 3 mean of all), channels in the 3rd dimension
[V, keep, subjects] = build_maps(base_path, file, win, bands, freq_ranges, MIN_POINTS, NUM_REPS, NUM_POINTS, TOL);
nKeep = nnz(keep);
fprintf('\nExperts in the maps: %d of %d (%s)\n', nKeep, numel(keep), strjoin(subjects(keep), ', '));

%% 3 + 4. AVERAGE OVER EXPERTS AND PLOT ---------------------------------------------------------------
for b = 1:numel(bands)
    M = squeeze(mean(V{b}(keep, :, :), 1, 'omitnan'));        % [3 conditions x chan] group maps
    lim = max(abs(M(:)));                                      % one symmetric colour scale for the 3 heads
    fprintf('%-6s colour scale +/- %.3f | channel range: first %.3f..%.3f, last %.3f..%.3f, mean %.3f..%.3f\n', bands{b}, lim, ...
        min(M(1, :)), max(M(1, :)), min(M(2, :)), max(M(2, :)), min(M(3, :)), max(M(3, :)));

    f = claude_figure_right(sprintf('Experts Task 2 %s topographies %s', label, bands{b}), 1500, 480);   set(f, 'Color', 'w');
    for k = 1:3
        ax = subplot(1, 3, k);
        topoplot(M(k, :), EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-lim lim]);
        title(sprintf('%s (n = %d)', condNames{k}, nKeep), 'FontSize', 13);
    end
    colormap(f, 'jet');
    cb = colorbar('Position', [0.93 0.25 0.012 0.5]);   ylabel(cb, 'Normalised power');
    sgtitle(sprintf('Experts, Task 2, %s - %s band (%d-%d Hz), window %g to %g s', label, bands{b}, freq_ranges(b, 1), freq_ranges(b, 2), win(1), win(2)));
    if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('Exp_T2_%s_topo_%s.png', WHICH, bands{b})), '-dpng', '-r110'); end
end


%% 5. SAME COLOUR SCALE FOR BOTH EVENTS AND ALL 4 BANDS ----------------------------------------------
% Every head of every figure uses the SAME colour limits (+/- LIM, LIM = the largest absolute value over
% both events, all bands and the 3 conditions). One figure per band, placed in one quarter of the rightmost screen:
%   top-left = Theta, top-right = Alpha, bottom-left = Beta, bottom-right = Gamma
% Rows of each figure: grasp-locked (ERD) on top, exit-locked (ERS) below. Columns: first, last, mean of all repetitions.
events(1).name = 'grasp';  events(1).file = 'Task2_norm_grasp_allExp.mat';  events(1).win = [-0.5 1.0];  events(1).label = 'ERD (grasp-locked)';
events(2).name = 'exit';   events(2).file = 'Task2_norm_exit_allExp.mat';   events(2).win = [-2.0 0.0];  events(2).label = 'ERS (exit-locked)';
MAPS = cell(numel(events), numel(bands));          % MAPS{e, b} = [3 conditions x chan] group map
for e = 1:numel(events)
    fprintf('\n##### event: %s #####\n', events(e).name);
    [Ve, keepE, subjE] = build_maps(base_path, events(e).file, events(e).win, bands, freq_ranges, MIN_POINTS, NUM_REPS, NUM_POINTS, TOL);
    nE(e) = nnz(keepE);   %#ok<SAGROW>
    fprintf('Experts in the maps: %d (%s)\n', nE(e), strjoin(subjE(keepE), ', '));
    for b = 1:numel(bands), MAPS{e, b} = squeeze(mean(Ve{b}(keepE, :, :), 1, 'omitnan')); end
end

LIM = 0;
for e = 1:numel(events), for b = 1:numel(bands), LIM = max(LIM, max(abs(MAPS{e, b}(:)))); end, end
fprintf('\nCOMMON COLOUR SCALE: +/- %.3f\n', LIM);
fprintf('Largest absolute value of each event x band (compare with the common limit):\n');
fprintf('%-7s', 'event'); fprintf('%10s', bands{:}); fprintf('\n');
for e = 1:numel(events)
    fprintf('%-7s', events(e).name);
    for b = 1:numel(bands), fprintf('%10.3f', max(abs(MAPS{e, b}(:)))); end
    fprintf('\n');
end

for b = 1:numel(bands)
    f = figure_quadrant(sprintf('Common scale %s', bands{b}), b);   set(f, 'Color', 'w');
    for e = 1:numel(events)
        for k = 1:3
            subplot(numel(events), 3, (e - 1) * 3 + k);
            topoplot(MAPS{e, b}(k, :), EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-LIM LIM]);
            title(sprintf('%s | %s (n=%d)', events(e).name, condNames{k}, nE(e)), 'FontSize', 9);
        end
    end
    colormap(f, 'jet');
    cb = colorbar('Position', [0.94 0.25 0.012 0.5]);   ylabel(cb, 'Normalised power');
    sgtitle(sprintf('Experts, Task 2 - %s (%d-%d Hz) - common colour scale +/- %.2f', bands{b}, freq_ranges(b, 1), freq_ranges(b, 2), LIM));
    if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('Exp_T2_commonscale_%s.png', bands{b})), '-dpng', '-r110'); end
end


%% ---------------------------------------------------------------------
function f = figure_quadrant(name, q)
% opens a figure in quarter q (1 top-left, 2 top-right, 3 bottom-left, 4 bottom-right) of the RIGHTMOST monitor
    mp = get(0, 'MonitorPositions');   [~, k] = max(mp(:, 1) + mp(:, 3));   m = mp(k, :);   % rightmost monitor
    w = m(3) / 2;   h = m(4) / 2;
    col = mod(q - 1, 2);   row = floor((q - 1) / 2);                                         % row 0 = top
    f = figure('Name', name, 'NumberTitle', 'off');
    set(f, 'OuterPosition', [m(1) + col * w, m(2) + (1 - row) * h, w, h]);
end

function [V, keep, subjects] = build_maps(base_path, file, win, bands, freq_ranges, MIN_POINTS, NUM_REPS, NUM_POINTS, TOL)
% Loads one event file and returns, for every band, one value per channel for FIRST / LAST / MEAN of the usable
% repetitions of every expert. V{b}(s, k, :) with k = 1 first, 2 last, 3 mean of all. keep = experts with >= 2 usable reps.
    S = load(fullfile(base_path, file));
    fn = fieldnames(S);   allTF = S.(fn{1});   subjects = S.subjects;
    nSubj = numel(allTF);   nChan = numel(allTF{1}.label);
    fprintf('Loaded %s: %d experts, %d channels, window %g to %g s\n', file, nSubj, nChan, win(1), win(2));
    V    = arrayfun(@(~) nan(nSubj, 3, nChan), 1:numel(bands), 'UniformOutput', false);
    keep = false(nSubj, 1);
    fprintf('Usable repetitions per expert:\n');
    for s = 1:nSubj
        tf = allTF{s};   pw = tf.powspctrm;                                                % [80 x chan x freq x time]
        hasData = squeeze(any(any(~isnan(pw), 2), [3 4]));   hasData = hasData(:);        % does each slot have data?
        nPts = sum(reshape(hasData, NUM_POINTS, NUM_REPS), 1);                            % points with data per repetition
        usable = find(nPts >= MIN_POINTS);
        if numel(usable) < 2
            fprintf('  %-6s only %d usable repetition(s) -> left out\n', subjects{s}, numel(usable));
            continue;
        end
        keep(s) = true;
        fprintf('  %-6s %2d usable | first = rep %d | last = rep %d\n', subjects{s}, numel(usable), usable(1), usable(end));
        tIdx = find(tf.time >= win(1) - TOL & tf.time <= win(2) + TOL);                   % time window
        for b = 1:numel(bands)
            fIdx = find(tf.freq >= freq_ranges(b, 1) - TOL & tf.freq <= freq_ranges(b, 2) + TOL);   % frequencies of the band
            repVal = nan(numel(usable), nChan);                                           % one map per usable repetition
            for k = 1:numel(usable)
                slots = (usable(k) - 1) * NUM_POINTS + (1:NUM_POINTS);
                x = pw(slots, :, fIdx, tIdx);
                x = squeeze(mean(mean(x, 4, 'omitnan'), 3, 'omitnan'));                   % [4 points x chan]
                repVal(k, :) = mean(x, 1, 'omitnan');                                     % mean over the usable points
            end
            V{b}(s, 1, :) = repVal(1, :);                  % first usable repetition
            V{b}(s, 2, :) = repVal(end, :);                % last usable repetition
            V{b}(s, 3, :) = mean(repVal, 1, 'omitnan');    % mean over all usable repetitions
        end
    end
end
