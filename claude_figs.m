clear; close all;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106'; ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0'; eeglab nogui;

D='/home/acatalano/Desktop/Intuitive/DataStructures/';
OUT=[D 'Figures_claude_figs/'];          % PNGs are saved here (created if missing)
if ~exist(OUT,'dir'), mkdir(OUT); end
E1 = load('/home/acatalano/Desktop/Intuitive/IE_Task/Modulation_Experts.mat');
E2=load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');
R=load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);
F=load([D 'Task_FOOOF_Residents.mat']);
C=load([D 'Task_ClusterFirstLast_Residents.mat']);

rn=E2.roi_names; cE=[0.15 0.35 0.7]; cR=[0.85 0.4 0.1];
NS=6;NR=10;NP=4;
mk=@() figure('Visible','on','Position',[50 50 1400 700],'Color','w');
sv=@(f,n) print(f,[OUT n],'-dpng','-r110');

%% Fig 1: group comparison ERD / ERS / Mod (beta, alpha), motor+frontal ROIs
f=mk(); 
met={'ERD','ERS','Mod'}; rois=[1 2 3 4]; bnm={'Beta','Alpha'};
for b=1:2
    for m=1:3
      subplot(2,3,(b-1)*3+m); hold on;
      for k=1:numel(rois)
        r =rois(k);
        e =mean( squeeze( E2.([met{m} '_all'])(b,r,:,:)), 2, 'omitnan'); 
        s =mean( squeeze(R.([met{m} '_all'])(b,r,:,:)), 2, 'omitnan');
        bar(k-0.18,mean(e,'omitnan'), 0.33,'FaceColor',cE,'FaceAlpha',0.6); 
        bar(k+0.18,mean(s,'omitnan'), 0.33, 'FaceColor', cR, 'FaceAlpha', 0.6);
        scatter(k-0.18+0.05*randn(size(e)), e, 14, cE, 'filled'); 
        scatter(k+0.18+0.05*randn(size(s)), s, 14, cR, 'filled');
      end
      xticks(1:4); xticklabels(rn(rois)); title(sprintf('%s | %s', bnm{b}, met{m})); grid on; yline(0, 'k-');
      if b==1&&m==1,  legend({'Experts', 'Residents'}, 'Location', 'southeast'); end
    end 
end
sgtitle('ERD,  ERS,  modulation per ROI: bars = group mean of subject means');
sv(f,  'fig1_groups.png');

%% Fig 1b: same as Fig 1, but residents ONLY on the 3 successful repetitions of each scenario
% (ERD_ERS_Modulation_IR_Last3.mat: [band x ROI x subject x scenario], mean over the 3 repetitions x 4 points)
% Each resident = mean over the scenarios for which he/she has a value. Experts: all repetitions (as Fig 1).
L3 = load([D 'ERD_ERS_Modulation_IR_Last3.mat']);
f=mk();
for b=1:2
    for m=1:3
      subplot(2,3,(b-1)*3+m); hold on;
      for k=1:numel(rois)
        r =rois(k);
        e =mean( squeeze( E2.([met{m} '_all'])(b,r,:,:)), 2, 'omitnan');
        s =mean( squeeze( L3.([met{m} '_last3'])(b,r,:,:)), 2, 'omitnan');   % [subj x scenario] -> subj
        bar(k-0.18,mean(e,'omitnan'), 0.33,'FaceColor',cE,'FaceAlpha',0.6);
        bar(k+0.18,mean(s,'omitnan'), 0.33, 'FaceColor', cR, 'FaceAlpha', 0.6);
        scatter(k-0.18+0.05*randn(size(e)), e, 14, cE, 'filled');
        scatter(k+0.18+0.05*randn(size(s)), s, 14, cR, 'filled');
      end
      xticks(1:4); xticklabels(rn(rois)); title(sprintf('%s | %s', bnm{b}, met{m})); grid on; yline(0, 'k-');
      if b==1&&m==1,  legend({'Experts (all repetitions)', 'Residents (3 successful)'}, 'Location', 'southeast'); end
    end
end
sgtitle('ERD,  ERS,  modulation per ROI: experts = all repetitions, residents = 3 successful repetitions only (bars = group mean of subject means)');
sv(f,  'fig1b_groups_last3.png');

%% Fig 2: ERS beta/Mod beta left motor: experts across 20 repetitions; residents across scenarios and points
f = mk();
ee = squeeze(E2.ERS_all(1, 1, :, :)); 
em = squeeze(E2.Mod_all(1, 1, :, :));
ex = @(A) squeeze(mean(reshape(A, 10,  4,  20), 2, 'omitnan')); % subj x rep

subplot(2, 3, 1); 
errorbar(1:20, mean(ex(ee), 1, 'omitnan'), std(ex(ee), 0, 1, 'omitnan') / sqrt(10), '-o', 'Color', cE, 'LineWidth', 1.4); 
title('Experts: ERS beta, left motor, per repetition'); 
xlabel('Repetition'); ylabel('ERS'); grid on;

subplot(2,3,4); 
errorbar(1:20, mean(ex(em), 1, 'omitnan'), std(ex(em), 0, 1, 'omitnan')/sqrt(10), '-o', 'Color', cE, 'LineWidth', 1.4); 
title('Experts: modulation beta,   left motor'); 
xlabel('Repetition'); ylabel('Modulation'); grid on;

rs = squeeze(R.ERS_all(1, 1, :, :)); 
rm = squeeze(R.Mod_all(1, 1, :, :));
sc = @(A) squeeze(mean(mean(reshape(A, 21, 4, 10, 6), 2, 'omitnan'), 3, 'omitnan')); % subj x scenario
pt = @(A) squeeze(mean(mean(reshape(A, 21, 4, 10, 6), 3, 'omitnan'), 4, 'omitnan')); % subj x point
sem = @(A) std(A, 0, 1, 'omitnan')./sqrt(sum(~isnan(A), 1));

% Experts TASK 1 (6 scenarios done once, 4 points each = 24 slots; slot = (scenario-1)*4 + point)
T1 = load('/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG/ERD_ERS_Modulation_Task1_ROI_bands.mat');
t1 = @(A) squeeze(mean(reshape(A, 10, 4, 6), 2, 'omitnan'));   % subj x scenario
t1s = squeeze(T1.ERS_all(1, 1, :, :));  t1m = squeeze(T1.Mod_all(1, 1, :, :));

subplot(2, 3, 2); hold on;
errorbar(1:6, mean(sc(rs), 1, 'omitnan'), sem(sc(rs)), '-o', 'Color', cR, 'LineWidth', 1.4);
errorbar(1:6, mean(t1(t1s), 1, 'omitnan'), sem(t1(t1s)), '--s', 'Color', cE, 'LineWidth', 1.4);
title('ERS beta, left motor, per scenario'); xlabel('Scenario');xticks([1:6]); grid on;
legend({'Residents (all reps)', 'Experts, Task 1 (6 scenarios, once)'}, 'Location', 'best');

subplot(2, 3, 5); hold on;
errorbar(1:6,  mean(sc(rm), 1, 'omitnan'), sem(sc(rm)), '-o', 'Color', cR, 'LineWidth', 1.4);
errorbar(1:6, mean(t1(t1m), 1, 'omitnan'), sem(t1(t1m)), '--s', 'Color', cE, 'LineWidth', 1.4);
title('Modulation beta, left motor, per scenario'); xlabel('Scenario'); xticks([1:6]); grid on;

pe = @(A) squeeze(mean(mean(reshape(A, 10, 4, 20), 3, 'omitnan'), 1, 'omitnan'));

subplot(2, 3, 3); hold on; 
errorbar(1:4, mean(pt(rs), 1, 'omitnan'), sem(pt(rs)), '-o', 'Color', cR, 'LineWidth', 1.4); 
plot(1:4, pe(ee), '--s', 'Color', cE, 'LineWidth', 1.4); 
title('ERS beta,  left motor,  per suture point'); 
xlabel('Suture point'); xticks([1:4]);legend({'Residents', 'Experts'}, 'Location', 'best'); grid on;

subplot(2, 3, 6); hold on; 
errorbar(1:4, mean(pt(rm), 1, 'omitnan'), sem(pt(rm)), '-o', 'Color', cR, 'LineWidth', 1.4); 
plot(1:4, pe(em), '--s', 'Color', cE,'LineWidth',1.4); 
title('Modulation beta, left motor, per suture point'); xlabel('Suture point'); xticks([1:4]);grid on;
sgtitle('Learning and within-suture behaviour (mean +- SEM over subjects; experts dashed in the point panels)');
sv(f,'fig2_learning.png');

%% Fig 2b: MODULATION per scenario, ALL ROIs, beta and alpha: residents vs experts Task 1 (6 scenarios once)
% mean +- SEM over subjects of the per-scenario value (4 suture points averaged); n below the title.
f = mk(); bn2 = {'Beta','Alpha'};
for b = 1:2
  for r = 1:4
    subplot(2, 4, (b-1)*4 + r); hold on;
    rM  = squeeze(R.Mod_all(b, r, :, :));                      % resident subj x 240
    rS  = squeeze(mean(mean(reshape(rM, 21, 4, 10, 6), 2, 'omitnan'), 3, 'omitnan'));   % subj x scenario
    eS  = squeeze(mean(reshape(squeeze(T1.Mod_all(b, r, :, :)), 10, 4, 6), 2, 'omitnan')); % subj x scenario
    errorbar(1:6, mean(rS, 1, 'omitnan'), sem(rS), '-o', 'Color', cR, 'LineWidth', 1.4);
    errorbar(1:6, mean(eS, 1, 'omitnan'), sem(eS), '--s', 'Color', cE, 'LineWidth', 1.4);
    xlim([0.5 6.5]); xticks(1:6); xlabel('Scenario'); ylabel('Modulation'); grid on;
    title(sprintf('%s | %s\nn per scenario: residents %d-%d, experts %d-%d', bn2{b}, rn{r}, ...
        min(sum(~isnan(rS),1)), max(sum(~isnan(rS),1)), min(sum(~isnan(eS),1)), max(sum(~isnan(eS),1))), 'FontSize', 9);
    if b==1 && r==1, legend({'Residents (all reps)', 'Experts, Task 1'}, 'Location', 'best'); end
  end
end
sgtitle('Modulation per scenario, all ROIs: residents vs experts Task 1 (each expert did the 6 scenarios once); mean +- SEM over subjects');
sv(f,'fig2b_modulation_scenarios_Task1.png');


%% Fig 3: resident mean spectra successful vs not, Grasp and Exit
f = mk(); gc = {[0.1 0.5 0.2],[0.8 0.2 0.2]}; freq=F.freq;
[pp,rr,ss]=ndgrid(1:NP,1:NR,1:NS); slotSc=ss(:)'; slotRp=rr(:)';
succ=nan(21,240); for s=1:21, for k=1:240, succ(s,k)=F.Success(s,slotSc(k),slotRp(k)); end,end
SP={F.Spec_grasp,F.Spec_exit}; el={'Grasp','Exit'};
for e=1:2, for r=1:4
  subplot(2,4,(e-1)*4+r); hold on;
  for g=1:2
    sm=nan(21,numel(freq));
    for s=1:21, sel=succ(s,:)==(g==1); sp=squeeze(SP{e}(s,r,sel,:)); if ~isempty(sp)&&any(~isnan(sp(:))), sm(s,:)=mean(log10(sp),1,'omitnan'); end, end
    mu=mean(sm,1,'omitnan'); se=std(sm,0,1,'omitnan')./sqrt(sum(~isnan(sm(:,1))));
    fill([freq fliplr(freq)],[mu+se fliplr(mu-se)],gc{g},'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off'); plot(freq,mu,'Color',gc{g},'LineWidth',1.6);
  end
  xlim([4 35]); grid on; title(sprintf('%s | %s',el{e},rn{r})); xlabel('Hz'); ylabel('log10 power');
  if r==1&&e==1, legend({'Successful (PS>=75)','Not successful'},'Location','southwest'); end
end,end
sgtitle('Residents: mean spectrum, successful vs not successful repetitions (shading = SEM over subjects)');
sv(f,'fig3_spectra.png'); close(f);

%% Fig 4: dominant / alpha / beta peak frequency distribution, residents
f=mk(); 
for e=1:2, FD={F.FOOOF_grasp,F.FOOOF_exit}; 
  for r=1:4
    subplot(2,4,(e-1)*4+r); v=squeeze(FD{e}.dom_cf(:,r,:)); r2=squeeze(FD{e}.r_squared(:,r,:));
    histogram(v(~isnan(v)),4:1:35,'FaceColor',cR); xlabel('Dominant peak frequency (Hz)'); ylabel('# slots'); grid on; title(sprintf('%s | %s',el{e},rn{r}));
  end
end
sgtitle('Residents: distribution of the dominant FOOOF peak frequency (two humps: alpha and beta)');
sv(f,'fig4_peakhist.png'); close(f);

%% Fig 5: cluster topographies (last - first), residents
EEG=pop_loadset('filename','IR06_EO_downS_filt.set','filepath','/home/acatalano/Desktop/Intuitive/');
f=figure('Visible','off','Position',[50 50 1500 480],'Color','w');
cl={{'graspERD','Alpha'},{'exitERS','Theta'},{'exitERS','Alpha'}};
for i=1:3
  s=C.Results.(cl{i}{1}).(cl{i}{2}); el_=[];
  for k=find([s.negclusters.prob]<0.05), el_=[el_; find(s.negclusterslabelmat==k)]; end
  subplot(1,3,i); topoplot(s.stat,EEG.chanlocs,'gridscale',100,'headrad',0.61,'electrodes','off','maplimits',[-5 5],'emarker2',{el_,'o',[0 0 0],5,1});
  colorbar; title(sprintf('%s | %s',cl{i}{1},cl{i}{2}));
end
sgtitle('Residents: t-map of last minus first repetition (black dots = channels of the significant cluster)');
sv(f,'fig5_clusters.png'); close(f);

%% Fig 6: EXPERTS - aperiodic-corrected spectrum ("log power - 1/f"), where are the peaks
% Same code as FIGURE 2 of Task2_fooof.m. One line per expert = mean over the slots of
% log10(power) minus its straight-line fit in log-log (the 1/f part); triangle = peak.
% Top row: Exit epoch (-2..0 s), bottom row: Grasp epoch (-0.5..1 s). Solid = alpha peak (8-15 Hz), dashed = other.
% NOTE: loads two big files (about 1.7 GB), it takes a while.
bpE = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2/';
load([bpE 'Task2exit_ps_allExp_struct.mat']);      % Task2_exit_allExp  (fourierspctrm)
load([bpE 'Task2grasp_ps_allExp_struct.mat']);     % Task2_grasp_allExp
subjE = E2.subjects;  nSubjE = numel(subjE);  NUM_SLOTS_E = 80;
ROIch = {[15 20 10],[13 19 9],[29 30 31],[4 5 6]};   % MotorLeft, MotorRight, Visual, Frontal (reference montage)
freq_axis = Task2_exit_allExp{1}.freq;  freq_axis_even = linspace(freq_axis(1),freq_axis(end),length(freq_axis));
tE = Task2_exit_allExp{1}.time;  tG = Task2_grasp_allExp{1}.time;
winE = {find(tE>=-2.0,1,'first'):find(tE<=0.0,1,'last'), find(tG>=-0.5,1,'first'):find(tG<=1.0,1,'last')};
TFe = {Task2_exit_allExp, Task2_grasp_allExp};  epN = {'Exit','Grasp'};
colE = lines(nSubjE);
f = figure('Visible','on','Position',[50 50 1400 700],'Color','w');
for e = 1:2
  for r = 1:4
    subplot(2,4,(e-1)*4+r); hold on;
    for s = 1:nSubjE
      specs = nan(NUM_SLOTS_E,length(freq_axis_even));
      for slot = 1:NUM_SLOTS_E
        pow_s = squeeze(mean(abs(TFe{e}{s}.fourierspctrm(slot,ROIch{r},:,:)).^2,2,'omitnan'));
        spec_s = mean(pow_s(:,winE{e}),2,'omitnan')';
        if any(spec_s<=0)||any(isnan(spec_s)), continue; end
        spec_even = interp1(freq_axis,spec_s,freq_axis_even,'linear');
        log_f = log10(freq_axis_even(:)); log_s = log10(spec_even(:));
        valid = ~isnan(log_s)&~isinf(log_s); if sum(valid)<5, continue; end
        p = polyfit(log_f(valid),log_s(valid),1);
        specs(slot,:) = log_s' - polyval(p,log_f)';
      end
      mean_spec = mean(specs,1,'omitnan'); if all(isnan(mean_spec)), continue; end
      [~,pk] = max(mean_spec); ls = '-'; if e==1 && ~(freq_axis_even(pk)>=8&&freq_axis_even(pk)<15), ls = '--'; end
      plot(freq_axis_even,mean_spec,ls,'Color',[colE(s,:) 0.85],'LineWidth',1.5);
      scatter(freq_axis_even(pk),mean_spec(pk),60,colE(s,:),'v','filled');
    end
    xline(8,'k:'); xline(15,'k:'); xline(25,'k:'); yline(0,'k--','LineWidth',0.8);
    xlabel('Hz'); ylabel('Log power - 1/f'); grid on; xlim([freq_axis_even(1) freq_axis_even(end)]);
    title(sprintf('%s | %s',rn{r},epN{e}),'Interpreter','none');
  end
end
sgtitle('EXPERTS: aperiodic-corrected spectrum (one line per expert) - triangle = peak; Exit row: solid = alpha peak, dashed = other');
sv(f,'fig6_spectraCorrected_experts.png'); clear Task2_exit_allExp Task2_grasp_allExp TFe;

%% Fig 7: RESIDENTS - same plot (spectra stored by Task_Res_FOOOF.m, already averaged over ROI channels and window)
freqR = F.freq(:)'; freqR_even = linspace(freqR(1),freqR(end),numel(freqR));
nSubjR = numel(F.subjects); colR = turbo(nSubjR); SPr = {F.Spec_exit, F.Spec_grasp};
f = figure('Visible','on','Position',[50 50 1400 700],'Color','w');
for e = 1:2
  for r = 1:4
    subplot(2,4,(e-1)*4+r); hold on; nPl = 0;
    for s = 1:nSubjR
      specs = nan(size(F.Spec_grasp,3),numel(freqR_even));
      for slot = 1:size(F.Spec_grasp,3)
        spec_s = squeeze(SPr{e}(s,r,slot,:))';
        if any(spec_s<=0)||any(isnan(spec_s)), continue; end
        spec_even = interp1(freqR,spec_s,freqR_even,'linear');
        log_f = log10(freqR_even(:)); log_s = log10(spec_even(:));
        valid = ~isnan(log_s)&~isinf(log_s); if sum(valid)<5, continue; end
        p = polyfit(log_f(valid),log_s(valid),1);
        specs(slot,:) = log_s' - polyval(p,log_f)';
      end
      mean_spec = mean(specs,1,'omitnan'); if all(isnan(mean_spec)), continue; end
      [~,pk] = max(mean_spec); ls = '-'; if e==1 && ~(freqR_even(pk)>=8&&freqR_even(pk)<15), ls = '--'; end
      plot(freqR_even,mean_spec,ls,'Color',[colR(s,:) 0.85],'LineWidth',1.2);
      scatter(freqR_even(pk),mean_spec(pk),60,colR(s,:),'v','filled'); nPl = nPl+1;
    end
    xline(8,'k:'); xline(15,'k:'); xline(25,'k:'); yline(0,'k--','LineWidth',0.8);
    xlabel('Hz'); ylabel('Log power - 1/f'); grid on; xlim([freqR_even(1) freqR_even(end)]);
    title(sprintf('%s | %s (n=%d)',rn{r},epN{e},nPl),'Interpreter','none');
  end
end
sgtitle('RESIDENTS: aperiodic-corrected spectrum (one line per resident) - triangle = peak; Exit row: solid = alpha peak, dashed = other');
sv(f,'fig7_spectraCorrected_residents.png');
disp('done');
