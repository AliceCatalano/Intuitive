clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path = '/home/acatalano/Desktop/Intuitive/IR_Task';
% subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
images_path = '/home/acatalano/Desktop/Intuitive/IE_Task';
%%
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 14; 15 25; 25 35];
Clusterstatistic = struct();
load('IE_Task/TFtask_norm_allExp.mat')
load('IE_Task/TaskExp_allSbj.mat')
first_3 = cell(size(TFtask_norm_allExp,2),1);
last_3  = cell(size(TFtask_norm_allExp,2),1);
%% The matrix has the normalised powerspectrum of all the first repetitions of each tentative of the
% subject to complete the suture. We want to compare the activity between
% the final and initial repetitions. I will compare the first 3 tentatives
% vs the last 3 tentatives (because anyway you needed 3 tent to go to the
% next level)

for i = 1:size(TaskExp_allSbj,1)

    tf_sngl_subj = TFtask_norm_allExp{i};
    nTrials = size(tf_sngl_subj.powspctrm, 1);

    cfg = [];
    cfg.variance      = 'no'; % estimate standard error in the standard way (default = 'no')
    cfg.jackknife     = 'no'; % estimate standard error by means of the jack-knife (default = 'no')
    cfg.keeptrials    = 'no'; % estimate single trial power (useful for fourier data) (default = 'no')
    cfg.channel       = 'all';
    cfg.trials        =  1:3;  %primi 3 trial
    cfg.frequency     = 'all'; %keepfreq no oppure media
    cfg.latency       = [-1 5];

    first_3{i} = ft_freqdescriptives(cfg, tf_sngl_subj);
    cfg.trials = (nTrials-2):nTrials;    % dynamically the real last 3 trials for this subject
    last_3{i}  = ft_freqdescriptives(cfg, tf_sngl_subj);
end
cfg1 = [];
cfg1.keepindividual = 'yes';
GA_first3 = ft_freqgrandaverage(cfg1, first_3{:});
GA_first3.elec = TFtask_norm_allExp{1,1}.elec;
GA_last3  = ft_freqgrandaverage(cfg1, last_3{:});
GA_last3.elec = TFtask_norm_allExp{1,1}.elec;

GA_first3_notime = GA_first3;
GA_last3_notime= GA_last3;

GA_first3_notime.dimord = 'subj_chan_freq';
GA_last3_notime.dimord = 'subj_chan_freq';

% Vecchi indici necessari per vedere i cluster su valori di tempo inferiori
% 22:41 [0 1]s    % 42:61 [1 2]s    % 62:81 [2 3]s    % 82:101 [3 4]s   102:121 [4 5]s

GA_first3_notime.powspctrm = nanmean(GA_first3_notime.powspctrm(:,:,:,:),4);
GA_last3_notime.powspctrm = nanmean(GA_last3_notime.powspctrm(:,:,:,:),4);

%% Prepare data for cluster-based permutation test
EEG = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');

for b = 1:length(bands)
    cfg = [];
    cfg.channel          = 'EEG';
    cfg.latency          = 'all';   % Use all time points
    cfg.frequency        = [freq_ranges(b,1) freq_ranges(b,2)];  % Frequency range
    cfg.avgoverfreq      = 'yes';
    cfg.method           = 'montecarlo';
    cfg.statistic        = 'ft_statfun_depsamplesT';  % Paired samples t-test
    cfg.correctm         = 'cluster';
    cfg.clusteralpha     = 0.05;
    cfg.clusterstatistic = 'maxsum';
    cfg.minnbchan        = 2; %2
    cfg.tail             = 0;       % Two-sided test
    cfg.clustertail      = 0;
    cfg.alpha            = 0.05;
    cfg.numrandomization = 1000 ; %'all';     % Number of permutations

    cfg_neighb.method    = 'distance';
    cfg_neighb.neighbourdist = 1;
    cfg.neighbours       = ft_prepare_neighbours(cfg_neighb, GA_first3_notime);

    subj = 10;
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

    % Perform cluster-based permutation test
    stat = ft_freqstatistics(cfg,GA_last3_notime,GA_first3_notime);
    
    % Initialize so variables always exist
    Clusterstatistic.(bands{b}) = stat;

    nonzero_channelsN = [];
    nonzero_channelsP = [];
    if isfield(stat, 'negclusterslabelmat') && ~isempty(stat.negclusterslabelmat)
        %[row, col, col2] = ind2sub([64,1,21],find(any(statCurr.negclusterslabelmat ~= 0, 2)));
        nonzero_channelsN = find(any(stat.negclusterslabelmat ~= 0, 2));
    end
    if isfield(stat, 'posclusterslabelmat') && ~isempty(stat.posclusterslabelmat)
        %[row, col, col2] = ind2sub([64,1,21],find(any(statCurr.posclusterslabelmat ~= 0, 2)));
        nonzero_channelsP = find(any(stat.posclusterslabelmat ~= 0, 2));
    end
    el = [nonzero_channelsN(:); nonzero_channelsP(:)];


    figure;
    topoplot(stat.stat, EEG.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-5 5], 'emarker2', {el, 'o', [0 0 0], 5, 1});
    title(sprintf('Cluster test: %s band (%d–%d Hz)', bands{b}, freq_ranges(b,1), freq_ranges(b,2)));
    % ---- Plot results ----
    % figure;
    % cfg_plot = [];
    % cfg_plot.parameter = 'stat';
    % cfg_plot.alpha = 0.05;
    % cfg_plot.zlim = [-5 5];
    % layout = 'Layout.mat';
    % ft_clusterplot(cfg_plot, stat);
    %
end

