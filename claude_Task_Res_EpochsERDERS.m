% claude_Task_Res_EpochsERDERS.m
% RESIDENTS (IR): epochs the two event datasets produced by
% claude_Task_events_Residents_v2.m
%   graspERD : lock events Grasp_S#_T#_P#   window [-0.8  1.5] s
%   exitERS  : lock events Ext_S#_T#_P#     window [-2.5  0.5] s
% Input : <subj>_IR_graspERD_events.set , <subj>_IR_exitERS_events.set
% Output: <subj>_IR_graspERD_epochs.set , <subj>_IR_exitERS_epochs.set
%         Epoching_Log_IR.mat  (lock events lost during epoching)
%
% pop_epoch rejects epochs that overlap data limits or a boundary (removed
% data). Those epochs are reported (never silently lost): the FieldTrip step
% will leave the corresponding slot NaN.

clear; clc; close all
restoredefaultpath;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
log_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/Epoching_Log_IR.mat';

T        = load(times_file);
subjects = T.subjects;           % same subject order as the behavioural matrices

cond(1).name    = 'graspERD';
cond(1).pattern = '^Grasp_S\d+_T\d+_P\d+$';
cond(1).win     = [-0.8 1.5];
cond(2).name    = 'exitERS';
cond(2).pattern = '^Ext_S\d+_T\d+_P\d+$';
cond(2).win     = [-2.5 0.5];

LOG = {};   % {subject, condition, lock event lost, reason}

for s = 1:numel(subjects)
    subject = subjects{s};
    fprintf('\n=== %s ===\n', subject);

    for c = 1:numel(cond)
        in_name  = sprintf('%s_IR_%s_events.set', subject, cond(c).name);
        out_name = sprintf('%s_IR_%s_epochs.set', subject, cond(c).name);

        if ~exist(fullfile(base_path, in_name), 'file')
            warning('%s: %s not found', subject, in_name);
            LOG(end+1,:) = {subject, cond(c).name, '', 'events dataset not found'}; %#ok<SAGROW>
            continue;
        end

        EEG   = pop_loadset('filename', in_name, 'filepath', base_path);
        types = event_types(EEG);
        lockTypes = unique(types(~cellfun(@isempty, regexp(types, cond(c).pattern, 'once'))));

        fprintf('  [%s] %d lock events in the dataset\n', cond(c).name, numel(lockTypes));
        if isempty(lockTypes)
            warning('%s [%s]: no lock events, skipping', subject, cond(c).name);
            LOG(end+1,:) = {subject, cond(c).name, '', 'no lock events'}; %#ok<SAGROW>
            continue;
        end

        EEG_ep = pop_epoch(EEG, lockTypes, cond(c).win, ...
            'newname', sprintf('%s_IR_%s_epochs', subject, cond(c).name), 'epochinfo', 'yes');

        % which lock events survived epoching
        survived = cell(1, EEG_ep.trials);
        for ep = 1:EEG_ep.trials
            survived{ep} = epoch_lock_type(EEG_ep, ep, cond(c).pattern);
        end
        lost = setdiff(lockTypes, survived);

        fprintf('  [%s] epochs created: %d / %d | lost: %d\n', ...
            cond(c).name, EEG_ep.trials, numel(lockTypes), numel(lost));
        for k = 1:numel(lost)
            LOG(end+1,:) = {subject, cond(c).name, lost{k}, 'rejected by pop_epoch (boundary / data limits)'}; %#ok<SAGROW>
            fprintf('      lost %s\n', lost{k});
        end

        pop_saveset(EEG_ep, 'filename', out_name, 'filepath', base_path);
    end
end

save(log_file, 'LOG');
fprintf('\n=== LOCK EVENTS LOST DURING EPOCHING: %d ===\n', size(LOG,1));
for k = 1:size(LOG,1)
    fprintf('  %s [%s] %s : %s\n', LOG{k,:});
end
fprintf('Log saved: %s\n', log_file);


%% Local functions
function types = event_types(EEG)
    types = cell(1, numel(EEG.event));
    for k = 1:numel(EEG.event)
        t = EEG.event(k).type;
        if ischar(t), types{k} = t;
        elseif isstring(t), types{k} = char(t);
        else, types{k} = '';
        end
    end
end

function lockType = epoch_lock_type(EEG, ep, pattern)
    % lock event of an epoch = matching event closest to latency 0
    typ = EEG.epoch(ep).eventtype;
    lat = EEG.epoch(ep).eventlatency;
    if ~iscell(typ), typ = {typ}; end
    if ~iscell(lat), lat = {lat}; end
    idx = find(~cellfun(@isempty, regexp(typ, pattern, 'once')));
    if isempty(idx), lockType = ''; return; end
    [~, k]   = min(abs(cellfun(@(x) x, lat(idx))));
    lockType = typ{idx(k)};
end
