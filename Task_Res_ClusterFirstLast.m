% Task_Res_ClusterFirstLast.m
% RESIDENTS (IR): cluster-based permutation test, FIRST vs LAST repetition of
% each subject, on the Grasp (ERD) and Exit (ERS) epochs.
%
% Input : <subj>_IR_graspERD_TFR.mat , <subj>_IR_exitERS_TFR.mat  (Task_Res_TFR.m)
%         TFRhann.powspctrm = [240 slots x chan x freq x time], already normalised.
%         Slot = (scenario-1)*40 + (rep-1)*4 + point.
%
% Definition of first / last repetition (per subject, per condition):
%   a "repetition" = one (scenario, rep) pair = 4 suture points. It counts as
%   usable if at least MIN_POINTS of its 4 points have data in that condition.
%   FIRST = earliest usable repetition in task order (scenario, then rep)
%   LAST  = latest usable repetition in task order
%   Power of a repetition = mean over its usable points.
%   Subjects with fewer than 2 usable repetitions are excluded.
%   (set SCENARIO_FILTER to e.g. 1 to compare first vs last WITHIN one scenario)
%
% Test: per band, power averaged over the time window and frequency band, one
% value per channel; paired (depsamplesT) montecarlo cluster test over channels.
%   ERD window (grasp-locked): -0.5 to 1.0 s
%   ERS window (exit-locked) : -2.0 to 0.0 s
%
% Output: Task_ClusterFirstLast_Residents.mat  (stats, which repetitions were used)

clear; close all; clc;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/Task_ClusterFirstLast_Residents.mat';
ref_file   = 'IR06_EO_downS_filt.set';
ref_path   = '/home/acatalano/Desktop/Intuitive/';

NUM_SCENARIOS = 6;  NUM_REPS = 10;  NUM_POINTS = 4;
MIN_POINTS      = 2;        % usable points needed to accept a repetition
SCENARIO_FILTER = [];       % [] = all scenarios; e.g. 1 = only scenario 1
NUM_PERM        = 1000;
TOL             = 1e-6;

bands = {'Theta','Alpha','Beta','Gamma'};
freq_ranges = [4 8; 8 15; 15 25; 25 35];

cond(1).name = 'graspERD'; cond(1).win = [-0.5 1.0];
cond(2).name = 'exitERS';  cond(2).win = [-2.0 0.0];

T        = load(times_file);
subjects = T.subjects;
nSubj    = numel(subjects);

EEG_ref = pop_loadset('filename', ref_file, 'filepath', ref_path);

Results = struct();

for c = 1:numel(cond)
    fprintf('\n##### %s #####\n', cond(c).name);
    bandVal = cell(1, numel(bands));            % each: [subj x chan] first / last
    firstV  = cell(1, numel(bands));
    lastV   = cell(1, numel(bands));
    used    = nan(nSubj, 2);                    % repetition index (1..60) first/last
    keep    = false(nSubj, 1);
    ref     = [];                               % template freq structure

    for s = 1:nSubj
        f = fullfile(base_path, sprintf('%s_IR_%s_TFR.mat', subjects{s}, cond(c).name));
        if ~exist(f, 'file'), warning('%s missing', f); continue; end
        S = load(f); tf = S.TFRhann;
        pw = tf.powspctrm;                      % [240 x chan x freq x time]
        if isempty(ref), ref = tf; end

        % usable points per repetition
        hasData = squeeze(any(any(~isnan(pw), 2), [3 4]));   % [240 x 1]
        hasData = hasData(:);
        nPts    = sum(reshape(hasData, NUM_POINTS, NUM_REPS * NUM_SCENARIOS), 1);  % 1 x 60
        repSc   = ceil((1:NUM_REPS*NUM_SCENARIOS) / NUM_REPS);
        usable  = nPts >= MIN_POINTS;
        if ~isempty(SCENARIO_FILTER), usable = usable & ismember(repSc, SCENARIO_FILTER); end
        u = find(usable);
        if numel(u) < 2
            fprintf('  %s: <2 usable repetitions, excluded\n', subjects{s});
            continue;
        end
        used(s,:) = [u(1) u(end)];
        keep(s)   = true;

        tIdx = find(tf.time >= cond(c).win(1)-TOL & tf.time <= cond(c).win(2)+TOL);
        for b = 1:numel(bands)
            fIdx = find(tf.freq >= freq_ranges(b,1)-TOL & tf.freq <= freq_ranges(b,2)+TOL);
            for w = 1:2
                r     = used(s,w);
                slots = (r-1)*NUM_POINTS + (1:NUM_POINTS);
                x     = pw(slots, :, fIdx, tIdx);                       % [4 x chan x f x t]
                x     = squeeze(mean(mean(x, 4, 'omitnan'), 3, 'omitnan')); % [4 x chan]
                x     = mean(x, 1, 'omitnan');                          % [1 x chan]
                if w == 1, firstV{b}(s,:) = x; else, lastV{b}(s,:) = x; end
            end
        end
        fprintf('  %s: first rep #%d (S%d R%d, %d pts) | last rep #%d (S%d R%d, %d pts)\n', ...
            subjects{s}, used(s,1), repSc(used(s,1)), mod(used(s,1)-1,NUM_REPS)+1, nPts(used(s,1)), ...
            used(s,2), repSc(used(s,2)), mod(used(s,2)-1,NUM_REPS)+1, nPts(used(s,2)));
    end

    nKeep = nnz(keep);
    fprintf('Subjects included: %d / %d\n', nKeep, nSubj);

    cfg_n = []; cfg_n.method = 'distance'; cfg_n.neighbourdist = 1;
    for b = 1:numel(bands)
        mk = @(M) struct('label', {ref.label}, 'freq', mean(freq_ranges(b,:)), ...
            'dimord', 'subj_chan_freq', 'powspctrm', reshape(M(keep,:), nKeep, [], 1), 'elec', ref.elec);
        Gf = mk(firstV{b});  Gl = mk(lastV{b});

        cfg = [];
        cfg.method           = 'montecarlo';
        cfg.statistic        = 'ft_statfun_depsamplesT';
        cfg.correctm         = 'cluster';
        cfg.clusteralpha     = 0.05;
        cfg.clusterstatistic = 'maxsum';
        cfg.minnbchan        = 2;
        cfg.tail             = 0;
        cfg.clustertail      = 0;
        cfg.alpha            = 0.05;
        cfg.numrandomization = NUM_PERM;
        cfg.neighbours       = ft_prepare_neighbours(cfg_n, Gf);
        cfg.design           = [1:nKeep 1:nKeep; ones(1,nKeep) 2*ones(1,nKeep)];
        cfg.uvar = 1;  cfg.ivar = 2;

        stat = ft_freqstatistics(cfg, Gl, Gf);          % last - first
        Results.(cond(c).name).(bands{b}) = stat;

        sigP = []; sigN = [];
        if isfield(stat,'posclusters') && ~isempty(stat.posclusters)
            for k = find([stat.posclusters.prob] < 0.05), sigP = [sigP; find(stat.posclusterslabelmat == k)]; end %#ok<AGROW>
        end
        if isfield(stat,'negclusters') && ~isempty(stat.negclusters)
            for k = find([stat.negclusters.prob] < 0.05), sigN = [sigN; find(stat.negclusterslabelmat == k)]; end %#ok<AGROW>
        end
        el = [sigP(:); sigN(:)];
        fprintf('  %s: %d significant channels (pos %d, neg %d)\n', bands{b}, numel(el), numel(sigP), numel(sigN));

        figure('Name', sprintf('%s %s', cond(c).name, bands{b}));
        topoplot(stat.stat, EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, ...
            'electrodes', 'off', 'maplimits', [-5 5], 'emarker2', {el, 'o', [0 0 0], 5, 1});
        colorbar;
        title(sprintf('%s | %s (%d-%d Hz) | last vs first (t-values), N=%d', ...
            cond(c).name, bands{b}, freq_ranges(b,1), freq_ranges(b,2), nKeep));
    end
    Results.(cond(c).name).usedReps = used;
    Results.(cond(c).name).included = subjects(keep);
end

save(out_file, 'Results', 'subjects', 'bands', 'freq_ranges', 'cond', 'MIN_POINTS', 'SCENARIO_FILTER');
fprintf('\nSaved: %s\n', out_file);
