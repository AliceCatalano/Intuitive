% claude_Task_Res_FirstLast.m
% RESIDENTS: ERS and modulation (beta, alpha; per region) in the FIRST vs the LAST repetition of each scenario,
% analysed as in the paper:
%   - ONE repetition each (no first-3 / last-3): first = repetition 1 of the scenario, last = the last repetition
%     performed (the residents stop when they reach the criterion). Each repetition = mean over its 4 suture points.
%   - FIRST_RULES{1} = 'paper'   : a scenario needs repetition 1 (performed, not skipped, with EEG data); a resident
%                                  without it is not in the ANOVA (the paper excluded residents who could not
%                                  complete the first repetition).
%   - FIRST_RULES{2} = 'fallback': first = the first valid repetition (rep 2 when rep 1 is invalid). SENSITIVITY check.
%   - FIRST_RULES{3} = 'available': first = the EARLIEST repetition that has data for that test and last = the LATEST one
%                                  (always two different repetitions; every scenario has at least 3 repetitions, but the
%                                  EEG value of a given repetition can be missing). Keeps more residents.
%   - Test: two-way repeated-measures ANOVA Scenario (6) x Repetition (first/last) per band x region x metric
%     (claude_residents_rm2way.m): only residents with all six scenarios, Mauchly + Greenhouse-Geisser, partial eta^2,
%     Holm post hoc tests. Holm is also applied across the region x band tests of the same metric and effect.
%   - Outliers: the SAME rule as for the experts (claude_comparisons_ERDS.m, section 5), applied to the resident's mean ERS
%     over all their trials, per region and band: robust z (median/MAD) |z| > 3.5 or leave-one-out z |z| > 3.
%     A flagged resident is removed from the whole analysis (OUTLIER_SCOPE = 'all', default), or only from the
%     region x band where flagged ('test').
%     No repetition is removed.
%
% Also prints WHO is missing from each ANOVA and WHY (repetition skipped, no ERS data, no ERD data).
% Input : ERD_ERS_Modulation_IR_ROI_bands.mat, GraspERD_Times_IR.mat (skip list), performanceStruct_IR_updated.mat
% Plots : mean +/- SD per scenario, first and last repetition side by side (paper rule only). No text on the plots.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % claude_figure_right.m, claude_holm_adjust.m, claude_residents_rm2way.m

D       = '/home/acatalano/Desktop/Intuitive/DataStructures/';
fig_dir = [D 'Figures_IR_FirstLast/'];
FIRST_RULES          = {'available'}; %'paper', 'fallback', 
ROBUST_Z             = 3.5;       % robust z limit (median / MAD), as for the experts
LOO_Z                = 3;         % leave-one-out z limit, as for the experts
OUTLIER_SCOPE        = 'all';     % 'all': a flagged resident is removed from EVERY test (default); 'test': only from the region x band where flagged
INCLUDE_JOINED_MOTOR = false;     % true: add "Motor (L+R)" = mean of left and right as a 5th region
PLOT_RMANOVA         = true;
SAVE_FIGS            = true;

R = load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);     % ERS_6d, Mod_6d: [band x ROI x resident x scenario x rep x point]
T = load([D 'GraspERD_Times_IR.mat']);                   % RepStatus [resident x scenario x rep]: 1 = skip list
P = load([D 'performanceStruct_IR_updated.mat']);        % GlobalData: performed repetitions
subjects  = R.subjects;   roi_names = R.roi_names;   BANDS = R.BANDS;
if ~isequal(subjects(:), T.subjects(:)), error('Subject lists differ between the ERD/ERS file and GraspERD_Times_IR.mat'); end
sz = size(R.ERS_6d);   nB = sz(1);   nROI = sz(2);   nS = sz(3);   NS = sz(4);   NRp = sz(5);
ERS6 = R.ERS_6d;   MOD6 = R.Mod_6d;

%% which repetitions were performed and are not skipped
performed = false(nS, NS, NRp);
for g = 1:numel(P.GlobalData)
    s = find(strcmp(subjects, strtok(P.GlobalData(g).ID, '_')));
    if isempty(s), continue; end
    for k = 1:numel(P.GlobalData(g).Scenarios)
        scn = P.GlobalData(g).Scenarios(k).ScenarioID;
        ids = [P.GlobalData(g).Scenarios(k).Trials.TrialID];
        performed(s, scn, ids(ids >= 1 & ids <= NRp)) = true;
    end
end
valid = performed & (T.RepStatus ~= 1);                  % performed and not in the skip list
lastRep = nan(nS, NS);   firstValid = nan(nS, NS);   rep1ok = false(nS, NS);
for s = 1:nS
    for sc = 1:NS
        v = find(squeeze(valid(s, sc, :)));
        if numel(v) >= 2, lastRep(s, sc) = v(end);   firstValid(s, sc) = v(1); end
        rep1ok(s, sc) = valid(s, sc, 1);
    end
end
firstRepRule.paper    = nan(nS, NS);   firstRepRule.paper(rep1ok & ~isnan(lastRep)) = 1;
firstRepRule.fallback = firstValid;
firstRepRule.available = firstValid;                      % placeholder: chosen per test (needs the data of that test)

%% regions, bands
regions = {1, 2, 3, 4};   regNames = roi_names(:)';
if INCLUDE_JOINED_MOTOR, regions{end+1} = [1 2];   regNames{end+1} = 'Motor (L+R)'; end
nReg  = numel(regions);
mdata = {ERS6, MOD6};   mname = {'ERS', 'Modulation'};

%% outliers: same rule as for the experts, on the resident's mean ERS (all trials), per region x band
FLAG = false(nS, nB, nReg);   ZROB = nan(nS, nB, nReg);   ZLOO = nan(nS, nB, nReg);
for b = 1:nB
    for r = 1:nReg
        X = squeeze(mean(ERS6(b, regions{r}, :, :, :, :), 2));     % [resident x scenario x rep x point]
        v = mean(reshape(X, nS, []), 2, 'omitnan');                 % resident mean ERS
        ZROB(:,b,r) = robust_z(v);   ZLOO(:,b,r) = loo_z(v);
        FLAG(:,b,r) = abs(ZROB(:,b,r)) > ROBUST_Z | abs(ZLOO(:,b,r)) > LOO_Z;
    end
end
if strcmp(OUTLIER_SCOPE, 'all'), FLAG = repmat(any(any(FLAG, 2), 3), [1 nB nReg]); end
fprintf('=== Residents flagged as outliers (resident mean ERS: robust z > %g or leave-one-out z > %g; scope: %s) ===\n', ROBUST_Z, LOO_Z, OUTLIER_SCOPE);
for b = 1:nB
    for r = 1:nReg
        idx = find(FLAG(:,b,r))';
        if isempty(idx), fprintf('%-5s %-12s none\n', BANDS(b).name, regNames{r}); continue; end
        fprintf('%-5s %-12s %s\n', BANDS(b).name, regNames{r}, strjoin(arrayfun(@(i) ...
            sprintf('%s (robust z %+.1f, leave-one-out z %+.1f)', subjects{i}, ZROB(i,b,r), ZLOO(i,b,r)), idx, 'UniformOutput', false), '; '));
    end
end

%% repeated-measures ANOVA per rule x metric x band x region
if SAVE_FIGS && ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
for ru = 1:numel(FIRST_RULES)
    rule = FIRST_RULES{ru};   firstRep = firstRepRule.(rule);
    if strcmp(rule, 'paper')
        fprintf('\n\n################ PAPER RULE: first = repetition 1 ################\n');
    elseif strcmp(rule, 'fallback')
        fprintf('\n\n################ SENSITIVITY: first = first valid repetition (rep 2 when rep 1 is invalid) ################\n');
    else
        fprintf('\n\n################ AVAILABLE RULE: first / last = earliest / latest repetition that has data ################\n');
    end
    PU = nan(nB, nReg, 2, 3);    NN = nan(nB, nReg, 2);               % p used per effect, n per test
    for m = 1:2
        for b = 1:nB
            doPlot = PLOT_RMANOVA && any(strcmp(rule, {'paper', 'available'}));
            if doPlot
                f = claude_figure_right(sprintf('rmANOVA %s - %s (%s rule)', mname{m}, BANDS(b).name, rule), 1100, 800);  set(f, 'Color', 'w');
            end
            for r = 1:nReg
                Xr    = squeeze(mean(mdata{m}(b, regions{r}, :, :, :, :), 2));     % [resident x scenario x rep x point]
                Xrep  = mean(Xr, 4, 'omitnan');                                     % [resident x scenario x rep]
                Xe    = squeeze(mean(ERS6(b, regions{r}, :, :, :, :), 2));
                Erep  = mean(Xe, 4, 'omitnan');                                     % ERS availability per repetition
                subjV = {};   scnV = [];   repV = {};   valV = [];   miss = cell(nS, 1);
                for s = 1:nS
                    if FLAG(s,b,r), continue; end
                    for sc = 1:NS
                        fr = firstRep(s, sc);   lr = lastRep(s, sc);
                        if strcmp(rule, 'available')      % earliest and latest repetition with data for this test
                            av = find(squeeze(valid(s, sc, :)) & ~isnan(squeeze(Xrep(s, sc, :))));
                            if numel(av) >= 2, fr = av(1);   lr = av(end); else, fr = NaN;   lr = NaN; end
                        end
                        vals = [NaN NaN];
                        if ~isnan(fr) && ~isnan(lr), vals = [Xrep(s, sc, fr), Xrep(s, sc, lr)]; end
                        subjV = [subjV; repmat(subjects(s), 2, 1)];  scnV = [scnV; sc; sc];  repV = [repV; {'first'; 'last'}];  valV = [valV; vals(:)]; %#ok<AGROW>
                        % why is a cell missing?
                        if isnan(fr) || isnan(lr)
                            if strcmp(rule, 'paper') && ~rep1ok(s, sc), miss{s}{end+1} = sprintf('Sc%d: repetition 1 skipped/not performed', sc); %#ok<AGROW>
                            elseif strcmp(rule, 'available'), miss{s}{end+1} = sprintf('Sc%d: fewer than 2 repetitions with data', sc); %#ok<AGROW>
                            else, miss{s}{end+1} = sprintf('Sc%d: fewer than 2 valid repetitions', sc); end %#ok<AGROW>
                        else
                            rr2 = [fr lr];
                            for w = 1:2
                                if isnan(vals(w))
                                    if isnan(Erep(s, sc, rr2(w))), why = 'no ERS data (no valid exit event / epoch)';
                                    else, why = 'no ERD data (no grasp event)'; end
                                    miss{s}{end+1} = sprintf('Sc%d %s (rep %d): %s', sc, ternary(w == 1, 'first', 'last'), rr2(w), why); %#ok<AGROW>
                                end
                            end
                        end
                    end
                end
                Tl = table(subjV, scnV, repV, valV, 'VariableNames', {'subject', 'scenario', 'rep', 'value'});
                ax = [];
                if doPlot, ax = subplot(ceil(nReg/2), 2, r); end
                res = claude_residents_rm2way(Tl, sprintf('%s | %s %s', mname{m}, BANDS(b).name, regNames{r}), ax);
                if ~isempty(ax) && r == 1, legend(ax, {'First repetition', 'Last repetition'}, 'Location', 'best'); end
                NN(b, r, m) = res.n;
                for e = 1:numel(res.eff), PU(b, r, m, e) = res.eff(e).pUse; end
                % who is missing and why (residents flagged as outliers are listed above, not here)
                for s = 1:nS
                    if ~FLAG(s,b,r) && ismember(subjects{s}, res.droppedNames) && ~isempty(miss{s})
                        fprintf('      %s missing: %s\n', subjects{s}, strjoin(miss{s}, '; '));
                    end
                end
            end
            if doPlot
                sgtitle(sprintf('Residents, %s %s (%s rule): first vs last repetition by scenario (mean +/- SD, residents with all 6 scenarios)', mname{m}, BANDS(b).name, rule));
                if SAVE_FIGS, print(f, [fig_dir sprintf('IR_rmANOVA_%s_%s_%s.png', mname{m}, BANDS(b).name, rule)], '-dpng', '-r110'); end
            end
        end
    end

    % Holm across the region x band tests of the same metric and effect
    effNames = {'Scenario', 'Repetition', 'Scenario x Repetition'};
    fprintf('\n=== %s rule: p (GG when Mauchly is significant) with Holm correction across the %d region x band tests of each metric ===\n', rule, nB*nReg);
    for m = 1:2
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
end


%% ---------------------------------------------------------------------
function z = robust_z(x)
    % modified z-score: 0.6745 * (x - median) / MAD
    md = median(x, 'omitnan');   s = median(abs(x - md), 'omitnan');
    if s == 0, z = zeros(size(x)); else, z = 0.6745 * (x - md) / s; end
end

function z = loo_z(x)
    % leave-one-out z: distance of each value from the mean/SD of the OTHER values
    n = numel(x);   z = nan(n, 1);
    for i = 1:n
        o = x([1:i-1, i+1:n]);
        z(i) = (x(i) - mean(o, 'omitnan')) / std(o, 'omitnan');
    end
end

function out = ternary(c, x, y)
    if c, out = x; else, out = y; end
end
