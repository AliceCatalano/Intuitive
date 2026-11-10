% Task2_Exp_EpochsERS.m
% Epochs around Ext%d_R%02d events with window [-2.5, 0.5]s
% Saves: IE_Task/*_Task2_exitERS_epochs.set

clear, clc, close all
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0'
eeglab;

subjects     = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path    = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
epoch_window = [-2.5 0.5];

for i = 1:length(subjects)
    subject = subjects{i};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_Task2_exitERS_events.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');

    allTypes   = {EEG.event.type};
    exitEvents = {};
    for ev = 1:length(allTypes)
        evType = allTypes{ev};
        if ~isempty(regexp(evType, '^Ext\d+_R\d+$', 'once'))
            if ~ismember(evType, exitEvents)
                exitEvents{end+1} = evType;
            end
        end
    end

    fprintf('  Found %d unique Ext*_R* event types\n', length(exitEvents));

    if isempty(exitEvents)
        warning('No Ext*_R* events found for subject %s, skipping.\n', subject);
        continue;
    end

    EEG_epoch = pop_epoch(EEG, exitEvents, epoch_window,'newname', [subject '_Task2_exitERS_epochs'], 'epochinfo', 'yes');
    fprintf('  Epochs created: %d\n', EEG_epoch.trials);

    EEG_epoch = pop_saveset(EEG_epoch,'filename', [subject '_Task2_exitERS_epochs.set'], 'filepath', base_path);
    eeglab redraw;
end