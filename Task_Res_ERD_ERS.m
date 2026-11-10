clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;
subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/IR_Task';
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'};
freq_ranges = [4 8; 8 14; 15 25; 25 35];
images_path = '/home/acatalano/Desktop/Intuitive/IR_Task'; 
load("TaskRes_ERds.mat"); % 21(subj)    42(il numero max di ripetizioni)    32(chan)    77(freq bin)   121(timebin -1, 5)
% extract power repetitions of interest
csvFile = fullfile(base_path,'scenario_reps.csv');  % <- save your sheet as csv
raw = readcell(csvFile,'Delimiter',';');
pow_norm = TaskRes_allSbj;

RepCounts = [
     4   3  10   6   6   7   % IR02
     5   6   3   3   3   9   % IR04
     6  10   9   3   3   5   % IR05
     6   3   8   3   6   4   % IR06
     4   4   9   5   3  10   % IR07
     6  10  10   5   3   3   % IR08
     4   3  10   3   5   3   % IR09
    10  10  10  10   3   3   % IR10
     5   3   4   3   9   5   % IR11
     7   3  10   4   8   3   % IR12
    10   3   3   3   5   4   % IR13
     3   6  10   3   3   5   % IR14
     6   3   3   3   3   3   % IR16
     6   3   3   3   3   3   % IR17
    10   8   9   4   4   4   % IR18
    10   6   3  10   4  10   % IR19
     3   8   7   3   4   4   % IR21
     7   5   3   3   3   7   % IR22
     5   8   3   8   6   8   % IR23
    10   3   3   5   9   3   % IR24
    10  10   6   4   5   3   % IR25
];

startIdx = nan(length(subjects),6);
for s = 1:length(subjects)
    cum = 0;
    for sc = 1:6
        startIdx(s,sc) = cum + 1;
        cum = cum + RepCounts(s,sc);
    end
    if cum > size(pow_norm,2)
        warning(['Subject %s: cumulative repetitions (%d) exceed pow_norm ' ...
                 'trial dimension (%d) -> check for mismatch!'], ...
                 subjects{s}, cum, size(pow_norm,2));
    end
end
% Extract power spectrum of the first repetition of each scenario
nChan = size(pow_norm,3);
nFreq = size(pow_norm,4);
nTime = size(pow_norm,5);

Tr1Scn = nan(length(subjects),6,nChan,nFreq,nTime);

for s = 1:length(subjects)
    for sc = 1:6
        idx = startIdx(s,sc);
        if ~isnan(idx) && idx <= size(pow_norm,2)
            Tr1Scn(s,sc,:,:,:) = pow_norm(s, idx, :,:,:);
        else
            warning('Subj %s - scenario %d: index %d out of range (max %d trials)', subjects{s}, sc, idx, size(pow_norm,2));
        end
    end
end

% Compute last-trial index for each subject/scenario
lastIdx = nan(length(subjects), 6);
for s = 1:length(subjects)
    for sc = 1:6
        lastIdx(s,sc) = startIdx(s,sc) + RepCounts(s,sc) - 1;
    end
end

% Extract data for the last repetition of each scenario
TrLastScn = nan(length(subjects),6,nChan,nFreq,nTime);

for s = 1:length(subjects)
    for sc = 1:6
        idx = lastIdx(s,sc);
        if ~isnan(idx) && idx <= size(pow_norm,2)
            TrLastScn(s,sc,:,:,:) = pow_norm(s, idx, :,:,:);
        else
            warning('Subj %s - scenario %d: last index %d out of range (max %d trials)', subjects{s}, sc, idx, size(pow_norm,2));
        end
    end
end
%% 
time= -1:0.05:5;
freq =2:0.5:40;
timeERDS=find(time<=-0.2, 1, 'last');
timeERDE=find(time<=0, 1, 'last');
    
timeERSS=find(time<=0, 1, 'last');
timeERSE=find(time<=2, 1, 'last');
ERD_values = nan(21, 6);
ERS_values = nan(21, 6);
bs = find(freq == 15);
be = find(freq == 25);
%% ERDS primi punti per ogni scenario
for i = 1:21
    for j = 1:6
        [ERD, indERD] = min(nanmean(nanmean(Tr1Scn(i, j, :, bs:be, timeERDS:timeERDE), 3), 4));
        [ERS, indERS] = max(nanmean(nanmean(Tr1Scn(i, j, :, bs:be, timeERSS:timeERSE), 3), 4));
        sampleERD = timeERDS + indERD;
        sampleERS = timeERSS + indERS;
        
        % Store ERD and ERS values
        ERD_values(i, j) = ERD;
        ERS_values(i, j) = ERS;
        modulation_values(i, j) = abs(ERS - ERD);
        %subplot(10, 5, j);
        %plot(squeeze(nanmean(nanmean(nanmean(nanmean(TaskRes_allSbj(i, j, :, bs:be, :), 3), 2), 4), 1)))
        % plot(1:42,modulation_values(i,j))
        % hold on
        % plot(sampleERD, ERD, '-o')
        % plot(sampleERS, ERS, '-*')
        % title(['Trial', num2str(j)])
    end
end

% Calculate mean and std for ERD and ERS for each trial across subjects
mean_ERD = nanmean(ERD_values, 1);
std_ERD = nanstd(ERD_values, 0, 1);
mean_ERS = nanmean(ERS_values, 1);
std_ERS = nanstd(ERS_values, 0, 1);

%% ERDS primo punto primo tentativo vs primo punto ultimo tentativo ogni scenario
ERD_values_last = nan(21, 6);
ERS_values_last = nan(21, 6);
modulation_values_last = nan(21, 6);

for i = 1:21
    for j = 1:6
        [ERD, ~] = min(nanmean(nanmean(TrLastScn(i, j, :, bs:be, timeERDS:timeERDE), 3), 4));
        [ERS, ~] = max(nanmean(nanmean(TrLastScn(i, j, :, bs:be, timeERSS:timeERSE), 3), 4));

        ERD_values_last(i, j) = ERD;
        ERS_values_last(i, j) = ERS;
        modulation_values_last(i, j) = abs(ERS - ERD);
    end
end

% Difference = last repetition - first repetition
% (positive = increase over the task, negative = decrease/habituation)
diff_ERD = ERD_values_last - ERD_values;
diff_ERS = ERS_values_last - ERS_values;
diff_Mod = modulation_values_last - modulation_values;
color_decrease = [0.2 0.4 0.8];   % blue = decrease (last < first)
color_increase = [0.8 0.3 0.3];   % red = increase (last > first)

mean_diff_ERD = nanmean(diff_ERD, 1);
std_diff_ERD  = nanstd(diff_ERD, 0, 1);
mean_diff_ERS = nanmean(diff_ERS, 1);
std_diff_ERS  = nanstd(diff_ERS, 0, 1);
mean_diff_Mod = nanmean(diff_Mod, 1);
std_diff_Mod  = nanstd(diff_Mod, 0, 1);

all_diffs = [diff_ERD(:); diff_ERS(:); diff_Mod(:)];
y_min_diff = min(all_diffs) - 0.1*range(all_diffs);
y_max_diff = max(all_diffs) + 0.1*range(all_diffs);
common_ylim_diff = [y_min_diff y_max_diff];
save('ERD_allFirst_res.mat', 'ERD_values');            % 21x6
save('ERS_allFirst_res.mat', 'ERS_values');            % 21x6 (you may not have saved this one before!)
save('Modulation_Residents_first.mat', 'modulation_values');  % 21x6

% Last-attempt values
save('ERD_allLast_res.mat', 'ERD_values_last');         % 21x6
save('ERS_allLast_res.mat', 'ERS_values_last');         % 21x6 (missing from your original list too!)
save('Modulation_Residents_Last.mat', 'modulation_values_last'); % 21x6

% Last - First differences (per subject, NOT averaged)
save('DeltaerD_res.mat', 'diff_ERD');    % 21x6 — NOT mean_diff_ERD
save('DeltaerS_res.mat', 'diff_ERS');    % 21x6 — NOT mean_diff_ERS
save('DeltaMod_res.mat', 'diff_Mod');
figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

subplot(1,3,1);
boxplot(diff_ERD, 'Labels', {'S1','S2','S3','S4','S5','S6'});
hold on; yline(0, 'k--');
ylim(common_ylim_diff);
ylabel('\Delta Power (Last - First)');
title('\Delta ERD (Last - First rep)');

subplot(1,3,2);
boxplot(diff_ERS, 'Labels', {'S1','S2','S3','S4','S5','S6'});
hold on; yline(0, 'k--');
ylim(common_ylim_diff);
title('\Delta ERS (Last - First rep)');

subplot(1,3,3);
boxplot(diff_Mod, 'Labels', {'S1','S2','S3','S4','S5','S6'});
hold on; yline(0, 'k--');
ylim(common_ylim_diff);
title('\Delta Modulation (Last - First rep)');

figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

subplot(1,3,1);
b1 = bar(1:6, mean_diff_ERD);
b1.FaceColor = 'flat';
for k = 1:6
    if mean_diff_ERD(k) >= 0
        b1.CData(k,:) = color_increase;
    else
        b1.CData(k,:) = color_decrease;
    end
end
hold on;
errorbar(1:6, mean_diff_ERD, std_diff_ERD, 'k.', 'LineWidth', 1);
yline(0, 'k--');
ylim(common_ylim_diff);
title('\Delta ERD (Last - First)');
ylabel('\Delta Power (normalized)');

subplot(1,3,2);
b2 = bar(1:6, mean_diff_ERS);
b2.FaceColor = 'flat';
for k = 1:6
    if mean_diff_ERS(k) >= 0
        b2.CData(k,:) = color_increase;
    else
        b2.CData(k,:) = color_decrease;
    end
end
hold on;
errorbar(1:6, mean_diff_ERS, std_diff_ERS, 'k.', 'LineWidth', 1);
yline(0, 'k--');
ylim(common_ylim_diff);
title('\Delta ERS (Last - First)');

subplot(1,3,3);
b3 = bar(1:6, mean_diff_Mod);
b3.FaceColor = 'flat';
for k = 1:6
    if mean_diff_Mod(k) >= 0
        b3.CData(k,:) = color_increase;
    else
        b3.CData(k,:) = color_decrease;
    end
end
hold on;
errorbar(1:6, mean_diff_Mod, std_diff_Mod, 'k.', 'LineWidth', 1);
yline(0, 'k--');
ylim(common_ylim_diff);
title('\Delta Modulation (Last - First)');
%%
color_ERD = [0.0000 0.2000 0.6000];   % dark blue
color_Mod = [0.2000 0.4500 0.7500];   % medium blue
color_ERS = [0.4000 0.7000 0.9000];   % light blue

mean_Mod = nanmean(modulation_values, 1);
std_Mod  = nanstd(modulation_values, 0, 1);

% Common y-limits across ALL three metrics (for combined figures)
all_vals_full = [ERD_values(:); ERS_values(:); modulation_values(:)];
y_min_full = min(all_vals_full) - 0.1*range(all_vals_full);
y_max_full = max(all_vals_full) + 0.1*range(all_vals_full);
common_ylim_full = [y_min_full y_max_full];


%% Plot mean and std for ERD and ERS for each trial
figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
errorbar(1:6, mean_ERD, std_ERD, 'o-', 'Color', color_ERD, 'MarkerFaceColor', color_ERD, 'LineWidth', 1.5);
hold on;
errorbar(1:6, mean_ERS, std_ERS, 'o-', 'Color', color_ERS, 'MarkerFaceColor', color_ERS, 'LineWidth', 1.5);
ylim(common_ylim_full);
xlabel('Scenario');
ylabel('Power (normalized)');
title('Mean ± STD of ERD and ERS per scenario');
legend('ERD','ERS');
%%
figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

subplot(1,2,1);
boxplot(ERD_values, 'Labels', {'S1','S2','S3','S4','S5','S6'},'Colors', color_ERD, 'Symbol', 'o');
ylim(common_ylim_full);
ylabel('Power (normalized)');
title('ERD by Scenario');

subplot(1,2,2);
boxplot(ERS_values, 'Labels', {'S1','S2','S3','S4','S5','S6'}, ...
        'Colors', color_ERS, 'Symbol', 'o');
ylim(common_ylim_full);
ylabel('Power (normalized)');
title('ERS by Scenario');
%%  Grouped bar chart beta mod

figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

b = bar(1:6, [mean_ERD; mean_ERS; mean_Mod]', 'grouped');
b(1).FaceColor = color_ERD;
b(2).FaceColor = color_ERS;
b(3).FaceColor = color_Mod;
hold on;

ngroups = 6; nbars = 3;
groupwidth = min(0.8, nbars/(nbars + 1.5));
means_all = {mean_ERD, mean_ERS, mean_Mod};
stds_all  = {std_ERD, std_ERS, std_Mod};

for i = 1:nbars
    xpos = (1:6) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
    errorbar(xpos, means_all{i}, stds_all{i}, 'k.', 'LineWidth', 1);
end

ylim(common_ylim_full);
xlabel('Scenario');
ylabel('Power (normalized)');
title('Mean ± STD of ERD, ERS, and Beta Modulation per scenario');
legend(b, {'ERD','ERS','Modulation'});

%%  Three-panel figure (ERD, ERS, Modulation as boxplots, shared y-axis)
figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

subplot(1,3,1);
boxplot(ERD_values, 'Labels', {'S1','S2','S3','S4','S5','S6'}, ...
        'Colors', color_ERD, 'Symbol', 'o');
ylim(common_ylim_full);
ylabel('Power (normalized)');
title('ERD by Scenario');

subplot(1,3,2);
boxplot(ERS_values, 'Labels', {'S1','S2','S3','S4','S5','S6'}, ...
        'Colors', color_ERS, 'Symbol', 'o');
ylim(common_ylim_full);
title('ERS by Scenario');

subplot(1,3,3);
boxplot(modulation_values, 'Labels', {'S1','S2','S3','S4','S5','S6'}, ...
        'Colors', color_Mod, 'Symbol', 'o');
ylim(common_ylim_full);
title('Beta Modulation by Scenario');

%% Modulation as a standalone plot 
y_min_mod = min(modulation_values(:)) - 0.1*range(modulation_values(:));
y_max_mod = max(modulation_values(:)) + 0.1*range(modulation_values(:));
common_ylim_mod = [y_min_mod y_max_mod];

figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
bar(1:6, mean_Mod, 'FaceColor', color_Mod);
hold on;
errorbar(1:6, mean_Mod, std_Mod, 'k.', 'LineWidth', 1);
ylim(common_ylim_mod);
xlabel('Scenario');
ylabel('|ERS - ERD| (normalized)');
title('Mean ± STD of Beta Modulation per scenario');
