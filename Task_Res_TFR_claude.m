% Task2_TFR_Experts.m
% Computes TFR for Task 2 (20 repetitions of scenario 4).
% Processes both graspERD (locked to grasp onset) and exitERS (locked to needle exit).
% Output matrices: (subjects x slots x channels x freqs x times)
%   slots = 80 = 20 reps x 4 suture points, indexed as (rep-1)*4 + pt

clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects = {'IR02','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref';

EEG_reference = pop_loadset('filename', 'IR06_EO_downS_filt.set','filepath', '/home/acatalano/Desktop/Intuitive/');

nSubj = length(subjects);

%% ---- GRASP ERD (locked to grasp onset, window [-0.8, 1.5]s) ----
Task2_norm_grasp_allExp = cell(1, nSubj);
grasp_IR_allSbj   = [];

for i = 1:nSubj
    subject = subjects{i};
    fprintf('\n=== GRASP ERD: Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_IR_graspERD_epochs.set'], ...
        'filepath', base_path);
    load(fullfile(base_path, [subject '_IR_graspERD_FT.mat']));  % loads 'data'

    cfg            = [];
    cfg.output     = 'pow';
    cfg.taper      = 'hann';
    cfg.pad        = 'nextpow2';
    cfg.foi        = 2:0.5:40;
    cfg.method     = 'mtmconvol';
    cfg.t_ftimwin  = 0.2 * ones(size(cfg.foi));
    cfg.toi        = -0.8:0.05:1.5;   % grasp-locked window
    cfg.keeptrials = 'yes';
    cfg.channel    = 'EEG';

    TFRhann = ft_freqanalysis(cfg, data);

    % Reorder channels to match reference
    eeg_labels = {EEG_reference.chanlocs.labels}';
    ft_labels  = TFRhann.label;
    [~, reorder_idx] = ismember(eeg_labels, ft_labels);
    if any(reorder_idx == 0)
        error('Channel mismatch for subject %s', subject);
    end
    TFRhann.powspctrm = TFRhann.powspctrm(:, reorder_idx, :, :);
    TFRhann.label     = eeg_labels(:);

    X = [EEG_reference.chanlocs.X]';
    Y = [EEG_reference.chanlocs.Y]';
    Z = [EEG_reference.chanlocs.Z]';
    TFRhann.elec.label   = {EEG_reference.chanlocs.labels}';
    TFRhann.elec.chanpos = [X Y Z];
    TFRhann.elec.elecpos = [X Y Z];

    % Normalize
    pow_norm = (TFRhann.powspctrm - nanmean(TFRhann.powspctrm, [1 2 3 4]))./ nanmean(TFRhann.powspctrm, [1 2 3 4]);

    TFRhann.powspctrm = pow_norm;
    IR_norm_grasp{i} = TFRhann;

    fprintf('  powspctrm size: %s\n', mat2str(size(pow_norm)));

    grasp_IR_allSbj(i, 1:size(pow_norm,1), 1:size(pow_norm,2),1:size(pow_norm,3), 1:size(pow_norm,4)) = pow_norm;   %#ok<AGROW>
end

save(fullfile(base_path, 'IR_norm_grasp.mat'),'IR_norm_grasp', 'subjects', '-v7.3');
save(fullfile(base_path, 'grasp_IR_allSbj.mat'),'grasp_IR_allSbj', 'subjects', '-v7.3');
fprintf('\n=== SAVED: grasp_IR_allSbj.mat ===\n');

%% ---- EXIT ERS (locked to needle exit, window [-2.5, 0.5]s) ----
IR_norm_exit = cell(1, nSubj);
exit_IR_allSbj   = [];

for i = 1:nSubj
    subject = subjects{i};
    fprintf('\n=== EXIT ERS: Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_IR_exitERS_epochs.set'],'filepath', base_path);
    load(fullfile(base_path, [subject '_IR_exitERS_FT.mat']));  % loads 'data'

    cfg            = [];
    cfg.output     = 'pow';
    cfg.taper      = 'hann';
    cfg.pad        = 'nextpow2';
    cfg.foi        = 2:0.5:40;
    cfg.method     = 'mtmconvol';
    cfg.t_ftimwin  = 0.2 * ones(size(cfg.foi));
    cfg.toi        = -2.5:0.05:0.5;   % exit-locked window
    cfg.keeptrials = 'yes';
    cfg.channel    = 'EEG';

    TFRhann = ft_freqanalysis(cfg, data);

    % Reorder channels
    eeg_labels = {EEG_reference.chanlocs.labels}';
    ft_labels  = TFRhann.label;
    [~, reorder_idx] = ismember(eeg_labels, ft_labels);
    if any(reorder_idx == 0)
        error('Channel mismatch for subject %s', subject);
    end
    TFRhann.powspctrm = TFRhann.powspctrm(:, reorder_idx, :, :);
    TFRhann.label     = eeg_labels(:);

    X = [EEG_reference.chanlocs.X]';
    Y = [EEG_reference.chanlocs.Y]';
    Z = [EEG_reference.chanlocs.Z]';
    TFRhann.elec.label   = {EEG_reference.chanlocs.labels}';
    TFRhann.elec.chanpos = [X Y Z];
    TFRhann.elec.elecpos = [X Y Z];

    % Normalize
    pow_norm = (TFRhann.powspctrm - nanmean(TFRhann.powspctrm, [1 2 3 4])) ./ nanmean(TFRhann.powspctrm, [1 2 3 4]);

    TFRhann.powspctrm = pow_norm;
    IR_norm_exit{i} = TFRhann;

    fprintf('  powspctrm size: %s\n', mat2str(size(pow_norm)));

    exit_IR_allSbj(i, 1:size(pow_norm,1), 1:size(pow_norm,2),1:size(pow_norm,3), 1:size(pow_norm,4)) = pow_norm;   %#ok<AGROW>
end

save(fullfile(base_path, 'IR_norm_exit.mat'),'IR_norm_exit', 'subjects', '-v7.3');
save(fullfile(base_path, 'exit_IR_allSbj.mat'),'exit_IR_allSbj', 'subjects', '-v7.3');
fprintf('\n=== SAVED: exit_IR_allSbj.mat ===\n');