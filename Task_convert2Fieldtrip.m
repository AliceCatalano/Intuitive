% Task1_Exp_GraspERD_Fieldtrip.m
% Converts graspERD epochs to FieldTrip format.
% Each epoch is locked to a G<pt>_S<sc> event.
% Output: one tapered data structure per subject with trials indexed
% as (scenario-1)*4 + point, giving 24 slots (6 scenarios x 4 points).
% NaN-padded where no epoch exists.

clear; clc; close all;
restoredefaultpath;

addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
save_path = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};

NUM_SCENARIOS = 6;
NUM_POINTS    = 4;
NUM_SLOTS     = NUM_SCENARIOS * NUM_POINTS;   % 24 total slots

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

for i = 1:length(subjects)
    subject = subjects{i};
    fprintf('\n=== Subject %s ===\n', subject);

    %datasetFilename = [subject '_graspERD_epochs.set'];
    datasetFilename = [subject '_exitERS_epochs.set'];
    EEG = pop_loadset('filename', datasetFilename, 'filepath', base_path);
    %[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname', [subject '_graspERD_FT'], 'gui', 'off');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname', [subject '_exitERS_FT'], 'gui', 'off');

    dataRaw = eeglab2fieldtrip(EEG, 'preprocessing', 'none');

    nChan    = size(dataRaw.trial{1}, 1);
    nSamp    = size(dataRaw.trial{1}, 2);
    nanTrial = nan(nChan, nSamp);

    % --- Identify which (scenario, point) each epoch belongs to
    % Locking event is G<pt>_S<sc>, closest to latency 0
    foundSlot = nan(EEG.trials, 1);   % linear index: (sc-1)*4 + pt

    for ep = 1:EEG.trials
        typ = EEG.epoch(ep).eventtype;
        lat = EEG.epoch(ep).eventlatency;
        if ~iscell(typ), typ = {typ}; end
        if ~iscell(lat), lat = {lat}; end

        %isGrasp = ~cellfun('isempty', regexp(typ, '^G\d+_S\d+$', 'once'));
        isGrasp = ~cellfun('isempty', regexp(typ, '^Ext\d+_S\d+$', 'once'));
        candidateIdx = find(isGrasp);

        if isempty(candidateIdx)
            warning('Subject %s epoch %d: no G*_S* event found, skip', subject, ep);
            continue;
        end

        candidateLat = cellfun(@(x) x, lat(candidateIdx));
        [~, closest] = min(abs(candidateLat));
        lockIdx = candidateIdx(closest);

        %tok = regexp(typ{lockIdx}, '^G(\d+)_S(\d+)$', 'tokens', 'once');
        tok = regexp(typ{lockIdx}, '^Ext(\d+)_S(\d+)$', 'tokens', 'once');
        if ~isempty(tok)
            pt = str2double(tok{1});
            sc = str2double(tok{2});
            if pt >= 1 && pt <= NUM_POINTS && sc >= 1 && sc <= NUM_SCENARIOS
                foundSlot(ep) = (sc - 1) * NUM_POINTS + pt;
            end
        end
    end

    % --- Build tapered structure with NUM_SLOTS slots, NaN-padded
    data        = dataRaw;
    data.trial  = cell(1, NUM_SLOTS);
    data.time   = cell(1, NUM_SLOTS);

    for slot = 1:NUM_SLOTS
        data.time{slot} = dataRaw.time{1};
        idx = find(foundSlot == slot, 1, 'first');
        if ~isempty(idx)
            data.trial{slot} = dataRaw.trial{idx};
        else
            data.trial{slot} = nanTrial;
        end
    end

    n_real = sum(~isnan(foundSlot));
    fprintf('  Trials: %d real epochs placed into %d slots (%d NaN-padded)\n',n_real, NUM_SLOTS, NUM_SLOTS - n_real);

    % Print slot map for verification
    fprintf('  Slot map (sc x pt):\n');
    for sc = 1:NUM_SCENARIOS
        row = '';
        for pt = 1:NUM_POINTS
            slot = (sc-1)*NUM_POINTS + pt;
            idx  = find(foundSlot == slot, 1);
            if ~isempty(idx)
                row = [row sprintf('  Pt%d:OK', pt)]; %#ok<AGROW>
            else
                row = [row sprintf('  Pt%d:--', pt)]; %#ok<AGROW>
            end
        end
        fprintf('    Scn%d:%s\n', sc, row);
    end

    % outputFilename = [subject '_graspERD_FT.mat'];
    outputFilename = [subject '_exitERS_FT.mat'];
    save(fullfile(save_path, outputFilename), 'data');
    fprintf('  Saved: %s\n', outputFilename);
end