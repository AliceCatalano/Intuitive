% Task_Res_TFR.m
% RESIDENTS (IR): time-frequency analysis of the graspERD and exitERS epochs.
% Parameters identical to the experts (Task2_fft_Exp.m):
%   mtmconvol, hann taper, pad nextpow2, foi 2:0.5:40 Hz, 0.2 s window,
%   toi step 0.05 s, keeptrials, channel 'EEG'
%   graspERD toi -0.8:0.05:1.5 s | exitERS toi -2.5:0.05:0.5 s
%   channels reordered to the reference (IR06_EO_downS_filt.set) so ROI
%   indices are the same as for the experts
%   normalisation per subject (and per condition):
%       pow_norm = (pow - mean(pow)) / mean(pow), mean over trials, channels,
%       frequencies and times (NaN-padded slots ignored)
%
% Input : <subj>_IR_graspERD_FT.mat , <subj>_IR_exitERS_FT.mat   (variable data)
% Output: <subj>_IR_graspERD_TFR.mat , <subj>_IR_exitERS_TFR.mat (variable TFRhann)
%         TFRhann.powspctrm = [240 slots x chan x freq x time], normalised, single
%         TFRhann.trialinfo = [scenario rep point valid]
%
% One file per subject (instead of one 5-D matrix for everybody): with 240
% slots the all-subject matrix would not fit comfortably in memory.

clear; close all; clc;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
ref_file   = 'IR06_EO_downS_filt.set';
ref_path   = '/home/acatalano/Desktop/Intuitive/';

T        = load(times_file);
subjects = T.subjects;

EEG_reference = pop_loadset('filename', ref_file, 'filepath', ref_path);

cond(1).name = 'graspERD';  cond(1).toi = -0.8:0.05:1.5;
cond(2).name = 'exitERS';   cond(2).toi = -2.5:0.05:0.5;

for s = 1:numel(subjects)
    subject = subjects{s};

    for c = 1:numel(cond)
        in_name  = sprintf('%s_IR_%s_FT.mat',  subject, cond(c).name);
        out_name = sprintf('%s_IR_%s_TFR.mat', subject, cond(c).name);
        fprintf('\n=== %s [%s] ===\n', subject, cond(c).name);

        if ~exist(fullfile(base_path, in_name), 'file')
            warning('%s not found, skipping', in_name);
            continue;
        end
        S = load(fullfile(base_path, in_name));   % loads 'data'
        data = S.data;

        cfg            = [];
        cfg.output     = 'pow';
        cfg.taper      = 'hann';
        cfg.pad        = 'nextpow2';
        cfg.foi        = 2:0.5:40;
        cfg.method     = 'mtmconvol';
        cfg.t_ftimwin  = 0.2 * ones(size(cfg.foi));
        cfg.toi        = cond(c).toi;
        cfg.keeptrials = 'yes';
        cfg.channel    = 'EEG';

        TFRhann = ft_freqanalysis(cfg, data);

        % reorder channels to match the reference
        eeg_labels = {EEG_reference.chanlocs.labels}';
        [~, reorder_idx] = ismember(eeg_labels, TFRhann.label);
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

        % normalise: (pow - mean) / mean over trials, chan, freq, time
        mu = mean(TFRhann.powspctrm, 'all', 'omitnan');
        TFRhann.powspctrm = single((TFRhann.powspctrm - mu) ./ mu);

        % make sure the slot descriptors survive
        if ~isfield(TFRhann, 'trialinfo') || size(TFRhann.trialinfo,1) ~= size(TFRhann.powspctrm,1)
            TFRhann.trialinfo = data.trialinfo;
        end

        nValid = nnz(any(~isnan(reshape(TFRhann.powspctrm, size(TFRhann.powspctrm,1), [])), 2));
        fprintf('  powspctrm size: %s | slots with data: %d / %d\n', ...
            mat2str(size(TFRhann.powspctrm)), nValid, size(TFRhann.powspctrm,1));

        save(fullfile(base_path, out_name), 'TFRhann', '-v7.3');
        fprintf('  Saved: %s\n', out_name);
    end
end
