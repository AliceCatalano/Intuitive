% claude_Task_Res_PointTimes.m
% RESIDENTS: behavioural side, computed in the same way as the EEG (claude_Task_Res_FirstLast.m):
%   first repetition (rep 1) vs last repetition of each scenario, two-way repeated-measures ANOVA
%   Scenario (6) x Repetition (first/last), residents with all six scenarios (claude_residents_rm2way.m).
%
% Variables
%   completion time : the Time of the trial in performanceStruct_IR_updated.mat (the behavioural dataset)
%   point time      : execution time of each suture point measured from the EXIT OF THE PREVIOUS POINT
%                     (Pt1: from the start of the trial). The saved exit times are cumulative from the start,
%                     so  point time(p) = exit(p) - exit(p-1);  NaN when either exit is missing
%                     (no interval spanning two points is created). Exits are the validated ones used for the ERS
%                     (ExitERS_Times_IR.mat), so skipped repetitions are NaN.
% Holm correction across the 4 point-time tests of each effect.
% Plots: mean +/- SD per scenario, first and last repetition side by side. No text on the plots.

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));   % claude_figure_right.m, claude_holm_adjust.m, claude_residents_rm2way.m

D = '/home/acatalano/Desktop/Intuitive/DataStructures/';
G = load([D 'GraspERD_Times_IR.mat']);                   % RepStatus (1 = skip list), subjects
X = load([D 'ExitERS_Times_IR.mat']);                    % ValidExitTimes [resident x scenario x rep x point]
P = load([D 'performanceStruct_IR_updated.mat']);        % GlobalData: performed trials and their Time
subjects = G.subjects;   nS = numel(subjects);   NS = 6;   NRp = 10;   NP = 4;
if ~isequal(subjects(:), X.subjects(:)), error('Subject lists differ between GraspERD_Times_IR.mat and ExitERS_Times_IR.mat'); end

%% performed repetitions, behavioural completion time
performed = false(nS, NS, NRp);   tComp = nan(nS, NS, NRp);
for g = 1:numel(P.GlobalData)
    s = find(strcmp(subjects, strtok(P.GlobalData(g).ID, '_')));
    if isempty(s), continue; end
    for k = 1:numel(P.GlobalData(g).Scenarios)
        scn = P.GlobalData(g).Scenarios(k).ScenarioID;
        trs = P.GlobalData(g).Scenarios(k).Trials;
        for j = 1:numel(trs)
            id = trs(j).TrialID;
            if id >= 1 && id <= NRp
                performed(s, scn, id) = true;
                if ~isempty(trs(j).Time), tComp(s, scn, id) = double(trs(j).Time); end
            end
        end
    end
end
valid = performed & (G.RepStatus ~= 1);                  % performed and not in the skip list
firstRep = nan(nS, NS);   lastRep = nan(nS, NS);
for s = 1:nS
    for sc = 1:NS
        v = find(squeeze(valid(s, sc, :)));
        if numel(v) >= 2 && valid(s, sc, 1), firstRep(s, sc) = 1;   lastRep(s, sc) = v(end); end   % paper rule: rep 1 needed
    end
end
fprintf('Scenario x resident pairs with rep 1 and a last repetition: %d of %d\n', nnz(~isnan(firstRep)), nS*NS);

%% point times from the cumulative exit times
E = X.ValidExitTimes;                                    % [resident x scenario x rep x point], cumulative from the start
durP = nan(size(E));   durP(:,:,:,1) = E(:,:,:,1);
for p = 2:NP, durP(:,:,:,p) = E(:,:,:,p) - E(:,:,:,p-1); end

series = cell(1, 1 + NP);   labels = cell(1, 1 + NP);
series{1} = tComp;   labels{1} = 'completion time (s)';
for p = 1:NP
    series{1+p} = squeeze(durP(:,:,:,p));   labels{1+p} = sprintf('Pt%d time (s)%s', p, ternary(p == 1, ' from start', ' from previous exit'));
end

%% rmANOVA per variable
effNames = {'Scenario', 'Repetition', 'Scenario x Repetition'};
PU = nan(1 + NP, 3);   NN = nan(1 + NP, 1);
f = claude_figure_right('Residents first vs last - times', 1200, 760);   set(f, 'Color', 'w');
for k = 1:(1 + NP)
    Tl  = long_table(series{k}, subjects, firstRep, lastRep);
    ax  = subplot(2, 3, k);
    res = claude_residents_rm2way(Tl, labels{k}, ax);
    ylabel(ax, 'seconds');
    if k == 1, legend(ax, {'First repetition', 'Last repetition'}, 'Location', 'best'); end
    NN(k) = res.n;
    for e = 1:numel(res.eff), PU(k, e) = res.eff(e).pUse; end
end
sgtitle('Residents: first vs last repetition by scenario (mean +/- SD, residents with all 6 scenarios)');
SAVE_FIGS = true;   % save the figure as PNG (completion time and the 4 point times, first vs last, rmANOVA)
if SAVE_FIGS
    if ~exist([D 'Figures_IR_PointTimes'], 'dir'), mkdir([D 'Figures_IR_PointTimes']); end
    print(f, [D 'Figures_IR_PointTimes/IR_point_times_first_vs_last.png'], '-dpng', '-r110');
end

fprintf('\n=== Holm across the %d point-time tests (completion time is a single test, not corrected) ===\n', NP);
for e = 1:3
    padj = claude_holm_adjust(PU(2:end, e));
    fprintf('\n--- effect: %s ---\n', effNames{e});
    fprintf('%-34s n=%2d | p=%.4f\n', labels{1}, NN(1), PU(1, e));
    for p = 1:NP
        fprintf('%-34s n=%2d | p=%.4f | p(Holm)=%.4f\n', labels{1+p}, NN(1+p), PU(1+p, e), padj(p));
    end
end


%% ---------------------------------------------------------------------
function Tl = long_table(Z, subjects, firstRep, lastRep)
    % Z = [resident x scenario x rep]; one row per resident x scenario x {first, last}
    nS = numel(subjects);   NS = size(Z, 2);
    subjV = {};   scnV = [];   repV = {};   valV = [];
    for s = 1:nS
        for sc = 1:NS
            fr = firstRep(s, sc);   lr = lastRep(s, sc);
            vals = [NaN NaN];
            if ~isnan(fr) && ~isnan(lr), vals = [Z(s, sc, fr), Z(s, sc, lr)]; end
            subjV = [subjV; repmat(subjects(s), 2, 1)];  scnV = [scnV; sc; sc];  repV = [repV; {'first'; 'last'}];  valV = [valV; vals(:)]; %#ok<AGROW>
        end
    end
    Tl = table(subjV, scnV, repV, valV, 'VariableNames', {'subject', 'scenario', 'rep', 'value'});
end

function out = ternary(c, x, y)
    if c, out = x; else, out = y; end
end
