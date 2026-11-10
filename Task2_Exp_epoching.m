clear, clc, close all
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0'
eeglab;

subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/';

nScenes = 20;
epoch_window = [-1 5];  % matches cfg.toi in Task_Experts.m, gives ERD/S a pre-event baseline

for i = 1:length(subjects)
    subject = subjects{i};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_Task2_events.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');

    % Only the Start_S% events that actually exist for this subject
    allTypes = {EEG.event.type};
    candidateTypes = arrayfun(@(s) sprintf('Start_S%d', s), 1:nScenes, 'UniformOutput', false);
    startEvents = candidateTypes(ismember(candidateTypes, allTypes));

    fprintf('  Found %d/%d Start_S event types\n', length(startEvents), nScenes);

    if isempty(startEvents)
        warning('No Start_S events found for subject %s, skipping.\n', subject);
        continue;
    end

    % Scenes that never had a marker at all (missing before epoching even starts)
    missingScenes = setdiff(1:nScenes, cellfun(@(s) sscanf(s, 'Start_S%d'), startEvents));

    % Epoch around each Start_S event (trials < nScenes if some scenes are missing
    % or dropped by pop_epoch due to a boundary inside the window)
    EEG_epoch = pop_epoch(EEG, startEvents, epoch_window, 'newname', [subject '_Task2_epochs'], 'epochinfo', 'yes');
    fprintf('  Epochs created: %d/%d\n', EEG_epoch.trials, nScenes);

    % Which scenes survived epoching, by reading the locking event's type
    % string back out (closest-to-zero-latency Start_S match)
    survivedScenes = nan(EEG_epoch.trials, 1);
    fprintf('Trials: %d\n', EEG_epoch.trials);
    fprintf('Length of EEG_epoch.epoch: %d\n', length(EEG_epoch.epoch));
    fprintf('Length of EEG_epoch.event: %d\n', length(EEG_epoch.event));
    for ep = 1:EEG_epoch.trials
        typ = EEG_epoch.epoch(ep).eventtype;
        lat = EEG_epoch.epoch(ep).eventlatency;
        if ~iscell(typ), typ = {typ}; end
        if ~iscell(lat), lat = {lat}; end
        isStart = ~cellfun('isempty', regexp(typ, '^Start_S\d+$', 'once'));
        candidateIdx = find(isStart);
        if isempty(candidateIdx), continue; end
        candidateLat = cellfun(@(x) x, lat(candidateIdx));
        [~, closest] = min(abs(candidateLat));
        tok = regexp(typ{candidateIdx(closest)}, '^Start_S(\d+)$', 'tokens', 'once');
        if ~isempty(tok), survivedScenes(ep) = str2double(tok{1}); end
    end

    % Scenes that had a marker (were in startEvents) but got dropped by
    % pop_epoch anyway - almost always a boundary/discontinuity inside the window
    hadMarkerScenes = cellfun(@(s) sscanf(s, 'Start_S%d'), startEvents);
    droppedByEpoching = setdiff(hadMarkerScenes, survivedScenes(~isnan(survivedScenes)));

    fprintf('  Never had a marker (%d): %s\n', numel(missingScenes), mat2str(sort(missingScenes)));
    fprintf('  Dropped by pop_epoch, likely boundary in window (%d): %s\n', ...
        numel(droppedByEpoching), mat2str(sort(droppedByEpoching)'));

    EEG_epoch = pop_saveset(EEG_epoch, 'filename', [subject '_Task2_epochs.set'], 'filepath', base_path);
    eeglab redraw;
end