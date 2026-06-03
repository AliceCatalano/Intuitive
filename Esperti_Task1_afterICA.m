clear, clc, close all
addpath '/home/acatalano/Documents/eeglab_current/eeglab2025.0.0'
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Load initial dataset
subject = input('Enter the subject name (e.g., IE#): ', 's');
datasetFilename = [subject '_Task1_ICA.set'];
baseFolderPath = '/home/acatalano/Desktop/Intuitive/IE_Task';
datasetPath = baseFolderPath;
EEG = pop_loadset('filename', datasetFilename, 'filepath', datasetPath);

% Store the loaded dataset
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);

%% Ask for components to remove
compToRemove = input('Enter the components to remove (e.g., [1 6 13]): ');

% Remove specified ICA components
EEG = pop_subcomp( EEG, compToRemove, 0);
EEG = eeg_checkset( EEG );
EEG = pop_reref( EEG, []);
EEG = pop_saveset( EEG, 'filename', [ subject, '_rejComp.set'], 'filepath', datasetPath);
eeglab redraw;
% Plot the spectrum and ask for user validation
figure; pop_spectopo(EEG, 1, [0 870448.0068], 'EEG', 'freq', [3 6 12 20], 'freqrange',[2 40], 'electrodes','off');
validSpectrum = input('Is the spectrum valid? Yes (1) or No (0): ');

% Check user response
if ~validSpectrum
    fprintf('Spectrum not valid. ');
    interpolate = input('Enter channels to interpolate (e.g., [1 2 5]): ');
    EEG = pop_interp(EEG, EEG.chanlocs(interpolate), 'spherical');
    figure; pop_spectopo(EEG, 1, [0 870448.0068], 'EEG', 'freq', [3 6 12 20], 'freqrange',[2 40], 'electrodes','off');
    
end

% Load full dataset with all channels
EEG_full = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive');
eeglab redraw;
%% Interpolate
channelsToInterpolate = input('Enter channels to interpolate (e.g., [1 2 5]): ');
EEG = pop_interp(EEG, EEG_full.chanlocs(channelsToInterpolate), 'spherical');

%% Rereference
% Save the dataset with subject ID in the file name
EEG = pop_saveset( EEG, 'filename', [subject, '_final.set'], 'filepath', datasetPath);
figure; pop_spectopo(EEG2, 1, [0 870448.0068], 'EEG', 'freq', [3 6 12 20], 'freqrange',[2 40], 'electrodes','off');title('EO2');
eset( EEG, 'filename', [subject, '_final.set'], 'filepath', datasetPath);
