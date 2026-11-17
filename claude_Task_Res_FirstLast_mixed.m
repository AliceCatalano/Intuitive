% claude_Task_Res_FirstLast_mixed.m
% RESIDENTS: same trials as claude_Task_Res_FirstLast_paper.m, analysed with a linear mixed model on ALL available data
% instead of a complete-case rmANOVA:
%     value ~ scenario * repetition + (1 | resident)        scenario: 6 levels, repetition: first / last trial
%   - the first and the last performed trial of each scenario (performed list minus the skip list); a trial without
%     a value just contributes no row, so no resident is thrown away because of one missing cell
%   - effects coding (sum to zero) so that Scenario and Repetition are tested averaged over the other factor
%   - F tests with Satterthwaite degrees of freedom; Holm across the 8 region x band tests of each metric and effect
%   - outlier residents: same rule as the experts, removed from the whole analysis
% Metrics: ERD, ERS, modulation. The printout also gives, for each test, how many residents and observations were used
% and the mean change (last - first) over the available resident x scenario pairs.
% Needs the Statistics and Machine Learning Toolbox (fitlme, anova).

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % claude_holm_adjust.m

D = '/home/acatalano/Desktop/Intuitive/DataStructures/';
REMOVE_OUTLIERS = true;   ROBUST_Z = 3.5;   LOO_Z = 3;   INCLUDE_JOINED_MOTOR = false;

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

%% mixed model per metric x band x region
effTerms = {'scenario', 'rep', 'scenario:rep'};   effNames = {'Scenario', 'Repetition', 'Scenario x Repetition'};
shortNames = {'Scen', 'Rep', 'Scen*Rep'};
PU = nan(nB, nReg, 3, 3);   NN = nan(nB, nReg, 3);
for m = 1:3
    fprintf('\n=== %s: value ~ scenario * repetition + (1|resident) ===\n', mname{m});
    for b = 1:nB
        for r = 1:nReg
            X = squeeze(mean(mdata{m}(b, regions{r}, :, :, :, :), 2));     % [resident x scenario x rep x point]
            Xrep = mean(X, 4, 'omitnan');                                    % one value per trial
            sid = [];   scn = [];   rp = [];   val = [];   dif = [];
            for s = 1:nS
                if out(s), continue; end
                for sc = 1:NS
                    if isnan(first(s, sc)), continue; end
                    vf = Xrep(s, sc, first(s, sc));   vl = Xrep(s, sc, last(s, sc));
                    if ~isnan(vf), sid(end+1,1) = s;  scn(end+1,1) = sc;  rp(end+1,1) = 1;  val(end+1,1) = vf; end %#ok<AGROW>
                    if ~isnan(vl), sid(end+1,1) = s;  scn(end+1,1) = sc;  rp(end+1,1) = 2;  val(end+1,1) = vl; end %#ok<AGROW>
                    if ~isnan(vf) && ~isnan(vl), dif(end+1,1) = vl - vf; end %#ok<AGROW>
                end
            end
            tbl = table(categorical(sid), categorical(scn), categorical(rp, [1 2], {'first', 'last'}), val, ...
                'VariableNames', {'subj', 'scenario', 'rep', 'value'});
            NN(b, r, m) = numel(unique(sid));
            try
                lme = fitlme(tbl, 'value ~ scenario*rep + (1|subj)', 'DummyVarCoding', 'effects');
                a = anova(lme, 'DFMethod', 'satterthwaite');
                line = sprintf('%-5s %-11s %2d residents, %3d obs | mean change last-first %+.3f (n pairs %d) |', ...
                    BANDS(b).name, regNames{r}, NN(b,r,m), height(tbl), mean(dif), numel(dif));
                for e = 1:3
                    i = strcmp(strtrim(string(a.Term)), effTerms{e});
                    PU(b, r, m, e) = a.pValue(i);
                    line = sprintf('%s %s F(%d,%.1f)=%.2f p=%.4f |', line, shortNames{e}, a.DF1(i), a.DF2(i), a.FStat(i), a.pValue(i));
                end
                fprintf('%s\n', line);
            catch ME
                fprintf('%-5s %-11s model failed: %s\n', BANDS(b).name, regNames{r}, ME.message);
            end
        end
    end
end

%% Holm across the 8 region x band tests of each metric and effect
fprintf('\n=== p and Holm p across the %d region x band tests of each metric ===\n', nB*nReg);
for m = 1:3
    for e = 1:3
        pv = reshape(PU(:, :, m, e), [], 1);   padj = reshape(claude_holm_adjust(pv), nB, nReg);
        fprintf('\n--- %s | effect: %s ---\n', mname{m}, effNames{e});
        for b = 1:nB
            for r = 1:nReg
                fprintf('%-5s %-12s %2d residents | p=%.4f | p(Holm)=%.4f\n', BANDS(b).name, regNames{r}, NN(b,r,m), PU(b,r,m,e), padj(b,r));
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
