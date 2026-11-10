clear, close all;

base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
load(fullfile(base_path, 'ERD_ERS_Modulation_Task2_ROI_bands.mat'));
% Expects: ERD_all, ERS_all, Mod_all (nBands x nROI x nSubj x nSlots)
%          roi_names, BANDS, subjects

nBands     = numel(BANDS);          % should be 2: Beta, Alpha
nROI       = numel(roi_names);      % 4: MotorLeft, MotorRight, Visual, Frontal
nSubj      = size(ERD_all, 3);
nSlots     = size(ERD_all, 4);      % 80 = 20 reps x 4 points
NUM_OUTER  = 20;                    % repetitions
NUM_POINTS = 4;

firstReps = 1:3;     % first 3 repetitions
lastReps  = 18:20;   % last 3 repetitions

metrics     = {'ERD','ERS','Modulation'};
data_fields = {ERD_all, ERS_all, Mod_all};
nMetrics    = numel(metrics);


%  COMPUTE FIRST-3 / LAST-4 AVERAGES (per subj, band, ROI, metric)

First3 = nan(nBands, nROI, nMetrics, nSubj);
Last4  = nan(nBands, nROI, nMetrics, nSubj);

for b = 1:nBands
    for r = 1:nROI
        for m = 1:nMetrics
            D      = data_fields{m};                    % (nBands,nROI,nSubj,nSlots)
            D_subj = squeeze(D(b,r,:,:));                % (nSubj, nSlots)
            D_3d   = reshape(D_subj, nSubj, NUM_POINTS, NUM_OUTER); D_3d = permute(D_3d, [1 3 2]);      % (subj, rep, point) -- SEE CAVEAT ABOVE
            D_rep  = squeeze(nanmean(D_3d, 3));          % average across points -> (subj, rep)

            First3(b,r,m,:) = nanmean(D_rep(:, firstReps), 2);
            Last4(b,r,m,:)  = nanmean(D_rep(:, lastReps),  2);
        end
    end
end

Diff = Last4 - First3;   % (nBands, nROI, nMetrics, nSubj)


%  STATISTICAL TESTS: paired t-test + Wilcoxon signed-rank, per
%  band x ROI x metric, with FDR correction across all tests

P_ttest  = nan(nBands, nROI, nMetrics);
P_wilcox = nan(nBands, nROI, nMetrics);
Tstat    = nan(nBands, nROI, nMetrics);

for b = 1:nBands
    for r = 1:nROI
        for m = 1:nMetrics
            x = squeeze(First3(b,r,m,:));
            y = squeeze(Last4(b,r,m,:));
            valid = ~isnan(x) & ~isnan(y);
            if sum(valid) > 2
                [~, p_t, ~, stats] = ttest(y(valid), x(valid));
                P_ttest(b,r,m)  = p_t;
                Tstat(b,r,m)    = stats.tstat;

                p_w = signrank(y(valid), x(valid));
                P_wilcox(b,r,m) = p_w;
            end
        end
    end
end

% FDR correction across ALL tests (both t-test and Wilcoxon families, separately)
allP_t = P_ttest(:);
validP_t = ~isnan(allP_t);
adjP_t = fdr_bh_simple(allP_t(validP_t));
adjP_ttest = nan(size(P_ttest));
adjP_ttest(validP_t) = adjP_t;

allP_w = P_wilcox(:);
validP_w = ~isnan(allP_w);
adjP_w = fdr_bh_simple(allP_w(validP_w));
adjP_wilcox = nan(size(P_wilcox));
adjP_wilcox(validP_w) = adjP_w;


%  PRINT SUMMARY TABLE

fprintf('\n=== First3 vs Last4 - Task2 - Summary (FDR-corrected) ===\n');
for b = 1:nBands
    fprintf('\n--- Band: %s ---\n', BANDS(b).name);
    for r = 1:nROI
        for m = 1:nMetrics
            fprintf('  %-12s %-6s: t-test p(adj)=%.4f | Wilcoxon p(adj)=%.4f | mean diff=%.3f\n', ...
                roi_names{r}, metrics{m}, adjP_ttest(b,r,m), adjP_wilcox(b,r,m), ...
                nanmean(squeeze(Diff(b,r,m,:))));
        end
    end
end


%  VISUALIZATION: paired dot-line plots, First3 vs Last4
%  rows = ROI, cols = metric, one figure per band

color_first = [0.4 0.6 0.9];   % light blue = first3
color_last  = [0.0 0.2 0.6];   % dark blue  = last4

for b = 1:nBands
    figure('Name', sprintf('Task2 - %s - First3 vs Last4', BANDS(b).name), ...
           'Position', [50 50 1000 900]);

    % Shared y-limits per metric across all ROIs (for this band)
    ylim_per_metric = nan(nMetrics, 2);
    for m = 1:nMetrics
        vals = [squeeze(First3(b,:,m,:)); squeeze(Last4(b,:,m,:))];
        vals = vals(:);
        vals = vals(~isnan(vals));
        pad = 0.08 * range(vals);
        ylim_per_metric(m,:) = [min(vals)-pad, max(vals)+pad];
    end

    for r = 1:nROI
        for m = 1:nMetrics
            subplot(nROI, nMetrics, (r-1)*nMetrics + m);
            hold on;

            x1 = squeeze(First3(b,r,m,:));
            x2 = squeeze(Last4(b,r,m,:));
            valid = ~isnan(x1) & ~isnan(x2);

            % Paired lines per subject
            for s = find(valid)'
                plot([1 2], [x1(s) x2(s)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
            end
            scatter(ones(sum(valid),1),   x1(valid), 40, color_first, 'filled');
            scatter(2*ones(sum(valid),1), x2(valid), 40, color_last,  'filled');

            % Mean markers
            plot(1, nanmean(x1), 'ks', 'MarkerSize', 10, 'MarkerFaceColor','k');
            plot(2, nanmean(x2), 'ks', 'MarkerSize', 10, 'MarkerFaceColor','k');

            xlim([0.5 2.5]);
            ylim(ylim_per_metric(m,:));
            xticks([1 2]); xticklabels({'First3','Last4'});
            grid on; box on;

            % Significance annotation (using FDR-corrected Wilcoxon p-value)
            p_show = adjP_wilcox(b,r,m);
            if ~isnan(p_show)
                if p_show < 0.05
                    sigTxt = sprintf('p=%.3f *', p_show);
                else
                    sigTxt = sprintf('p=%.3f', p_show);
                end
                yl = ylim;
                text(1.5, yl(2)-0.05*range(yl), sigTxt, ...
                     'HorizontalAlignment','center','FontWeight','bold','FontSize',8);
            end

            if r == 1, title(metrics{m}, 'FontWeight','bold'); end
            if m == 1, ylabel(roi_names{r}, 'FontWeight','bold'); end
            hold off;
        end
    end
    sgtitle(sprintf('Task2 - %s band: First3 vs Last4 repetitions (paired, n=%d)', ...
            BANDS(b).name, nSubj));
end


%  Helper: Benjamini-Hochberg FDR (self-contained, no dependency)

function adjP = fdr_bh_simple(pvals)
    pvals = pvals(:);
    n = length(pvals);
    [sortedP, sortIdx] = sort(pvals);
    adjSorted = sortedP .* n ./ (1:n)';
    adjSorted = flipud(cummin(flipud(adjSorted)));
    adjSorted = min(adjSorted, 1);
    adjP = nan(n,1);
    adjP(sortIdx) = adjSorted;
end