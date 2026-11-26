function T = claude_gap_table(EXCLUDE_RES)
% claude_gap_table  One row per COMPLETE suture point (grasp, entry and exit all valid), experts + residents.
%
%   T = claude_gap_table(EXCLUDE_RES)      EXCLUDE_RES: cellstr of residents left out (default {'IR04'})
%
% Sources (same ones used by the ERD / ERS analyses, so skip lists are already applied)
%   residents : GraspERD_Times_IR.mat  (EntryTimes_Valid, LastGraspBeforeEntry)  +  ExitERS_Times_IR.mat (ValidExitTimes)
%   experts   : NeedlePassageTimes_IE_T2.mat (EntryTimes) + GraspERD_Times_IE_T2.mat + ExitERS_Times_IE_T2.mat   (Task 2, 20 reps)
% All times are seconds from the start of the repetition (MS marker), same clock inside a repetition.
%
% Columns
%   group     1 = resident, 2 = expert
%   subjIdx   index inside its group (order of the .mat files)       subj  name (IR02, IE01, ...)
%   scenario  resident scenario 1-6 (experts: 1 = Task 2)            rep   repetition number inside the scenario
%   point     suture point 1-4                                       slot  slot of the TFR files
%                                                                          residents (sc-1)*40+(rep-1)*4+pt | experts (rep-1)*4+pt
%   tGrasp, tEntry, tExit         event times (s)
%   GA   entry - grasp            'approach'   : last grasp -> needle enters the tissue
%   EE   exit  - entry            'passage'    : needle inside the tissue (entry -> exit)
%   GE   exit  - grasp            whole point  : last grasp -> needle exits
%   TR   next grasp - this exit   'transport'  : exit of this point -> last grasp before the next entry (NaN for point 4 / missing)
    if nargin < 1, EXCLUDE_RES = {'IR04'}; end
    D = '/home/acatalano/Desktop/Intuitive/DataStructures/';

    % ---------------- residents ----------------
    G  = load([D 'GraspERD_Times_IR.mat']);
    X  = load([D 'ExitERS_Times_IR.mat']);
    subjR = G.subjects(:);
    if ~isequal(subjR, X.subjects(:)), error('Resident subject lists differ'); end
    enR = G.EntryTimes_Valid;  grR = G.LastGraspBeforeEntry;  exR = X.ValidExitTimes;      % [subj x 6 x 10 x 4]
    rows = {};
    for s = 1:numel(subjR)
        if ismember(subjR{s}, EXCLUDE_RES), continue; end
        for sc = 1:6
            for rp = 1:10
                g = squeeze(grR(s,sc,rp,:))';  n = squeeze(enR(s,sc,rp,:))';  x = squeeze(exR(s,sc,rp,:))';
                rows = [rows; point_rows(1, s, subjR{s}, sc, rp, g, n, x, (sc-1)*40 + (rp-1)*4)]; %#ok<AGROW>
            end
        end
    end

    % ---------------- experts (Task 2) ----------------
    GE_ = load([D 'GraspERD_Times_IE_T2.mat']);
    XE  = load([D 'ExitERS_Times_IE_T2.mat']);
    NE  = load([D 'NeedlePassageTimes_IE_T2.mat']);
    subjE = GE_.subjects(:);
    if ~isequal(subjE, XE.subjects(:)) || ~isequal(subjE, NE.subjects(:)), error('Expert subject lists differ'); end
    grE = GE_.LastGraspBeforeEntry;  exE = XE.ValidExitTimes;  enE = NE.EntryTimes;          % [subj x 20 x 4]
    for s = 1:numel(subjE)
        for rp = 1:20
            g = squeeze(grE(s,rp,:))';  n = squeeze(enE(s,rp,:))';  x = squeeze(exE(s,rp,:))';
            rows = [rows; point_rows(2, s, subjE{s}, 1, rp, g, n, x, (rp-1)*4)]; %#ok<AGROW>
        end
    end

    T = cell2table(rows, 'VariableNames', {'group','subjIdx','subj','scenario','rep','point','slot','tGrasp','tEntry','tExit','TR'});
    T.GA = T.tEntry - T.tGrasp;
    T.EE = T.tExit  - T.tEntry;
    T.GE = T.tExit  - T.tGrasp;
    T = T(:, {'group','subjIdx','subj','scenario','rep','point','slot','tGrasp','tEntry','tExit','GA','EE','GE','TR'});
    fprintf('claude_gap_table: %d complete points | residents %d (%d residents) | experts %d (%d experts)\n', height(T), ...
        nnz(T.group==1), numel(unique(T.subj(T.group==1))), nnz(T.group==2), numel(unique(T.subj(T.group==2))));
end

function R = point_rows(grp, sIdx, sName, sc, rp, g, n, x, slotBase)
    % rows of the complete points of one repetition (g, n, x = 1x4 grasp / entry / exit times)
    tr = nan(1, 4);
    for p = 1:3
        v = g(p+1) - x(p);
        if isfinite(v) && v > 0, tr(p) = v; end          % NaN when either time is missing or order is impossible
    end
    R = {};
    for p = 1:4
        if ~isfinite(g(p)) || ~isfinite(n(p)) || ~isfinite(x(p)), continue; end
        if x(p) <= n(p) || n(p) < g(p), continue; end   % exit before entry / entry before the grasp: not a usable point
        R(end+1,:) = {grp, sIdx, sName, sc, rp, p, slotBase + p, g(p), n(p), x(p), tr(p)}; %#ok<AGROW>
    end
end
