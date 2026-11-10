clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
images_path = base_path;
nSubj = length(subjects);

EEG_reference = pop_loadset('filename','IR06_EO_downS_filt.set','filepath','/home/acatalano/Desktop/Intuitive/');

for i = 1:length(subjects)
    subject = subjects{i};
    eegFilePath = base_path;

    eeg_filename   = [subject '_exitERS_epochs.set'];
    converted_file = [subject '_exitERS_FT.mat'];
    % eeg_filename   = [subject '_graspERD_epochs.set'];
    % converted_file = [subject '_graspERD_FT.mat'];

    EEG  = pop_loadset('filename', eeg_filename, 'filepath', eegFilePath);
    load(fullfile(eegFilePath, converted_file));

    for ch = 1:numel(data.label)
        vals = cellfun(@(x) x(ch,:), data.trial, 'UniformOutput', false);
        if all(cellfun(@(x) all(isnan(x)), vals))
            fprintf('Channel %s is all NaN\n', data.label{ch});
        end
    end

    cfg            = [];
    cfg.output     = 'fourier';
    cfg.taper      = 'hann';
    cfg.pad        = 'nextpow2';
    cfg.foi        = 2:0.5:40;
    cfg.method     = 'mtmconvol';
    cfg.t_ftimwin  = 0.2 * ones(size(cfg.foi));
    % cfg.toi        = -0.8:0.05:1.5;
    cfg.toi        = -2.5:0.05:0.5;
    cfg.keeptrials = 'yes';
    cfg.channel    = 'EEG';

    TFRhann = ft_freqanalysis(cfg, data);
    % TFRhann.fourierspctrm: [nTrials x nChan x nFreq x nTime] complex

    eeg_labels   = {EEG_reference.chanlocs.labels}';
    ft_labels    = TFRhann.label;
    [~, reorder_idx] = ismember(eeg_labels, ft_labels);

    if any(reorder_idx == 0)
        error('Channel mismatch between EEGLAB and FieldTrip labels.');
    end

    TFRhann.fourierspctrm = TFRhann.fourierspctrm(:, reorder_idx, :, :);
    TFRhann.label         = eeg_labels(:);

    X = [EEG_reference.chanlocs.X]';
    Y = [EEG_reference.chanlocs.Y]';
    Z = [EEG_reference.chanlocs.Z]';
    TFRhann.elec.label   = {EEG_reference.chanlocs.labels}';
    TFRhann.elec.chanpos = [X Y Z];
    TFRhann.elec.elecpos = [X Y Z];

    % Extract power and normalise (real-valued, safe to normalise)
    pow = abs(TFRhann.fourierspctrm).^2;  % [nTrials x nChan x nFreq x nTime]

    global_mean_pow = nanmean(pow(:));
    pow_norm        = (pow - global_mean_pow) / global_mean_pow;
    % This is the same normalisation you had before, now correctly on real power

    % --- Extract phase (complex unit vectors, do NOT normalise) ---
    phase_raw = TFRhann.fourierspctrm ./ abs(TFRhann.fourierspctrm);
    % [nTrials x nChan x nFreq x nTime] complex unit vectors, angle = phase

    % --- Store Fourier struct with original (non-normalised) coefficients ---
     Task1_exit_allExp{i} = TFRhann;
     %Task1_grasp_allExp{i} = TFRhann;
    % 
    % % --- Store normalised power matrix ---
    Task1exit_Exp_allSbj(i, 1:size(pow_norm,1), 1:size(pow_norm,2),1:size(pow_norm,3), 1:size(pow_norm,4)) = pow_norm;

    % --- Store phase matrix ---
    Task1exit_Phase_allSbj(i, 1:size(phase_raw,1), 1:size(phase_raw,2), 1:size(phase_raw,3), 1:size(phase_raw,4)) = phase_raw;
    % Task1grasp_Phase_allSbj(i, 1:size(phase_raw,1), 1:size(phase_raw,2),1:size(phase_raw,3), 1:size(phase_raw,4)) = phase_raw;

    fprintf('Subject %s done. pow_norm: [%s]  phase: [%s]\n', subject, num2str(size(pow_norm)), num2str(size(phase_raw)));
end

save(fullfile(images_path,'Task1exit_ps_allExp_struct.mat'),  'Task1_exit_allExp',       'subjects', '-v7.3');
save(fullfile(images_path,'Task1exit_Phase_allExpSbj.mat'),   'Task1exit_Phase_allSbj',  'subjects', '-v7.3');
% save(fullfile(images_path,'Task1grasp_ps_allExp_struct.mat'),  'Task1_grasp_allExp',       'subjects', '-v7.3');
% save(fullfile(images_path,'Task1grasp_Phase_allExpSbj.mat'),   'Task1grasp_Phase_allSbj',  'subjects', '-v7.3');