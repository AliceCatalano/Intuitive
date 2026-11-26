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
WHICH          = 'exit';    % PART A event: 'exit' = ERS (exit-locked)  |  'grasp' = ERD (grasp-locked)
MIN_POINTS     = 2;         % usable points (out of 4) needed to accept a trial
CUTOFF         = 75;        % score (%) separating good and bad trials
SAME_RESIDENTS = false;      % true: heads use the same residents; false: every head uses everybody who has it
SAME_ACROSS_EVENTS = true;  % true: ONLY residents who have all the maps in BOTH events (grasp and exit) are used, in every figure
GROUP_STAT     = 'median';    % 'mean' or 'median' over residents (median = a resident with extreme values cannot create a spot)
DIAG_BAND      = 'Alpha';   % band shown in the per-resident figure of PART C
SOURCE         = 'avgref';  % which TFR files: 'original' = IR_Task/ERDS | 'filtered' = the residents in FILTERED_RES from IR_Task/ERDS_filtered | 'avgref' = ALL residents from IR_Task/ERDS_avgref
                            %   (filtered + average reference, made by claude_Res_FilterSensitivity.m with MODE = 'avgref')
FILTERED_RES   = {'IR02', 'IR05', 'IR06', 'IR07', 'IR08', 'IR09'};   % residents without the band-pass in the original data
EXCLUDE        = {'IR04'};  % residents left out of everything (IR04: ICA components never removed)
SAVE_FIGS      = true;

D         = '/home/acatalano/Desktop/Intuitive/DataStructures/';
tfr_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/';
tfr_path_filt = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_filtered/';
tfr_path_avg  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref/';
tag = ''; if ~strcmp(SOURCE, 'original'), tag = ['_' SOURCE]; end      % added to the figure file names so the earlier figures are not overwritten
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
nE = numel(events);
tfrDirs = repmat({tfr_path}, nS, 1);                                   % folder with the TFR files of every resident
switch SOURCE
    case 'filtered', tfrDirs(ismember(subjects, FILTERED_RES)) = {tfr_path_filt};
    case 'avgref',   tfrDirs(:) = {tfr_path_avg};
    case 'original'
    otherwise, error('SOURCE must be original, filtered or avgref');
end
isExcl = ismember(subjects, EXCLUDE);
fprintf('TFR source = %s : %d residents read from a copy folder, excluded: %s\n', SOURCE, nnz(~strcmp(tfrDirs, tfr_path)), strjoin(subjects(isExcl), ', '));
VV = cell(1, nE);   CMm = cell(1, nE);   infoE = cell(1, nE);   haveE = cell(1, nE);
for e = 1:nE
    fprintf('\n################ %s ################\n', events(e).label);
    [VV{e}, infoE{e}, CMm{e}] = build_maps(tfrDirs, events(e), subjects, performed, score, bands, freq_ranges, MIN_POINTS, CUTOFF, NS, NREP, NPT, TOL, isExcl);
    % VV{e}{b}(s, k, :) : band b, resident s, condition k (1 first, 2 last, 3 good, 4 bad), channels last
    % CMm{e}{b}(s, :)   : the resident's mean over ALL his usable trials (used in PART C)
    haveE{e} = squeeze(~isnan(VV{e}{1}(:, :, 1)));                           % [resident x 4] has this map?
end
both = all(haveE{1}, 2) & all(haveE{2}, 2);                                   % residents with all 4 maps in BOTH events

MAPS = cell(nE, numel(bands));    % MAPS{e, b} = [4 conditions x chan] group map
nPer = zeros(nE, 4);   useE = cell(1, nE);   inSet = cell(1, nE);
for e = 1:nE
    have = haveE{e};
    if SAME_RESIDENTS, use = repmat(all(have, 2), 1, 4); else, use = have; end
    if SAME_ACROSS_EVENTS, use = use & repmat(both, 1, 4); end
    useE{e} = use;   inSet{e} = all(have, 2) & (both | ~SAME_ACROSS_EVENTS);   nPer(e, :) = sum(use, 1);
    fprintf('\n%s - residents per head: first %d | last %d | good %d | bad %d   (SAME_RESIDENTS = %d, SAME_ACROSS_EVENTS = %d, group %s)\n', events(e).name, nPer(e, :), SAME_RESIDENTS, SAME_ACROSS_EVENTS, GROUP_STAT);
    for s = 1:nS
        miss = find(~have(s, :));
        if ~isempty(miss), fprintf('  %-5s without: %s  (%s)\n', subjects{s}, strjoin(condNames(miss), ', '), infoE{e}{s}); end
        if SAME_ACROSS_EVENTS && isempty(miss) && ~both(s), fprintf('  %-5s has all maps here but not in the other event -> left out\n', subjects{s}); end
    end
    fprintf('  Residents in the maps: %s\n', strjoin(subjects(all(use, 2)), ', '));
    for b = 1:numel(bands)
        M = nan(4, size(VV{e}{b}, 3));
        for k = 1:4, M(k, :) = squeeze(gstat(VV{e}{b}(use(:, k), k, :), GROUP_STAT)); end
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
    if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_%s_topo_%s%s.png', events(eA).name, bands{b}, tag)), '-dpng', '-r110'); end
end

%% 5. PART B: SAME COLOUR SCALE FOR BOTH EVENTS AND ALL BANDS, 4 FIGURES IN THE 4 QUARTERS OF THE SCREEN ---
LIM = 0;
for e = 1:numel(events), for b = 1:numel(bands), LIM = max(LIM, max(abs(MAPS{e, b}(:)))); end, end
fprintf('\nCOMMON COLOUR SCALE %s : +/- %.3f\n', events(eA).label,  LIM);
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
    if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_commonscale_%s%s%s.png', bands{b}, tag,events(eA).label)), '-dpng', '-r110'); end
end


%% 6. PART C: WHAT DRIVES THESE MAPS? (diagnostics, event WHICH) ---------------------------------------
% The four heads of Part A look alike because they share one big, constant spatial pattern (the normalisation removes
% the overall mean, not each channel's own level). A focal spot present in every band, event and condition is more
% likely a noisy channel or one resident than brain activity. Four checks:
%   C1  one map per resident (mean over ALL his usable trials): is the spot in everybody or in one/two residents?
%   C2  hottest channels: value of the group, with and without the most extreme resident (printed)
%   C3  the 4 conditions after removing each resident's own per-channel mean (= what is specific to the condition)
%   C4  differences last - first and good - bad (the shared pattern cancels)
%   C5  exit - grasp, ONLY residents who have both events
labels = {EEG_ref.chanlocs.labels};
roiDef = struct('MotorLeft', [15 20 10], 'MotorRight', [13 19 9], 'Visual', [29 30 31], 'Frontal', [4 5 6]);   % same ROIs as the ERD/ERS analysis
fprintf('\nChannels of the ROIs used in the ERD/ERS analysis:\n');
for rn = fieldnames(roiDef)', fprintf('  %-11s %s\n', rn{1}, strjoin(labels(roiDef.(rn{1})), ', ')); end
R  = find(inSet{eA});   nRr = numel(R);                       % residents used in PART C
fprintf('\nPART C uses %d residents (%s)\n', nRr, strjoin(subjects(R), ', '));
bD = find(strcmp(bands, DIAG_BAND));

% ---- C1: one map per resident ----
CMb = CMm{eA}{bD}(R, :);                                        % [resident x chan]
lim = prctile(abs(CMb(:)), 99);
f = claude_figure_right(sprintf('PART C1 single residents %s %s', events(eA).name, bands{bD}), 1700, 950);   set(f, 'Color', 'w');
nc = ceil(sqrt(nRr * 1.6));   nr = ceil(nRr / nc);
for i = 1:nRr
    subplot(nr, nc, i);
    topoplot(CMb(i, :), EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-lim lim]);
    title(subjects{R(i)}, 'FontSize', 10);
end
colormap(f, 'jet');   cb = colorbar('Position', [0.95 0.3 0.010 0.4]);   ylabel(cb, 'Normalised power');
sgtitle(sprintf('Residents, %s, %s: each resident''s map over all his usable trials (colour limit = 99th percentile, +/- %.2f)', events(eA).label, bands{bD}, lim));
if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_C1_single_residents_%s_%s%s.png', events(eA).name, bands{bD}, tag)), '-dpng', '-r110'); end

% ---- C2: hottest channels, with and without the most extreme resident ----
fprintf('\nC2. HOTTEST CHANNELS (%s). value = group mean over the %d residents; "without top" = mean without the resident with the highest value\n', events(eA).name, nRr);
for b = 1:numel(bands)
    X = CMm{eA}{b}(R, :);   g = mean(X, 1, 'omitnan');   gm = median(X, 1, 'omitnan');
    [~, ord] = sort(g, 'descend');
    fprintf('%s\n  %-6s %8s %8s %9s  %-32s %s\n', bands{b}, 'chan', 'mean', 'median', 'w/o top', 'highest resident (value, robust z)', 'residents above 3 robust z');
    for ch = ord(1:3)
        [vmax, ir] = max(X(:, ch));   o = X([1:ir-1, ir+1:end], ch);
        sd = median(abs(X(:, ch) - gm(ch))) / 0.6745;   z = (X(:, ch) - gm(ch)) / max(sd, eps);
        fprintf('  %-6s %8.3f %8.3f %9.3f  %-32s %s\n', labels{ch}, g(ch), gm(ch), mean(o, 'omitnan'), sprintf('%s (%.2f, z=%.1f)', subjects{R(ir)}, vmax, z(ir)), strjoin(subjects(R(z > 3)), ' '));
    end
end

% ---- C3: the 4 conditions, each resident's own per-channel mean removed ----
f = claude_figure_right('PART C3 conditions without each resident''s own channel mean', 1700, 1000);   set(f, 'Color', 'w');
for b = 1:numel(bands)
    Vb = VV{eA}{b}(R, :, :);                                    % [resident x 4 x chan]
    Dm = Vb - reshape(CMm{eA}{b}(R, :), nRr, 1, []);            % condition minus the resident's mean over all trials
    G  = nan(4, size(Dm, 3));   for k = 1:4, G(k, :) = squeeze(gstat(Dm(:, k, :), GROUP_STAT)); end
    lim = max(abs(G(:)));
    for k = 1:4
        ax = subplot(numel(bands), 4, (b - 1) * 4 + k);
        topoplot(G(k, :), EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-lim lim]);
        if b == 1, title(condNames{k}, 'FontSize', 11); end
        if k == 1, ylabel(bands{b}, 'FontSize', 12, 'FontWeight', 'bold'); end
        if k == 4, cb = colorbar(ax, 'eastoutside'); end
    end
end
colormap(f, 'jet');
sgtitle(sprintf('Residents, %s: condition minus the resident''s mean over all his trials (n = %d, each row its own colour scale)', events(eA).label, nRr));
if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_C3_conditions_demeaned_%s%s.png', events(eA).name, tag)), '-dpng', '-r110'); end

% ---- C4: differences ----
f = claude_figure_right('PART C4 differences', 1700, 700);   set(f, 'Color', 'w');
for b = 1:numel(bands)
    Vb = VV{eA}{b}(R, :, :);
    d1 = squeeze(gstat(Vb(:, 2, :) - Vb(:, 1, :), GROUP_STAT));   d2 = squeeze(gstat(Vb(:, 3, :) - Vb(:, 4, :), GROUP_STAT));
    for rr = 1:2
        ax = subplot(2, numel(bands), (rr - 1) * numel(bands) + b);   d = tern(rr == 1, d1, d2);   lim = max(abs(d(:)));
        topoplot(d(:)', EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-lim lim]);
        title(sprintf('%s | %s', bands{b}, tern(rr == 1, 'last - first', 'good - bad')), 'FontSize', 10);   colorbar(ax, 'eastoutside');
    end
end
colormap(f, 'jet');
sgtitle(sprintf('Residents, %s: differences between conditions (n = %d, each head its own colour scale)', events(eA).label, nRr));
if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('IR_C4_differences_%s%s.png', events(eA).name, tag)), '-dpng', '-r110'); end

% ---- C5: exit - grasp, only residents with both events ----
R2 = find(inSet{1} & inSet{2});
fprintf('\nC5. exit - grasp map uses ONLY the %d residents who have all maps in both events: %s\n', numel(R2), strjoin(subjects(R2), ', '));
iG = find(strcmp({events.name}, 'grasp'));   iX = find(strcmp({events.name}, 'exit'));
f = claude_figure_right('PART C5 exit minus grasp', 1700, 450);   set(f, 'Color', 'w');
for b = 1:numel(bands)
    d = squeeze(gstat(CMm{iX}{b}(R2, :) - CMm{iG}{b}(R2, :), GROUP_STAT));   lim = max(abs(d(:)));
    ax = subplot(1, numel(bands), b);
    topoplot(d(:)', EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-lim lim]);
    title(sprintf('%s (n = %d)', bands{b}, numel(R2)), 'FontSize', 11);   colorbar(ax, 'eastoutside');
end
colormap(f, 'jet');
sgtitle('Residents: exit-locked (ERS) minus grasp-locked (ERD), mean over all usable trials, same residents in both (each head its own colour scale)');
if SAVE_FIGS, print(f, fullfile(fig_dir, ['IR_C5_exit_minus_grasp' tag '.png']), '-dpng', '-r110'); end


%% ---------------------------------------------------------------------
function f = figure_quadrant(name, q)
% opens a figure in quarter q (1 top-left, 2 top-right, 3 bottom-left, 4 bottom-right) of the RIGHTMOST monitor
    mp = get(0, 'MonitorPositions');   [~, k] = max(mp(:, 1) + mp(:, 3));   m = mp(k, :);
    w = m(3) / 2;   h = m(4) / 2;   col = mod(q - 1, 2);   row = floor((q - 1) / 2);
    f = figure('Name', name, 'NumberTitle', 'off');
    set(f, 'OuterPosition', [m(1) + col * w, m(2) + (1 - row) * h, w, h]);
end

function [V, info, CM] = build_maps(tfrDirs, ev, subjects, performed, score, bands, freq_ranges, MIN_POINTS, CUTOFF, NS, NREP, NPT, TOL, isExcl)
% One value per channel for FIRST / LAST / GOOD / BAD of every resident. V{b}(s, k, :) ; NaN = resident has no such map.
    nS = numel(subjects);   V = cell(1, numel(bands));   CM = cell(1, numel(bands));   info = repmat({''}, nS, 1);
    % avgref: all residents in ONE file written by Task_Res_TFR_claude.m (IR_norm_grasp.mat / IR_norm_exit.mat, cell per resident)
    allFile = fullfile(tfrDirs{1}, sprintf('IR_norm_%s.mat', ev.name));
    useAll  = exist(allFile, 'file') == 2;
    if useAll, fprintf('  reading %s\n', allFile); A = load(allFile); A_tfr = A.(sprintf('IR_norm_%s', ev.name)); A_sub = A.subjects; clear A; end
    for s = 1:nS
        if isExcl(s), info{s} = 'excluded'; fprintf('  %-5s excluded\n', subjects{s}); continue; end
        if useAll
            k = find(strcmp(A_sub, subjects{s}));
            if isempty(k), info{s} = 'not in TFR file'; fprintf('  %-5s not in TFR file\n', subjects{s}); continue; end
            tf = A_tfr{k};
        else   % ORIGINAL: one TFR file per resident
            fn = fullfile(tfrDirs{s}, sprintf('%s_IR_%s_TFR.mat', subjects{s}, ev.file));
            if ~exist(fn, 'file'), info{s} = 'no TFR file'; fprintf('  %-5s no TFR file\n', subjects{s}); continue; end
            S = load(fn);   tf = S.TFRhann;
        end
        pw = tf.powspctrm;                                                                       % [240 x chan x freq x time]
        nChan = size(pw, 2);
        if isempty(V{1}), V = arrayfun(@(~) nan(nS, 4, nChan), 1:numel(bands), 'UniformOutput', false);   CM = arrayfun(@(~) nan(nS, nChan), 1:numel(bands), 'UniformOutput', false); end
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
            CM{b}(s, :)   = squeeze(mean_over_trials(repMap, usable, nChan));      % mean over ALL usable trials
        end
        miss = {};
        if isempty(nsc), miss{end+1} = 'no scenario with 2 usable trials'; end %#ok<AGROW>
        if ~any(usable(:) & scr(:) >= CUTOFF), miss{end+1} = 'no good trial'; end %#ok<AGROW>
        if ~any(usable(:) & scr(:) < CUTOFF),  miss{end+1} = 'no bad trial'; end %#ok<AGROW>
        info{s} = strjoin(miss, '; ');
    end
    if isempty(V{1}), error('no TFR file found (first folder tried: %s)', tfrDirs{1}); end
end

function v = mean_over_trials(repMap, mask, nChan)
% mean over the trials selected by mask [rep x scenario] of repMap [rep x scenario x chan]; NaN if no trial
    if ~any(mask(:)), v = nan(1, 1, nChan); return; end
    X = reshape(repMap, [], nChan);   v = reshape(mean(X(mask(:), :), 1, 'omitnan'), 1, 1, nChan);
end

function g = gstat(X, how)
% group statistic over residents (dimension 1), ignoring NaN: 'mean' or 'median'
    if strcmp(how, 'median'), g = median(X, 1, 'omitnan'); else, g = mean(X, 1, 'omitnan'); end
end

function o = tern(c, x, y)
    if c, o = x; else, o = y; end
end
