% Task_Exp_ClusterFirstLast.m
% EXPERTS (IE), Task 2: cluster-based permutation test, FIRST vs LAST
% repetition of each subject, on the Grasp (ERD) and Exit (ERS) epochs.
% Same procedure as Task_Res_ClusterFirstLast.m (residents), so the two
% groups can be compared.
%
% Input : IE_Task/Task2/Task2_norm_grasp_allExp.mat , Task2_norm_exit_allExp.mat
%         cell {1 x subj}, each powspctrm = [80 slots x chan x freq x time],
%         already normalised (Task2_fft_Exp.m). Slot = (rep-1)*4 + point.
%
% Definition of first / last repetition (per subject, per condition):
%   a repetition = 4 suture points. It counts as usable if at least
%   MIN_POINTS of its 4 points have data in that condition.
%   FIRST = earliest N_AVG usable repetitions, LAST = latest N_AVG usable ones.
%   N_AVG = 1 reproduces the residents' test (single first vs single last
%   repetition); N_AVG = 3 is the older first-3 vs last-3 comparison.
%   Power of a repetition = mean over its usable points.
%   Subjects with fewer than 2*N_AVG usable repetitions are excluded.
%
% Test: per band, power averaged over the time window and frequency band, one
% value per channel; paired (depsamplesT) montecarlo cluster test over channels.
%   ERD window (grasp-locked): -0.5 to 1.0 s
%   ERS window (exit-locked) : -2.0 to 0.0 s
%
% Output: DataStructures/Task_ClusterFirstLast_Experts_N<N_AVG>.mat
%         figures (t-maps with significant channels) saved as PNG in
%         DataStructures/Figures_Exp_ClusterFirstLast/

clear; close all; clc;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
out_dir   = '/home/acatalano/Desktop/Intuitive/DataStructures';
fig_dir   = fullfile(out_dir, 'Figures_Exp_ClusterFirstLast');
ref_file  = 'IR06_EO_downS_filt.set';
ref_path  = '/home/acatalano/Desktop/Intuitive/';
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

NUM_REPS = 20;  NUM_POINTS = 4;
MIN_POINTS = 2;                 % usable points needed to accept a repetition
N_LIST     = [1 3];             % repetitions averaged at each end (1 = residents' test)
NUM_PERM   = 1000;
TOL        = 1e-6;

bands = {'Theta','Alpha','Beta','Gamma'};
freq_ranges = [4 8; 8 15; 15 25; 25 35];

cond(1).name = 'graspERD'; cond(1).file = 'Task2_norm_grasp_allExp.mat'; cond(1).win = [-0.5 1.0];
cond(2).name = 'exitERS';  cond(2).file = 'Task2_norm_exit_allExp.mat';  cond(2).win = [-2.0 0.0];

EEG_ref = pop_loadset('filename', ref_file, 'filepath', ref_path);

for N_AVG = N_LIST
    Results = struct();
    for c = 1:numel(cond)
        fprintf('\n##### %s | N_AVG = %d #####\n', cond(c).name, N_AVG);
        S = load(fullfile(base_path, cond(c).file));
        fn = fieldnames(S); allTF = S.(fn{1}); subjects = S.subjects;
        nSubj = numel(allTF);
        ref   = allTF{1};
        nChan = numel(ref.label);

        firstV = cell(1, numel(bands));  lastV = cell(1, numel(bands));
        used   = nan(nSubj, 2*N_AVG);
        keep   = false(nSubj, 1);

        for s = 1:nSubj
            tf = allTF{s};  pw = tf.powspctrm;                     % [80 x chan x freq x time]
            hasData = squeeze(any(any(~isnan(pw), 2), [3 4])); hasData = hasData(:);
            nPts    = sum(reshape(hasData, NUM_POINTS, NUM_REPS), 1);          % 1 x 20
            u = find(nPts >= MIN_POINTS);
            if numel(u) < 2*N_AVG
                fprintf('  %s: only %d usable repetitions, excluded\n', subjects{s}, numel(u));
                continue;
            end
            reps = [u(1:N_AVG), u(end-N_AVG+1:end)];
            used(s,:) = reps; keep(s) = true;

            tIdx = find(tf.time >= cond(c).win(1)-TOL & tf.time <= cond(c).win(2)+TOL);
            for b = 1:numel(bands)
                fIdx = find(tf.freq >= freq_ranges(b,1)-TOL & tf.freq <= freq_ranges(b,2)+TOL);
                for w = 1:2
                    rr = reps((w-1)*N_AVG + (1:N_AVG));
                    v = nan(N_AVG, nChan);
                    for k = 1:N_AVG
                        slots = (rr(k)-1)*NUM_POINTS + (1:NUM_POINTS);
                        x = pw(slots, :, fIdx, tIdx);
                        x = squeeze(mean(mean(x, 4, 'omitnan'), 3, 'omitnan'));   % [4 x chan]
                        v(k,:) = mean(x, 1, 'omitnan');
                    end
                    x = mean(v, 1, 'omitnan');
                    if w == 1, firstV{b}(s,:) = x; else, lastV{b}(s,:) = x; end
                end
            end
            fprintf('  %s: first reps %s | last reps %s\n', subjects{s}, mat2str(used(s,1:N_AVG)), mat2str(used(s,N_AVG+1:end)));
        end

        nKeep = nnz(keep);
        fprintf('Subjects included: %d / %d\n', nKeep, nSubj);

        cfg_n = []; cfg_n.method = 'distance'; cfg_n.neighbourdist = 1;
        for b = 1:numel(bands)
            mk = @(M) struct('label', {ref.label}, 'freq', mean(freq_ranges(b,:)), ...
                'dimord', 'subj_chan_freq', 'powspctrm', reshape(M(keep,:), nKeep, [], 1), 'elec', ref.elec);
            Gf = mk(firstV{b});  Gl = mk(lastV{b});

            cfg = [];
            cfg.method = 'montecarlo'; cfg.statistic = 'ft_statfun_depsamplesT';
            cfg.correctm = 'cluster'; cfg.clusteralpha = 0.05; cfg.clusterstatistic = 'maxsum';
            cfg.minnbchan = 2; cfg.tail = 0; cfg.clustertail = 0; cfg.alpha = 0.05;
            cfg.numrandomization = NUM_PERM;
            cfg.neighbours = ft_prepare_neighbours(cfg_n, Gf);
            cfg.design = [1:nKeep 1:nKeep; ones(1,nKeep) 2*ones(1,nKeep)];
            cfg.uvar = 1;  cfg.ivar = 2;

            stat = ft_freqstatistics(cfg, Gl, Gf);                     % last - first
            Results.(cond(c).name).(bands{b}) = stat;

            sigP = []; sigN = [];
            if isfield(stat,'posclusters') && ~isempty(stat.posclusters)
                for k = find([stat.posclusters.prob] < 0.05), sigP = [sigP; find(stat.posclusterslabelmat == k)]; end %#ok<AGROW>
            end
            if isfield(stat,'negclusters') && ~isempty(stat.negclusters)
                for k = find([stat.negclusters.prob] < 0.05), sigN = [sigN; find(stat.negclusterslabelmat == k)]; end %#ok<AGROW>
            end
            el = [sigP(:); sigN(:)];
            allp = 1;
            if isfield(stat,'posclusters') && ~isempty(stat.posclusters), allp = [allp, stat.posclusters.prob]; end
            if isfield(stat,'negclusters') && ~isempty(stat.negclusters), allp = [allp, stat.negclusters.prob]; end
            minp = min(allp);
            if numel(allp) == 1
                fprintf('  %s: no cluster formed (no neighbouring channels passed the cluster-forming threshold)\n', bands{b});
            else
                fprintf('  %s: %d significant channels (pos %d, neg %d); smallest cluster p = %.3f\n', ...
                    bands{b}, numel(el), numel(sigP), numel(sigN), minp);
            end

            f = figure('Name', sprintf('%s %s N%d', cond(c).name, bands{b}, N_AVG), 'Color', 'w');
            topoplot(stat.stat, EEG_ref.chanlocs, 'gridscale', 100, 'headrad', 0.61, ...
                'electrodes', 'off', 'maplimits', [-5 5], 'emarker2', {el, 'o', [0 0 0], 5, 1});
            colorbar;
            title(sprintf('EXPERTS %s | %s (%d-%d Hz) | last vs first (t), N=%d, n_{avg}=%d', ...
                cond(c).name, bands{b}, freq_ranges(b,1), freq_ranges(b,2), nKeep, N_AVG));
            print(f, fullfile(fig_dir, sprintf('Exp_%s_%s_N%d.png', cond(c).name, bands{b}, N_AVG)), '-dpng', '-r110');
        end
        Results.(cond(c).name).usedReps = used;
        Results.(cond(c).name).included = subjects(keep);
    end
    out_file = fullfile(out_dir, sprintf('Task_ClusterFirstLast_Experts_N%d.mat', N_AVG));
    save(out_file, 'Results', 'bands', 'freq_ranges', 'cond', 'MIN_POINTS', 'N_AVG');
    fprintf('\nSaved: %s\n', out_file);
end
