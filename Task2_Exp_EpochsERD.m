% Task2_Exp_EpochsERD.m
% Epochs around G%d_R%02d events with window [-0.8, 1.5]s
% Saves: IE_Task/*_Task2_graspERD_epochs.set

clear, clc, close all
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0'
eeglab;

subjects     = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path    = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
epoch_window = [-0.8 1.5];

for i = 1:length(subjects)
    subject = subjects{i};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_Task2_graspERD_events.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');

    allTypes    = {EEG.event.type};
    graspEvents = {};
    for ev = 1:length(allTypes)
        evType = allTypes{ev};
        if ~isempty(regexp(evType, '^G\d+_R\d+$', 'once'))
            if ~ismember(evType, graspEvents)
                graspEvents{end+1} = evType;
            end
        end
    end

    fprintf('  Found %d unique G*_R* event types\n', length(graspEvents));
    if ~isempty(graspEvents)
        fprintf('  Events: %s\n', strjoin(graspEvents, ', '));
    end

    if isempty(graspEvents)
        warning('No G*_R* events found for subject %s, skipping.\n', subject);
        continue;
    end

    EEG_epoch = pop_epoch(EEG, graspEvents, epoch_window, ...
        'newname', [subject '_Task2_graspERD_epochs'], 'epochinfo', 'yes');
    fprintf('  Epochs created: %d\n', EEG_epoch.trials);

    EEG_epoch = pop_saveset(EEG_epoch, ...
        'filename', [subject '_Task2_graspERD_epochs.set'], 'filepath', base_path);
    eeglab redraw;
end