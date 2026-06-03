clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/fieldtrip-20241219';
ft_defaults;
addpath '/home/acatalano/Documents/eeglab_current/eeglab2025.0.0';
eeglab;

% base_path = '/home/acatalano/Desktop/Intuitive/IE_EO_Puliti';
% subjects = {'IE02','IE03','IE04', 'IE06', 'IE07', 'IE08', 'IE09', 'IE10',};
subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/IR';

images_path = '/home/acatalano/Desktop/Intuitive/';  % fixed typo (added /home/acatalano)

conditions = {'EO1', 'EO2'};
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 14; 15 25; 25 35];
nSubj = length(subjects);
nBands = length(bands);
nChan = 32;

RestingStateEO1_allSbjMatrix = nan(nSubj, nChan, 77);
RestingStateEO2_allSbjMatrix = nan(nSubj, nChan, 77);
%% Frequency analysis on all frequency and normalization of power distributetd on channels
all_data_cond1_norm = cell(length(subjects), 1);
all_data_cond2_norm = cell(length(subjects), 1);
EEG_reference = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');


for i = 1:length(subjects)
    subject = subjects{i};
    eegFilePath = base_path;


    for cond = 1:length(conditions)
        condition = conditions{cond};
        eeg_filename = [subject '_' condition '_final.set'];
        converted_file = [subject '_' condition '_Fieldtrip.mat'];

        EEG = pop_loadset('filename', eeg_filename, 'filepath', eegFilePath);
        load(fullfile(eegFilePath, converted_file));

        for ch = 1:numel(data.label)
            vals = cellfun(@(x) x(ch,:), data.trial, 'UniformOutput', false);
            if all(cellfun(@(x) all(isnan(x)), vals))
                fprintf('Channel %s is all NaN\n', data.label{ch});
            end
        end

        % Frequency analysis configuration
        cfg = [];
        cfg.output = 'pow';
        cfg.method = 'mtmfft';
        cfg.taper = 'hanning';
        cfg.pad = 'nextpow2';
        cfg.foi = 2:0.5:40;
        cfg.keeptrials = 'no';
        cfg.channel = 'EEG';

        TFRhann = ft_freqanalysis(cfg, data);
        
        % ===== Reorder FieldTrip channels to match EEGLAB order =====
        eeg_labels = {EEG_reference.chanlocs.labels}';   % EEGLAB reference order
        ft_labels  = TFRhann.label;           % Current FieldTrip order

        % Find matching indices
        [~, reorder_idx] = ismember(eeg_labels, ft_labels);
        
        % Safety check
        if any(reorder_idx == 0)
            error('Channel mismatch between EEGLAB and FieldTrip labels.');
        end
        
        % Reorder power spectrum (chan × freq)
        TFRhann.powspctrm = TFRhann.powspctrm(reorder_idx, :);
        
        % Reorder labels
        TFRhann.label = eeg_labels(:);
        % Extract XYZ coordinates from EEGLAB
        X = [EEG_reference.chanlocs.X]';
        Y = [EEG_reference.chanlocs.Y]';
        Z = [EEG_reference.chanlocs.Z]';
        TFRhann.elec.label   = {EEG_reference.chanlocs.labels}';
        TFRhann.elec.chanpos = [X Y Z];
        TFRhann.elec.elecpos = [X Y Z];

        for b = 1:length(bands)

            fmin = freq_ranges(b,1);
            fmax = freq_ranges(b,2);
        
            fs = find(TFRhann.freq <= fmin, 1, 'last');
            fe = find(TFRhann.freq <= fmax, 1, 'last');
        
            bandpow = TFRhann.powspctrm(:, fs:fe);
        
            % global mean across channels and freq in band
            bandmean = nanmean(bandpow(:));
        
            bandfrac = (bandpow - bandmean) ./ bandmean;
        
            % mean across frequencies → channel vector
            channels_band = squeeze(nanmean(bandfrac, 2));   % channels × 1
        end
        
        pow_norm = (TFRhann.powspctrm(:,:, :, :) - nanmean(TFRhann.powspctrm(:,:, :, :), [1 2 3 4])) ./ nanmean(TFRhann.powspctrm(:,:, :, :), [1 2 3 4]);
       % ===== Create normalized TFR structure =====
        TFRhann_norm = TFRhann;
        TFRhann_norm.powspctrm = pow_norm;
        
        % ===== Store =====
        if cond == 1
            all_data_cond1_norm{i} = TFRhann_norm;
            RestingStateEO1_allSbjMatrix(i,:,:) = TFRhann_norm.powspctrm;
        else
            all_data_cond2_norm{i} = TFRhann_norm;
            RestingStateEO2_allSbjMatrix(i, :,:) = TFRhann_norm.powspctrm;
        end
        
    end

    
end


