% Task_Res_ClusterFirstLast.m
% RESIDENTS: cluster-based permutation test, FIRST vs LAST repetition, grasp (ERD) and exit (ERS) epochs.
% Same structure as Task_Res_ClusterBased.m (descriptives per subject -> grand average -> mean over time -> cluster test).
% Input: IR_norm_grasp.mat / IR_norm_exit.mat (Task_Res_TFR_claude.m): one normalised TFR per resident, 240 slots each,
%        slot = (scenario-1)*40 + (rep-1)*4 + point, empty slots are NaN.
% FIRST = first repetition (scenario, rep) with data, LAST = last repetition with data; all its suture points are used.

clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

base_path = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref';
out_file  = '/home/acatalano/Desktop/Intuitive/DataStructures/Task_ClusterFirstLast_Residents_avgref.mat';
fig_dir   = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ClusterFirstLast_avgref';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

bands       = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 15; 15 25; 25 35];

epochs     = {'grasp', 'exit'};
latency    = [-0.5 1.0; -2.0 0.0];   % ERD window (grasp-locked) | ERS window (exit-locked)

EEG = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');
Clusterstatistic = struct();

for e = 1:length(epochs)
    load(fullfile(base_path, ['IR_norm_' epochs{e} '.mat']));     % IR_norm_grasp / IR_norm_exit, subjects
    TFR_allSubj = eval(['IR_norm_' epochs{e}]);
    nSubj = length(TFR_allSubj);
    elec  = TFR_allSubj{1}.elec;

    first_rep = cell(nSubj,1);
    last_rep  = cell(nSubj,1);
    for i = 1:nSubj
        tf_sngl_subj = TFR_allSubj{i};

        % slots with data -> repetitions (4 slots each) with data
        hasData = any(~isnan(tf_sngl_subj.powspctrm(:,:,:)), [2 3]);        % [240 x 1]
        repData = find(any(reshape(hasData, 4, []), 1));                     % repetitions 1..60 with data
        firstSlots = (repData(1)-1)*4 + (1:4);
        lastSlots  = (repData(end)-1)*4 + (1:4);
        firstSlots = firstSlots(hasData(firstSlots));                          % only the suture points with data
        lastSlots  = lastSlots(hasData(lastSlots));
        fprintf('%s: first = S%d R%d (%d points) | last = S%d R%d (%d points)\n', subjects{i}, ...
            ceil(repData(1)/10), mod(repData(1)-1,10)+1, numel(firstSlots), ceil(repData(end)/10), mod(repData(end)-1,10)+1, numel(lastSlots));

        cfg = [];
        cfg.variance      = 'no';
        cfg.jackknife     = 'no';
        cfg.keeptrials    = 'no';
        cfg.channel       = 'all';
        cfg.trials        = firstSlots;          % first repetition
        cfg.frequency     = 'all';
        cfg.latency       = latency(e,:);
        first_rep{i} = ft_freqdescriptives(cfg, tf_sngl_subj);
        cfg.trials        = lastSlots;           % last repetition
        last_rep{i}  = ft_freqdescriptives(cfg, tf_sngl_subj);
    end
    clear TFR_allSubj tf_sngl_subj
    eval(['clear IR_norm_' epochs{e}]);

    cfg1 = [];
    cfg1.keepindividual = 'yes';
    GA_first = ft_freqgrandaverage(cfg1, first_rep{:});
    GA_first.elec = elec;
    GA_last  = ft_freqgrandaverage(cfg1, last_rep{:});
    GA_last.elec = elec;

    % mean over the time window
    GA_first_notime = GA_first;
    GA_last_notime  = GA_last;
    GA_first_notime.dimord = 'subj_chan_freq';
    GA_last_notime.dimord  = 'subj_chan_freq';
    GA_first_notime.powspctrm = mean(GA_first.powspctrm, 4, 'omitnan');
    GA_last_notime.powspctrm  = mean(GA_last.powspctrm, 4, 'omitnan');
    GA_first_notime = rmfield(GA_first_notime, 'time');
    GA_last_notime  = rmfield(GA_last_notime, 'time');

    %% cluster-based permutation test, one per band
    for b = 1:length(bands)
        cfg = [];
        cfg.channel          = 'EEG';
        cfg.frequency        = [freq_ranges(b,1) freq_ranges(b,2)];
        cfg.avgoverfreq      = 'yes';
        cfg.method           = 'montecarlo';
        cfg.statistic        = 'ft_statfun_depsamplesT';  % paired t-test
        cfg.correctm         = 'cluster';
        cfg.clusteralpha     = 0.05;
        cfg.clusterstatistic = 'maxsum';
        cfg.minnbchan        = 2;
        cfg.tail             = 0;
        cfg.clustertail      = 0;
        cfg.alpha            = 0.05;
        cfg.numrandomization = 1000;      % number of permutations

        cfg_neighb = [];
        cfg_neighb.method        = 'distance';
        cfg_neighb.neighbourdist = 1;     % electrodes on a unit sphere: 5-10 neighbours per channel (mean 8)
        cfg.neighbours       = ft_prepare_neighbours(cfg_neighb, GA_first_notime);

        subj = nSubj;                     % was fixed to 21 in Task_Res_ClusterBased.m (20 residents)
        design = zeros(2,2*subj);
        for i = 1:subj
            design(1,i) = i;
        end
        for i = 1:subj
            design(1,subj+i) = i;
        end
        design(2,1:subj)        = 1;
        design(2,subj+1:2*subj) = 2;

        cfg.design   = design;
        cfg.uvar     = 1;
        cfg.ivar     = 2;

        stat = ft_freqstatistics(cfg, GA_last_notime, GA_first_notime);   % last - first
        Clusterstatistic.(epochs{e}).(bands{b}) = stat;

        % channels of the SIGNIFICANT clusters only (p < 0.05)
        el = [];
        if isfield(stat, 'posclusters') && ~isempty(stat.posclusters)
            for k = find([stat.posclusters.prob] < cfg.alpha), el = [el; find(stat.posclusterslabelmat == k)]; end
        end
        if isfield(stat, 'negclusters') && ~isempty(stat.negclusters)
            for k = find([stat.negclusters.prob] < cfg.alpha), el = [el; find(stat.negclusterslabelmat == k)]; end
        end

        fig = figure;
        topoplot(stat.stat, EEG.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-5 5], 'emarker2', {el, 'o', [0 0 0], 5, 1});
        colorbar;
        title(sprintf('%s | %s band (%d-%d Hz) | last vs first, N = %d', epochs{e}, bands{b}, freq_ranges(b,1), freq_ranges(b,2), subj));
        exportgraphics(fig, fullfile(fig_dir, sprintf('IR_ClusterFirstLast_%s_%s_avgref.png', epochs{e}, bands{b})), 'Resolution', 300);
    end
end

save(out_file, 'Clusterstatistic', 'subjects', 'bands', 'freq_ranges', 'latency');
