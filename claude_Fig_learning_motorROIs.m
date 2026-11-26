% claude_Fig_learning_motorROIs.m
% Same figure as "Fig 2: Learning and within-suture behaviour" of claude_figs.m
% (ERS and modulation: experts per repetition, residents/experts per scenario and
% per suture point), but for
%     1) MotorLeft   2) MotorRight   3) Motor = mean of the two ROIs
% so that the two motor areas can be checked separately and then joined.
%
% Joined motor area = average of the left and right ROI values of the same slot
% (ERS_motor = (ERS_left + ERS_right)/2, same for ERD and modulation, which is linear).
% This is an average of the two ROI METRICS. It is not the same as taking the
% maximum of the power pooled over the 6 channels; if you want that, ERD/ERS have
% to be recomputed with a 6-channel ROI in both ERD/ERS scripts.
%
% Per-area figures: mean +/- ERR over subjects (ERR_TYPE below), as in claude_figs.m.
% Overlay figure: the three areas on the same axes (means only, to keep it readable).
%
% Data: experts Task 2 (20 repetitions), experts Task 1 (6 scenarios once), residents.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % claude_figure_right.m

BANDS_TO_RUN = 1;          % 1 = Beta, 2 = Alpha, [1 2] = both
ERR_TYPE     = 'sem';      % 'sem' (as in claude_figs.m) or 'sd' (as in the expert scripts)
SAVE_FIGS    = true;
D   = '/home/acatalano/Desktop/Intuitive/DataStructures/';
OUT = [D 'Figures_motor_ROIs/'];
if SAVE_FIGS && ~exist(OUT, 'dir'), mkdir(OUT); end

E2 = load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');          % experts Task 2
T1 = load('/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG/ERD_ERS_Modulation_Task1_ROI_bands.mat'); % experts Task 1
% ORIGINAL (common reference): R  = load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);
R  = load([D 'ERD_ERS_Modulation_IR_ROI_bands_avgref.mat']);                                                          % residents

cE = [0.15 0.35 0.7];   cR = [0.85 0.4 0.1];                 % experts / residents (as in claude_figs.m)
area_names = {'MotorLeft', 'MotorRight', 'Motor (left+right mean)'};
area_cols  = [0.10 0.40 0.80; 0.80 0.20 0.20; 0.10 0.10 0.10];
bnm = {'Beta', 'Alpha'};

nE2 = size(E2.ERS_all, 3);   nT1 = size(T1.ERS_all, 3);   nR = size(R.ERS_all, 3);   % subjects per group
if strcmp(ERR_TYPE, 'sem')
    errf = @(A) std(A, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(A), 1));  errlab = 'SEM';
else
    errf = @(A) std(A, 0, 1, 'omitnan');                              errlab = 'SD';
end

% aggregators ([subject x 4*...] slot matrices -> subject x something)
exp_rep = @(A) squeeze(mean(reshape(A, nE2, 4, 20), 2, 'omitnan'));                          % experts Task 2: subj x rep
exp_pt  = @(A) squeeze(mean(reshape(A, nE2, 4, 20), 3, 'omitnan'));                          % experts Task 2: subj x point
exp_sc  = @(A) squeeze(mean(reshape(A, nT1, 4, 6),  2, 'omitnan'));                          % experts Task 1: subj x scenario
res_sc  = @(A) squeeze(mean(mean(reshape(A, nR, 4, 10, 6), 2, 'omitnan'), 3, 'omitnan'));    % residents: subj x scenario
res_pt  = @(A) squeeze(mean(mean(reshape(A, nR, 4, 10, 6), 3, 'omitnan'), 4, 'omitnan'));    % residents: subj x point

mets = {'ERS', 'Mod'};   metlab = {'ERS', 'Modulation'};

for b = BANDS_TO_RUN
    % ---- one figure per area (same layout as Fig 2 of claude_figs.m) ----
    for a = 1:3
        f = claude_figure_right(sprintf('Learning %s %s', bnm{b}, area_names{a}), 1400, 700);  set(f, 'Color', 'w');
        for m = 1:2
            eRep = exp_rep(area_slice(E2.([mets{m} '_all']), b, a));
            eSc  = exp_sc (area_slice(T1.([mets{m} '_all']), b, a));
            ePt  = exp_pt (area_slice(E2.([mets{m} '_all']), b, a));
            rSc  = res_sc (area_slice(R.([mets{m} '_all']),  b, a));
            rPt  = res_pt (area_slice(R.([mets{m} '_all']),  b, a));

            subplot(2, 3, (m-1)*3 + 1); hold on;
            errorbar(1:20, mean(eRep, 1, 'omitnan'), errf(eRep), '-o', 'Color', cE, 'LineWidth', 1.4);
            title(sprintf('Experts: %s %s, %s, per repetition', metlab{m}, lower(bnm{b}), area_names{a}));
            xlabel('Repetition'); ylabel(metlab{m}); xlim([0.5 20.5]); grid on;

            subplot(2, 3, (m-1)*3 + 2); hold on;
            h1 = errorbar(1:6, mean(rSc, 1, 'omitnan'), errf(rSc), '-o', 'Color', cR, 'LineWidth', 1.4);
            h2 = errorbar(1:6, mean(eSc, 1, 'omitnan'), errf(eSc), '--s', 'Color', cE, 'LineWidth', 1.4);
            title(sprintf('%s %s, %s, per scenario', metlab{m}, lower(bnm{b}), area_names{a}));
            xlabel('Scenario'); xticks(1:6); xlim([0.5 6.5]); grid on;
            if m == 1, legend([h1 h2], {'Residents (all reps)', 'Experts, Task 1 (6 scenarios, once)'}, 'Location', 'best'); end

            subplot(2, 3, (m-1)*3 + 3); hold on;
            h1 = errorbar(1:4, mean(rPt, 1, 'omitnan'), errf(rPt), '-o', 'Color', cR, 'LineWidth', 1.4);
            h2 = errorbar(1:4, mean(ePt, 1, 'omitnan'), errf(ePt), '--s', 'Color', cE, 'LineWidth', 1.4);
            title(sprintf('%s %s, %s, per suture point', metlab{m}, lower(bnm{b}), area_names{a}));
            xlabel('Suture point'); xticks(1:4); xlim([0.5 4.5]); grid on;
            if m == 1, legend([h1 h2], {'Residents', 'Experts (Task 2)'}, 'Location', 'best'); end
        end
        sgtitle(sprintf('Learning and within-suture behaviour, %s: %s (mean +- %s over subjects)', ...
            bnm{b}, area_names{a}, errlab));
        if SAVE_FIGS, print(f, [OUT sprintf('fig2_learning_%s_%s.png', bnm{b}, strtok(area_names{a}, ' '))], '-dpng', '-r110'); end
    end

    % ---- overlay: the three areas on the same axes ----
    f = claude_figure_right(sprintf('Learning %s overlay', bnm{b}), 1400, 700);  set(f, 'Color', 'w');
    for m = 1:2
        for a = 1:3
            col = area_cols(a,:);  lw = 1.4 + 0.8*(a == 3);
            eRep = exp_rep(area_slice(E2.([mets{m} '_all']), b, a));
            eSc  = exp_sc (area_slice(T1.([mets{m} '_all']), b, a));
            ePt  = exp_pt (area_slice(E2.([mets{m} '_all']), b, a));
            rSc  = res_sc (area_slice(R.([mets{m} '_all']),  b, a));
            rPt  = res_pt (area_slice(R.([mets{m} '_all']),  b, a));

            subplot(2, 3, (m-1)*3 + 1); hold on;
            hh(a) = plot(1:20, mean(eRep, 1, 'omitnan'), '-o', 'Color', col, 'LineWidth', lw, 'MarkerSize', 4);
            subplot(2, 3, (m-1)*3 + 2); hold on;
            plot(1:6, mean(rSc, 1, 'omitnan'), '-o', 'Color', col, 'LineWidth', lw, 'MarkerSize', 4);
            plot(1:6, mean(eSc, 1, 'omitnan'), '--s', 'Color', col, 'LineWidth', lw, 'MarkerSize', 4);
            subplot(2, 3, (m-1)*3 + 3); hold on;
            plot(1:4, mean(rPt, 1, 'omitnan'), '-o', 'Color', col, 'LineWidth', lw, 'MarkerSize', 4);
            plot(1:4, mean(ePt, 1, 'omitnan'), '--s', 'Color', col, 'LineWidth', lw, 'MarkerSize', 4);
        end
        subplot(2, 3, (m-1)*3 + 1); title(sprintf('Experts: %s %s, per repetition', metlab{m}, lower(bnm{b})));
        xlabel('Repetition'); ylabel(metlab{m}); xlim([0.5 20.5]); grid on;
        if m == 1, legend(hh, area_names, 'Location', 'best'); end
        subplot(2, 3, (m-1)*3 + 2); title(sprintf('%s %s, per scenario (solid residents, dashed experts Task 1)', metlab{m}, lower(bnm{b})));
        xlabel('Scenario'); xticks(1:6); xlim([0.5 6.5]); grid on;
        subplot(2, 3, (m-1)*3 + 3); title(sprintf('%s %s, per suture point (solid residents, dashed experts)', metlab{m}, lower(bnm{b})));
        xlabel('Suture point'); xticks(1:4); xlim([0.5 4.5]); grid on;
    end
    sgtitle(sprintf('Left vs right vs joined motor area, %s (group means over subjects)', bnm{b}));
    if SAVE_FIGS, print(f, [OUT sprintf('fig2_learning_%s_overlay.png', bnm{b})], '-dpng', '-r110'); end

    % ---- left vs right: are the two areas telling the same story? ----
    fprintf('\n=== %s: agreement between MotorLeft and MotorRight (subject x slot values) ===\n', bnm{b});
    for m = 1:2
        for g = 1:2
            if g == 1, S = E2; gl = 'experts  (Task 2)'; else, S = R; gl = 'residents        '; end
            L = area_slice(S.([mets{m} '_all']), b, 1);   Rr = area_slice(S.([mets{m} '_all']), b, 2);
            ok = ~isnan(L(:)) & ~isnan(Rr(:));
            fprintf('%-10s %s  corr(left,right) over %4d slots = %.2f | mean left %.3f, mean right %.3f\n', ...
                metlab{m}, gl, nnz(ok), corr(L(ok), Rr(ok), 'Type', 'Spearman'), mean(L(ok)), mean(Rr(ok)));
        end
    end
end


%% ---------------------------------------------------------------------
function A = area_slice(X, b, a)
    % X = [band x ROI x subject x slot] -> [subject x slot] for area a:
    % 1 = MotorLeft, 2 = MotorRight, 3 = mean of the two (same slot, NaN if either is NaN)
    if a <= 2
        A = squeeze(X(b, a, :, :));
    else
        A = (squeeze(X(b, 1, :, :)) + squeeze(X(b, 2, :, :))) / 2;
    end
end
