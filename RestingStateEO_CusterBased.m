clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/fieldtrip-20241219';
ft_defaults;
addpath '/home/acatalano/Documents/eeglab_current/eeglab2025.0.0';
eeglab;

subjects = {'IE02','IE03','IE04', 'IE06', 'IE07', 'IE08', 'IE09', 'IE10',};
base_path = '/home/acatalano/Desktop/Intuitive/IE_EO_Puliti';
% subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
% base_path = '/home/acatalano/Desktop/Intuitive/IR';

images_path = '/home/acatalano/Desktop/Intuitive/';  % fixed typo (added /home/acatalano)

conditions = {'EO1', 'EO2'};
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 14; 15 25; 25 35];
Clusterstatistic = struct();

for cond = 1:length(conditions)
    condition = conditions{cond};
    %filename = ['IR_' condition '.mat']; 
    filename = [condition '.mat']; 
    load(fullfile(images_path,filename))
end 

cfg = [];
cfg.keepindividual = 'yes';  % Keep individual subject data for later statistical comparison
grandavg_cond1 = ft_freqgrandaverage(cfg, all_data_cond1_norm{:});
grandavg_cond2 = ft_freqgrandaverage(cfg, all_data_cond2_norm{:});
grandavg_cond1.elec = all_data_cond2_norm{1,1}.elec;
grandavg_cond2.elec = all_data_cond2_norm{1,1}.elec;

%% Prepare data for cluster-based permutation test
EEG = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 14; 15 25; 25 35];
for b = 1:length(bands)
    fprintf('\n=== Running stats for %s band (%d–%d Hz) ===\n', bands{b}, freq_ranges(b,1), freq_ranges(b,2));
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
    cfg.neighbours       = ft_prepare_neighbours(cfg_neighb, grandavg_cond1);
    
    subj = 8;
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
    stat = ft_freqstatistics(cfg,  grandavg_cond2,grandavg_cond1);
    statCurr = stat;
    % Initialize so variables always exist
    Clusterstatistic.(bands{b}) = stat;


    nonzero_channelsN = [];
    nonzero_channelsP = [];
    if isfield(statCurr, 'negclusterslabelmat') && ~isempty(statCurr.negclusterslabelmat)
        %[row, col, col2] = ind2sub([64,1,21],find(any(statCurr.negclusterslabelmat ~= 0, 2)));
        nonzero_channelsN = find(any(statCurr.negclusterslabelmat ~= 0, 2));
    end
    if isfield(statCurr, 'posclusterslabelmat') && ~isempty(statCurr.posclusterslabelmat)
        %[row, col, col2] = ind2sub([64,1,21],find(any(statCurr.posclusterslabelmat ~= 0, 2)));
        nonzero_channelsP = find(any(statCurr.posclusterslabelmat ~= 0, 2));
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

%% Across subjects, is the mean power (averaged across frequencies) in EO2 different from EO1?

eo1=nanmean(grandavg_cond1.powspctrm(:,:,:),3); %[sbj, chn, freq]
eo2=nanmean(grandavg_cond2.powspctrm(:,:,:),3); %[sbj, chn, freq]
[H,P,CI,STATS] = ttest(eo2, eo1);
figure;
topoplot(STATS.tstat, EEG.chanlocs, 'gridscale', 100, 'headrad', 0.61, 'electrodes', 'off', 'maplimits', [-5 5]); 
cbar =  colorbar;
ylabel(cbar, 'T-values');  
title('T-values Topography - eo2 - eo1');

