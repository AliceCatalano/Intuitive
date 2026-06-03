clear; clc; close all;
restoredefaultpath;

addpath '/home/acatalano/Documents/fieldtrip-20241219';
ft_defaults;
addpath '/home/acatalano/Documents/eeglab_current/eeglab2025.0.0';
% base_path = '/home/acatalano/Desktop/Intuitive/IE_EO_Puliti';
% 
% subjects = {'IE02','IE03','IE04', 'IE06', 'IE07', 'IE08', 'IE09', 'IE10',};
subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/IR';

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

for i = 1:length(subjects)
    subject = subjects{i};
    eegFilePath = base_path;
    %datasetFilename = [subject '_EO1_final_epochs.set'];
    datasetFilename = [subject '_EO2_final_epochs.set'];
    fullInputPath = fullfile(eegFilePath, datasetFilename);
    disp(['Processing file: ' fullInputPath]);
    
    % Load the EEG data for the current subject
    EEG = pop_loadset('filename', datasetFilename, 'filepath', eegFilePath);
    %[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', [subject '_EO1_Fieldtrip'], 'gui', 'off');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', [subject '_EO2_Fieldtrip'], 'gui', 'off');
    EEG = eeg_checkset(EEG);
    
    data = eeglab2fieldtrip(EEG, 'preprocessing', 'none');
    
    % Save the FieldTrip data
    %outputFilename = [subject '_EO1_Fieldtrip.mat'];
    outputFilename = [subject '_EO2_Fieldtrip.mat'];
    outputFilepath = fullfile(eegFilePath, outputFilename);
    save(outputFilepath, 'data');
end
