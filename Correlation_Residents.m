clear; close all; clc;

% Paths
base_path = '/home/acatalano/Desktop/Intuitive';
addpath('/home/acatalano/Documents/fieldtrip-20241219');
ft_defaults;

load(fullfile(base_path, 'grandavg1_IR.mat')); % EO1
load(fullfile(base_path, 'grandavg2_IR.mat')); % EO2

load(fullfile(base_path, 'ROI_residents.mat'));
load('/home/acatalano/Downloads/V1_TimeDiff_Total.mat')
load('/home/acatalano/Downloads/V2_TotalReps.mat')
load('/home/acatalano/Downloads/V3_TrialDiff_1_6.mat')
load('/home/acatalano/Downloads/V4_TimeDiff_Firsts.mat')
load('/home/acatalano/Downloads/V5_MeanReps.mat')
load('/home/acatalano/Downloads/performanceStruct_IR_updated.mat')

time_reduction_ultimissima_primissima = V1_TimeDiff_Total;   %prima - ultima

bands = {'Theta', 'Alpha'};
freq_ranges = [4 8; 8 14;];
nBands = numel(bands);
% ---------------- ROI definitions ----------------

% ROIs = struct;
% ROIs.cluster1 = [ 13, 17, 18, 23,  29, 30] % alpha
% ROIs.cluster2 = [ 10, 15, 20] % alpha
% ROIs.cluster3 = [1, 2, 3, 5, 6, 9] % theta
% ---- Exp ----
%ROIs.cluster1 = [11, 16, 21, 26, 22, 27]; 

freq = grandavg_cond1.freq;
nFreq = length(freq);
nSubjects = size(grandavg_cond1.powspctrm,1);
roi_names = intersect(fieldnames(ROI), bands);  % only Theta & Alpha
Results = struct;

%% scenario 6 ultima rip tempo - scenario 1 prima rip tempo.
x = time_reduction_ultimissima_primissima(:);   % subjects × 1
fprintf('\nFrequency-resolved correlations: Time vs EEG change\n');

for f = 1:nBands
    
    band_name = bands{f};
    
    % Skip if this band has no ROI defined
    if ~isfield(ROI, band_name) || isempty(ROI.(band_name))
        continue
    end
    
    chan_idx = ROI.(band_name);

    fmin = freq_ranges(f,1);
    fmax = freq_ranges(f,2);

    fs = find(freq >= fmin, 1, 'first');
    fe = find(freq <= fmax, 1, 'last');

    % Mean power across ROI electrodes
    EO1_pow = nanmean(grandavg_cond1.powspctrm(:,chan_idx,fs:fe), [2 3]);
    EO2_pow = nanmean(grandavg_cond2.powspctrm(:,chan_idx,fs:fe), [2 3]);

    y = EO2_pow - EO1_pow;   % subjects × 1
    valid = ~isnan(x) & ~isnan(y);

    if sum(valid) >= 5
        [r,p] = corr(x(valid), y(valid), 'Type','Spearman');

        Results.(band_name).r = r;
        Results.(band_name).p = p;

        fprintf('%s band: r = %.3f, p = %.4f (n=%d)\n', ...
                band_name, r, p, sum(valid));

        figure;
        scatter(x(valid), y(valid), 70, 'filled');
        lsline;
        xlabel('Behavioral metric');
        ylabel(sprintf('Δ Resting Power (%s)', band_name));
        title(sprintf('%s band: r = %.2f, p = %.3f', band_name, r, p));
        grid on;
    end
end
%% numero totale ripetizioni
clear x y r 
x = V2_Total_Reps(:);   % subjects × 1
fprintf('\nFrequency-resolved correlations: total reps vs eeg \n');

for f = 1:nBands
    
    band_name = bands{f};
    
    % Skip if this band has no ROI defined
    if ~isfield(ROI, band_name) || isempty(ROI.(band_name))
        continue
    end
    
    chan_idx = ROI.(band_name);

    fmin = freq_ranges(f,1);
    fmax = freq_ranges(f,2);

    fs = find(freq >= fmin, 1, 'first');
    fe = find(freq <= fmax, 1, 'last');

    % Mean power across ROI electrodes
    EO1_pow = nanmean(grandavg_cond1.powspctrm(:,chan_idx,fs:fe), [2 3]);
    EO2_pow = nanmean(grandavg_cond2.powspctrm(:,chan_idx,fs:fe), [2 3]);

    y = EO2_pow - EO1_pow;   % subjects × 1
    valid = ~isnan(x) & ~isnan(y);

    if sum(valid) >= 5
        [r,p] = corr(x(valid), y(valid), 'Type','Pearson');

        Results.(band_name).r = r;
        Results.(band_name).p = p;

        fprintf('%s band: r = %.3f, p = %.4f (n=%d)\n', ...
                band_name, r, p, sum(valid));

        figure;
        scatter(x(valid), y(valid), 70, 'filled');
        lsline;
        xlabel('Behavioral metric');
        ylabel(sprintf('Δ Resting Power (%s)', band_name));
        title(sprintf('%s band: r = %.2f, p = %.3f', band_name, r, p));
        grid on;
    end
end

%%
clear x y r 
x = V3_TrialDiff_1_6(:);   % subjects × 1
fprintf('\nFrequency-resolved correlations: delta numero reps 6 - num reps 1  vs eeg \n');

for f = 1:nBands
    
    band_name = bands{f};
    
    % Skip if this band has no ROI defined
    if ~isfield(ROI, band_name) || isempty(ROI.(band_name))
        continue
    end
    
    chan_idx = ROI.(band_name);

    fmin = freq_ranges(f,1);
    fmax = freq_ranges(f,2);

    fs = find(freq >= fmin, 1, 'first');
    fe = find(freq <= fmax, 1, 'last');

    % Mean power across ROI electrodes
    EO1_pow = nanmean(grandavg_cond1.powspctrm(:,chan_idx,fs:fe), [2 3]);
    EO2_pow = nanmean(grandavg_cond2.powspctrm(:,chan_idx,fs:fe), [2 3]);

    y = EO2_pow - EO1_pow;   % subjects × 1
    valid = ~isnan(x) & ~isnan(y);

    if sum(valid) >= 5
        [r,p] = corr(x(valid), y(valid), 'Type','Pearson');

        Results.(band_name).r = r;
        Results.(band_name).p = p;

        fprintf('%s band: r = %.3f, p = %.4f (n=%d)\n', ...
                band_name, r, p, sum(valid));

        figure;
        scatter(x(valid), y(valid), 70, 'filled');
        lsline;
        xlabel('Behavioral metric');
        ylabel(sprintf('Δ Resting Power (%s)', band_name));
        title(sprintf('%s band: r = %.2f, p = %.3f', band_name, r, p));
        grid on;
    end
end

%%
clear x y r 
x = V4_TimeDiff_Firsts(:);   % subjects × 1
fprintf('\nFrequency-resolved correlations: tempo 6.1 - tempo 1.1  vs eeg \n');


for f = 1:nBands
    
    band_name = bands{f};
    
    % Skip if this band has no ROI defined
    if ~isfield(ROI, band_name) || isempty(ROI.(band_name))
        continue
    end
    
    chan_idx = ROI.(band_name);

    fmin = freq_ranges(f,1);
    fmax = freq_ranges(f,2);

    fs = find(freq >= fmin, 1, 'first');
    fe = find(freq <= fmax, 1, 'last');

    % Mean power across ROI electrodes
    EO1_pow = nanmean(grandavg_cond1.powspctrm(:,chan_idx,fs:fe), [2 3]);
    EO2_pow = nanmean(grandavg_cond2.powspctrm(:,chan_idx,fs:fe), [2 3]);

    y = EO2_pow - EO1_pow;   % subjects × 1
    valid = ~isnan(x) & ~isnan(y);

    if sum(valid) >= 5
        [r,p] = corr(x(valid), y(valid), 'Type','Pearson');

        Results.(band_name).r = r;
        Results.(band_name).p = p;

        fprintf('%s band: r = %.3f, p = %.4f (n=%d)\n', ...
                band_name, r, p, sum(valid));

        figure;
        scatter(x(valid), y(valid), 70, 'filled');
        lsline;
        xlabel('Behavioral metric');
        ylabel(sprintf('Δ Resting Power (%s)', band_name));
        title(sprintf('%s band: r = %.2f, p = %.3f', band_name, r, p));
        grid on;
    end
end

%%

vecSubj_1    = NaN(21, 6);
vecSubj_last = NaN(21, 6);

for s = 1:21
    for j = 1:6

        trials = GlobalData(s).Scenarios(j).Trials;

        % First trial, first time
        vecSubj_1(s, j) = trials(1).Time(1);

        % Last trial, last time
        vecSubj_last(s, j) = trials(end).Time(end);

    end
end
avgSubj_1 = nanmean(vecSubj_1, 1);
avgSubj_last = nanmean(vecSubj_last, 1);
[p,h] = signrank(avgSubj_last,avgSubj_1)

%%
vecSubj11 =[];
vecSubj61 =[];
for s = 1:length(GlobalData)
    vecSubj11 = [vecSubj11, GlobalData(s).Scenarios(1).Trials(1).Time(1)];
    vecSubj61 = [vecSubj61, GlobalData(s).Scenarios(6).Trials(1).Time(1)];
    
   

end
figure;
bar(1,nanmean(vecSubj11));
hold on; 
bar(2, nanmean(vecSubj61));
 [p,h] = signrank(vecSubj61,vecSubj11)