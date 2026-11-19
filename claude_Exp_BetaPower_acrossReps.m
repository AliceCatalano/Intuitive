% claude_Exp_BetaPower_acrossReps.m
% =====================================================================================================
% EXPERTS: BETA POWER ACROSS REPETITIONS.
%   left panel  = Task 1: x = the 6 scenarios (one repetition each)
%   right panel = Task 2: x = the 20 repetitions of the same scenario
%   y           = normalised beta power (band range BETA, default 15-30 Hz)
%   dots        = one dot per expert and repetition (each expert has his own colour and his own small
%                 horizontal position inside the repetition, so you can follow him from one repetition to the next)
%   black       = mean +/- SD over the experts that have a value in that repetition
%
% HOW ONE DOT IS BUILT
%   data = normalised power (pow - mean)/mean of Task*_norm_<event>_allExp.mat, powspctrm = [slot x channel x freq x time],
%   slot = (repetition - 1) * 4 + point.
%   value of a slot = mean over the chosen channels, the beta frequencies and the time window of the event
%   value of a repetition = mean over its 4 points; needs at least MIN_POINTS points with data, otherwise no dot
%
% STEPS: 1 settings, 2 compute the values (function band_values at the end), 3 print n per repetition, 4 plot
% =====================================================================================================

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));      % claude_figure_right.m

%% 1. SETTINGS (change here) ---------------------------------------------------------------------------
alpha       = [8 15];     % Hz, band limits
EVENT      = 'exit';      % 'exit'  = exit-locked (ERS), window -2 to 0 s   |   'grasp' = grasp-locked (ERD), window -0.5 to 1 s
CHAN       = 'Motor';     % 'Motor' (left + right motor ROI) | 'MotorLeft' | 'MotorRight' | 'Visual' | 'Frontal' | 'All' (all channels)
MIN_POINTS = 2;           % points (out of 4) needed to accept a repetition
SHOW_LINES = false;       % true: join the dots of the same expert with a thin line
SAVE_FIGS  = true;

ROI.MotorLeft  = [15 20 10];   ROI.MotorRight = [13 19 9];   ROI.Visual = [29 30 31];   ROI.Frontal = [4 5 6];   % same as Task12_Exp_ERD_ERS_ROI.m
ROI.Motor      = [ROI.MotorLeft ROI.MotorRight];
if strcmp(EVENT, 'exit'), win = [-2.0 0.0]; else, win = [-0.5 1.0]; end
if strcmp(CHAN, 'All'), chIdx = []; else, chIdx = ROI.(CHAN); end                 % [] = all channels

tasks(1).name = 'Task 1';  tasks(1).file = ['/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG/Task1_norm_' EVENT '_allExp.mat'];  tasks(1).xlabel = 'Scenario';
tasks(2).name = 'Task 2';  tasks(2).file = ['/home/acatalano/Desktop/Intuitive/IE_Task/Task2/Task2_norm_' EVENT '_allExp.mat'];                tasks(2).xlabel = 'Repetition';
fig_dir = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_Exp_alphaAcrossReps';
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

%% 2. COMPUTE ------------------------------------------------------------------------------------------
for k = 1:numel(tasks)
    fprintf('\n##### %s: %s #####\n', tasks(k).name, tasks(k).file);
    [tasks(k).Y, tasks(k).subjects] = band_values(tasks(k).file, alpha, win, chIdx, MIN_POINTS);   % Y = [expert x repetition]
end

%% 3. PRINT n PER REPETITION ---------------------------------------------------------------------------
for k = 1:numel(tasks)
    Y = tasks(k).Y;
    fprintf('\n%s: experts with a value in each repetition (of %d experts)\n', tasks(k).name, size(Y, 1));
    fprintf('%-5s', 'rep');  fprintf('%4d', 1:size(Y, 2));  fprintf('\n');
    fprintf('%-5s', 'n');    fprintf('%4d', sum(~isnan(Y), 1));  fprintf('\n');
    fprintf('%-5s', 'mean'); fprintf('%6.2f', mean(Y, 1, 'omitnan'));  fprintf('\n');
    for s = 1:size(Y, 1)
        miss = find(isnan(Y(s, :)));
        if ~isempty(miss), fprintf('  %s has no value in repetition(s): %s\n', tasks(k).subjects{s}, mat2str(miss)); end
    end
end

%% 4. PLOT ---------------------------------------------------------------------------------------------
allSubj = unique([tasks(1).subjects(:); tasks(2).subjects(:)], 'stable');
colS    = lines(numel(allSubj));                         % one colour per expert, the same in both panels
nRep1 = size(tasks(1).Y, 2);   nRep2 = size(tasks(2).Y, 2);

f = claude_figure_right(sprintf('Experts alpha power across repetitions (%s, %s)', EVENT, CHAN), 1700, 650);   set(f, 'Color', 'w');
ax(1) = subplot(1, 4, 1);   ax(2) = subplot(1, 4, 2:4);
for k = 1:numel(tasks)
    axes(ax(k)); hold on; %#ok<LAXES>
    Y = tasks(k).Y;   nS = size(Y, 1);   nR = size(Y, 2);
    offs = linspace(-0.28, 0.28, nS);                    % each expert has his own lane inside a repetition
    h = gobjects(nS, 1);
    for s = 1:nS
        c = colS(strcmp(allSubj, tasks(k).subjects{s}), :);
        x = (1:nR) + offs(s);
        if SHOW_LINES, plot(x, Y(s, :), '-', 'Color', [c 0.35], 'LineWidth', 0.8); end
        h(s) = scatter(x, Y(s, :), 30, c, 'filled', 'MarkerFaceAlpha', 0.65, 'MarkerEdgeColor', 'none');
    end
    mu = mean(Y, 1, 'omitnan');   sd = std(Y, 0, 1, 'omitnan');
    errorbar(1:nR, mu, sd, 'o', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'LineWidth', 1.8, 'CapSize', 10);   % mean +/- SD on top
    xlim([0.4 nR + 0.6]);   xticks(1:nR);   grid on;   box on;   xlabel(tasks(k).xlabel);
    if k == 1, ylabel(sprintf('Normalised alpha power (%d-%d Hz)', alpha(1), alpha(2))); end
    title(sprintf('%s (%d experts)', tasks(k).name, nS), 'FontSize', 12);
    if k == 2, legend(h, tasks(k).subjects, 'Location', 'eastoutside'); end
end
yl = [min(arrayfun(@(a) a.YLim(1), ax)), max(arrayfun(@(a) a.YLim(2), ax))];   set(ax, 'YLim', yl);   % same y axis in both panels
sgtitle(sprintf('Experts - alpha power (%d-%d Hz), %s-locked, channels: %s, window %g to %g s (dots = experts, black = mean +/- SD)', ...
    alpha(1), alpha(2), EVENT, CHAN, win(1), win(2)));
if SAVE_FIGS, print(f, fullfile(fig_dir, sprintf('Exp_alpha_acrossReps_%s_%s.png', EVENT, CHAN)), '-dpng', '-r110'); end


%% ---------------------------------------------------------------------
function [Y, subjects] = band_values(file, alpha, win, chIdx, MIN_POINTS)
% Returns Y = [expert x repetition]: mean alpha power of every repetition (mean of its 4 points).
    NUM_POINTS = 4;   TOL = 1e-6;
    S = load(file);   fn = fieldnames(S);   allTF = S.(fn{1});   subjects = S.subjects;
    nSubj = numel(allTF);   nRep = size(allTF{1}.powspctrm, 1) / NUM_POINTS;      % 24 slots -> 6, 80 slots -> 20
    fprintf('%d experts, %d repetitions (%d slots), window %g to %g s, alpha %d-%d Hz\n', nSubj, nRep, nRep * NUM_POINTS, win(1), win(2), alpha(1), alpha(2));
    Y = nan(nSubj, nRep);
    for s = 1:nSubj
        tf = allTF{s};   pw = tf.powspctrm;                                       % [slot x chan x freq x time]
        ch   = chIdx;   if isempty(ch), ch = 1:size(pw, 2); end
        fIdx = find(tf.freq >= alpha(1) - TOL & tf.freq <= alpha(2) + TOL);
        tIdx = find(tf.time >= win(1) - TOL & tf.time <= win(2) + TOL);
        slotVal = squeeze(mean(pw(:, ch, fIdx, tIdx), [2 3 4], 'omitnan'));      % one value per slot
        slotVal = reshape(slotVal(:), NUM_POINTS, []);                            % [4 points x repetitions]
        v = mean(slotVal, 1, 'omitnan');
        v(sum(~isnan(slotVal), 1) < MIN_POINTS) = NaN;                            % too few points -> no value
        Y(s, 1:numel(v)) = v;
    end
end
