% claude_Task_Res_FirstLast_simple.m
% RESIDENTS, simple version. For each scenario:
%   - for each resident take the FIRST performed trial and the LAST performed trial of that scenario
%     (performed list = performanceStruct_IR_updated.mat, without the skipped repetitions of the skip list)
%   - read ERD, ERS and modulation of those two trials from the matrix (mean of the 4 suture points)
%   - compare first vs last across residents (paired), then go to the next scenario
% A trial without a value (no needle data) is NOT replaced: that resident is simply left out of that comparison.
% Test as in the paper: Shapiro-Wilk on the paired differences -> paired t-test or Wilcoxon signed-rank.
% Holm correction across the 6 scenarios (for each metric x band x region).
% Outlier residents (same rule as for the experts: robust z / leave-one-out z on the resident's mean ERS) are
% removed from the whole analysis.
% Output: console grid, DataStructures/IR_first_last_simple.csv (every test), errorbar plots (mean +/- SD).

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % claude_figure_right.m, claude_shapiro_wilk.m, claude_holm_adjust.m, claude_paired_first_last.m

D = '/home/acatalano/Desktop/Intuitive/DataStructures/';
REMOVE_OUTLIERS = true;   ROBUST_Z = 3.5;   LOO_Z = 3;
INCLUDE_JOINED_MOTOR = false;   ALPHA = 0.05;   MIN_N = 3;   SAVE_FIGS = true;

R = load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);   % ERD_6d, ERS_6d, Mod_6d: [band x ROI x resident x scenario x rep x point]
T = load([D 'GraspERD_Times_IR.mat']);                 % RepStatus == 1: skip list
P = load([D 'performanceStruct_IR_updated.mat']);      % performed trials
subjects = R.subjects;   roi_names = R.roi_names;   BANDS = R.BANDS;
sz = size(R.ERS_6d);   nB = sz(1);   nS = sz(3);   NS = sz(4);   NRp = sz(5);

%% performed list -> first and last performed trial of each resident and scenario
performed = false(nS, NS, NRp);
for g = 1:numel(P.GlobalData)
    s = find(strcmp(subjects, strtok(P.GlobalData(g).ID, '_')));
    if isempty(s), continue; end
    for k = 1:numel(P.GlobalData(g).Scenarios)
        ids = [P.GlobalData(g).Scenarios(k).Trials.TrialID];
        performed(s, P.GlobalData(g).Scenarios(k).ScenarioID, ids(ids >= 1 & ids <= NRp)) = true;
    end
end
performed = performed & (T.RepStatus ~= 1);
first = nan(nS, NS);   last = nan(nS, NS);
for s = 1:nS
    for sc = 1:NS
        v = find(squeeze(performed(s, sc, :)));
        if numel(v) >= 2, first(s, sc) = v(1);   last(s, sc) = v(end); end
    end
end

%% regions, metrics
regions = {1, 2, 3, 4};   regNames = roi_names(:)';
if INCLUDE_JOINED_MOTOR, regions{end+1} = [1 2];   regNames{end+1} = 'Motor (L+R)'; end
nReg = numel(regions);
mdata = {R.ERD_6d, R.ERS_6d, R.Mod_6d};   mname = {'ERD', 'ERS', 'Modulation'};

%% outlier residents (removed from the whole analysis)
out = false(nS, 1);
if REMOVE_OUTLIERS
    for b = 1:nB
        for r = 1:nReg
            v = mean(reshape(squeeze(mean(R.ERS_6d(b, regions{r}, :, :, :, :), 2)), nS, []), 2, 'omitnan');   % resident mean ERS
            out = out | abs(robust_z(v)) > ROBUST_Z | abs(loo_z(v)) > LOO_Z;
        end
    end
    fprintf('Outlier residents removed from everything: %s\n', ternary(any(out), strjoin(subjects(out), ', '), 'none'));
end

%% first vs last, scenario by scenario
rows = {};   cF = [0.40 0.60 0.90];   cL = [0.00 0.20 0.60];
for m = 1:3
    fprintf('\n=== %s: last vs first trial of each scenario. Entry = sign of the change (last - first) and raw p; * = Holm p < 0.05 over the 6 scenarios ===\n', mname{m});
    fprintf('%-5s %-12s', '', ''); fprintf(' %9s', 'Sc1', 'Sc2', 'Sc3', 'Sc4', 'Sc5', 'Sc6'); fprintf('\n');
    for b = 1:nB
        f = claude_figure_right(sprintf('%s %s first vs last', mname{m}, BANDS(b).name), 1000, 230*ceil(nReg/2)+60);   set(f, 'Color', 'w');
        for r = 1:nReg
            X    = squeeze(mean(mdata{m}(b, regions{r}, :, :, :, :), 2));     % [resident x scenario x rep x point]
            Xrep = mean(X, 4, 'omitnan');                                      % one value per trial
            Q    = cell(1, NS);   p = nan(1, NS);
            for sc = 1:NS
                Fv = nan(nS, 1);   Lv = nan(nS, 1);
                for s = 1:nS
                    if ~isnan(first(s, sc)) && ~out(s), Fv(s) = Xrep(s, sc, first(s, sc));   Lv(s) = Xrep(s, sc, last(s, sc)); end
                end
                Q{sc} = claude_paired_first_last(Fv, Lv, ALPHA);   p(sc) = Q{sc}.p;
            end
            padj = claude_holm_adjust(p(:))';
            fprintf('%-5s %-12s', BANDS(b).name, regNames{r});
            for sc = 1:NS
                if isnan(p(sc)), fprintf(' %9s', 'n/a'); continue; end
                sgn = ternary(Q{sc}.mLast >= Q{sc}.mFirst, '+', '-');
                fprintf(' %9s', sprintf('%s%.3f%s', sgn, p(sc), ternary(padj(sc) < 0.05, '*', ' ')));
                rows(end+1, :) = {mname{m}, BANDS(b).name, regNames{r}, sc, Q{sc}.n, Q{sc}.mFirst, Q{sc}.sdFirst, Q{sc}.mLast, Q{sc}.sdLast, ...
                    Q{sc}.swP, Q{sc}.test, p(sc), padj(sc)}; %#ok<AGROW>
            end
            fprintf('\n');
            % errorbar plot: mean +/- SD per scenario, first and last side by side
            subplot(ceil(nReg/2), 2, r); hold on;
            n  = cellfun(@(q) q.n, Q);   ok = n >= MIN_N;
            mF = cellfun(@(q) q.mFirst, Q);   sF = cellfun(@(q) q.sdFirst, Q);   mL = cellfun(@(q) q.mLast, Q);   sL = cellfun(@(q) q.sdLast, Q);
            mF(~ok) = NaN;   sF(~ok) = NaN;   mL(~ok) = NaN;   sL(~ok) = NaN;
            h1 = errorbar((1:NS) - 0.07, mF, sF, 'o-', 'Color', cF, 'MarkerFaceColor', cF, 'LineWidth', 1.6, 'CapSize', 8);
            h2 = errorbar((1:NS) + 0.07, mL, sL, 's-', 'Color', cL, 'MarkerFaceColor', cL, 'LineWidth', 1.6, 'CapSize', 8);
            xlim([0.5 NS+0.5]); xticks(1:NS); grid on; box on; xlabel('Scenario'); ylabel(mname{m}); title(regNames{r});
            if r == 1, legend([h1 h2], {'First trial', 'Last trial'}, 'Location', 'best'); end
        end
        sgtitle(sprintf('Residents, %s %s: first vs last performed trial of each scenario (mean +/- SD over residents)', mname{m}, BANDS(b).name));
        if SAVE_FIGS, print(f, [D 'Figures_IR_FirstLast/' sprintf('IR_simple_%s_%s.png', mname{m}, BANDS(b).name)], '-dpng', '-r110'); end
    end
end

Tout = cell2table(rows, 'VariableNames', {'metric', 'band', 'region', 'scenario', 'n', 'meanFirst', 'sdFirst', 'meanLast', 'sdLast', 'shapiroP', 'test', 'p', 'pHolm'});
writetable(Tout, [D 'IR_first_last_simple.csv']);
fprintf('\nAll tests (n, mean +- SD, test, p, Holm p) saved to %sIR_first_last_simple.csv\n', D);
fprintf('n per comparison ranges from %d to %d residents.\n', min(Tout.n), max(Tout.n));


%% ---------------------------------------------------------------------
function z = robust_z(x)
    md = median(x, 'omitnan');   s = median(abs(x - md), 'omitnan');
    if s == 0, z = zeros(size(x)); else, z = 0.6745 * (x - md) / s; end
end

function z = loo_z(x)
    n = numel(x);   z = nan(n, 1);
    for i = 1:n
        o = x([1:i-1, i+1:n]);   z(i) = (x(i) - mean(o, 'omitnan')) / std(o, 'omitnan');
    end
end

function o = ternary(c, x, y)
    if c, o = x; else, o = y; end
end
