% Task_Res_PhaseShift.m
% RESIDENTS (IR): phase consistency (PLV / ITPC) of the Grasp (ERD) and Exit (ERS)
% locked epochs in 4 ROIs, same logic as the experts (Phaseshift_matGen_ExpT2.m +
% PhaseShift_expT2.m) with the corrections listed below.
%
% Input : <subj>_IR_graspERD_FT.mat , <subj>_IR_exitERS_FT.mat   (Task_Res_FieldtripERDERS.m)
%         Slot = (scenario-1)*40 + (rep-1)*4 + point ; NaN-padded slots are ignored.
%
% Phase per slot: complex Fourier coefficients (mtmconvol, hann, 0.2 s window,
% foi 4:0.5:35 Hz) -> unit phasors -> mean over the ROI channels -> re-normalised
% to unit length (the channel average shrinks the vector; the experts did not fix this).
%
% OPTION A (group, across subjects): for every (scenario, rep, point) slot the PLV
%   over the subjects that have that slot (>= MIN_SUBJ). Shown as scenario x point
%   (mean over the repetitions).
% OPTION B (within subject, across trials): for every subject and scenario the PLV
%   over all valid trials of that scenario (up to 10 reps x 4 points = 40, >= MIN_TRIALS).
%   (experts: across the 4 points only -> far too few trials)
% PLV is averaged over time in the analysis window (ERD -0.5..1.0 s, ERS -2.0..0 s)
% and over the frequency band.
%
% Corrections vs the expert code:
%  1) PLV is biased upward for small N (random phases give ~0.89/sqrt(N)). Besides the
%     raw PLV a bias-corrected value is stored: PLVc = sqrt(max(0,(N*PLV^2-1)/(N-1))),
%     0 = no consistency, 1 = perfect. Figures and tests use PLVc.
%  2) Mean phase = circular mean (angle of the time-averaged resultant vector), not
%     the arithmetic mean of angles (wrap-around at +-pi).
%  3) Statistics: per-subject Spearman correlation PLVc vs scenario, then signed-rank
%     test of the correlations against 0 (repeated measures), not Kruskal-Wallis.
%
% Output: DataStructures/PhaseAnalysis_Residents.mat   (no phasors saved, too big)

clear; close all; clc;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106'; ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0'; eeglab nogui;

% ORIGINAL (common reference): base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref';   % filtered + average reference
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
% ORIGINAL: out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/PhaseAnalysis_Residents.mat';
out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/PhaseAnalysis_Residents_avgref.mat';
fig_dir    = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_PhaseShift_avgref';
EEG_ref    = pop_loadset('filename','IR06_EO_downS_filt.set','filepath','/home/acatalano/Desktop/Intuitive/');

NUM_SC = 6; NUM_REPS = 10; NUM_PTS = 4; NUM_SLOTS = NUM_SC*NUM_REPS*NUM_PTS;
MIN_SUBJ = 8;          % option A: min subjects per slot
MIN_TRIALS = 8;        % option B: min trials per subject and scenario
foi = 4:0.5:35; nF = numel(foi);
bands(1).name = 'Beta';  bands(1).rng = [15 25];
bands(2).name = 'Alpha'; bands(2).rng = [8 15];

T = load(times_file); subjects = T.subjects; nSubj = numel(subjects);
ROI.MotorLeft = [15 20 10]; ROI.MotorRight = [13 19 9];
ROI.Visual = [29 30 31];    ROI.Frontal = [4 5 6];
roi_names = fieldnames(ROI); nROI = numel(roi_names);

cond(1).name = 'graspERD'; cond(1).toi = -0.8:0.05:1.5; cond(1).win = [-0.5 1.0]; cond(1).label = 'Grasp (ERD)';
cond(2).name = 'exitERS';  cond(2).toi = -2.5:0.05:0.5; cond(2).win = [-2.0 0.0]; cond(2).label = 'Exit (ERS)';
ft_warning off;

[pp,rr,ss] = ndgrid(1:NUM_PTS,1:NUM_REPS,1:NUM_SC);
slotSc = ss(:)'; slotRep = rr(:)'; slotPt = pp(:)';

R = struct();
for c = 1:2
    tw = find(cond(c).toi >= cond(c).win(1)-1e-6 & cond(c).toi <= cond(c).win(2)+1e-6);
    toi = cond(c).toi(tw); nT = numel(toi);
    Ph = complex(nan(nSubj, nROI, NUM_SLOTS, nF, nT, 'single'));

    %% 1) unit phasors per subject / ROI / slot
    for s = 1:nSubj
        fn = fullfile(base_path, sprintf('%s_IR_%s_FT.mat', subjects{s}, cond(c).name));
        if ~exist(fn,'file'), warning('%s missing', fn); continue; end
        D = load(fn); data = D.data;
        for r = 1:nROI
            labs = {EEG_ref.chanlocs(ROI.(roi_names{r})).labels};
            missing = setdiff(labs, data.label);
            if ~isempty(missing), error('%s [%s] ROI %s: missing %s', subjects{s}, cond(c).name, roi_names{r}, strjoin(missing,',')); end
            cfg = []; cfg.output='fourier'; cfg.method='mtmconvol'; cfg.taper='hann'; cfg.pad='nextpow2';
            cfg.foi = foi; cfg.t_ftimwin = 0.2*ones(size(foi)); cfg.toi = toi;
            cfg.keeptrials='yes'; cfg.channel=labs; cfg.feedback='no';
            tf = ft_freqanalysis(cfg, data);                    % fourierspctrm [slot x chan x f x t]
            z  = tf.fourierspctrm; z = z ./ abs(z);             % unit phasors
            m  = squeeze(mean(z, 2, 'omitnan'));                % [slot x f x t]
            m  = m ./ abs(m);                                   % back to unit length
            Ph(s,r,:,:,:) = single(m);
        end
        fprintf('[%s] %s phasors done\n', cond(c).name, subjects{s});
    end

    %% 2) OPTION A: across subjects, per (scenario, rep, point)
    PLVA = nan(nROI, nF, NUM_SC, NUM_REPS, NUM_PTS); PLVAc = PLVA; PhA = PLVA; NA = nan(nROI, NUM_SC, NUM_REPS, NUM_PTS);
    for r = 1:nROI
        for k = 1:NUM_SLOTS
            z = squeeze(Ph(:,r,k,:,:));                         % [subj x f x t]
            valid = ~all(isnan(reshape(z, nSubj, [])), 2);
            N = nnz(valid); sc = slotSc(k); rp = slotRep(k); pt = slotPt(k);
            NA(r,sc,rp,pt) = N;
            if N < MIN_SUBJ, continue; end
            res = squeeze(mean(z(valid,:,:), 1, 'omitnan'));    % [f x t] resultant vector
            plv = mean(abs(res), 2, 'omitnan');
            PLVA(r,:,sc,rp,pt)  = plv;
            PLVAc(r,:,sc,rp,pt) = sqrt(max(0, (N*plv.^2 - 1)/(N-1)));
            PhA(r,:,sc,rp,pt)   = angle(mean(res, 2, 'omitnan'));
        end
    end

    %% 3) OPTION B: within subject, across all trials of a scenario
    PLVB = nan(nSubj, nROI, nF, NUM_SC); PLVBc = PLVB; PhB = PLVB; NB = nan(nSubj, nROI, NUM_SC);
    for s = 1:nSubj
        for r = 1:nROI
            for sc = 1:NUM_SC
                idx = find(slotSc == sc);
                z = squeeze(Ph(s,r,idx,:,:));                   % [trials x f x t]
                valid = ~all(isnan(reshape(z, numel(idx), [])), 2);
                N = nnz(valid); NB(s,r,sc) = N;
                if N < MIN_TRIALS, continue; end
                res = squeeze(mean(z(valid,:,:), 1, 'omitnan'));
                plv = mean(abs(res), 2, 'omitnan');
                PLVB(s,r,:,sc)  = plv;
                PLVBc(s,r,:,sc) = sqrt(max(0, (N*plv.^2 - 1)/(N-1)));
                PhB(s,r,:,sc)   = angle(mean(res, 2, 'omitnan'));
            end
        end
    end
    R.(cond(c).name) = struct('PLVA',PLVA,'PLVAc',PLVAc,'PhA',PhA,'NA',NA, ...
                              'PLVB',PLVB,'PLVBc',PLVBc,'PhB',PhB,'NB',NB);
    clear Ph;
end
save(out_file, 'R','roi_names','foi','bands','subjects','cond','MIN_SUBJ','MIN_TRIALS','-v7.3');
fprintf('Saved %s\n', out_file);

%% PLOTS
bandIdx = @(b) find(foi >= bands(b).rng(1) & foi <= bands(b).rng(2));
scColors = lines(NUM_SC);
for b = 1:numel(bands)
    fi = bandIdx(b); bn = bands(b).name;

    % Fig 1: group PLVc, scenario x point (mean over reps)
    figure('Position',[50 50 1400 650],'Name',['A heatmap ' bn]);
    for c = 1:2
        for r = 1:nROI
            subplot(2,nROI,(c-1)*nROI+r);
            M = squeeze(mean(mean(R.(cond(c).name).PLVAc(r,fi,:,:,:),2,'omitnan'),4,'omitnan'));  % sc x pt
            imagesc(1:NUM_PTS, 1:NUM_SC, M); colorbar; clim([0 max(0.3, max(M(:)))]);
            xticks(1:4); yticks(1:NUM_SC); xlabel('Suture point'); ylabel('Scenario');
            title(sprintf('%s | %s',roi_names{r},cond(c).label),'Interpreter','none','FontSize',8);
        end
    end
    colormap(hot); sgtitle(sprintf('Option A: across-subject PLV (bias-corrected), %s %d-%d Hz', bn, bands(b).rng));

    % Fig 2: within-subject PLVc across scenarios
    figure('Position',[50 50 1400 650],'Name',['B scenarios ' bn]);
    for c = 1:2
        for r = 1:nROI
            subplot(2,nROI,(c-1)*nROI+r); hold on;
            V = squeeze(mean(R.(cond(c).name).PLVBc(:,r,fi,:),3,'omitnan'));    % subj x sc
            plot(1:NUM_SC, V', '-', 'Color',[0.8 0.8 0.8]);
            ok = sum(~isnan(V),1) >= 3;
            errorbar(find(ok), mean(V(:,ok),1,'omitnan'), std(V(:,ok),0,1,'omitnan')./sqrt(sum(~isnan(V(:,ok)),1)), 'k-o','LineWidth',1.8);
            xticks(1:NUM_SC); xlabel('Scenario'); ylabel('PLV corrected'); grid on; ylim([0 0.6]);
            title(sprintf('%s | %s',roi_names{r},cond(c).label),'Interpreter','none','FontSize',8);
        end
    end
    sgtitle(sprintf('Option B: within-subject PLV across the trials of a scenario, %s (grey = subjects, black = mean +- SEM)', bn));

    % Fig 3: mean phase (polar), one spoke per scenario, length = PLVc
    figure('Position',[50 50 1400 650],'Name',['Phase ' bn]);
    for c = 1:2
        for r = 1:nROI
            subplot(2,nROI,(c-1)*nROI+r, polaraxes); hold on;
            for sc = 1:NUM_SC
                ph = squeeze(PhAcirc(R.(cond(c).name).PhA(r,fi,sc,:,:)));
                pl = squeeze(mean(R.(cond(c).name).PLVAc(r,fi,sc,:,:),'all','omitnan'));
                if ~isnan(ph) && ~isnan(pl), polarplot([0 ph],[0 pl],'LineWidth',2,'Color',scColors(sc,:)); end
            end
            title(sprintf('%s | %s',roi_names{r},cond(c).label),'Interpreter','none','FontSize',8);
        end
    end
    sgtitle(sprintf('Mean phase per scenario (spoke length = PLV corrected), %s; colours = scenarios 1-6', bn));
end

% Fig 4: PLV spectrum (which frequencies are phase consistent), option B
figure('Position',[50 50 1400 650],'Name','PLV spectrum');
for c = 1:2
    for r = 1:nROI
        subplot(2,nROI,(c-1)*nROI+r); hold on;
        for sc = 1:NUM_SC
            y = squeeze(mean(R.(cond(c).name).PLVBc(:,r,:,sc),1,'omitnan'));
            plot(foi, y, 'Color', scColors(sc,:), 'LineWidth',1.2);
        end
        xline(8,'k:'); xline(15,'k:'); xline(25,'k:'); xlim([4 35]); grid on;
        xlabel('Frequency (Hz)'); ylabel('PLV corrected'); title(sprintf('%s | %s',roi_names{r},cond(c).label),'Interpreter','none','FontSize',8);
        if r==1 && c==1, legend(arrayfun(@(x) sprintf('S%d',x),1:NUM_SC,'UniformOutput',false),'FontSize',6); end
    end
end
sgtitle('Option B: within-subject PLV vs frequency (mean over subjects), one line per scenario');

%% STATISTICS: does within-subject PLV change with scenario? (per-subject Spearman, then signed-rank)
fprintf('\n=== PLV (option B) vs scenario: per-subject Spearman rho, signed-rank across subjects ===\n');
fprintf('%-8s %-12s %-12s %5s %9s %8s\n','Band','ROI','Epoch','nSubj','mean rho','p');
for b = 1:numel(bands)
    fi = bandIdx(b);
    for c = 1:2
        for r = 1:nROI
            V = squeeze(mean(R.(cond(c).name).PLVBc(:,r,fi,:),3,'omitnan'));    % subj x sc
            rho = nan(nSubj,1);
            for s = 1:nSubj
                ok = ~isnan(V(s,:));
                if nnz(ok) >= 4, rho(s) = corr((1:NUM_SC)', V(s,:)', 'Type','Spearman','Rows','complete'); end
            end
            ok = ~isnan(rho);
            if nnz(ok) >= 5, p = signrank(rho(ok)); else, p = NaN; end
            fprintf('%-8s %-12s %-12s %5d %9.2f %8.3f%s\n', bands(b).name, roi_names{r}, cond(c).name, nnz(ok), mean(rho(ok)), p, ternary(p<0.05,' *',''));
        end
    end
end

% save every figure as PNG (file name = figure name)
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
figs = findobj('Type', 'figure');
for i = 1:numel(figs)
    exportgraphics(figs(i), fullfile(fig_dir, ['IR_Phase_' regexprep(figs(i).Name, '\W+', '_') '_avgref.png']), 'Resolution', 200);
end

function o = PhAcirc(x)   % circular mean of an angle array (rad)
    x = x(~isnan(x)); if isempty(x), o = NaN; else, o = angle(mean(exp(1i*x))); end
end
function o = ternary(c,a,b), if c, o=a; else, o=b; end, end
