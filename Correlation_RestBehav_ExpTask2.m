clear; close all; clc;

% Paths
base_path = '/home/acatalano/Desktop/Intuitive';
addpath '/home/acatalano/Matlab/fieldtrip-20250106';
ft_defaults;

load(fullfile(base_path, 'grandavg1_IE.mat')); % EO1
load(fullfile(base_path, 'grandavg2_IE.mat')); % EO2
load(fullfile(base_path, 'EO1.mat')); % EO1
% Expected dimensions:
% EO1, EO2 → [nSubjects x nChannels x nFreqs]

load(fullfile(base_path, 'Tapered_CleanedMatrix_IE_20_10subj.mat'));  
AlignedMatrix(:,:, [4 10]) = [];

mean_TE1 = squeeze(nanmean(AlignedMatrix(1:3,1,:),1));
mean_TE2 = squeeze(nanmean(AlignedMatrix(end-3:end,1,:),1));

time_reduction = mean_TE2 - mean_TE1;   % TE1 − TE2

bands = {'Beta','Gamma'};
freq_ranges = [15 25; 25 35];
nBands = numel(bands);

ROIs = struct;
% [1, 2, 3, 5, 6, 9]
% ROIs.cluster1 = [ 13, 17, 18, 23,  29, 30]
% ROIs.cluster2 = [ 10, 15, 20]
% ---- Alpha ----
ROIs.cluster1 = [11, 16, 21, 26, 22, 27];  %21 26 22 27

freq = all_data_cond1_norm{1,1}.freq;
nFreq = length(freq);
nSubjects = size(grandavg_cond1.powspctrm,1);

x = time_reduction(:);   % subjects × 1
fprintf('\nFrequency-resolved correlations: Time vs EEG change\n');

roi_names = fieldnames(ROIs);
Results = struct;

for rID = 1:numel(roi_names)

    roi_name = roi_names{rID};
    chan_idx = ROIs.(roi_name);

    r_vec = NaN(nFreq,1);
    p_vec = NaN(nFreq,1);

    for f = 1:nBands

        fmin = freq_ranges(f,1);
        fmax = freq_ranges(f,2);
    
        fs = find(freq >= fmin, 1, 'first');
        fe = find(freq <= fmax, 1, 'last');

        % Mean power across ROI electrodes at this frequency
        EO1_pow = nanmean(grandavg_cond1.powspctrm(:,chan_idx,fs:fe), [2 3]);
        EO2_pow = nanmean(grandavg_cond2.powspctrm(:,chan_idx,fs:fe), [2 3]);

        y = EO2_pow - EO1_pow;   % subjects × 1

        valid = ~isnan(x) & ~isnan(y);

        if sum(valid) >= 5   % minimum sensible n
            [r,p] = corr(x(valid), y(valid), 'Type','Spearman');
            r_vec(f) = r;
            p_vec(f) = p;
            fprintf('%s band: r = %.3f, p = %.4f (n=%d)\n', ...
                    bands{f}, r, p, sum(valid));
            
                figure;
                scatter(x(valid), y(valid), 70, 'filled');
                lsline;
                xlabel('Time reduction (TE1 − TE2)');
                ylabel(sprintf('Δ Resting Power (%s cluster)', bands{f}));
                title(sprintf('%s band: r = %.2f, p = %.3f', bands{f}, r, p));
                grid on;
        end
    end

    Results.(roi_name).r = r_vec;
    Results.(roi_name).p = p_vec;

    fprintf('Done: %s\n', roi_name);
end
% R value meaning
% 0.0 → no linear relationship
% 0.1–0.3 → weak
% 0.3–0.5 → moderate
% 0.5–0.7 → moderately strong
% 0.7–1.0 → strong
