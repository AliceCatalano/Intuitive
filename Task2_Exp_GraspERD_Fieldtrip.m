% Task2_Exp_GraspERD_Fieldtrip.m
% Converts Task2 graspERD epochs to FieldTrip format.
% Each epoch is locked to a G<pt>_R<rep> event.
% Output: one tapered data structure per subject with trials indexed
% as (rep-1)*4 + point, giving 80 slots (20 reps x 4 points).
% NaN-padded where no epoch exists.

clear; clc; close all;
restoredefaultpath;

addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};

NUM_REPS   = 20;
NUM_POINTS = 4;
NUM_SLOTS  = NUM_REPS * NUM_POINTS;   % 80 total slots

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

for i = 1:length(subjects)
    subject = subjects{i};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_Task2_graspERD_epochs.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, ...
        'setname', [subject '_Task2_graspERD_FT'], 'gui', 'off');

    dataRaw  = eeglab2fieldtrip(EEG, 'preprocessing', 'none');
    nChan    = size(dataRaw.trial{1}, 1);
    nSamp    = size(dataRaw.trial{1}, 2);
    nanTrial = nan(nChan, nSamp);

    % Identify which (rep, point) each epoch belongs to
    % Locking event is G<pt>_R<rep>
    foundSlot = nan(EEG.trials, 1);   % linear index: (rep-1)*4 + pt

    for ep = 1:EEG.trials
        typ = EEG.epoch(ep).eventtype;
        lat = EEG.epoch(ep).eventlatency;
        if ~iscell(typ), typ = {typ}; end
        if ~iscell(lat), lat = {lat}; end

        isGrasp      = ~cellfun('isempty', regexp(typ, '^G\d+_R\d+$', 'once'));
        candidateIdx = find(isGrasp);

        if isempty(candidateIdx)
            warning('Subject %s epoch %d: no G*_R* event found, skip', subject, ep);
            continue;
        end

        candidateLat = cellfun(@(x) x, lat(candidateIdx));
        [~, closest] = min(abs(candidateLat));
        lockIdx      = candidateIdx(closest);

        tok = regexp(typ{lockIdx}, '^G(\d+)_R(\d+)$', 'tokens', 'once');
        if ~isempty(tok)
            pt  = str2double(tok{1});
            rep = str2double(tok{2});
            if pt >= 1 && pt <= NUM_POINTS && rep >= 1 && rep <= NUM_REPS
                foundSlot(ep) = (rep - 1) * NUM_POINTS + pt;
            end
        end
    end

    % Build tapered structure: 80 slots, NaN-padded
    data       = dataRaw;
    data.trial = cell(1, NUM_SLOTS);
    data.time  = cell(1, NUM_SLOTS);

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
    fprintf('  Trials: %d real epochs placed into %d slots (%d NaN-padded)\n', ...
        n_real, NUM_SLOTS, NUM_SLOTS - n_real);

    % Print slot map
    fprintf('  Slot map (rep x pt):\n');
    for rep = 1:NUM_REPS
        row = '';
        for pt = 1:NUM_POINTS
            slot = (rep-1)*NUM_POINTS + pt;
            idx  = find(foundSlot == slot, 1);
            if ~isempty(idx)
                row = [row sprintf('  Pt%d:OK', pt)]; %#ok<AGROW>
            else
                row = [row sprintf('  Pt%d:--', pt)]; %#ok<AGROW>
            end
        end
        fprintf('    Rep%02d:%s\n', rep, row);
    end

    outputFilename = [subject '_Task2_graspERD_FT.mat'];
    save(fullfile(base_path, outputFilename), 'data');
    fprintf('  Saved: %s\n', outputFilename);
end