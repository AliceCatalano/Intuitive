% claude_Gap_Spectra.m
% =====================================================================================================
% EXPLORATORY: does the spectrum / topography around grasp (ERD) and exit (ERS) change when the needle
% passage (entry -> exit) is FAST?  EXPERTS (Task 2, 80 slots) and RESIDENTS (6 x 10 x 4 = 240 slots).
% Needs GapTable.mat (run claude_Gap_Timing.m first) and the TFR files of both groups.
%
% Every slot (= suture point of a repetition) is classified by its GAP value (GAP_DEF):
%   'EE'  exit - entry  (needle passage, default)     'GE'  exit - grasp  (whole point)     'GA'  entry - grasp
%   class 1 SHORT  gap < EDGES(1)  |  class 2 MID  EDGES(1) <= gap < EDGES(2)  |  class 3 LONG  gap >= EDGES(2)
% Fixed (absolute) cut points, so that "short" means the same in both groups. Subjects enter a class only
% with >= MIN_SLOTS slots in it; group maps = mean over subjects of the subject's class mean.
%
% TFR data = the existing normalised power (pow - mean)/mean per subject: values are relative to the subject's own
% average power over the whole epoch set, NOT to a pre-event baseline. Motor ROI = MotorLeft + MotorRight channels.
%
% Figures (DataStructures/Figures_Gap_Spectra), per group unless stated
%   S1  motor-ROI time-frequency maps  grasp-locked / exit-locked  x  SHORT | MID | LONG | SHORT-LONG
%   S2  alpha and beta time courses (mean +/- SEM over subjects) for the 3 classes, both groups side by side
%   S3  single slots sorted by the gap (beta, motor ROI): entry / grasp positions drawn on top  -> "what the window contains"
%   S4  topographies over TIME (whole epoch cut in NB bins) for SHORT, LONG and SHORT-LONG, per group x event x band
%   S5  TREND over the repetitions (4 bins): ERD (grasp window) and ERS (exit window) amplitude, SHORT vs MID vs LONG
% Text: class counts, paired tests short vs long (within group) and experts vs residents.
% =====================================================================================================
clear; clc; close all
addpath(fileparts(mfilename('fullpath')));          % claude_figure_right.m
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

%% 1. SETTINGS
GAP_DEF     = 'EE';                    % 'EE' | 'GE' | 'GA'
EDGES_ALL   = struct('EE', [2 4], 'GE', [4 8], 'GA', [2 4]);     % s: cut points short|mid|long of each gap definition
MIN_SLOTS   = 3;                       % slots a subject needs in a class
EXCLUDE_RES = {'IR04'};
ROI_MOTOR   = [15 20 10 13 19 9];      % MotorLeft + MotorRight (same channel indices as the ERD/ERS analysis)
bands       = {'Alpha', 'Beta'};   bandHz = [8 15; 15 25];
RASTER_BAND = 2;                       % band of figure S3 (1 alpha, 2 beta)
SMOOTH_N    = 25;                      % slots averaged along the sorted axis in S3
NB_TOPO     = 6;                       % time bins of the topographies
SAVE_FIGS   = true;
TOL         = 1e-6;
D        = '/home/acatalano/Desktop/Intuitive/DataStructures/';
tfr_res  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref/';     % residents: filtered + average reference
tfr_exp  = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2/';           % experts: Task2_norm_{grasp,exit}_allExp.mat
fig_dir  = [D 'Figures_Gap_Spectra'];   if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
EDGES    = EDGES_ALL.(GAP_DEF);
grpName  = {'Residents', 'Experts'};
clsName  = {sprintf('SHORT (%s < %g s)', GAP_DEF, EDGES(1)), sprintf('MID (%g-%g s)', EDGES(1), EDGES(2)), sprintf('LONG (>= %g s)', EDGES(2))};
clsCol   = [0.80 0.10 0.10; 0.45 0.45 0.45; 0.10 0.40 0.80];
ev(1).name = 'grasp';  ev(1).label = 'ERD (grasp-locked)';  ev(1).win = [-0.5 1.0];  ev(1).epoch = [-0.8 1.5];
ev(2).name = 'exit';   ev(2).label = 'ERS (exit-locked)';   ev(2).win = [-2.0 0.0];  ev(2).epoch = [-2.5 0.5];

EEG_ref = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');   % chanlocs
load([D 'GapTable.mat'], 'T');
subjNames = {unique(T.subj(T.group == 1), 'stable'), unique(T.subj(T.group == 2), 'stable')};
for g = 1:2
    if g == 1, subjNames{g} = setdiff(subjNames{g}, EXCLUDE_RES, 'stable'); end
end

%% 2. LOAD + REDUCE: per subject and event keep the motor-ROI TFR per slot and band x time maps per channel
DAT = cell(2, 2);        % DAT{g,e}: names, freq, time, roi{s} [slot x F x T], cb{s} [slot x chan x band x T]
for e = 1:2
    for g = 1:2
        nm = subjNames{g};   n = numel(nm);
        DAT{g, e} = struct('names', {nm}, 'freq', [], 'time', [], 'roi', {cell(n, 1)}, 'cb', {cell(n, 1)});
        if g == 2
            S = load(fullfile(tfr_exp, sprintf('Task2_norm_%s_allExp.mat', ev(e).name)));
            allTF = S.(sprintf('Task2_norm_%s_allExp', ev(e).name));   expNames = S.subjects;
        else
            % ORIGINAL: per-resident <name>_IR_<event>_TFR.mat (old files, not rebuilt by Task_Res_TFR_claude.m)
            S = load(fullfile(tfr_res, sprintf('IR_norm_%s.mat', ev(e).name)));     % IR_norm_grasp / IR_norm_exit, subjects
            allTF = S.(sprintf('IR_norm_%s', ev(e).name));   resNames = S.subjects;
        end
        for s = 1:n
            fprintf('loading %s [%s]\n', nm{s}, ev(e).name);
            if g == 1
                k = find(strcmp(resNames, nm{s}));   if isempty(k), warning('%s not in IR_norm file', nm{s}); continue; end
                tf = allTF{k};
            else
                k = find(strcmp(expNames, nm{s}));   if isempty(k), warning('%s not in expert file', nm{s}); continue; end
                tf = allTF{k};
            end
            DAT{g, e}.freq = tf.freq(:)';   DAT{g, e}.time = tf.time(:)';
            pw = tf.powspctrm;                                            % [slot x chan x freq x time]
            DAT{g, e}.roi{s} = single(squeeze(mean(pw(:, ROI_MOTOR, :, :), 2, 'omitnan')));      % [slot x F x T]
            cb = nan(size(pw, 1), size(pw, 2), numel(bands), size(pw, 4), 'single');
            for b = 1:numel(bands)
                fi = tf.freq >= bandHz(b, 1) - TOL & tf.freq <= bandHz(b, 2) + TOL;
                cb(:, :, b, :) = reshape(single(mean(pw(:, :, fi, :), 3, 'omitnan')), size(pw, 1), size(pw, 2), 1, size(pw, 4));
            end
            DAT{g, e}.cb{s} = cb;
            clear pw tf
        end
        clear S allTF
    end
end

%% 3. SLOT CLASSES + SUBJECT x CLASS AVERAGES
SL  = cell(2, 2);                                  % SL{g,e}(s): slot list with data
AVR = cell(2, 2);   AVC = cell(2, 2);   NCL = cell(2, 2);
for e = 1:2
    for g = 1:2
        d = DAT{g, e};   n = numel(d.names);   nF = numel(d.freq);   nT = numel(d.time);   k1 = find(~cellfun(@isempty, d.cb), 1);   nCh = size(d.cb{k1}, 2);
        AVR{g, e} = nan(n, 3, nF, nT, 'single');   AVC{g, e} = nan(n, 3, nCh, numel(bands), nT, 'single');   NCL{g, e} = zeros(n, 3);
        SL{g, e}  = repmat(struct('slot', [], 'gap', [], 'cls', [], 'rep', [], 'GA', [], 'EE', [], 'GE', []), n, 1);
        for s = 1:n
            if isempty(d.roi{s}), continue; end
            m = T.group == g & strcmp(T.subj, d.names{s});
            slot = T.slot(m);   gap = T.(GAP_DEF)(m);
            hasData = squeeze(any(any(~isnan(d.roi{s}), 2), 3));          % [slot x 1]
            ok = slot <= size(d.roi{s}, 1) & isfinite(gap);   ok(ok) = hasData(slot(ok));
            cls = 1 + (gap >= EDGES(1)) + (gap >= EDGES(2));
            r = T.rep(m);   ga = T.GA(m);   ee = T.EE(m);   ge = T.GE(m);
            SL{g, e}(s) = struct('slot', slot(ok), 'gap', gap(ok), 'cls', cls(ok), 'rep', r(ok), 'GA', ga(ok), 'EE', ee(ok), 'GE', ge(ok));
            for c = 1:3
                sl = SL{g, e}(s).slot(SL{g, e}(s).cls == c);   NCL{g, e}(s, c) = numel(sl);
                if numel(sl) < MIN_SLOTS, continue; end
                AVR{g, e}(s, c, :, :)    = mean(d.roi{s}(sl, :, :), 1, 'omitnan');
                AVC{g, e}(s, c, :, :, :) = mean(d.cb{s}(sl, :, :, :), 1, 'omitnan');
            end
        end
    end
end

fprintf('\n================ SLOTS PER CLASS (%s; cut points %g and %g s) ================\n', GAP_DEF, EDGES);
for e = 1:2
    for g = 1:2
        N = NCL{g, e};
        fprintf('%-10s %-6s slots: short %4d | mid %4d | long %4d   subjects with >= %d slots: short %2d | mid %2d | long %2d  (of %d)\n', grpName{g}, ev(e).name, ...
            sum(N, 1), MIN_SLOTS, sum(N >= MIN_SLOTS, 1), size(N, 1));
    end
end

%% 4. S1 : TIME-FREQUENCY MAPS
for g = 1:2
    f = claude_figure_right(sprintf('S1 TF maps %s', grpName{g}), 1700, 800);   set(f, 'Color', 'w');
    for e = 1:2
        d = DAT{g, e};   A = AVR{g, e};
        M = cell(1, 4);
        for c = 1:3, M{c} = squeeze(mean(A(:, c, :, :), 1, 'omitnan')); end
        M{4} = squeeze(mean(A(:, 1, :, :) - A(:, 3, :, :), 1, 'omitnan'));
        lim  = prctile(abs(cat(1, M{1}(:), M{2}(:), M{3}(:))), 99);   limD = prctile(abs(M{4}(:)), 99);
        for c = 1:4
            ax = subplot(2, 4, (e - 1) * 4 + c);   imagesc(ax, d.time, d.freq, M{c});   axis(ax, 'xy');
            caxis(ax, tern(c < 4, [-lim lim], [-limD limD]));   colormap(ax, 'jet');   hold(ax, 'on');
            xline(ax, 0, 'k-');   yline(ax, [8 15 25], ':w');
            if c <= 3, mk_events(ax, e, SL{g, e}, c, 'k'); end
            if c <= 3, title(ax, sprintf('%s | %s  (n=%d)', ev(e).name, clsName{c}, sum(NCL{g, e}(:, c) >= MIN_SLOTS)), 'FontSize', 9);
            else,      title(ax, sprintf('%s | SHORT - LONG', ev(e).name), 'FontSize', 9); end
            if c == 1, ylabel(ax, 'Hz'); end
            if e == 2, xlabel(ax, 'time from event (s)'); end
            colorbar(ax);
        end
    end
    sgtitle(sprintf('%s - motor ROI, normalised power; dashed = median entry, dash-dot = median grasp (exit-locked) / exit (grasp-locked)', grpName{g}));
    save_fig(f, SAVE_FIGS, fig_dir, sprintf('S1_TF_%s', grpName{g}));
end

%% 5. S2 : BAND TIME COURSES
f = claude_figure_right('S2 band time courses', 1800, 760);   set(f, 'Color', 'w');
for b = 1:numel(bands)
    col = 0;
    for g = 1:2
        for e = 1:2
            col = col + 1;   d = DAT{g, e};   fi = d.freq >= bandHz(b, 1) - TOL & d.freq <= bandHz(b, 2) + TOL;
            tc = squeeze(mean(AVR{g, e}(:, :, fi, :), 3, 'omitnan'));        % [subj x 3 x T]
            ax = subplot(numel(bands), 4, (b - 1) * 4 + col);   hold(ax, 'on');
            hl = gobjects(1, 3);
            for c = 1:3
                X = squeeze(tc(:, c, :));   ns = sum(any(~isnan(X), 2));      % subjects with data (the first/last time bins of an epoch are NaN)
                if ns < 2, continue; end
                mu = mean(X, 1, 'omitnan');   se = std(X, 0, 1, 'omitnan') / sqrt(ns);
                fill(ax, [d.time fliplr(d.time)], [mu - se fliplr(mu + se)], clsCol(c, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
                hl(c) = plot(ax, d.time, mu, '-', 'Color', clsCol(c, :), 'LineWidth', 2);
                mk_events(ax, e, SL{g, e}, c, clsCol(c, :));
            end
            xline(ax, 0, 'k-');   set(ax, 'Box', 'off', 'FontSize', 10, 'XLim', d.time([1 end]));
            yl = ylim(ax);   patch(ax, [ev(e).win fliplr(ev(e).win)], [yl(1) yl(1) yl(2) yl(2)], [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.5);   uistack(findobj(ax, 'Type', 'patch', 'FaceColor', [0.92 0.92 0.92]), 'bottom');   ylim(ax, yl);
            title(ax, sprintf('%s %s - %s', grpName{g}, ev(e).name, bands{b}), 'FontSize', 10);
            if b == 2, xlabel(ax, 'time from event (s)'); end
            if col == 1, ylabel(ax, 'normalised power'); end
            if b == 1 && col == 1, okh = isgraphics(hl);   legend(ax, hl(okh), clsName(okh), 'Location', 'best'); end
        end
    end
end
sgtitle('Motor ROI, mean +/- SEM over subjects; grey = analysis window; dashed / dash-dot colour lines = median entry / grasp (exit-locked) or exit (grasp-locked) of each class');
save_fig(f, SAVE_FIGS, fig_dir, 'S2_band_timecourses');

%% 6. S3 : SORTED SLOTS
f = claude_figure_right('S3 sorted slots', 1700, 900);   set(f, 'Color', 'w');
for g = 1:2
    for e = 1:2
        d = DAT{g, e};   fi = d.freq >= bandHz(RASTER_BAND, 1) - TOL & d.freq <= bandHz(RASTER_BAND, 2) + TOL;
        Z = [];   G = [];   GAv = [];   GEv = [];   EEv = [];
        for s = 1:numel(d.names)
            if isempty(SL{g, e}(s).slot), continue; end
            sl = SL{g, e}(s).slot;
            Z   = [Z;   reshape(mean(d.roi{s}(sl, fi, :), 2, 'omitnan'), numel(sl), [])];   %#ok<AGROW>   [slot x T]
            G   = [G;   SL{g, e}(s).gap(:)];   GAv = [GAv; SL{g, e}(s).GA(:)];   EEv = [EEv; SL{g, e}(s).EE(:)];   GEv = [GEv; SL{g, e}(s).GE(:)]; %#ok<AGROW>
        end
        [G, o] = sort(G);   Z = Z(o, :);   GAv = GAv(o);   EEv = EEv(o);   GEv = GEv(o);
        Zs = movmean(Z, SMOOTH_N, 1, 'omitnan');   n = size(Z, 1);
        ax = subplot(2, 2, (g - 1) * 2 + e);   imagesc(ax, d.time, 1:n, Zs);   hold(ax, 'on');
        lim = prctile(abs(Zs(:)), 99);   caxis(ax, [-lim lim]);   colormap(ax, 'jet');   colorbar(ax);
        if e == 2,  plot(ax, -EEv, 1:n, 'k.', 'MarkerSize', 3);   plot(ax, -GEv, 1:n, '.', 'Color', [0.1 0.7 0.1], 'MarkerSize', 3);
        else,       plot(ax,  GAv, 1:n, 'k.', 'MarkerSize', 3);   plot(ax,  GEv, 1:n, '.', 'Color', [0.1 0.7 0.1], 'MarkerSize', 3); end
        xline(ax, 0, 'w-', 'LineWidth', 1.5);   xlim(ax, d.time([1 end]));   ylim(ax, [0.5 n + 0.5]);
        q = round(linspace(1, n, 6));   set(ax, 'YTick', q, 'YTickLabel', arrayfun(@(x) sprintf('%.1f', x), G(q), 'UniformOutput', false), 'FontSize', 10);
        ylabel(ax, sprintf('slots sorted by %s (s)', GAP_DEF));   xlabel(ax, 'time from event (s)');
        title(ax, sprintf('%s %s - %s, motor ROI (%d slots, smoothed over %d)', grpName{g}, ev(e).name, bands{RASTER_BAND}, n, SMOOTH_N), 'FontSize', 10);
    end
end
sgtitle('Sorted slots. black dots = needle entry, green = last grasp (exit-locked) / needle exit (grasp-locked)');
save_fig(f, SAVE_FIGS, fig_dir, 'S3_sorted_slots');

%% 7. S4 : TOPOGRAPHIES OVER TIME
for g = 1:2
    for e = 1:2
        d = DAT{g, e};   edg = linspace(ev(e).epoch(1), ev(e).epoch(2), NB_TOPO + 1);
        for b = 1:numel(bands)
            A = AVC{g, e};                                                         % [subj x 3 x chan x band x T]
            tm = nan(NB_TOPO, 3, size(A, 3));   df = nan(NB_TOPO, size(A, 3));
            for k = 1:NB_TOPO
                ti = d.time >= edg(k) - TOL & d.time < edg(k + 1) - TOL + (k == NB_TOPO) * 2 * TOL;
                Bk = squeeze(mean(A(:, :, :, b, ti), 5, 'omitnan'));               % [subj x 3 x chan]
                for c = 1:3, tm(k, c, :) = squeeze(mean(Bk(:, c, :), 1, 'omitnan')); end
                df(k, :) = squeeze(mean(Bk(:, 1, :) - Bk(:, 3, :), 1, 'omitnan'));
            end
            lim = prctile(abs([reshape(tm(:, 1, :), [], 1); reshape(tm(:, 3, :), [], 1)]), 99);   limD = prctile(abs(df(:)), 99);
            if isnan(lim) || lim == 0, continue; end
            f = claude_figure_right(sprintf('S4 %s %s %s', grpName{g}, ev(e).name, bands{b}), 1700, 760);   set(f, 'Color', 'w');
            for k = 1:NB_TOPO
                for r = 1:3
                    ax = subplot(3, NB_TOPO, (r - 1) * NB_TOPO + k);
                    if r == 1, v = squeeze(tm(k, 1, :)); L = lim; elseif r == 2, v = squeeze(tm(k, 3, :)); L = lim; else, v = df(k, :)'; L = limD; end
                    topoplot(v, EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-L L]);
                    colormap(ax, 'jet');
                    if r == 1, title(ax, sprintf('%.2f to %.2f s', edg(k), edg(k + 1)), 'FontSize', 9); end
                    if k == 1, text(ax, -0.80, 0, tern(r == 1, 'SHORT', tern(r == 2, 'LONG', 'SHORT - LONG')), 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off'); end
                    if k == NB_TOPO, colorbar(ax); end
                end
            end
            sgtitle(sprintf('%s - %s - %s (%d-%d Hz): %s | SHORT n=%d, LONG n=%d subjects', grpName{g}, ev(e).label, bands{b}, bandHz(b, :), GAP_DEF, ...
                sum(NCL{g, e}(:, 1) >= MIN_SLOTS), sum(NCL{g, e}(:, 3) >= MIN_SLOTS)));
            save_fig(f, SAVE_FIGS, fig_dir, sprintf('S4_topo_%s_%s_%s', grpName{g}, ev(e).name, bands{b}));
        end
    end
end

%% 8. SLOT VALUES IN THE ANALYSIS WINDOWS (per subject and class) : S5 and statistics
VAL = cell(2, 2, numel(bands));        % VAL{g,e,b}(s, c) subject mean of the window power ; slot-level values in SLV
SLV = cell(2, 2, numel(bands));        % slot-level: struct array with cls, rep, val
for e = 1:2
    for g = 1:2
        d = DAT{g, e};   ti = d.time >= ev(e).win(1) - TOL & d.time <= ev(e).win(2) + TOL;   n = numel(d.names);
        for b = 1:numel(bands)
            fi = d.freq >= bandHz(b, 1) - TOL & d.freq <= bandHz(b, 2) + TOL;
            V = nan(n, 3);   sv = repmat(struct('cls', [], 'rep', [], 'val', []), n, 1);
            for s = 1:n
                if isempty(SL{g, e}(s).slot), continue; end
                val = squeeze(mean(mean(d.roi{s}(SL{g, e}(s).slot, fi, ti), 3, 'omitnan'), 2, 'omitnan'));
                sv(s) = struct('cls', SL{g, e}(s).cls, 'rep', SL{g, e}(s).rep, 'val', val(:));
                for c = 1:3, if NCL{g, e}(s, c) >= MIN_SLOTS, V(s, c) = mean(val(sv(s).cls == c), 'omitnan'); end, end
            end
            VAL{g, e, b} = V;   SLV{g, e, b} = sv;
        end
    end
end

fprintf('\n================ WINDOW POWER, SHORT vs LONG (subject means; paired signed-rank) ================\n');
fprintf('windows: grasp %g..%g s (ERD) | exit %g..%g s (ERS); normalised units (negative = below the subject''s own mean)\n', ev(1).win, ev(2).win);
for e = 1:2
    for b = 1:numel(bands)
        for g = 1:2
            V = VAL{g, e, b};   ok = all(~isnan(V(:, [1 3])), 2);
            if nnz(ok) >= 4, p = signrank(V(ok, 1), V(ok, 3)); else, p = NaN; end
            fprintf('%-6s %-5s %-10s n=%2d | short %7.3f | mid %7.3f | long %7.3f | short-long %7.3f | p = %.3f\n', ev(e).name, bands{b}, grpName{g}, nnz(ok), ...
                median(V(ok, 1)), median(V(:, 2), 'omitnan'), median(V(ok, 3)), median(V(ok, 1) - V(ok, 3)), p);
        end
        for c = [1 3]
            a = VAL{2, e, b}(:, c);  r = VAL{1, e, b}(:, c);  a = a(~isnan(a));  r = r(~isnan(r));
            if numel(a) >= 3 && numel(r) >= 3
                fprintf('       experts vs residents, class %-5s: experts %7.3f (n=%d) | residents %7.3f (n=%d) | rank-sum p = %.3f\n', tern(c == 1, 'SHORT', 'LONG'), median(a), numel(a), median(r), numel(r), ranksum(a, r));
            end
        end
    end
end

%% 9. S5 : TREND OVER REPETITIONS
nBin = 4;
f = claude_figure_right('S5 trend over repetitions', 1700, 800);   set(f, 'Color', 'w');
for row = 1:2                               % row 1 = ERD (grasp window), row 2 = ERS (exit window)
    for g = 1:2
        nRep = tern(g == 1, 10, 20);   sv = SLV{g, row, 2};                % beta
        ax = subplot(2, 2, (row - 1) * 2 + g);   hold(ax, 'on');
        for c = 1:3
            Y = nan(numel(sv), nBin);
            for s = 1:numel(sv)
                if isempty(sv(s).cls), continue; end
                bn = ceil(sv(s).rep * nBin / nRep);
                for k = 1:nBin
                    m = sv(s).cls == c & bn == k;   if nnz(m) >= 1, Y(s, k) = mean(sv(s).val(m), 'omitnan'); end
                end
            end
            ok = sum(~isnan(Y), 1) >= 3;   mu = nan(1, nBin);   se = nan(1, nBin);
            mu(ok) = mean(Y(:, ok), 1, 'omitnan');   se(ok) = std(Y(:, ok), 0, 1, 'omitnan') ./ sqrt(sum(~isnan(Y(:, ok)), 1));
            errorbar(ax, (1:nBin) + (c - 2) * 0.08, mu, se, '-o', 'Color', clsCol(c, :), 'LineWidth', 2, 'MarkerFaceColor', clsCol(c, :));
        end
        set(ax, 'Box', 'off', 'FontSize', 11, 'XTick', 1:nBin, 'XLim', [0.5 nBin + 0.5]);
        xlabel(ax, 'repetition quarter (early -> late)');   ylabel(ax, 'beta, normalised power');
        title(ax, sprintf('%s - %s window (%g..%g s)', grpName{g}, tern(row == 1, 'ERD grasp', 'ERS exit'), ev(row).win), 'FontSize', 10);
        if row == 1 && g == 1, legend(ax, clsName, 'Location', 'best'); end
    end
end
sgtitle('Beta (motor ROI) window amplitude across repetitions, by passage-time class (mean +/- SEM of subjects; >= 3 subjects per point)');
save_fig(f, SAVE_FIGS, fig_dir, 'S5_trend_repetitions');
fprintf('\nFigures saved in %s\n', fig_dir);

%% ---------------------------------------------------------------------
function mk_events(ax, e, sl, c, col)
    % vertical marks at the median entry and grasp (exit-locked) or entry and exit (grasp-locked) of class c
    cls = vertcat(sl.cls);   GA = vertcat(sl.GA);   EE = vertcat(sl.EE);   GE = vertcat(sl.GE);
    m = cls == c;   if ~any(m), return; end
    if e == 2, xline(ax, -median(EE(m)), '--', 'Color', col);   xline(ax, -median(GE(m)), '-.', 'Color', col);
    else,      xline(ax,  median(GA(m)), '--', 'Color', col);   xline(ax,  median(GE(m)), '-.', 'Color', col); end
end

function save_fig(f, doSave, dirName, name)
    if doSave, print(f, fullfile(dirName, [name '.png']), '-dpng', '-r110'); end
end

function out = tern(c, a, b)
    if c, out = a; else, out = b; end
end
