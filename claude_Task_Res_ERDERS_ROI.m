% claude_Task_Res_ERDERS_ROI.m
% RESIDENTS (IR): beta and alpha ERD, ERS and modulation per ROI and slot, the plots of all the ROIs, and the same values
% computed ONLY on the three successful repetitions that let the resident move to the next scenario (+ their plots).
% ONE SCRIPT = what used to be claude_Task_Res_ERDERS_ROI.m + claude_Task_Res_ERDERS_Last3.m. Four switches below:
%   RUN_ROI    compute ERD/ERS/modulation per ROI and slot from the TFR files (slow). false: load the saved result
%   PLOT_ROI   plots of all the ROIs: by scenario / by repetition / by suture point, and Beta vs Alpha
%   RUN_LAST3  compute the values of the 3 successful repetitions of every scenario (needs last3_successful_residents.csv)
%   PLOT_LAST3 plots of the 3 successful repetitions: by scenario and by suture point
%
% PART 1  Same definitions as the experts (Task12_Exp_ERD_ERS_ROI.m):
%   ROIs (channel indices in the reference order, as for the experts):
%       MotorLeft [15 20 10] | MotorRight [13 19 9] | Visual [29 30 31] | Frontal [4 5 6]
%   Bands: Beta 15-25 Hz | Alpha 8-15 Hz   (the experts' "high alpha" band)
%   ERD  : grasp-locked epoch, ROI-mean band power, MINIMUM over time in [-0.5, 1.0] s
%   ERS  : exit-locked epoch , ROI-mean band power, MAXIMUM over time in [-2.0, 0.0] s
%   Modulation = |ERS - ERD|  (only where both exist for the same slot)
%   Slots: 240 = 6 scenarios x 10 repetitions x 4 points,  slot = (scenario-1)*40 + (rep-1)*4 + point
%   Slots without an epoch are NaN and stay NaN (skipped / missing / not completed).
%   Input : IR_norm_grasp.mat , IR_norm_exit.mat  (Task_Res_TFR_claude.m): one TFR per resident, in the order of their 'subjects'
%   Output: ERD_ERS_Modulation_IR_ROI_bands.mat  ERD_all, ERS_all, Mod_all [nBands x nROI x nSubj x 240]
%           and the same reshaped as [nBands x nROI x nSubj x 6 x 10 x 4] (scenario, repetition, point)
%
% PART 2  Which repetitions: last3_successful_residents.csv (one row per resident, one column per scenario, e.g. "4-5-6",
%   "1-3-4" when a repetition in between was skipped; "NR" = never reached the criterion in 10 attempts -> no value).
%   Numbers are the ORIGINAL repetition numbers. Footnote symbols in the CSV are ignored.
%   Output (ERD_ERS_Modulation_IR_Last3.mat), per band x ROI x subject x scenario:
%     ERD_last3, ERS_last3, Mod_last3 (mean over 3 repetitions x 4 points), the same x 4 points (..._pt),
%     N_ERD, N_ERS, N_Mod = slots actually available (max 12), Last3Reps = repetitions used.
%   LAST3_FROM_FILE: '' = use the values of PART 1; or the name of another file in DataStructures (for instance the merged
%   file of the filter sensitivity test) to compute the last-3 values from it.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % so claude_figure_right.m is found

% ORIGINAL (common reference, before the average reference): base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref';   % NEW: filtered + average reference
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
% ORIGINAL (common reference, before the average reference): out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat';
out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands_avgref.mat';   % NEW: filtered + average reference
% ORIGINAL (common reference, before the average reference): fig_dir    = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ERDERS';
fig_dir    = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ERDERS_avgref';   % NEW: filtered + average reference
csv_file   = '/home/acatalano/Desktop/Intuitive/last3_successful_residents.csv';
% ORIGINAL (common reference, before the average reference): out_file3  = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_Last3.mat';
out_file3  = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_Last3_avgref.mat';   % NEW: filtered + average reference
% ORIGINAL (common reference, before the average reference): fig_dir3   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ERDERS_Last3';
fig_dir3   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ERDERS_avgref_Last3';   % NEW: filtered + average reference
LAST3_FROM_FILE = '';

RUN_ROI    = true;    % PART 1: compute (slow). false: load out_file
PLOT_ROI   = true;    % PART 1: plots of all the ROIs
RUN_LAST3  = true;    % PART 2: compute the 3 successful repetitions
PLOT_LAST3 = true;    % PART 2: plots
SAVE_FIGS  = true;    % true: also save every figure as PNG
MIN_N      = 3;       % minimum number of subjects needed to draw a point of a curve

%% ======================= PART 1: ERD / ERS / MODULATION PER ROI =======================
NUM_SCENARIOS = 6;
NUM_REPS      = 10;
NUM_POINTS    = 4;
NUM_SLOTS     = NUM_SCENARIOS * NUM_REPS * NUM_POINTS;

T        = load(times_file);
subjects = T.subjects;
nSubj    = numel(subjects);

ROI.MotorLeft  = [15, 20, 10];
ROI.MotorRight = [13, 19, 9];
ROI.Visual     = [29, 30, 31];
ROI.Frontal    = [4,  5,  6];
roi_names = fieldnames(ROI);
nROI      = numel(roi_names);

BANDS(1).name = 'Beta';   BANDS(1).fmin = 15;  BANDS(1).fmax = 25;
BANDS(2).name = 'Alpha';  BANDS(2).fmin = 8;   BANDS(2).fmax = 15;
nBands = numel(BANDS);

TOL = 1e-6;   % guards against floating point noise in the time/freq vectors

if RUN_ROI
ERD_all = nan(nBands, nROI, nSubj, NUM_SLOTS);
ERS_all = nan(nBands, nROI, nSubj, NUM_SLOTS);
Mod_all = nan(nBands, nROI, nSubj, NUM_SLOTS);

% ORIGINAL: one file per resident (<subj>_IR_graspERD_TFR.mat / _exitERS_TFR.mat) loaded inside the loop
TG = load(fullfile(base_path, 'IR_norm_grasp.mat'));   % IR_norm_grasp{k}, subjects (20 residents, no IR04)
TE = load(fullfile(base_path, 'IR_norm_exit.mat'));    % IR_norm_exit{k},  subjects
if ~isequal(TG.subjects, TE.subjects), error('Grasp and exit TFR files have different subject lists'); end

for i = 1:nSubj
    subject = subjects{i};
    fprintf('\n=== %s ===\n', subject);

    % row of this resident in the TFR files (they have no IR04): the output keeps the order of T.subjects
    k = find(strcmp(TG.subjects, subject));
    if isempty(k), fprintf('  not in the TFR files, skipped\n'); continue; end
    G.TFRhann = TG.IR_norm_grasp{k};
    E.TFRhann = TE.IR_norm_exit{k};
    gpow = G.TFRhann.powspctrm;    % [slot x chan x freq x time]
    epow = E.TFRhann.powspctrm;
    freq     = G.TFRhann.freq;
    time_ERD = G.TFRhann.time;
    time_ERS = E.TFRhann.time;

    if size(gpow,1) ~= NUM_SLOTS || size(epow,1) ~= NUM_SLOTS
        error('%s: expected %d slots, got %d (grasp) and %d (exit)', ...
            subject, NUM_SLOTS, size(gpow,1), size(epow,1));
    end

    timeERDS = find(time_ERD >= -0.5 - TOL, 1, 'first');
    timeERDE = find(time_ERD <=  1.0 + TOL, 1, 'last');
    timeERSS = find(time_ERS >= -2.0 - TOL, 1, 'first');
    timeERSE = find(time_ERS <=  0.0 + TOL, 1, 'last');

    if i == 1
        fprintf('ERD window: %.2f to %.2f s | ERS window: %.2f to %.2f s\n', ...
            time_ERD(timeERDS), time_ERD(timeERDE), time_ERS(timeERSS), time_ERS(timeERSE));
        for r = 1:nROI
            fprintf('ROI %-10s: %s\n', roi_names{r}, strjoin(G.TFRhann.label(ROI.(roi_names{r}))', ' '));
        end
    end

    for b = 1:nBands
        bs = find(freq >= BANDS(b).fmin - TOL, 1, 'first');
        be = find(freq <= BANDS(b).fmax + TOL, 1, 'last');

        for r = 1:nROI
            roi_ch = ROI.(roi_names{r});

            for j = 1:NUM_SLOTS
                % ERD (grasp-locked)
                erdPow = squeeze(gpow(j, roi_ch, :, :));      % [nROIchan x nFreq x nTime]
                if ~all(isnan(erdPow(:)))
                    roi_mean = squeeze(mean(erdPow, 1, 'omitnan'));   % [nFreq x nTime]
                    ERD_all(b,r,i,j) = min(mean(roi_mean(bs:be, timeERDS:timeERDE), 1, 'omitnan'));
                end

                % ERS (exit-locked)
                ersPow = squeeze(epow(j, roi_ch, :, :));
                if ~all(isnan(ersPow(:)))
                    roi_mean = squeeze(mean(ersPow, 1, 'omitnan'));
                    ERS_all(b,r,i,j) = max(mean(roi_mean(bs:be, timeERSS:timeERSE), 1, 'omitnan'));
                end

                % Modulation
                if ~isnan(ERD_all(b,r,i,j)) && ~isnan(ERS_all(b,r,i,j))
                    Mod_all(b,r,i,j) = abs(ERS_all(b,r,i,j) - ERD_all(b,r,i,j));
                end
            end
        end
    end

    fprintf('  slots with ERD: %d | with ERS: %d | with modulation: %d (Beta, MotorLeft)\n', ...
        nnz(~isnan(ERD_all(1,1,i,:))), nnz(~isnan(ERS_all(1,1,i,:))), nnz(~isnan(Mod_all(1,1,i,:))));
end

if all(isnan(ERD_all(:)) & isnan(ERS_all(:)))
    error('No resident of T.subjects was found in the TFR files of %s. Run the previous steps first (events -> epochs -> FieldTrip -> TFR). Nothing was saved.', base_path);
end

% reshape to [band x ROI x subj x scenario x rep x point]
% (slot = (sc-1)*40 + (rep-1)*4 + pt  ->  point varies fastest)
reshape6 = @(A) permute(reshape(A, nBands, nROI, nSubj, NUM_POINTS, NUM_REPS, NUM_SCENARIOS), [1 2 3 6 5 4]);
ERD_6d = reshape6(ERD_all);
ERS_6d = reshape6(ERS_all);
Mod_6d = reshape6(Mod_all);

save(out_file, 'ERD_all', 'ERS_all', 'Mod_all', 'ERD_6d', 'ERS_6d', 'Mod_6d', ...
    'roi_names', 'BANDS', 'subjects', '-v7.3');
fprintf('\n=== SAVED: %s ===\n', out_file);
else
    S0 = load(out_file);   ERD_6d = S0.ERD_6d;   ERS_6d = S0.ERS_6d;   Mod_6d = S0.Mod_6d;
    roi_names = S0.roi_names;   BANDS = S0.BANDS;   subjects = S0.subjects;   nSubj = numel(subjects);
    fprintf('Loaded %s (RUN_ROI = false)\n', out_file);
end

if PLOT_ROI
    plot_ERDERS_ROI(ERD_6d, ERS_6d, Mod_6d, roi_names, BANDS, SAVE_FIGS, fig_dir, MIN_N);
end

%% ======================= PART 2: THE 3 SUCCESSFUL REPETITIONS =======================
if RUN_LAST3
if isempty(LAST3_FROM_FILE)
    S3 = struct('ERD_6d', ERD_6d, 'ERS_6d', ERS_6d, 'Mod_6d', Mod_6d, 'subjects', {subjects}, 'roi_names', {roi_names}, 'BANDS', BANDS);
else
    S3 = load(fullfile(fileparts(out_file), LAST3_FROM_FILE));
    fprintf('PART 2 uses the values of %s\n', LAST3_FROM_FILE);
end
subjects = S3.subjects;   roi_names = S3.roi_names;   BANDS = S3.BANDS;
nSubj    = numel(subjects);
[nB, nR, ~, nSc, ~, nPt] = size(S3.ERD_6d);
metrics  = {'ERD', 'ERS', 'Mod'};
src      = {S3.ERD_6d, S3.ERS_6d, S3.Mod_6d};

%% 4a) read the successful repetitions
txt   = splitlines(strtrim(fileread(csv_file)));
Last3Reps = cell(nSubj, nSc);
seenInCsv = false(1, nSubj);
for k = 2:numel(txt)
    parts = strsplit(txt{k}, ',');
    sidx  = find(strcmp(strtrim(parts{1}), subjects));
    if isempty(sidx)
        fprintf('  %s is not in the analysed subjects, ignored\n', strtrim(parts{1}));
        continue;
    end
    seenInCsv(sidx) = true;
    for sc = 1:nSc
        cellTxt = regexprep(parts{sc+1}, '[^0-9\-NR]', '');      % drop footnote symbols
        if isempty(cellTxt) || strcmp(cellTxt, 'NR'), continue; end
        reps = str2double(strsplit(cellTxt, '-'));
        if numel(reps) ~= 3 || any(isnan(reps)) || any(reps < 1) || any(reps > size(S3.ERD_6d,5))
            error('Unreadable entry "%s" for %s Scenario %d', parts{sc+1}, subjects{sidx}, sc);
        end
        Last3Reps{sidx, sc} = reps;
    end
end
if any(~seenInCsv)
    warning('Subjects without a row in the CSV: %s', strjoin(subjects(~seenInCsv), ', '));
end

%% 4b) average over the successful repetitions
res    = struct();
for m = 1:3
    res.(metrics{m})      = nan(nB, nR, nSubj, nSc);
    res.([metrics{m} '_pt']) = nan(nB, nR, nSubj, nSc, nPt);
end
Ncount = nan(nSubj, nSc, 3);

for s = 1:nSubj
    for sc = 1:nSc
        reps = Last3Reps{s, sc};
        if isempty(reps), continue; end
        for m = 1:3
            X = reshape(src{m}(:, :, s, sc, reps, :), nB, nR, numel(reps), nPt);   % [band roi rep pt]
            res.(metrics{m})(:, :, s, sc)    =  mean(mean(X, 4, 'omitnan'), 3, 'omitnan');
            res.([metrics{m} '_pt'])(:, :, s, sc, :) = reshape(mean(X, 3, 'omitnan'), nB, nR, 1, 1, nPt);
            Ncount(s, sc, m) = nnz(~isnan(squeeze(X(1, 1, :, :))));
        end
    end
end

ERD_last3 = res.ERD;  ERS_last3 = res.ERS;  Mod_last3 = res.Mod;
ERD_last3_pt = res.ERD_pt;  ERS_last3_pt = res.ERS_pt;  Mod_last3_pt = res.Mod_pt;
N_ERD = Ncount(:,:,1);  N_ERS = Ncount(:,:,2);  N_Mod = Ncount(:,:,3);

save(out_file3, 'ERD_last3', 'ERS_last3', 'Mod_last3', 'ERD_last3_pt', 'ERS_last3_pt', 'Mod_last3_pt', ...
    'N_ERD', 'N_ERS', 'N_Mod', 'Last3Reps', 'roi_names', 'BANDS', 'subjects', '-v7.3');
fprintf('=== SAVED: %s ===\n', out_file3);

%% 4c) coverage report: slots available out of 12 (3 repetitions x 4 points), ERD/ERS/Mod
fprintf('\nCoverage (ERD/ERS/Mod slots available out of 12; -- = no successful triplet):\n');
fprintf('%-6s', 'Subj'); for sc = 1:nSc, fprintf('  %-11s', sprintf('Sc%d', sc)); end; fprintf('\n');
for s = 1:nSubj
    fprintf('%-6s', subjects{s});
    for sc = 1:nSc
        if isempty(Last3Reps{s,sc}), fprintf('  %-11s', '--');
        else, fprintf('  %-11s', sprintf('%d/%d/%d', N_ERD(s,sc), N_ERS(s,sc), N_Mod(s,sc))); end
    end
    fprintf('\n');
end
nTrip = nnz(~cellfun(@isempty, Last3Reps));
fprintf('\nSuccessful triplets: %d of %d subject-scenarios | with >=1 modulation slot: %d | fully covered (12/12): %d\n', ...
    nTrip, nSubj*nSc, nnz(N_Mod >= 1), nnz(N_Mod == nPt*3));
else
    if PLOT_LAST3, L3 = load(out_file3); end
end

if PLOT_LAST3
    if RUN_LAST3
        plot_last3(ERD_last3, ERS_last3, Mod_last3, ERD_last3_pt, ERS_last3_pt, Mod_last3_pt, roi_names, BANDS, SAVE_FIGS, fig_dir3, MIN_N);
    else
        plot_last3(L3.ERD_last3, L3.ERS_last3, L3.Mod_last3, L3.ERD_last3_pt, L3.ERS_last3_pt, L3.Mod_last3_pt, L3.roi_names, L3.BANDS, SAVE_FIGS, fig_dir3, MIN_N);
    end
end


%% ---------------------------------------------------------------------
%  Plotting
%  Inputs are [band x ROI x subject x scenario x rep x point].
%  Layout as for the experts: rows = ROI, columns = ERD | ERS | Modulation,
%  one figure per band. Curves are mean +/- SD ACROSS SUBJECTS; a point is drawn
%  only if at least MIN_N subjects contribute (residents have 3-10 repetitions
%  per scenario, so the later repetitions have fewer subjects).
%  Figures per band:  1) by scenario   2) by repetition   3) by suture point
%  Plus one figure comparing Beta vs Alpha by scenario.
%% ---------------------------------------------------------------------
function plot_ERDERS_ROI(ERD_6d, ERS_6d, Mod_6d, roi_names, BANDS, saveFigs, figDir, minN)
    metrics   = {'ERD', 'ERS', 'Modulation |ERS-ERD|'};
    fields    = {ERD_6d, ERS_6d, Mod_6d};
    nBands    = size(ERD_6d, 1);
    nROI      = size(ERD_6d, 2);
    nSubj     = size(ERD_6d, 3);
    nScn      = size(ERD_6d, 4);
    nRep      = size(ERD_6d, 5);
    nPt       = size(ERD_6d, 6);
    COL_ROI   = lines(nROI);
    COL_BAND  = [0.2 0.4 0.8; 0.8 0.3 0.1];

    if saveFigs && ~exist(figDir, 'dir'), mkdir(figDir); end

    % x axes: 'keep' = dimension of D=[subj sc rep pt] kept on the x axis
    axes_def(1) = struct('name', 'by scenario',         'keep', 2, 'n', nScn, 'xlab', 'Scenario', ...
                         'tick', {arrayfun(@(x) sprintf('Sc%d', x), 1:nScn, 'UniformOutput', false)}, 'mk', 'o-');
    axes_def(2) = struct('name', 'by repetition',       'keep', 3, 'n', nRep, 'xlab', 'Repetition', ...
                         'tick', {arrayfun(@(x) sprintf('Rep%d', x), 1:nRep, 'UniformOutput', false)}, 'mk', 'o-');
    axes_def(3) = struct('name', 'by suture point',     'keep', 4, 'n', nPt, 'xlab', 'Suture point', ...
                         'tick', {arrayfun(@(x) sprintf('Pt%d', x), 1:nPt, 'UniformOutput', false)}, 'mk', 's-');

    for b = 1:nBands
        for a = 1:numel(axes_def)
            ad  = axes_def(a);
            fig = claude_figure_right(sprintf('IR %s %s', BANDS(b).name, ad.name), 1300, 900);
            ylimsCol = nan(3, 2);

            for r = 1:nROI
                for m = 1:3
                    ax = subplot(nROI, 3, (r-1)*3 + m); hold on;
                    D = reshape(fields{m}(b, r, :, :, :, :), nSubj, nScn, nRep, nPt);
                    M = subj_by(D, ad.keep);                  % [subj x n]
                    [mn, sd, nn] = summarize(M, minN);
                    draw_curve(1:ad.n, mn, sd, COL_ROI(r,:), ad.mk);

                    xlim([0.5 ad.n+0.5]); xticks(1:ad.n);
                    if ad.keep == 3   % repetition axis: show how many subjects contribute
                        xticklabels(arrayfun(@(k) sprintf('%d\n(n=%d)', k, nn(k)), 1:ad.n, 'UniformOutput', false));
                    else
                        xticklabels(ad.tick);
                    end
                    grid on; box on;
                    if r == 1, title(metrics{m}, 'FontSize', 11, 'FontWeight', 'bold'); end
                    if m == 1, ylabel(roi_names{r}, 'FontSize', 10, 'FontWeight', 'bold'); end
                    if r == nROI, xlabel(ad.xlab, 'FontSize', 9); end
                    yl = ylim(ax);
                    ylimsCol(m,:) = [min([ylimsCol(m,1) yl(1)], [], 'omitnan'), max([ylimsCol(m,2) yl(2)], [], 'omitnan')];
                end
            end
            % same y range for all ROIs of a metric
            for r = 1:nROI
                for m = 1:3
                    subplot(nROI, 3, (r-1)*3 + m);
                    if all(~isnan(ylimsCol(m,:))), ylim(ylimsCol(m,:)); end
                end
            end
            sgtitle(sprintf('Residents - %s (%d-%d Hz): %s (mean \\pm SD across subjects, n>=%d)', ...
                BANDS(b).name, BANDS(b).fmin, BANDS(b).fmax, ad.name, minN), 'FontSize', 13);
            if saveFigs
                saveas(fig, fullfile(figDir, sprintf('IR_%s_%s.png', BANDS(b).name, strrep(ad.name, ' ', '_'))));
            end
        end
    end

    % Beta vs Alpha by scenario
    fig = claude_figure_right('IR Beta vs Alpha by scenario', 1300, 900);
    for r = 1:nROI
        for m = 1:3
            subplot(nROI, 3, (r-1)*3 + m); hold on;
            for b = 1:nBands
                D = reshape(fields{m}(b, r, :, :, :, :), nSubj, nScn, nRep, nPt);
                [mn, sd] = summarize(subj_by(D, 2), minN);
                draw_curve(1:nScn, mn, sd, COL_BAND(b,:), 'o-');
            end
            xlim([0.5 nScn+0.5]); xticks(1:nScn);
            xticklabels(arrayfun(@(x) sprintf('Sc%d', x), 1:nScn, 'UniformOutput', false));
            grid on; box on;
            if r == 1
                title(metrics{m}, 'FontSize', 11, 'FontWeight', 'bold');
                if m == 3, legend({BANDS.name}, 'Location', 'best', 'FontSize', 7); end
            end
            if m == 1, ylabel(roi_names{r}, 'FontSize', 10, 'FontWeight', 'bold'); end
            if r == nROI, xlabel('Scenario', 'FontSize', 9); end
        end
    end
    sgtitle('Residents - Beta vs Alpha by scenario (mean \pm SD across subjects)', 'FontSize', 13);
    if saveFigs, saveas(fig, fullfile(figDir, 'IR_Beta_vs_Alpha_by_scenario.png')); end
end

function M = subj_by(D, keep)
    % D = [subj x scenario x rep x point]; average over every dimension except 'keep'
    dims = setdiff(2:4, keep);
    M = reshape(mean(D, dims, 'omitnan'), size(D,1), size(D,keep));   % [subj x n]
end

function [mn, sd, n] = summarize(M, minN)
    n  = sum(~isnan(M), 1);
    mn = mean(M, 1, 'omitnan');
    sd = std(M, 0, 1, 'omitnan');
    bad = n < minN;
    mn(bad) = NaN;  sd(bad) = NaN;
end

function draw_curve(x, mn, sd, col, mk)
    ok = ~isnan(mn);
    if ~any(ok), return; end
    xv = x(ok);  m = mn(ok);  s = sd(ok);  s(isnan(s)) = 0;
    fill([xv fliplr(xv)], [m+s fliplr(m-s)], col, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(xv, m, mk, 'LineWidth', 2.0, 'Color', col);
end


%% ---------------------------------------------------------------------
%  Plotting: rows = ROI, columns = ERD | ERS | Modulation, one figure per band.
%  Thin grey lines = single residents, coloured = mean +/- SD across residents
%  (drawn where at least minN residents have a value).
%% ---------------------------------------------------------------------
function plot_last3(ERD, ERS, Mod, ERDp, ERSp, Modp, roi_names, BANDS, saveFigs, figDir, minN)
    metrics = {'ERD', 'ERS', 'Modulation |ERS-ERD|'};
    A  = {ERD, ERS, Mod};          % [band roi subj scenario]
    Ap = {ERDp, ERSp, Modp};       % [band roi subj scenario point]
    nB = size(ERD,1); nR = size(ERD,2); nSubj = size(ERD,3); nSc = size(ERD,4); nPt = size(ERDp,5);
    COL = lines(nR);
    if saveFigs && ~exist(figDir, 'dir'), mkdir(figDir); end

    for b = 1:nB
        for view = 1:2
            fig = claude_figure_right(sprintf('IR Last3 %s %d', BANDS(b).name, view), 1200, 900);
            ylc = nan(3,2);
            for r = 1:nR
                for m = 1:3
                    ax = subplot(nR, 3, (r-1)*3 + m); hold on;
                    if view == 1            % by scenario
                        M = reshape(A{m}(b, r, :, :), nSubj, nSc);
                        x = 1:nSc; lab = arrayfun(@(k) sprintf('Sc%d', k), x, 'UniformOutput', false); mk = 'o-';
                    else                    % by suture point (mean over scenarios)
                        M = reshape(mean(Ap{m}(b, r, :, :, :), 4, 'omitnan'), nSubj, nPt);
                        x = 1:nPt; lab = arrayfun(@(k) sprintf('Pt%d', k), x, 'UniformOutput', false); mk = 's-';
                    end
                    for s = 1:nSubj
                        plot(x, M(s,:), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6);
                    end
                    n  = sum(~isnan(M), 1);
                    mn = mean(M, 1, 'omitnan'); sd = std(M, 0, 1, 'omitnan');
                    bad = n < minN; mn(bad) = NaN; sd(bad) = NaN;
                    ok = ~isnan(mn);
                    if any(ok)
                        xv = x(ok); mv = mn(ok); sv = sd(ok); sv(isnan(sv)) = 0;
                        fill([xv fliplr(xv)], [mv+sv fliplr(mv-sv)], COL(r,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
                        plot(xv, mv, mk, 'LineWidth', 2.2, 'Color', COL(r,:));
                    end
                    xlim([0.5 x(end)+0.5]); xticks(x); xticklabels(lab); grid on; box on;
                    if r == 1, title(metrics{m}, 'FontSize', 11, 'FontWeight', 'bold'); end
                    if m == 1, ylabel(roi_names{r}, 'FontSize', 10, 'FontWeight', 'bold'); end
                    yl = ylim(ax);
                    ylc(m,:) = [min([ylc(m,1) yl(1)], [], 'omitnan'), max([ylc(m,2) yl(2)], [], 'omitnan')];
                end
            end
            for r = 1:nR
                for m = 1:3
                    subplot(nR, 3, (r-1)*3 + m); ylim(ylc(m,:));
                end
            end
            vname = {'by scenario', 'by suture point (mean over scenarios)'};
            sgtitle(sprintf('Residents, 3 successful repetitions - %s (%d-%d Hz): %s', ...
                BANDS(b).name, BANDS(b).fmin, BANDS(b).fmax, vname{view}), 'FontSize', 13);
            if saveFigs
                saveas(fig, fullfile(figDir, sprintf('IR_Last3_%s_%d_newFilt.png', BANDS(b).name, view)));
            end
        end
    end
end
