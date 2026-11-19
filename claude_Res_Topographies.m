% claude_Res_Topographies.m
% =====================================================================================================
% RESIDENTS (IR): scalp topographies of 4 frequency bands, 4 heads per band:
%       1 FIRST trial   |   2 LAST trial   |   3 ALL GOOD trials (score >= 75 %)   |   4 ALL BAD trials (score < 75 %)
% Each head = mean over the residents of the (normalised) band power in the event window, one value per channel.
%
% HOW A RESIDENT'S MAP IS BUILT
%   data   : <subj>_IR_<event>_TFR.mat (claude_Task_Res_TFR.m): powspctrm [240 slots x chan x freq x time], normalised
%            slot = (scenario-1)*40 + (rep-1)*4 + point ; channel order = the experts' (same head layout)
%   window : ERS = exit-locked -2 to 0 s ; ERD = grasp-locked -0.5 to 1 s (same as the experts)
%   trial  : a trial (= scenario x repetition) is USABLE if it was PERFORMED (performance struct), is not in the skip list,
%            and at least MIN_POINTS of its 4 points have data. Its map = mean over its usable points.
%   FIRST / LAST : in every scenario with >= 2 usable trials, the earliest / latest usable trial; the resident's map =
%            mean over those scenarios (same rule as claude_Res_Modulation_FirstLast_plot.m, with fallback to the next usable trial)
%   GOOD / BAD   : ALL usable trials of all scenarios with score >= CUTOFF / < CUTOFF, every trial counting once
%   SAME_RESIDENTS = true : only residents who have all 4 maps are used, so the 4 heads use the same people
%
% PART A: one figure per band for the event WHICH, each with its own colour scale
% PART B: the SAME colour scale for both events and all bands: 4 figures (one per band), one per quarter of the screen
% =====================================================================================================

clear; clc;
addpath(fileparts(mfilename('fullpath')));      % claude_figure_right.m
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

%% 1. SETTINGS 
WHICH          = 'grasp';    % PART A event: 'exit' = ERS (exit-locked)  |  'grasp' = ERD (grasp-locked)
MIN_POINTS     = 2;         % usable points (out of 4) needed to accept a trial
CUTOFF         = 75;        % score (%) separating good and bad trials
SAME_RESIDENTS = true;      % true: heads use the same residents; false: every head uses everybody who has it
SAVE_FIGS      = true;

D         = '/home/acatalano/Desktop/Intuitive/DataStructures/';
tfr_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/';
fig_dir   = [D 'Figures_IR_Topographies'];
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
bands       = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 15; 15 25; 25 35];
condNames   = {'First trial', 'Last trial', 'All good trials', 'All bad trials'};
events(1).name = 'grasp';  events(1).file = 'graspERD';  events(1).win = [-0.5 1.0];  events(1).label = 'ERD (grasp-locked)';
events(2).name = 'exit';   events(2).file = 'exitERS';   events(2).win = [-2.0 0.0];  events(2).label = 'ERS (exit-locked)';
NS = 6;   NREP = 10;   NPT = 4;   TOL = 1e-6;

EEG_ref = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');   % channel positions

%% 2. PERFORMED TRIALS AND SCORES ----------------------------------------------------------------------
T = load([D 'GraspERD_Times_IR.mat']);                 % T.subjects, T.RepStatus == 1 -> skip list
P = load([D 'performanceStruct_IR_updated.mat']);
subjects = T.subjects;   nS = numel(subjects);
performed = false(nS, NS, NREP);   score = nan(nS, NS, NREP);
for g = 1:numel(P.GlobalData)
    s = find(strcmp(subjects, strtok(P.GlobalData(g).ID, '_')));
    if isempty(s), continue; end
    for k = 1:numel(P.GlobalData(g).Scenarios)
        sc = P.GlobalData(g).Scenarios(k).ScenarioID;
        for tr = P.GlobalData(g).Scenarios(k).Trials
            if tr.TrialID >= 1 && tr.TrialID <= NREP, performed(s, sc, tr.TrialID) = true;   score(s, sc, tr.TrialID) = tr.Score; end
        end
    end
end
performed = performed & (T.RepStatus ~= 1);            % skip list removed

%% 3. MAPS OF BOTH EVENTS ------------------------------------------------------------------------------
MAPS = cell(numel(events), numel(bands));    % MAPS{e, b} = [4 conditions x chan] group map
nPer = zeros(numel(events), 4);              % residents in each head
for e = 1:numel(events)
    fprintf('\n################ %s ################\n', events(e).label);
    [V, info] = build_maps(tfr_path, events(e), subjects, performed, score, bands, freq_ranges, MIN_POINTS, CUTOFF, NS, NREP, NPT, TOL);
    % V{b}(s, k, :) : band b, resident s, condition k (1 first, 2 last, 3 good, 4 bad), channels last
    have = squeeze(~isnan(V{1}(:, :, 1)));                              % [resident x 4] has this map?
    if SAME_RESIDENTS, use = repmat(all(have, 2), 1, 4); else, use = have; end
    nPer(e, :) = sum(use, 1);
    fprintf('\nResidents per head: first %d | last %d | good %d | bad %d   (SAME_RESIDENTS = %d)\n', nPer(e, :), SAME_RESIDENTS);
    for s = 1:nS
        miss = find(~have(s, :));
        if ~isempty(miss), fprintf('  %-5s without: %s  (%s)\n', subjects{s}, strjoin(condNames(miss), ', '), info{s}); end
    end
    if SAME_RESIDENTS, fprintf('  Residents in the maps: %s\n', strjoin(subjects(all(have, 2)), ', ')); end
    for b = 1:numel(bands)
        M = nan(4, size(V{b}, 3));
        for k = 1:4, M(k, :) = squeeze(mean(V{b}(use(:, k), k, :), 1, 'omitnan')); end
        MAPS{e, b} = M;
    end
end

%% 4. PART A: ONE FIGURE PER BAND, OWN COLOUR SCALE (event WHICH) --------------------------------------
eA = find(strcmp({events.name}, WHICH));
for b = 1:numel(bands)
    M = MAPS{eA, b};   lim = max(abs(M(:)));
    fprintf('%-6s colour scale +/- %.3f\n', bands{b}, lim);
    f = claude_figure_right(sprintf('Residents %s topographies %s', events(eA).label, bands{b}), 1800, 480);   set(f, 'Color', 'w');
    for k = 1:4
        subplot(1, 4, k);
        topoplot(M(k, :), EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-lim lim]);
        title(sprintf('%s (n = %d)', condNames{k}, nPer(eA, k)), 'FontSize', 12);
    end
    colormap(f, 'jet');
    cb = colorbar('Position', [0.94 0.25 0.010 0.5]);   ylabel(cb, 'Normalised power');
    sgtitle(sprintf('Residents - %s - %s (%d-%d Hz), window %g to %g s', events(eA).label, bands{b}, freq_ranges(b, 1), freq_ranges(b, 2), events(eA).win(1), events(eA).win(2)));
    if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_%s_topo_%s.png', events(eA).name, bands{b})), '-dpng', '-r110'); end
end

%% 5. PART B: SAME COLOUR SCALE FOR BOTH EVENTS AND ALL BANDS, 4 FIGURES IN THE 4 QUARTERS OF THE SCREEN ---
LIM = 0;
for e = 1:numel(events), for b = 1:numel(bands), LIM = max(LIM, max(abs(MAPS{e, b}(:)))); end, end
fprintf('\nCOMMON COLOUR SCALE: +/- %.3f\n', LIM);
fprintf('Largest absolute value of each event x band (compare with the common limit):\n%-7s', 'event'); fprintf('%10s', bands{:}); fprintf('\n');
for e = 1:numel(events)
    fprintf('%-7s', events(e).name);
    for b = 1:numel(bands), fprintf('%10.3f', max(abs(MAPS{e, b}(:)))); end
    fprintf('\n');
end
for b = 1:numel(bands)
    f = figure_quadrant(sprintf('Residents common scale %s', bands{b}), b);   set(f, 'Color', 'w');
    for e = 1:numel(events)
        for k = 1:4
            subplot(numel(events), 4, (e - 1) * 4 + k);
            topoplot(MAPS{e, b}(k, :), EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-LIM LIM]);
            title(sprintf('%s | %s (n=%d)', events(e).name, condNames{k}, nPer(e, k)), 'FontSize', 8);
        end
    end
    colormap(f, 'jet');
    cb = colorbar('Position', [0.95 0.25 0.010 0.5]);   ylabel(cb, 'Normalised power');
    sgtitle(sprintf('Residents - %s (%d-%d Hz) - common colour scale +/- %.2f', bands{b}, freq_ranges(b, 1), freq_ranges(b, 2), LIM));
    if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_commonscale_%s.png', bands{b})), '-dpng', '-r110'); end
end


%% ---------------------------------------------------------------------
function f = figure_quadrant(name, q)
% opens a figure in quarter q (1 top-left, 2 top-right, 3 bottom-left, 4 bottom-right) of the RIGHTMOST monitor
    mp = get(0, 'MonitorPositions');   [~, k] = max(mp(:, 1) + mp(:, 3));   m = mp(k, :);
    w = m(3) / 2;   h = m(4) / 2;   col = mod(q - 1, 2);   row = floor((q - 1) / 2);
    f = figure('Name', name, 'NumberTitle', 'off');
    set(f, 'OuterPosition', [m(1) + col * w, m(2) + (1 - row) * h, w, h]);
end

function [V, info] = build_maps(tfr_path, ev, subjects, performed, score, bands, freq_ranges, MIN_POINTS, CUTOFF, NS, NREP, NPT, TOL)
% One value per channel for FIRST / LAST / GOOD / BAD of every resident. V{b}(s, k, :) ; NaN = resident has no such map.
    nS = numel(subjects);   V = cell(1, numel(bands));   info = repmat({''}, nS, 1);
    for s = 1:nS
        fn = fullfile(tfr_path, sprintf('%s_IR_%s_TFR.mat', subjects{s}, ev.file));
        if ~exist(fn, 'file'), info{s} = 'no TFR file'; fprintf('  %-5s no TFR file\n', subjects{s}); continue; end
        S = load(fn);   tf = S.TFRhann;   pw = tf.powspctrm;                                     % [240 x chan x freq x time]
        nChan = size(pw, 2);
        if isempty(V{1}), V = arrayfun(@(~) nan(nS, 4, nChan), 1:numel(bands), 'UniformOutput', false); end
        tIdx = find(tf.time >= ev.win(1) - TOL & tf.time <= ev.win(2) + TOL);
        % slot maps: band power of every slot and channel
        slotMap = cell(1, numel(bands));
        for b = 1:numel(bands)
            fIdx = find(tf.freq >= freq_ranges(b, 1) - TOL & tf.freq <= freq_ranges(b, 2) + TOL);
            x = mean(mean(pw(:, :, fIdx, tIdx), 4, 'omitnan'), 3, 'omitnan');                    % [240 x chan]
            slotMap{b} = reshape(squeeze(x), NPT, NREP, NS, nChan);                              % [point x rep x scenario x chan]
        end
        hasData = squeeze(any(~isnan(slotMap{1}), 4));                                            % [point x rep x scenario]
        nPts    = squeeze(sum(hasData, 1));                                                       % [rep x scenario]
        perf    = permute(squeeze(performed(s, :, :)), [2 1]);                                    % [rep x scenario]
        scr     = permute(squeeze(score(s, :, :)), [2 1]);
        usable  = nPts >= MIN_POINTS & perf;                                                      % usable trials
        fprintf('  %-5s usable trials %3d | good %3d | bad %3d\n', subjects{s}, nnz(usable), nnz(usable & scr >= CUTOFF), nnz(usable & scr < CUTOFF));
        % first / last trial of every scenario with >= 2 usable trials
        firstRep = nan(1, NS);   lastRep = nan(1, NS);
        for sc = 1:NS
            u = find(usable(:, sc))';
            if numel(u) >= 2, firstRep(sc) = u(1);   lastRep(sc) = u(end); end
        end
        for b = 1:numel(bands)
            repMap = squeeze(mean(slotMap{b}, 1, 'omitnan'));                                     % [rep x scenario x chan]
            nsc = find(~isnan(firstRep));
            if ~isempty(nsc)
                F = nan(numel(nsc), nChan);   L = F;
                for i = 1:numel(nsc), F(i, :) = squeeze(repMap(firstRep(nsc(i)), nsc(i), :));   L(i, :) = squeeze(repMap(lastRep(nsc(i)), nsc(i), :)); end
                V{b}(s, 1, :) = mean(F, 1, 'omitnan');   V{b}(s, 2, :) = mean(L, 1, 'omitnan');
            end
            gmask = usable & scr >= CUTOFF;   bmask = usable & scr < CUTOFF;
            V{b}(s, 3, :) = mean_over_trials(repMap, gmask, nChan);
            V{b}(s, 4, :) = mean_over_trials(repMap, bmask, nChan);
        end
        miss = {};
        if isempty(nsc), miss{end+1} = 'no scenario with 2 usable trials'; end %#ok<AGROW>
        if ~any(usable(:) & scr(:) >= CUTOFF), miss{end+1} = 'no good trial'; end %#ok<AGROW>
        if ~any(usable(:) & scr(:) < CUTOFF),  miss{end+1} = 'no bad trial'; end %#ok<AGROW>
        info{s} = strjoin(miss, '; ');
    end
    if isempty(V{1}), error('no TFR file found in %s', tfr_path); end
end

function v = mean_over_trials(repMap, mask, nChan)
% mean over the trials selected by mask [rep x scenario] of repMap [rep x scenario x chan]; NaN if no trial
    if ~any(mask(:)), v = nan(1, 1, nChan); return; end
    X = reshape(repMap, [], nChan);   v = reshape(mean(X(mask(:), :), 1, 'omitnan'), 1, 1, nChan);
end
