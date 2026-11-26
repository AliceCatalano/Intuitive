% claude_Task_Res_FieldtripERDERS.m
% RESIDENTS (IR): converts the epoched datasets to FieldTrip raw data.
% Input : <subj>_IR_graspERD_epochs.set , <subj>_IR_exitERS_epochs.set
% Output: <subj>_IR_graspERD_FT.mat , <subj>_IR_exitERS_FT.mat  (variable: data)
%
% Slot grid: 6 scenarios x 10 repetitions x 4 suture points = 240 slots,
%   slot = (scenario-1)*40 + (rep-1)*4 + point
% so that trial k of every subject is the same scenario/repetition/point.
% Slots with no epoch (skipped, missing, not completed, lost in epoching)
% are NaN-padded and flagged invalid. Same convention as the expert pipeline.
%
% data.trialinfo = [scenario rep point valid]   (240 x 4, defined for ALL slots)
% data.sampleinfo is NaN for padded slots.
%
% Note: the lock event closest to latency 0 identifies the epoch; if two epochs
% map to the same slot only the first is kept (warning).

clear; clc; close all;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

% ORIGINAL (common reference, before the average reference): base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref';   % NEW: filtered + average reference
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';

NUM_SCENARIOS = 6;
NUM_REPS      = 10;
NUM_POINTS    = 4;
NUM_SLOTS     = NUM_SCENARIOS * NUM_REPS * NUM_POINTS;   % 240

T        = load(times_file);
subjects = T.subjects;

cond(1).name    = 'graspERD';
cond(1).pattern = '^Grasp_S(\d+)_T(\d+)_P(\d+)$';
cond(2).name    = 'exitERS';
cond(2).pattern = '^Ext_S(\d+)_T(\d+)_P(\d+)$';

% trialinfo for every slot (independent of which slots are filled)
[pp, rr, ss] = ndgrid(1:NUM_POINTS, 1:NUM_REPS, 1:NUM_SCENARIOS);
slotInfo = [ss(:) rr(:) pp(:)];          % row k = [scenario rep point] of slot k

for s = 1:numel(subjects)
    subject = subjects{s};
    fprintf('\n=== %s ===\n', subject);

    for c = 1:numel(cond)
        in_name  = sprintf('%s_IR_%s_epochs.set', subject, cond(c).name);
        out_name = sprintf('%s_IR_%s_FT.mat',     subject, cond(c).name);

        if ~exist(fullfile(base_path, in_name), 'file')
            warning('%s: %s not found', subject, in_name);
            continue;
        end

        EEG = pop_loadset('filename', in_name, 'filepath', base_path);

        dataRaw  = eeglab2fieldtrip(EEG, 'preprocessing', 'none');
        nChan    = size(dataRaw.trial{1}, 1);
        nSamp    = size(dataRaw.trial{1}, 2);
        nanTrial = nan(nChan, nSamp);

        % slot of each epoch from its lock event
        epSlot = nan(EEG.trials, 1);
        for ep = 1:EEG.trials
            typ = EEG.epoch(ep).eventtype;
            lat = EEG.epoch(ep).eventlatency;
            if ~iscell(typ), typ = {typ}; end
            if ~iscell(lat), lat = {lat}; end
            idx = find(~cellfun(@isempty, regexp(typ, cond(c).pattern, 'once')));
            if isempty(idx)
                warning('%s [%s] epoch %d: no lock event, skipped', subject, cond(c).name, ep);
                continue;
            end
            [~, k] = min(abs(cellfun(@(x) x, lat(idx))));
            tok = regexp(typ{idx(k)}, cond(c).pattern, 'tokens', 'once');
            sc = str2double(tok{1}); tr = str2double(tok{2}); pt = str2double(tok{3});
            if sc < 1 || sc > NUM_SCENARIOS || tr < 1 || tr > NUM_REPS || pt < 1 || pt > NUM_POINTS
                warning('%s [%s]: %s outside slot grid, skipped', subject, cond(c).name, typ{idx(k)});
                continue;
            end
            epSlot(ep) = (sc-1)*NUM_REPS*NUM_POINTS + (tr-1)*NUM_POINTS + pt;
        end

        % build the 240-slot structure
        data            = dataRaw;
        data.trial      = cell(1, NUM_SLOTS);
        data.time       = cell(1, NUM_SLOTS);
        sampleinfo      = nan(NUM_SLOTS, 2);
        valid           = false(NUM_SLOTS, 1);
        hasSampleinfo   = isfield(dataRaw, 'sampleinfo') && size(dataRaw.sampleinfo,1) == EEG.trials;

        for slot = 1:NUM_SLOTS
            data.time{slot} = dataRaw.time{1};
            ep = find(epSlot == slot);
            if numel(ep) > 1
                warning('%s [%s]: slot %d has %d epochs, keeping the first', ...
                    subject, cond(c).name, slot, numel(ep));
                ep = ep(1);
            end
            if ~isempty(ep)
                data.trial{slot} = dataRaw.trial{ep};
                valid(slot)      = true;
                if hasSampleinfo, sampleinfo(slot,:) = dataRaw.sampleinfo(ep,:); end
            else
                data.trial{slot} = nanTrial;
            end
        end

        data.sampleinfo = sampleinfo;
        data.trialinfo  = [slotInfo double(valid)];

        fprintf('  [%s] %d epochs -> %d / %d slots filled\n', ...
            cond(c).name, EEG.trials, nnz(valid), NUM_SLOTS);
        for sc = 1:NUM_SCENARIOS
            sl = (sc-1)*NUM_REPS*NUM_POINTS + (1:NUM_REPS*NUM_POINTS);
            fprintf('      Sc%d: %2d slots filled (reps with data: %s)\n', sc, nnz(valid(sl)), ...
                mat2str(find(any(reshape(valid(sl), NUM_POINTS, NUM_REPS), 1))));
        end

        save(fullfile(base_path, out_name), 'data');
        fprintf('  Saved: %s\n', out_name);
    end
end
