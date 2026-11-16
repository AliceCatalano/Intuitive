% Task_Res_FOOOF_Analysis.m
% RESIDENTS (IR): behaviour of the dominant frequency (and alpha/beta peak) with
% scenario and within the trial (suture point), successful (PS>=75) vs not (<75).
% Input: Task_FOOOF_Residents.mat (Task_Res_FOOOF.m)
% Unit of analysis: subject mean per cell (scenario x success) so every subject
% counts once; cells with fewer than MIN_N subjects are not drawn.
% Repetitions with status "code" (S/X) are unclassified and excluded.

clear; close all; clc;
S = load('/home/acatalano/Desktop/Intuitive/DataStructures/Task_FOOOF_Residents.mat');
subjects = S.subjects; nSubj = numel(subjects); roi_names = S.roi_names; nROI = numel(roi_names);
NUM_SC = 6; NUM_REPS = 10; NUM_PTS = 4;
MIN_N  = 4;                      % min subjects per plotted point
R2_MIN = 0.8;                    % discard poor FOOOF fits
params = {'dom_cf','alpha_cf','beta_cf','dom_pow','exponent'};
plabel = {'Dominant peak freq (Hz)','Alpha peak freq (Hz)','Beta peak freq (Hz)','Dominant peak power','Aperiodic exponent'};
epochs = {'graspERD','exitERS'}; FD = {S.FOOOF_grasp, S.FOOOF_exit};
grp = {1,'Successful (PS>=75)',[0.1 0.5 0.2]; 0,'Not successful (<75)',[0.8 0.2 0.2]};

% slot descriptors [subj x ... x 240] -> index arrays
[pp,rr,ss] = ndgrid(1:NUM_PTS,1:NUM_REPS,1:NUM_SC);
slotPt = pp(:)'; slotSc = ss(:)'; slotRep = rr(:)';
succSlot = nan(nSubj,240);
for s = 1:nSubj
    for k = 1:240, succSlot(s,k) = S.Success(s,slotSc(k),slotRep(k)); end
end

Tbl = [];   % long table for stats in R / MATLAB: one row per valid slot
for e = 1:2
  for p = 1:numel(params)
    for r = 1:nROI
      V = squeeze(FD{e}.(params{p})(:,r,:));               % [subj x 240]
      V(squeeze(FD{e}.r_squared(:,r,:)) < R2_MIN) = NaN;
      for s = 1:nSubj, for k = find(~isnan(V(s,:)))
        Tbl = [Tbl; {epochs{e}, roi_names{r}, params{p}, subjects{s}, slotSc(k), slotRep(k), slotPt(k), succSlot(s,k), V(s,k)}]; %#ok<AGROW>
      end, end

      if p > 3, continue; end    % figures for frequency parameters only
      fig = figure('Position',[50 50 1100 420],'Name',sprintf('%s %s %s',epochs{e},roi_names{r},params{p}));
      for panel = 1:2         % 1: by scenario | 2: within trial (suture point)
        subplot(1,2,panel); hold on;
        nX = (panel==1)*NUM_SC + (panel==2)*NUM_PTS;
        for g = 1:2
          M = nan(nSubj,nX);
          for s = 1:nSubj
            for x = 1:nX
              if panel==1, sel = slotSc==x; else, sel = slotPt==x; end
              sel = sel & succSlot(s,:)==grp{g,1};
              M(s,x) = mean(V(s,sel),'omitnan');
            end
          end
          n  = sum(~isnan(M),1); mu = mean(M,1,'omitnan'); se = std(M,0,1,'omitnan')./sqrt(n);
          ok = n >= MIN_N;
          errorbar(find(ok), mu(ok), se(ok), 'o-', 'Color', grp{g,3}, 'LineWidth',1.5, 'DisplayName', grp{g,2});
        end
        xlabel(ternary(panel==1,'Scenario','Suture point')); ylabel(plabel{p});
        xticks(1:nX); xlim([0.5 nX+0.5]); grid on; legend('Location','best');
        title(ternary(panel==1,'Across scenarios','Within trial'));
      end
      sgtitle(sprintf('%s | %s | %s', epochs{e}, roi_names{r}, plabel{p}), 'Interpreter','none');
    end
  end
end

if isempty(Tbl), error('All FOOOF values are NaN: rerun Task_Res_FOOOF.m and read its diagnostics'); end
Tbl = cell2table(Tbl,'VariableNames',{'epoch','roi','param','subject','scenario','rep','point','success','value'});
writetable(Tbl,'/home/acatalano/Desktop/Intuitive/DataStructures/Task_FOOOF_Residents_long.csv');

%% how many slots / subjects contribute per group (check before trusting any curve)
for e = 1:2
    V = squeeze(FD{e}.dom_cf(:,1,:));
    fprintf('%s MotorLeft dom_cf: success slots %d, fail slots %d, unclassified %d\n', epochs{e}, ...
        nnz(~isnan(V) & succSlot==1), nnz(~isnan(V) & succSlot==0), nnz(~isnan(V) & isnan(succSlot)));
end

function o = ternary(c,a,b), if c, o=a; else, o=b; end, end

%% PLOT: per-subject trajectories of the dominant frequency across scenarios
% (thin lines = subjects, thick = group mean; all repetitions, success ignored)
for e = 1:2
    figure('Position',[50 50 1500 380],'Name',['Subjects ' epochs{e}]);
    for r = 1:nROI
        subplot(1,nROI,r); hold on;
        V = squeeze(FD{e}.dom_cf(:,r,:)); V(squeeze(FD{e}.r_squared(:,r,:)) < R2_MIN) = NaN;
        M = nan(nSubj,NUM_SC);
        for x = 1:NUM_SC, M(:,x) = mean(V(:,slotSc==x),2,'omitnan'); end
        plot(1:NUM_SC, M', '-', 'Color', [0.7 0.7 0.7]);
        plot(1:NUM_SC, mean(M,1,'omitnan'), 'k-o', 'LineWidth', 2);
        yline(8,'k:'); yline(15,'k:'); xlabel('Scenario'); ylabel('Dominant peak (Hz)');
        xticks(1:NUM_SC); grid on; title(sprintf('%s | %s',epochs{e},roi_names{r}),'Interpreter','none');
    end
end
