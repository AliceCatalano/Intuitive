% claude_Task_Res_ERDERS_ROI.m
% RESIDENTS (IR): beta and alpha ERD, ERS and modulation per ROI and slot.
% Same definitions as the experts (Task12_Exp_ERD_ERS_ROI.m):
%   ROIs (channel indices in the reference order, as for the experts):
%       MotorLeft [15 20 10] | MotorRight [13 19 9] | Visual [29 30 31] | Frontal [4 5 6]
%   Bands: Beta 15-25 Hz | Alpha 8-15 Hz   (the experts' "high alpha" band)
%   ERD  : grasp-locked epoch, ROI-mean band power, MINIMUM over time in [-0.5, 1.0] s
%   ERS  : exit-locked epoch , ROI-mean band power, MAXIMUM over time in [-2.0, 0.0] s
%   Modulation = |ERS - ERD|  (only where both exist for the same slot)
%
% Slots: 240 = 6 scenarios x 10 repetitions x 4 points,
%        slot = (scenario-1)*40 + (rep-1)*4 + point  (see claude_Task_Res_FieldtripERDERS.m)
% Slots without an epoch are NaN and stay NaN (skipped / missing / not completed).
%
% Input : <subj>_IR_graspERD_TFR.mat , <subj>_IR_exitERS_TFR.mat  (claude_Task_Res_TFR.m)
% Output: ERD_ERS_Modulation_IR_ROI_bands.mat
%         ERD_all, ERS_all, Mod_all  [nBands x nROI x nSubj x 240]
%         and the same reshaped as [nBands x nROI x nSubj x 6 x 10 x 4]
%         (scenario, repetition, point)

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % so claude_figure_right.m is found

base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat';
fig_dir    = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ERDERS';

MAKE_PLOTS = true;    % plot after the calculation
SAVE_FIGS  = false;   % true: also save every figure as PNG in fig_dir
PLOT_ONLY  = false;   % true: skip the calculation, load out_file and only plot
MIN_N      = 3;       % minimum number of subjects needed to draw a point of a curve

if PLOT_ONLY
    S = load(out_file);
    plot_ERDERS_ROI(S.ERD_6d, S.ERS_6d, S.Mod_6d, S.roi_names, S.BANDS, SAVE_FIGS, fig_dir, MIN_N);
    return;
end

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

ERD_all = nan(nBands, nROI, nSubj, NUM_SLOTS);
ERS_all = nan(nBands, nROI, nSubj, NUM_SLOTS);
Mod_all = nan(nBands, nROI, nSubj, NUM_SLOTS);

for i = 1:nSubj
    subject = subjects{i};
    fprintf('\n=== %s ===\n', subject);

    G = load(fullfile(base_path, sprintf('%s_IR_graspERD_TFR.mat', subject)));
    E = load(fullfile(base_path, sprintf('%s_IR_exitERS_TFR.mat',  subject)));
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

% reshape to [band x ROI x subj x scenario x rep x point]
% (slot = (sc-1)*40 + (rep-1)*4 + pt  ->  point varies fastest)
reshape6 = @(A) permute(reshape(A, nBands, nROI, nSubj, NUM_POINTS, NUM_REPS, NUM_SCENARIOS), [1 2 3 6 5 4]);
ERD_6d = reshape6(ERD_all);
ERS_6d = reshape6(ERS_all);
Mod_6d = reshape6(Mod_all);

save(out_file, 'ERD_all', 'ERS_all', 'Mod_all', 'ERD_6d', 'ERS_6d', 'Mod_6d', ...
    'roi_names', 'BANDS', 'subjects', '-v7.3');
fprintf('\n=== SAVED: %s ===\n', out_file);

if MAKE_PLOTS
    plot_ERDERS_ROI(ERD_6d, ERS_6d, Mod_6d, roi_names, BANDS, SAVE_FIGS, fig_dir, MIN_N);
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
