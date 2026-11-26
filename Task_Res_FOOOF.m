% Task_Res_FOOOF.m
% RESIDENTS (IR): ROI spectra + FOOOF per slot (same method as Task2_fooof.m, experts).
% Input : <subj>_IR_graspERD_FT.mat , <subj>_IR_exitERS_FT.mat   (Task_Res_FieldtripERDERS.m)
%         ps_ge75_long.csv  (performance score per subject / scene / rep)
% Output: DataStructures/Task_FOOOF_Residents.mat
%   FOOOF_grasp / FOOOF_exit .<field> = [nSubj x nROI x 240 slots]
%       fields: offset exponent r_squared alpha_cf/pow/bw beta_cf/pow/bw dom_cf/pow/bw
%       dom_* = highest-power peak anywhere in 4-35 Hz ("dominant frequency")
%   Success [nSubj x 6 x 10]: 1 = PS>=75, 0 = PS<75, NaN = code (S/X) or not in CSV
%   Slot = (scenario-1)*40 + (rep-1)*4 + point
%
% NOTE: spectra are computed here from the RAW (un-normalised) epochs, because
% the normalised TFRs from Task_Res_TFR.m can be negative and cannot be fitted by FOOOF.
% Window: ERD (grasp) -0.5..1.0 s | ERS (exit) -2.0..0.0 s, identical to the experts.

clear; close all; clc;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106'; ft_defaults;
addpath('/home/acatalano/Documents/MATLAB/fooof_mat/fooof_mat/');
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0'; eeglab nogui;

% ORIGINAL (common reference, before the average reference): base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_avgref';   % NEW: filtered + average reference (same as the experts)
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
% ORIGINAL (moved to the _to_delete folder): ps_file    = '/home/acatalano/Desktop/VIRTUES/ps_ge75_long.csv';
ps_file    = '/home/acatalano/Desktop/Intuitive/DataStructures/ps_ge75_long.csv';   % copy kept in the project
% ORIGINAL: out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/Task_FOOOF_Residents.mat';
out_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/Task_FOOOF_Residents_avgref.mat';   % NEW (the old file is not overwritten)
EEG_ref    = pop_loadset('filename','IR06_EO_downS_filt.set','filepath','/home/acatalano/Desktop/Intuitive/');

NUM_SC = 6; NUM_REPS = 10; NUM_PTS = 4; NUM_SLOTS = NUM_SC*NUM_REPS*NUM_PTS;
T = load(times_file); subjects = T.subjects; nSubj = numel(subjects);

ROI.MotorLeft = [15 20 10]; ROI.MotorRight = [13 19 9];
ROI.Visual = [29 30 31];    ROI.Frontal = [4 5 6];
roi_names = fieldnames(ROI); nROI = numel(roi_names);

cond(1).name = 'graspERD'; cond(1).win = [-0.5 1.0];
cond(2).name = 'exitERS';  cond(2).win = [-2.0 0.0];

fs = struct('peak_width_limits',[1 12],'max_n_peaks',4,'min_peak_height',0.05, ...
            'peak_threshold',2.0,'aperiodic_mode','fixed');
freq_range = [4 35]; alpha_range = [8 15]; beta_range = [15 25];
fields = {'offset','exponent','r_squared','alpha_cf','alpha_pow','alpha_bw', ...
          'beta_cf','beta_pow','beta_bw','dom_cf','dom_pow','dom_bw'};

%% success matrix from the performance-score CSV
P = readtable(ps_file, 'TextType','string');
Success = nan(nSubj, NUM_SC, NUM_REPS);
for k = 1:height(P)
    si = find(strcmp(subjects, P.subject(k)));
    if isempty(si), continue; end
    if P.status(k) == "ge75", Success(si, P.scene(k), P.rep(k)) = 1;
    elseif P.status(k) == "lt75", Success(si, P.scene(k), P.rep(k)) = 0; end
end
fprintf('Reps: %d success, %d fail, %d code/missing (left unclassified)\n', ...
    nnz(Success==1), nnz(Success==0), nnz(isnan(Success)));

%% spectra + FOOOF
ft_warning off;                      % silence the FieldTrip NaN / time-bin warnings
firstME = [];
nBadSpec = 0; nSpecOK = 0; nFail = 0;
for c = 1:2
    F = struct(); for f = 1:numel(fields), F.(fields{f}) = nan(nSubj,nROI,NUM_SLOTS); end
    Spec = []; 
    for s = 1:nSubj
        fn = fullfile(base_path, sprintf('%s_IR_%s_FT.mat', subjects{s}, cond(c).name));
        if ~exist(fn,'file'), warning('%s missing', fn); continue; end
        D = load(fn); data = D.data;
        for r = 1:nROI
            labs = {EEG_ref.chanlocs(ROI.(roi_names{r})).labels};
            missing = setdiff(labs, data.label);
            if ~isempty(missing)
                error('%s [%s]: ROI %s channels missing from data: %s', subjects{s}, cond(c).name, roi_names{r}, strjoin(missing,','));
            end
            cfg = []; cfg.output='pow'; cfg.method='mtmconvol'; cfg.taper='hann';
            cfg.pad='nextpow2'; cfg.foi=2:0.5:40; cfg.t_ftimwin=0.2*ones(1,numel(cfg.foi));
            cfg.toi = cond(c).win(1):0.05:cond(c).win(2); cfg.keeptrials='yes'; cfg.channel = labs; cfg.feedback='no';
            tf = ft_freqanalysis(cfg, data);                 % [slot x chan x freq x time]
            spec = squeeze(mean(mean(tf.powspctrm,2,'omitnan'),4,'omitnan'));   % [slot x freq]
            if isempty(Spec), Spec = nan(nSubj,nROI,NUM_SLOTS,numel(tf.freq)); freq = tf.freq; end
            Spec(s,r,:,:) = spec;
            freq_even = linspace(freq(1),freq(end),numel(freq));
            for k = 1:NUM_SLOTS
                sp = spec(k,:);
                if any(isnan(sp)) || any(sp<=0), nBadSpec = nBadSpec + 1; continue; end
                nSpecOK = nSpecOK + 1;
                try, fm = fooof(freq_even, interp1(freq,sp,freq_even,'linear'), freq_range, fs, false);
                catch ME
                    nFail = nFail + 1;
                    if nFail == 1, firstME = ME; end
                    continue;
                end
                F.offset(s,r,k) = fm.aperiodic_params(1); F.exponent(s,r,k) = fm.aperiodic_params(2);
                F.r_squared(s,r,k) = fm.r_squared;
                pk = fm.peak_params; if isempty(pk), continue; end
                [~,b] = max(pk(:,2)); F.dom_cf(s,r,k)=pk(b,1); F.dom_pow(s,r,k)=pk(b,2); F.dom_bw(s,r,k)=pk(b,3);
                for bd = {'alpha','beta'}
                    rg = eval([bd{1} '_range']); m = pk(:,1)>=rg(1) & pk(:,1)<rg(2);
                    if any(m), q = pk(m,:); [~,b] = max(q(:,2));
                        F.([bd{1} '_cf'])(s,r,k)=q(b,1); F.([bd{1} '_pow'])(s,r,k)=q(b,2); F.([bd{1} '_bw'])(s,r,k)=q(b,3); end
                end
            end
        end
        fprintf('[%s] %s done\n', cond(c).name, subjects{s});
    end
    if c==1, FOOOF_grasp = F; Spec_grasp = Spec; else, FOOOF_exit = F; Spec_exit = Spec; end
end

save(out_file,'FOOOF_grasp','FOOOF_exit','Spec_grasp','Spec_exit','freq','Success','roi_names','subjects','-v7.3');
fprintf('Saved %s\n', out_file);

if ~isempty(firstME), fprintf(2,'\nFIRST FOOOF ERROR:\n%s\n', getReport(firstME)); end
fprintf('Spectra: %d usable, %d NaN/<=0 (skipped), %d FOOOF errors\n', nSpecOK, nBadSpec, nFail);
if nSpecOK == 0, error('No usable spectrum: check the *_FT.mat slots / channels'); end
if nFail == nSpecOK, error('FOOOF failed on every spectrum (see message above)'); end

%% PLOTS: check of the spectra and of the FOOOF fits
epochs = {'graspERD','exitERS'}; Sp = {Spec_grasp, Spec_exit}; FD = {FOOOF_grasp, FOOOF_exit};
[~,~,ss] = ndgrid(1:NUM_PTS,1:NUM_REPS,1:NUM_SC); [~,rr,~] = ndgrid(1:NUM_PTS,1:NUM_REPS,1:NUM_SC);
succSlot = nan(nSubj,NUM_SLOTS);
for s = 1:nSubj, for k = 1:NUM_SLOTS, succSlot(s,k) = Success(s,ss(k),rr(k)); end, end
gcol = {[0.1 0.5 0.2],[0.8 0.2 0.2]}; gname = {'PS>=75','PS<75'};

% 1) mean spectrum (log10 power) per ROI, successful vs not, shaded = SEM over subjects
figure('Position',[50 50 1500 700],'Name','Mean ROI spectra');
for e = 1:2
  for r = 1:nROI
    subplot(2,nROI,(e-1)*nROI+r); hold on;
    for g = 1:2
      subjMean = nan(nSubj,numel(freq));
      for s = 1:nSubj
        sel = succSlot(s,:) == (g==1);                       % g=1 success, g=2 fail
        sp  = squeeze(Sp{e}(s,r,sel,:));
        if ~isempty(sp), subjMean(s,:) = mean(log10(sp),1,'omitnan'); end
      end
      mu = mean(subjMean,1,'omitnan'); se = std(subjMean,0,1,'omitnan')./sqrt(sum(~isnan(subjMean(:,1))));
      fill([freq fliplr(freq)],[mu+se fliplr(mu-se)],gcol{g},'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
      plot(freq,mu,'Color',gcol{g},'LineWidth',1.6,'DisplayName',gname{g});
    end
    xline(8,'k:'); xline(15,'k:'); xline(25,'k:'); xlim([4 35]); grid on;
    xlabel('Frequency (Hz)'); ylabel('log10 power'); title(sprintf('%s | %s',epochs{e},roi_names{r}),'Interpreter','none');
    if r==1, legend('Location','southwest'); end
  end
end
sgtitle('Mean ROI spectrum, successful vs not successful repetitions');

% 2) distribution of the dominant peak frequency per ROI + fit quality
figure('Position',[50 50 1500 700],'Name','FOOOF fit check');
for e = 1:2
  for r = 1:nROI
    subplot(2,nROI,(e-1)*nROI+r);
    v = squeeze(FD{e}.dom_cf(:,r,:)); histogram(v(~isnan(v)),4:1:35,'FaceColor',[0.3 0.4 0.7]);
    r2 = squeeze(FD{e}.r_squared(:,r,:));
    xlabel('Dominant peak freq (Hz)'); ylabel('# slots'); grid on;
    title(sprintf('%s | %s | median R^2=%.2f | peak found %d%%',epochs{e},roi_names{r}, ...
        median(r2(:),'omitnan'), round(100*nnz(~isnan(v))/max(nnz(~isnan(r2)),1))),'Interpreter','none','FontSize',8);
  end
end
sgtitle('Distribution of the dominant peak frequency (all slots) and quality of the FOOOF fit');
