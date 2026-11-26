% claude_check_ICA_removal.m
% =====================================================================================================
% WERE THE ICA COMPONENTS REMOVED FROM THE DATA?  Reads the datasets, changes nothing, writes nothing.
%
% Datasets checked
%   residents : IR_Task/ERDS/IR##_afterICA.set                (the files the resident pipeline uses)
%   experts   : IE_Task/Task2/IE##Task2_final.set             (components removed in your scripts: REFERENCE for "removed")
%   calibration / extra files (EXTRA below):
%       IE01_Task2_ICA.set  = expert dataset BEFORE the removal (REFERENCE for "not removed")
%       Downloads/OneDrive_1_11-19-2026/IR02_Task_ICA.set = the resident ICA file you just received
%
% THREE INDEPENDENT CLUES per dataset
%   1. nIC vs nICchan : number of ICA components stored (rows of EEG.icaweights) vs number of channels the ICA was computed on
%                       (EEG.icachansind). pop_subcomp deletes the removed components from the ICA, so nIC < nICchan means
%                       components WERE removed. nIC == nICchan: nothing removed from the stored ICA (it can still be that the
%                       data were cleaned in another way).
%   2. rank of the data : the data matrix of a dataset from which k components were projected out has rank (channels - k). A full
%                       rank means nothing was projected out. Other things lower the rank too: an average reference (1), channels
%                       interpolated after removing them (1 each). The table lists those so you can subtract them:
%                       rankDeficit = channels - rank ;  excess = rankDeficit - (channels removed in the history) - (average reference ? 1 : 0)
%                       excess > 0 suggests removed components (assuming removed channels were interpolated back).
%   3. flagged components : EEG.reject.gcompreject = components marked for rejection (marked is not the same as removed).
% And, from EEG.history: is there a pop_subcomp call? (absence is NOT proof: history can be incomplete.)
%
% HOW TO READ IT: look at the two calibration rows first. IE01_Task2_ICA must say "no sign of removal" and the experts'
% *_final must say "removed"; the residents' rows are then comparable to them.
% =====================================================================================================

clear; clc;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

%% SETTINGS --------------------------------------------------------------------------------------------
SEG_S    = 120;        % seconds of data used for the rank (a stretch without 'boundary' events)
RANK_TOL = 1e-5;       % a singular value below RANK_TOL * (largest) counts as zero

list = {};   % {path, folder, file, group label}
d = dir('/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/IR*_afterICA.set');
for k = 1:numel(d), list(end+1, :) = {d(k).folder, d(k).name, 'resident afterICA'}; end %#ok<SAGROW>
d = dir('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/IE*Task2_final.set');
for k = 1:numel(d), list(end+1, :) = {d(k).folder, d(k).name, 'expert final (removed)'}; end %#ok<SAGROW>
EXTRA = { '/home/acatalano/Desktop/Intuitive/IE_Task/Task2',               'IE01_Task2_ICA.set', 'expert BEFORE removal'
          '/home/acatalano/Downloads/OneDrive_1_11-19-2026',              'IR02_Task_ICA.set',  'resident ICA (received)' };
for k = 1:size(EXTRA, 1)
    if exist(fullfile(EXTRA{k, 1}, EXTRA{k, 2}), 'file'), list(end+1, :) = EXTRA(k, :); else, fprintf('(extra file not found: %s)\n', fullfile(EXTRA{k, 1}, EXTRA{k, 2})); end %#ok<SAGROW>
end

%% COMPUTE ---------------------------------------------------------------------------------------------
fprintf('\n%-22s %-24s %4s %5s %6s %7s | %5s %7s %9s %5s | %-6s %-6s %-6s %s\n', 'file', 'group', 'chan', 'nIC', 'ICchan', 'flagged', 'rank', 'deficit', 'log10 smin', 'excess', 'rmChan', 'interp', 'subcmp', 'verdict');
for k = 1:size(list, 1)
    EEG = pop_loadset('filename', list{k, 2}, 'filepath', list{k, 1});
    h = EEG.history;   nch = EEG.nbchan;

    % clue 1: ICA matrices
    if isempty(EEG.icaweights), nIC = 0; else, nIC = size(EEG.icaweights, 1); end
    nICchan = numel(EEG.icachansind);
    % clue 3: flagged components
    nFlag = NaN;   if isfield(EEG, 'reject') && isfield(EEG.reject, 'gcompreject') && ~isempty(EEG.reject.gcompreject), nFlag = nnz(EEG.reject.gcompreject); end

    % clue 2: rank of a stretch of data without boundary events
    X = double(EEG.data);   fs = EEG.srate;   n = round(SEG_S * fs);
    bL = [EEG.event(strcmp({EEG.event.type}, 'boundary')).latency];
    seg = [];
    for st = round(linspace(1, max(1, size(X, 2) - n), 8))
        if ~any(bL >= st & bL <= st + n), seg = st:st + n - 1; break; end
    end
    if isempty(seg), seg = round(size(X, 2) / 2) + (1:min(n, floor(size(X, 2) / 2))); fprintf('  (%s: no stretch without boundary found, using the middle)\n', list{k, 2}); end
    sv = svd(X(:, seg) - mean(X(:, seg), 2), 'econ');
    rk = nnz(sv > RANK_TOL * sv(1));   deficit = nch - rk;   smin = log10(sv(end) / sv(1));

    % from the history
    rm = regexp(h, '''rmchannel''\s*,\s*\{([^}]*)\}', 'tokens');
    nRmChan = 0;   for q = 1:numel(rm), nRmChan = nRmChan + numel(strsplit(strtrim(strrep(rm{q}{1}, '''', '')), {' ', ','}, 'CollapseDelimiters', true)); end
    hasInterp = contains(h, 'pop_interp');   hasSub = contains(h, 'pop_subcomp');
    avgRef = strcmp(EEG.ref, 'average');
    excess = deficit - nRmChan - double(avgRef);

    if nICchan > 0 && nIC < nICchan,               verdict = 'REMOVED (stored ICA has fewer components than channels)';
    elseif excess > 0 && nIC > 0,                  verdict = sprintf('probably removed (data rank lower by %d than channels/ref explain)', excess);
    elseif nIC == 0,                               verdict = 'no ICA stored';
    else,                                          verdict = 'no sign of removal';
    end
    fprintf('%-22s %-24s %4d %5d %6d %7s | %5d %7d %9.1f %5d | %-6d %-6s %-6s %s\n', list{k, 2}, list{k, 3}, nch, nIC, nICchan, num2str(nFlag), rk, deficit, smin, excess, nRmChan, ...
        ternary(hasInterp, 'yes', 'no'), ternary(hasSub, 'yes', 'no'), verdict);
end
fprintf('\nrmChan = channels removed according to the history (assumed interpolated back); interp / subcmp = pop_interp / pop_subcomp found in the history.\n');
fprintf('log10 smin = log10(smallest singular value / largest): about -7 or lower means exactly rank-deficient (something was projected out).\n');

function o = ternary(c, x, y)
    if c, o = x; else, o = y; end
end
