clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;
subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
% base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';

bands = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 14; 15 25; 25 35];
images_path = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG'; 
nSubj = length(subjects);
nBands = length(bands);

EEG_reference = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');
for i = 1:length(subjects)
    subject = subjects{i};
    eegFilePath = fullfile(base_path);
    % % Create a figure for all topoplots (2x4)
    % fig1 = figure('Name', ['Power Topographies - ' subject], 'Position', [100 100 1200 600]);
    % %Figure 2: normalized topographies (1x2, conditions)
    % fig2 = figure('Name', ['Power Topographies (bands - ' subject], 'Position', [100 100 1200 600]);
    
    
    eeg_filename = [subject '_graspERD_epochs.set'];
    converted_file = [subject '_graspERD_FT.mat']; 
    % eeg_filename = [subject '_exitERS_epochs.set'];
    % converted_file = [subject '_exitERS_FT.mat'];
    EEG = pop_loadset('filename', eeg_filename, 'filepath', eegFilePath);
    load(fullfile(eegFilePath, converted_file));

    for ch = 1:numel(data.label)
        vals = cellfun(@(x) x(ch,:), data.trial, 'UniformOutput', false);
        if all(cellfun(@(x) all(isnan(x)), vals))
            fprintf('Channel %s is all NaN\n', data.label{ch});
        end
    end
    cfg = [];
    cfg.output = 'pow';
    cfg.taper = 'hann';
    cfg.pad = 'nextpow2';
    cfg.foi = 2:0.5:40;
    cfg.method     = 'mtmconvol';
    cfg.t_ftimwin  = 0.2 * ones(size(cfg.foi));
    % cfg.toi        = -2.5:0.05:0.5;
    cfg.toi        = -0.8:0.05:1.5;
    cfg.keeptrials = 'yes';
    cfg.channel = 'EEG';

    TFRhann = ft_freqanalysis(cfg, data);
    eeg_labels = {EEG_reference.chanlocs.labels}';      % EEGLAB reference order
    ft_labels  = TFRhann.label;                         % Current FieldTrip order
    [~, reorder_idx] = ismember(eeg_labels, ft_labels); % Find matching indices

    if any(reorder_idx == 0)
        error('Channel mismatch between EEGLAB and FieldTrip labels.');
    end

    % Reorder power spectrum (chan × freq)
    TFRhann.powspctrm = TFRhann.powspctrm(:,reorder_idx,:, :);

    % Reorder labels
    TFRhann.label = eeg_labels(:);

    X = [EEG_reference.chanlocs.X]';
    Y = [EEG_reference.chanlocs.Y]';
    Z = [EEG_reference.chanlocs.Z]';
    TFRhann.elec.label   = {EEG_reference.chanlocs.labels}';
    TFRhann.elec.chanpos = [X Y Z];
    TFRhann.elec.elecpos = [X Y Z];
    
    %TFRhann = taperSkippedTrials(TFRhann, subject);

    for b = 1:length(bands)
        fmin = freq_ranges(b,1);
        fmax = freq_ranges(b,2);

        fs = find(TFRhann.freq <= fmin, 1, 'last');
        fe = find(TFRhann.freq <= fmax, 1, 'last');

        bandfrac = (TFRhann.powspctrm(:, :, fs:fe,:) - nanmean(TFRhann.powspctrm(:, :, fs:fe,:),[3 2 4 1]) )./ nanmean(TFRhann.powspctrm(:, :, fs:fe,:),[3 2 4 1]);
        channels_band = squeeze(nanmean(bandfrac, [1 3 4])); % chan × 1
            
        % Ensure row vector

        % figure(fig1);
        % subplot(1, nBands, b);
        % topoplot(channels_band, EEG.chanlocs, 'electrodes', 'on', 'gridscale', 100, 'headrad', 0.65);
        % colorbar;
        % title([bands{b}]);
    end
    
    pow_norm = (TFRhann.powspctrm(:,:,:,:) - nanmean(TFRhann.powspctrm(:,:, :, :), [1 2 3 4])) ./ nanmean(TFRhann.powspctrm(:,:, :, :), [1 2 3 4]);
    
    TFRhann.powspctrm = pow_norm;
    % Task1_norm_exit_allExp{i} = TFRhann;
    Task1_norm_grasp_allExp{i} = TFRhann;
    size(TFRhann.powspctrm)
    % Task1exit_Exp_allSbj(i,1:size(pow_norm, 1), 1:size(pow_norm, 2), 1:size(pow_norm, 3), 1:size(pow_norm, 4)) = TFRhann.powspctrm;
    Task1grasp_Exp_allSbj(i,1:size(pow_norm, 1), 1:size(pow_norm, 2), 1:size(pow_norm, 3), 1:size(pow_norm, 4)) = TFRhann.powspctrm;
     
    % save(fullfile(images_path, 'Task1_norm_exit_allExp.mat'), 'Task1_norm_exit_allExp', 'subjects', '-v7.3');
    % save(fullfile(images_path, 'Task1exit_Exp_allSbj.mat'), 'Task1exit_Exp_allSbj', 'subjects', '-v7.3');
    save(fullfile(images_path, 'Task1_norm_grasp_allExp.mat'), 'Task1_norm_grasp_allExp', 'subjects', '-v7.3');
    save(fullfile(images_path, 'Task1grasp_Exp_allSbj.mat'), 'Task1grasp_Exp_allSbj', 'subjects', '-v7.3');
    
    % Average across frequencies in this band
    channels_band = squeeze(nanmean(pow_norm, [1 3 4]));
    % figure(fig2);
    % topoplot(channels_band, EEG.chanlocs, 'electrodes', 'on', 'gridscale', 100, 'headrad', 0.65);
    % colorbar;
    % title(['Topographies - ' subject]);
    % sgtitle(['Topographies - ' subject]);
    % save_filename = fullfile(images_path, [subject '_TopographiesChannelNorm.png']);
    % saveas(fig, save_filename);
    % close(fig);
end

