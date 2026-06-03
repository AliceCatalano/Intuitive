clear, clc, close all

addpath '/home/acatalano/Documents/eeglab_current/eeglab2025.0.0';
eeglab;
%subj x trial x chan x freq
% subjects = {'IE02','IE03','IE04', 'IE06', 'IE07', 'IE08', 'IE09', 'IE10',};
% base_path = '/home/acatalano/Desktop/Intuitive/IE_EO_Puliti';
subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/IR';

conditions = {'EO1', 'EO2'};
% Loop through each subject/session
for i = 1:length(subjects)
    subject = subjects{i};
    
    for cond = 1:length(conditions)
        condition = conditions{cond};
        eegFileName = [subject '_' condition '_final.set'];
        %eegFiles = {'EO1_cleaned.set', 'EO2_cleaned.set'};

        % Load EEG data
        EEG = pop_loadset('filename', eegFileName, 'filepath', base_path);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname',eegFileName, 'gui', 'off');
        EEG = eeg_checkset(EEG);

        % Compute the time vector
        timeVector = (0:length(EEG.data)-1) / EEG.srate;

        % Define the event times
        eventTimes = 1:6:timeVector(end);

        % Add events to the EEG structure
        for k = 1:length(eventTimes)
            n_events = length(EEG.event);
            EEG.event(n_events+1).type = 'R';
            EEG.event(n_events+1).latency = find(timeVector >= eventTimes(k), 1);
            EEG.event(n_events+1).urevent = n_events + 1;
        end

        % Save the processed EEG dataset with events
        saveFileName = [eegFileName(1:end-4) '_with_events.set'];
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'gui', 'off');
        EEG = pop_saveset(EEG, 'filename', saveFileName, 'filepath', base_path);
        
        % Create epochs based on 'R' events
        EEG = pop_epoch(EEG, {'R'}, [-1 5], 'newname',[eegFileName(1:end-4) '_epochs'], 'epochinfo', 'yes');
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'savenew', fullfile(base_path, [eegFileName(1:end-4) '_epochs.set']), 'gui', 'off');
        
        % Optionally, plot the EEG data
        pop_eegplot(EEG, 1, 1, 1);
        eeglab redraw;
    end
end