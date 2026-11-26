% claude_FOOOF_duration_mixed.m
% =====================================================================================================
% DOES A FOOOF MEASURE TRACK SUTURE DURATION *WITHIN* A PERSON, or only differ BETWEEN people?
%
% PROBLEM WITH THE POOLED CORRELATIONS (Task2_fooof.m, "Spearman correlations: FOOOF params vs suture duration")
%   they correlate all slots of all experts together. "higher beta frequency -> slower" can then simply mean
%   "experts with a higher beta frequency are slower overall" = a trait, not an effect of performance.
%
% MODEL (one per group x epoch x ROI x parameter), fitlme:
%       duration ~ x_within + x_between + point + (1 | subject)           [MODEL A]
%       duration ~ x_within + x_between + point + rep + (1 | subject)     [MODEL B: also removes the practice trend]
%   x_between = the person's own mean of the measure (differences between people)
%   x_within  = the value minus the person's own mean (changes inside the person)
%   ONLY a significant x_within term supports "this measure tracks performance".
%   Residents: scenario is added as a factor (and rep in model B).
%   Degrees of freedom: Satterthwaite (as in the other mixed models). Holm over all x_within tests of the same group / model.
%
% Slots: experts slot = (rep-1)*4 + point (80); residents slot = (scenario-1)*40 + (rep-1)*4 + point (240).
% Duration of a slot: experts = exit - entry of the suture (NeedlePassageTimes_IE_T2.mat);
%                     residents = time from the previous exit (point 1: from the go) from ExitERS_Times_IR.mat.
% FOOOF fits with R^2 below R2_MIN are dropped.
% =====================================================================================================

clear; close all; clc;
D = '/home/acatalano/Desktop/Intuitive/DataStructures/';

%% SETTINGS --------------------------------------------------------------------------------------------
GROUPS  = {'experts', 'residents'};     % which groups to run
PARAMS  = {'beta_cf', 'alpha_cf', 'beta_pow', 'alpha_pow', 'exponent'};
R2_MIN  = 0.8;
LOG_DUR = false;                         % true: model log(duration) (durations are right-skewed); false: raw seconds as in the request
MIN_N   = 40;                            % minimum number of slots (and 5 subjects) for a model

for g = 1:numel(GROUPS)
    grp = GROUPS{g};
    fprintf('\n\n########################  %s  ########################\n', upper(grp));
    if strcmp(grp, 'experts')
        S = load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/Task2_FOOOF_Experts.mat');   % FOOOF_exit, FOOOF_grasp [subj x roi x 80]
        B = load([D 'NeedlePassageTimes_IE_T2.mat']);                                          % ExitTimes, EntryTimes [subj x 20 x 4]
        nSubj = numel(S.subjects);   nSlot = 80;
        dur = B.ExitTimes - B.EntryTimes;                                                      % subj x rep x point
        if ~isequal(size(dur), [nSubj 20 4]), error('Unexpected size of ExitTimes-EntryTimes: %s', mat2str(size(dur))); end
        slotDur = nan(nSubj, nSlot);   slotRep = nan(1, nSlot);   slotPt = nan(1, nSlot);   slotSc = ones(1, nSlot);
        for k = 1:nSlot, slotRep(k) = ceil(k / 4);   slotPt(k) = mod(k - 1, 4) + 1;   slotDur(:, k) = dur(:, slotRep(k), slotPt(k)); end
    else
        % ORIGINAL (common reference): S = load([D 'Task_FOOOF_Residents.mat']);
        S = load([D 'Task_FOOOF_Residents_avgref.mat']);                                              % FOOOF_grasp, FOOOF_exit [subj x roi x 240]
        X = load([D 'ExitERS_Times_IR.mat']);                                                  % ValidExitTimes [subj x 6 x 10 x 4], cumulative
        if ~isequal(S.subjects(:), X.subjects(:)), error('Subject lists differ'); end
        nSubj = numel(S.subjects);   nSlot = 240;
        E = X.ValidExitTimes;   P = nan(size(E));   P(:,:,:,1) = E(:,:,:,1);
        for p = 2:4, P(:,:,:,p) = E(:,:,:,p) - E(:,:,:,p - 1); end
        slotDur = nan(nSubj, nSlot);   slotRep = nan(1, nSlot);   slotPt = nan(1, nSlot);   slotSc = nan(1, nSlot);
        for k = 1:nSlot
            slotSc(k) = ceil(k / 40);   slotRep(k) = mod(ceil(k / 4) - 1, 10) + 1;   slotPt(k) = mod(k - 1, 4) + 1;
            slotDur(:, k) = P(:, slotSc(k), slotRep(k), slotPt(k));
        end
    end
    roi_names = S.roi_names;   subjects = S.subjects;   epochs = {'exit', 'grasp'};   FD = {S.FOOOF_exit, S.FOOOF_grasp};

    rows = {};   pw = [];   pb = [];
    for e = 1:2
        for r = 1:numel(roi_names)
            for p = 1:numel(PARAMS)
                V = squeeze(FD{e}.(PARAMS{p})(:, r, :));                                      % subj x slot
                V(squeeze(FD{e}.r_squared(:, r, :)) < R2_MIN) = NaN;
                ok = ~isnan(V) & ~isnan(slotDur) & slotDur > 0;
                [si, ki] = find(ok);   if numel(si) < MIN_N || numel(unique(si)) < 5, continue; end
                y = slotDur(sub2ind(size(slotDur), si, ki));   x = V(sub2ind(size(V), si, ki));
                if LOG_DUR, y = log(y); end
                mu = accumarray(si, x, [nSubj 1], @mean);
                T = table(categorical(subjects(si))', y, x - mu(si), mu(si), categorical(slotPt(ki))', categorical(slotSc(ki))', slotRep(ki)', ...
                          'VariableNames', {'subject', 'dur', 'xw', 'xb', 'point', 'scen', 'rep'});
                fA = 'dur ~ xw + xb + point + (1|subject)';   fB = 'dur ~ xw + xb + point + rep + (1|subject)';
                if strcmp(grp, 'residents'), fA = 'dur ~ xw + xb + point + scen + (1|subject)';   fB = 'dur ~ xw + xb + point + scen + rep + (1|subject)'; end
                res = nan(2, 4);                                                               % model A/B: [bw pw bb pb]
                chk = nan(1, 3);                                                               % model A checks: [df of xb, SD subject intercept, p person-level]
                for mdl = 1:2
                    try
                        m = fitlme(T, ternary(mdl == 1, fA, fB));
                        [~, ~, C] = fixedEffects(m, 'DFMethod', 'satterthwaite');   % Satterthwaite df for the p-values
                        iw = strcmp(C.Name, 'xw');   ib = strcmp(C.Name, 'xb');
                        res(mdl, :) = [C.Estimate(iw), C.pValue(iw), C.Estimate(ib), C.pValue(ib)];
                        if mdl == 1
                            psi = covarianceParameters(m);   chk(1:2) = [C.DF(ib), sqrt(psi{1}(1))];
                            pm = accumarray(si, y, [nSubj 1], @mean);   us = unique(si);           % person-level: mean duration ~ mean measure
                            lm = fitlm(mu(us), pm(us));   chk(3) = lm.Coefficients.pValue(2);
                        end
                    catch ME
                        fprintf('fitlme failed (%s %s %s, model %d): %s\n', epochs{e}, roi_names{r}, PARAMS{p}, mdl, ME.message);
                    end
                end
                % pooled correlation (what Task2_fooof.m did) for comparison: Spearman over all slots of all people
                rho = corr(x, slotDur(sub2ind(size(slotDur), si, ki)), 'Type', 'Spearman');
                rows(end+1, :) = {epochs{e}, roi_names{r}, PARAMS{p}, numel(y), numel(unique(si)), rho, res(1, :), res(2, :), chk, std(x - mu(si))};          % last: within-person SD of the measure %#ok<SAGROW>
                pw(end+1, :) = [res(1, 2), res(2, 2)]; %#ok<SAGROW>
            end
        end
    end
    % Holm over the within tests of each model
    adjW = [holm(pw(:, 1)), holm(pw(:, 2))];
    fprintf('Model A: %s\nModel B: %s\n', ternary(strcmp(grp, 'residents'), 'dur ~ xw + xb + point + scen + (1|subject)', 'dur ~ xw + xb + point + (1|subject)'), 'Model A + rep');
    fprintf('Units: duration in %s; slope = change of duration per +1 unit of the measure (beta_cf/alpha_cf: per Hz).\n', ternary(LOG_DUR, 'log(s)', 's'));
    d = slotDur(slotDur > 0);   fprintf('Suture point duration: mean %.2f s, median %.2f s, SD %.2f s.  s/1SD = within slope x within-person SD of the measure (s per 1 SD).\n', mean(d), median(d), std(d));
    fprintf('rho_pool = pooled Spearman over all slots of all people (the old analysis).  WITHIN = the effect inside a person (what counts).\n\n');
    fprintf('%-6s %-11s %-10s %5s %3s | %8s | %8s %8s %8s %8s | %8s %8s %8s %8s %8s | %8s %8s\n', 'epoch', 'ROI', 'param', 'n', 'sub', 'rho_pool', ...
        'A:withn', 's/1SD', 'p', 'p(Holm)', 'A:betwn', 'p', 'df', 'SDsubj', 'p_pers', 'B:withn', 'p');
    for i = 1:size(rows, 1)
        a = rows{i, 7};   b = rows{i, 8};
        sig = ''; if adjW(i, 1) < 0.05, sig = ' <== within survives Holm'; elseif a(2) < 0.05, sig = ' <- within p<0.05 (uncorrected)'; end
        fprintf('%-6s %-11s %-10s %5d %3d | %8.3f | %8.3g %8.3f %8.4f %8.4f | %8.3g %8.4f %8.1f %8.3f %8.4f | %8.3g %8.4f%s\n', rows{i, 1:6}, a(1), a(1) * rows{i, 10}, a(2), adjW(i, 1), a(3), a(4), rows{i, 9}, b(1), b(2), sig);
    end
    fprintf('\nRead: a measure "tracks performance" only if its WITHIN p survives Holm in model A and stays in model B (practice removed).\n');
    fprintf('If rho_pool is large but WITHIN is not, the pooled result was a between-person trait.\n');
end

function o = ternary(c, x, y)
    if c, o = x; else, o = y; end
end

function adj = holm(p)
    adj = nan(size(p));   ok = find(~isnan(p));   [ps, ix] = sort(p(ok));   m = numel(ps);
    a = max(cummax((m - (1:m)' + 1) .* ps(:)), 0);   a = min(a, 1);   adj(ok(ix)) = a;
end
