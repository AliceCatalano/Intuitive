% claude_Res_AlphaBetaPeak_wholeRep.m
% =====================================================================================================
% RESIDENTS: WHERE ARE THE ALPHA AND THE BETA PEAKS in the motor areas, using the WHOLE repetition
% (same method as claude_Exp_BetaPeak_wholeRep.m for the experts, so the two groups are comparable).
%
% WINDOW OF A REPETITION (scenario sc, repetition tr)
%   from the marker MS<sc>_<tr> (the go) to the LAST validated needle exit of it (events Ext_S<sc>_T<tr>_P*).
%   Data: <resident>_IR_exitERS_events.set (continuous, contains MS/ME and the Ext events).
%   A repetition with no Ext event (skipped / not usable) has no value.
%   If the window contains 'boundary' events (removed data) it is cut there and the pieces are averaged
%   (pieces shorter than the Welch window are dropped; repetitions with less than MIN_S seconds are dropped).
%
% HOW THE PEAK IS FOUND (FOOOF, same settings as Task_Res_FOOOF.m / Task2_fooof.m; helper claude_fooof_peak.m)
%   1. Welch spectrum of every channel (4 s Hamming windows, 50 % overlap), averaged over the channels of the ROI
%      ROIs: MotorLeft, MotorRight and Motor (L+R) = the two together
%   2. FOOOF on the RAW spectrum over 4-35 Hz: it fits the 1/f background and the peaks together (no baselining by us)
%   3. PEAK of a band (ALPHA 8-15, BETA 15-25 Hz) = the highest peak FOOOF finds with its centre in the band;
%      FOOOF found no peak there -> no peak (NaN). The printed tables say how many residents / repetitions have one.
%
% FIGURES (saved in DataStructures/Figures_IR_Peaks/, name suffix = SOURCE)
%   1. corrected spectrum of each resident (all repetitions, weighted by duration), dot = peak; row = band, column = ROI
%   2. peak frequency across the 10 repetitions (every resident = mean over his scenarios), black = mean +/- SD
%   3. first vs last usable repetition of each scenario (resident mean over scenarios): lines + mean +/- SD
% PRINTED: peak of every resident, n residents per repetition, first vs last (mean, Wilcoxon signed-rank p, uncorrected).
% =====================================================================================================

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));      % claude_figure_right.m
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;
addpath('/home/acatalano/Documents/MATLAB/fooof_mat/fooof_mat/');       % FOOOF (python wrapper)

%% 1. SETTINGS -----------------------------------------------------------------------------------------
USE_SAVED = true;        % true: use the saved spectra if they exist (skips the slow part)
SAVE_FIGS = true;
SOURCE    = 'avgref';     % 'avgref' = IR_Task/ERDS_avgref (filtered + average reference);  'orig' = IR_Task/ERDS (original)
EXCLUDE   = {'IR04'};
CUTOFF    = 75;           % score (%) that defines a successful trial (as in the modulation analysis)
MIN_S     = 12;           % s, minimum usable duration of a repetition
bands(1).name = 'Alpha';  bands(1).rng = [8 15];
bands(2).name = 'Beta';   bands(2).rng = [15 25];
EDGE_HZ = 1;              % a peak closer than this to a band edge is flagged '*' (may belong to the neighbouring band)
WEAK_PW = 0.10;           % a peak lower than this (log10 power above the aperiodic fit) is flagged '~' (small bump)
FIT   = [4 35];           % Hz, range fitted by FOOOF (as in the trial-level FOOOF scripts)
PER_REP = true;           % true: also a FOOOF fit for every single repetition (slow: a few minutes); false: only the whole-recording peak
WIN_S = 4;                % Welch window (s)

D = '/home/acatalano/Desktop/Intuitive/DataStructures/';
if strcmp(SOURCE, 'avgref'), eegDir = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref/'; else, eegDir = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/'; end
saved   = [D 'IR_AlphaBetaPeak_wholeRep_' SOURCE '.mat'];
fig_dir = [D 'Figures_IR_Peaks'];
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
ROI(1).name = 'MotorLeft';   ROI(1).ch = [15 20 10];     % same channels as the ERD/ERS ROI scripts
ROI(2).name = 'MotorRight';  ROI(2).ch = [13 19 9];
ROI(3).name = 'Motor (L+R)'; ROI(3).ch = [ROI(1).ch ROI(2).ch];
NS = 6;   NRp = 10;   nR = numel(ROI);   nB = numel(bands);

G = load([D 'GraspERD_Times_IR.mat']);   allSubj = G.subjects(:)';
subjects = allSubj(~ismember(allSubj, EXCLUDE));
subjects = subjects(cellfun(@(s) exist([eegDir s '_IR_exitERS_events.set'], 'file') > 0, subjects));
nS = numel(subjects);
fprintf('Residents analysed (%d): %s\n(excluded: %s)\n', nS, strjoin(subjects, ' '), strjoin(EXCLUDE, ' '));

%% 2. SPECTRUM OF EVERY REPETITION (slow part, saved) --------------------------------------------------
if USE_SAVED && exist(saved, 'file')
    S = load(saved);   PSD = S.PSD;   dur = S.dur;   fAxis = S.fAxis;   subjects = S.subjects;   nS = numel(subjects);
    fprintf('Loaded the saved spectra %s\n', saved);
else
    [PSD, dur, fAxis] = compute_psd(eegDir, subjects, ROI(1:2), NS, NRp, WIN_S, FIT, MIN_S);
    save(saved, 'PSD', 'dur', 'fAxis', 'subjects', 'bands', 'FIT', 'SOURCE');
    fprintf('Saved %s\n', saved);
end
PSD(:, 3, :, :, :) = mean(PSD(:, 1:2, :, :, :), 2);          % joint motor ROI = mean of the two ROI spectra

%% 2b. THE 3 SUCCESSFUL TRIALS OF EVERY SCENARIO (the triplet that let the resident go on; last3_successful_residents.csv) -----
CSV_FILE = '/home/acatalano/Desktop/Intuitive/last3_successful_residents.csv';
succ = false(nS, NS, NRp);
txt = splitlines(strtrim(fileread(CSV_FILE)));
for k = 2:numel(txt)
    parts = strsplit(txt{k}, ',');
    s = find(strcmp(strtrim(parts{1}), subjects));
    if isempty(s), continue; end
    for sc = 1:NS
        c = regexprep(parts{sc + 1}, '[^0-9\-NR]', '');          % drop footnote symbols
        if isempty(c) || strcmp(c, 'NR'), continue; end
        succ(s, sc, str2double(strsplit(c, '-'))) = true;
    end
end
PSD_all = PSD;   dur_all = dur;
conds = {'all trials', 'the 3 successful trials of each scenario'};   ctag = {'', '_successful'};
for cc = 1:2
close all;
if cc == 1, dur = dur_all;   PSD = PSD_all;
else
    dur = dur_all;   dur(~succ) = NaN;   PSD = PSD_all;
    m = repmat(reshape(~succ, [nS 1 NS NRp]), [1 nR 1 1 numel(fAxis)]);   PSD(m) = NaN;   % unsuccessful repetitions removed
end
fprintf('\n\n################ %s ################\n', upper(conds{cc}));
fprintf('Repetitions with a value: %d\n', nnz(~isnan(dur)));

%% 3. PEAKS ---------------------------------------------------------------------------------------------
% peakRep(res, roi, band, sc, rep), peakAll(res, roi, band) whole recording, corrAll(res, roi, freq)
peakRep = nan(nS, nR, nB, NS, NRp);   peakAll = nan(nS, nR, nB);   ampAll = nan(nS, nR, nB);   bwAll = nan(nS, nR, nB);   corrAll = nan(nS, nR, numel(fAxis));
rngM = reshape([bands.rng], 2, [])';   expAll = nan(nS, nR);   r2All = nan(nS, nR);
for s = 1:nS
    for r = 1:nR
        if PER_REP
            for sc = 1:NS
                for rep = 1:NRp
                    spec = squeeze(PSD(s, r, sc, rep, :))';
                    if ~any(isnan(spec)), o = claude_fooof_peak(fAxis, spec, FIT, rngM);   peakRep(s, r, :, sc, rep) = o.cf; end
                end
            end
        end
        w = dur(s, :, :);   ok = ~isnan(w);
        if any(ok(:))
            P = squeeze(PSD(s, r, :, :, :));                                  % sc x rep x freq
            wv = reshape(w, NS, NRp, 1);   wv(isnan(wv)) = 0;
            spec = squeeze(sum(sum(P .* wv, 1, 'omitnan'), 2, 'omitnan')) / sum(wv(:));
            o = claude_fooof_peak(fAxis, spec(:)', FIT, rngM);
            peakAll(s, r, :) = o.cf;   ampAll(s, r, :) = o.pw;   bwAll(s, r, :) = o.bw;   expAll(s, r) = o.exponent;   r2All(s, r) = o.r2;
            if ~isempty(o.freqs), corrAll(s, r, :) = interp1(o.freqs, o.resid, fAxis, 'linear', NaN); end
        end
    end
    fprintf('  FOOOF done: %s\n', subjects{s});
end

% first / last usable repetition of every scenario (earliest / latest repetition that has a value)
hasV = ~isnan(squeeze(dur));   %#ok<NASGU>
firstP = nan(nS, nR, nB, NS);   lastP = nan(nS, nR, nB, NS);
for s = 1:nS
    for sc = 1:NS
        v = find(~isnan(squeeze(dur(s, sc, :))));
        if numel(v) >= 2
            firstP(s, :, :, sc) = peakRep(s, :, :, sc, v(1));
            lastP(s, :, :, sc)  = peakRep(s, :, :, sc, v(end));
        end
    end
end
firstR = squeeze(mean(firstP, 4, 'omitnan'));   lastR = squeeze(mean(lastP, 4, 'omitnan'));    % res x roi x band (mean over scenarios)

%% 4. PRINT ---------------------------------------------------------------------------------------------
for b = 1:nB
    fprintf('\n%s PEAK OF EACH RESIDENT, WHOLE RECORDING (FOOOF, range %d-%d Hz; NaN = no peak found)\n', bands(b).name, bands(b).rng);
    fprintf('each cell: centre Hz (h = height in log10 above the 1/f, w = width in Hz); * = within %g Hz of the band edge, ~ = height < %.2f\n', EDGE_HZ, WEAK_PW);
    fprintf('%-6s %24s %24s %24s\n', 'res', ROI(1).name, ROI(2).name, ROI(3).name);
    for s = 1:nS
        fprintf('%-6s', subjects{s});
        for r = 1:nR, fprintf(' %24s', pk_str(peakAll(s, r, b), ampAll(s, r, b), bwAll(s, r, b), bands(b).rng, EDGE_HZ, WEAK_PW)); end
        fprintf('\n');
    end
    solid = peakAll(:, :, b) > bands(b).rng(1) + EDGE_HZ & peakAll(:, :, b) < bands(b).rng(2) - EDGE_HZ & ampAll(:, :, b) >= WEAK_PW;
    fprintf('%-6s mean of the peaks found: %.2f / %.2f / %.2f Hz;  peaks found: %d / %d / %d;  SOLID peaks (not edge, not weak): %d / %d / %d of %d residents\n', 'all', ...
        mean(peakAll(:, 1, b), 'omitnan'), mean(peakAll(:, 2, b), 'omitnan'), mean(peakAll(:, 3, b), 'omitnan'), nnz(~isnan(peakAll(:, 1, b))), nnz(~isnan(peakAll(:, 2, b))), nnz(~isnan(peakAll(:, 3, b))), ...
        nnz(solid(:, 1)), nnz(solid(:, 2)), nnz(solid(:, 3)), nS);
    fprintf('       mean of the SOLID peaks only: %.2f / %.2f / %.2f Hz\n', mean(peakAll(solid(:, 1), 1, b), 'omitnan'), mean(peakAll(solid(:, 2), 2, b), 'omitnan'), mean(peakAll(solid(:, 3), 3, b), 'omitnan'));
end
fprintf('\nRESIDENTS WITH A FOOOF PEAK IN THE WHOLE RECORDING (of %d):\n', nS);
for b = 1:nB, fprintf('%-6s %s\n', bands(b).name, sprintf('%s: %d   ', ROI(1).name, nnz(~isnan(peakAll(:, 1, b))))); for r = 2:nR, fprintf('       %s: %d\n', ROI(r).name, nnz(~isnan(peakAll(:, r, b)))); end, end
fprintf('FOOOF fit: median aperiodic exponent %.2f, median R^2 %.3f\n', median(expAll(:), 'omitnan'), median(r2All(:), 'omitnan'));
if cc == 1 && PER_REP
fprintf('\nRESIDENTS WITH A PEAK IN EACH REPETITION (any scenario), per band / ROI (of %d):\n%-18s', nS, 'repetition'); fprintf('%4d', 1:NRp); fprintf('\n');
for b = 1:nB
    for r = 1:nR
        fprintf('%-18s', [bands(b).name ' ' ROI(r).name]);
        fprintf('%4d', squeeze(sum(any(~isnan(squeeze(peakRep(:, r, b, :, :))), 2), 1))');   fprintf('\n');
    end
end
fprintf('\nFIRST vs LAST usable repetition, peak frequency (mean over scenarios, then over residents). Wilcoxon signed-rank, uncorrected.\n');
fprintf('%-8s %-12s %3s %9s %9s %9s\n', 'band', 'ROI', 'n', 'first', 'last', 'p');
for b = 1:nB
    for r = 1:nR
        a = firstR(:, r, b);   c = lastR(:, r, b);   ok = ~isnan(a) & ~isnan(c);   p = NaN;
        if nnz(ok) >= 5, try, p = signrank(a(ok), c(ok)); catch, end, end
        fprintf('%-8s %-12s %3d %7.2f Hz %7.2f Hz %9.4f\n', bands(b).name, ROI(r).name, nnz(ok), mean(a(ok)), mean(c(ok)), p);
    end
end

end   % (cc == 1: per-repetition counts and first vs last are not shown for the 3 successful trials)

%% 5. FIGURE 1: SPECTRA WITH THE PEAKS ------------------------------------------------------------------
colS = lines(nS);
f1 = claude_figure_right('Residents alpha/beta peak, whole recording', 1800, 800);   set(f1, 'Color', 'w');
for b = 1:nB
    for r = 1:nR
        subplot(nB, nR, (b - 1) * nR + r);   hold on;   h = gobjects(nS, 1);
        for s = 1:nS
            h(s) = plot(fAxis, squeeze(corrAll(s, r, :))', '-', 'Color', colS(s, :), 'LineWidth', 1);
            if ~isnan(peakAll(s, r, b)), scatter(peakAll(s, r, b), ampAll(s, r, b), 40, colS(s, :), 'filled', 'MarkerEdgeColor', 'k'); end
        end
        plot(fAxis, squeeze(mean(corrAll(:, r, :), 1, 'omitnan'))', 'k-', 'LineWidth', 3);
        xlim(FIT);   grid on;   box on;   xlabel('Frequency (Hz)');   ylabel('log10 power minus FOOOF aperiodic fit');
        yl = ylim;   yl = [min(yl(1), -0.3), yl(2)];   ylim(yl);
        pt = patch(bands(b).rng([1 2 2 1]), yl([1 1 2 2]), [0.5 0.5 0.5], 'FaceAlpha', 0.10, 'EdgeColor', 'none');   uistack(pt, 'bottom');
        title(sprintf('%s - %s', bands(b).name, ROI(r).name), 'FontSize', 11);
        if b == 1 && r == nR, legend(h, subjects, 'Location', 'eastoutside', 'FontSize', 7); end
    end
end
sgtitle('Residents: spectrum of all repetitions (1/f removed). Dot = peak, black = mean of residents, grey = band');
if SAVE_FIGS, print(f1, fullfile(fig_dir, ['IR_peak_spectra_' SOURCE ctag{cc} '.png']), '-dpng', '-r110'); end

if cc == 1 && PER_REP
%% 6. FIGURE 2: PEAK ACROSS REPETITIONS -----------------------------------------------------------------
f2 = claude_figure_right('Residents peak across repetitions', 1800, 900);   set(f2, 'Color', 'w');
for b = 1:nB
    for r = 1:nR
        subplot(nB, nR, (b - 1) * nR + r);   hold on;   offs = linspace(-0.28, 0.28, nS);
        Y = squeeze(mean(peakRep(:, r, b, :, :), 4, 'omitnan'));            % res x rep (mean over scenarios)
        for s = 1:nS, scatter((1:NRp) + offs(s), Y(s, :), 28, colS(s, :), 'filled', 'MarkerFaceAlpha', 0.65, 'MarkerEdgeColor', 'none'); end
        errorbar(1:NRp, mean(Y, 1, 'omitnan'), std(Y, 0, 1, 'omitnan'), 'o', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'LineWidth', 1.8, 'CapSize', 10);
        xlim([0.4 NRp + 0.6]);   xticks(1:NRp);   ylim(bands(b).rng + [-1 1]);   grid on;   box on;
        xlabel('Repetition');   ylabel([bands(b).name ' peak (Hz)']);   title(sprintf('%s - %s', bands(b).name, ROI(r).name), 'FontSize', 11);
    end
end
sgtitle('Residents: peak frequency of the whole repetition (dot = resident, mean over scenarios; black = mean +/- SD)');
if SAVE_FIGS, print(f2, fullfile(fig_dir, ['IR_peak_acrossReps_' SOURCE ctag{cc} '.png']), '-dpng', '-r110'); end

%% 7. FIGURE 3: FIRST vs LAST ---------------------------------------------------------------------------
f3 = claude_figure_right('Residents peak first vs last', 1500, 800);   set(f3, 'Color', 'w');
for b = 1:nB
    for r = 1:nR
        subplot(nB, nR, (b - 1) * nR + r);   hold on;
        A = [firstR(:, r, b), lastR(:, r, b)];
        for s = 1:nS, plot([1 2], A(s, :), '-o', 'Color', [colS(s, :) 0.5], 'MarkerFaceColor', colS(s, :), 'MarkerSize', 4); end
        errorbar([1 2], mean(A, 1, 'omitnan'), std(A, 0, 1, 'omitnan'), 'k-o', 'LineWidth', 2.2, 'MarkerFaceColor', 'k', 'CapSize', 12);
        xlim([0.5 2.5]);   xticks([1 2]);   xticklabels({'first', 'last'});   ylim(bands(b).rng + [-1 1]);   grid on;   box on;
        ylabel([bands(b).name ' peak (Hz)']);   title(sprintf('%s - %s', bands(b).name, ROI(r).name), 'FontSize', 11);
    end
end
sgtitle('Residents: peak frequency in the first vs last usable repetition (mean over scenarios; black = mean +/- SD)');
if SAVE_FIGS, print(f3, fullfile(fig_dir, ['IR_peak_firstlast_' SOURCE ctag{cc} '.png']), '-dpng', '-r110'); end

end
end

%% ---------------------------------------------------------------------
function [PSD, dur, fAxis] = compute_psd(eegDir, subjects, ROI, NS, NRp, WIN_S, FIT, MIN_S)
% PSD(res, roi, sc, rep, freq) = Welch spectrum of the whole repetition (MS -> last exit); dur(res, sc, rep) = seconds used.
    nS = numel(subjects);   nR = numel(ROI);   PSD = [];   dur = nan(nS, NS, NRp);   fAxis = [];
    for s = 1:nS
        EEG = pop_loadset('filename', [subjects{s} '_IR_exitERS_events.set'], 'filepath', eegDir);
        if EEG.trials > 1, error('%s is epoched, I need the continuous data', subjects{s}); end
        fs = EEG.srate;   types = cell(1, numel(EEG.event));
        for k = 1:numel(EEG.event), t = EEG.event(k).type; if ischar(t), types{k} = t; elseif isstring(t), types{k} = char(t); else, types{k} = ''; end, end
        lats = [EEG.event.latency];   bLat = lats(strcmp(types, 'boundary'));   winN = round(WIN_S * fs);
        fprintf('\n=== %s (srate %g Hz, %d channels, %d boundaries) ===\n', subjects{s}, fs, EEG.nbchan, numel(bLat));
        for sc = 1:NS
            for rep = 1:NRp
                i0 = find(strcmp(types, sprintf('MS%d_%d', sc, rep)), 1);
                ext = find(strcmp(types, sprintf('Ext_S%d_T%d_P1', sc, rep)) | strcmp(types, sprintf('Ext_S%d_T%d_P2', sc, rep)) | ...
                           strcmp(types, sprintf('Ext_S%d_T%d_P3', sc, rep)) | strcmp(types, sprintf('Ext_S%d_T%d_P4', sc, rep)));
                if isempty(i0) || isempty(ext), continue; end                       % not usable: no value
                t0 = round(lats(i0(end)));   t1 = round(max(lats(ext)));
                if t1 <= t0, continue; end
                edges = [t0, sort(bLat(bLat > t0 & bLat < t1)), t1];                % cut at the boundaries
                acc = [];   wsum = 0;   used = 0;
                for p = 1:numel(edges) - 1
                    a = ceil(edges(p)) + 1;   b = floor(edges(p + 1)) - 1;
                    if p == 1, a = t0; end
                    if b - a + 1 < winN, continue; end
                    for r = 1:nR
                        X = double(EEG.data(ROI(r).ch, a:b))';
                        [f, pxx, nSeg] = welch_psd(X, winN, round(winN / 2), fs);
                        if isempty(acc), acc = zeros(nR, numel(f)); end
                        acc(r, :) = acc(r, :) + nSeg * mean(pxx, 2)';
                    end
                    wsum = wsum + nSeg;   used = used + (b - a + 1) / fs;
                end
                if wsum == 0 || used < MIN_S, continue; end
                if isempty(PSD), keepF = f >= FIT(1) & f <= FIT(2);   fAxis = f(keepF);   PSD = nan(nS, nR, NS, NRp, nnz(keepF)); end
                for r = 1:nR, PSD(s, r, sc, rep, :) = acc(r, keepF) / wsum; end
                dur(s, sc, rep) = used;
            end
        end
        fprintf('  repetitions with a value: %d of %d (mean %.0f s each)\n', nnz(~isnan(dur(s, :, :))), NS * NRp, mean(dur(s, :, :), 'all', 'omitnan'));
    end
end

function [f, p, nSeg] = welch_psd(X, winN, nover, fs)
% Welch power spectrum without toolboxes. X = samples x channels. Returns f (Hz), p = [freq x channels], nSeg = number of windows.
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

function s = pk_str(cf, pw, bw, rng, EDGE_HZ, WEAK_PW)
% text of one table cell: centre (h = height, w = width) and flags
    if isnan(cf), s = 'NaN'; return; end
    fl = '';   if cf <= rng(1) + EDGE_HZ || cf >= rng(2) - EDGE_HZ, fl = [fl '*']; end
    if pw < WEAK_PW, fl = [fl '~']; end
    s = sprintf('%.2f (h%.2f w%.1f)%s', cf, pw, bw, fl);
end
