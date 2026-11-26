% claude_Task_Res_FirstLast_paper.m
% RESIDENTS: the analysis of the paper, with the simple choice of trials.
%   - for each resident and scenario: the FIRST performed trial and the LAST performed trial
%     (performed list = performanceStruct_IR_updated.mat, without the skipped repetitions of the skip list)
%   - ERD, ERS and modulation of those two trials from the matrix (mean of the 4 suture points)
%   - two-way repeated-measures ANOVA  Scenario (6) x Repetition (first, last), one per metric x band x region
%     (claude_residents_rm2way.m): only residents with all six scenarios (a trial without a value is not replaced, that
%     resident is left out), Mauchly's test + Greenhouse-Geisser correction, partial eta^2, Holm post hoc tests
%     between scenario pairs and first vs last within scenario
%   - Holm across the 8 region x band tests of each metric and effect
%   - outlier residents (same rule as the experts: robust z / leave-one-out z on the resident's mean ERS) are
%     removed from the whole analysis
% Plots: mean +/- SD per scenario, first and last side by side. No text on the plots.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % claude_figure_right.m, claude_holm_adjust.m, claude_residents_rm2way.m

D = '/home/acatalano/Desktop/Intuitive/DataStructures/';
REMOVE_OUTLIERS = true;   ROBUST_Z = 3.5;   LOO_Z = 3;
INCLUDE_JOINED_MOTOR = false;   SAVE_FIGS = false;

R = load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);   % ERD_6d, ERS_6d, Mod_6d: [band x ROI x resident x scenario x rep x point]
T = load([D 'GraspERD_Times_IR.mat']);                 % RepStatus == 1: skip list
P = load([D 'performanceStruct_IR_updated.mat']);      % performed trials
subjects = R.subjects;   roi_names = R.roi_names;   BANDS = R.BANDS;
sz = size(R.ERS_6d);   nB = sz(1);   nS = sz(3);   NS = sz(4);   NRp = sz(5);

%% first and last performed trial of each resident and scenario
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

%% regions, metrics, outliers
regions = {1, 2, 3, 4};   regNames = roi_names(:)';
if INCLUDE_JOINED_MOTOR, regions{end+1} = [1 2];   regNames{end+1} = 'Motor (L+R)'; end
nReg = numel(regions);
mdata = {R.ERD_6d, R.ERS_6d, R.Mod_6d};   mname = {'ERD', 'ERS', 'Modulation'};
out = false(nS, 1);
if REMOVE_OUTLIERS
    for b = 1:nB
        for r = 1:nReg
            v = mean(reshape(squeeze(mean(R.ERS_6d(b, regions{r}, :, :, :, :), 2)), nS, []), 2, 'omitnan');
            out = out | abs(robust_z(v)) > ROBUST_Z | abs(loo_z(v)) > LOO_Z;
        end
    end
end
fprintf('Outlier residents removed from everything: %s\n', ternary(any(out), strjoin(subjects(out), ', '), 'none'));

%% two-way rmANOVA per metric x band x region
PU = nan(nB, nReg, 3, 3);   NN = nan(nB, nReg, 3);          % p used per effect, n
for m = 1:3
    for b = 1:nB
        f = claude_figure_right(sprintf('rmANOVA %s - %s', mname{m}, BANDS(b).name), 1100, 800);   set(f, 'Color', 'w');
        for r = 1:nReg
            X = squeeze(mean(mdata{m}(b, regions{r}, :, :, :, :), 2));     % [resident x scenario x rep x point]
            Xrep = mean(X, 4, 'omitnan');                                    % one value per trial
            subjV = {};   scnV = [];   repV = {};   valV = [];
            for s = 1:nS
                if out(s), continue; end
                for sc = 1:NS
                    vals = [NaN NaN];
                    if ~isnan(first(s, sc)), vals = [Xrep(s, sc, first(s, sc)), Xrep(s, sc, last(s, sc))]; end
                    subjV = [subjV; repmat(subjects(s), 2, 1)];  scnV = [scnV; sc; sc];  repV = [repV; {'first'; 'last'}];  valV = [valV; vals(:)]; %#ok<AGROW>
                end
            end
            Tl  = table(subjV, scnV, repV, valV, 'VariableNames', {'subject', 'scenario', 'rep', 'value'});
            ax  = subplot(ceil(nReg/2), 2, r);
            res = claude_residents_rm2way(Tl, sprintf('%s | %s %s', mname{m}, BANDS(b).name, regNames{r}), ax);
            ylabel(ax, mname{m});
            if r == 1, legend(ax, {'First trial', 'Last trial'}, 'Location', 'best'); end
            NN(b, r, m) = res.n;
            for e = 1:numel(res.eff), PU(b, r, m, e) = res.eff(e).pUse; end
        end
        sgtitle(sprintf('Residents, %s %s: first vs last performed trial by scenario (mean +/- SD, residents with all 6 scenarios)', mname{m}, BANDS(b).name));
        if SAVE_FIGS, print(f, [D 'Figures_IR_FirstLast/' sprintf('IR_paper_%s_%s.png', mname{m}, BANDS(b).name)], '-dpng', '-r110'); end
    end
end

%% Holm across the region x band tests of each metric and effect
effNames = {'Scenario', 'Repetition', 'Scenario x Repetition'};
fprintf('\n=== p (Greenhouse-Geisser when Mauchly is significant) and Holm p across the %d region x band tests of each metric ===\n', nB*nReg);
for m = 1:3
    for e = 1:3
        pv = reshape(PU(:, :, m, e), [], 1);   padj = reshape(claude_holm_adjust(pv), nB, nReg);
        fprintf('\n--- %s | effect: %s ---\n', mname{m}, effNames{e});
        for b = 1:nB
            for r = 1:nReg
                fprintf('%-5s %-12s n=%2d | p=%.4f | p(Holm)=%.4f\n', BANDS(b).name, regNames{r}, NN(b,r,m), PU(b,r,m,e), padj(b,r));
            end
        end
    end
end


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
