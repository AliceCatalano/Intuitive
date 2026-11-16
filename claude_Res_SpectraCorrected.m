% claude_Res_SpectraCorrected.m
% RESIDENTS: aperiodic-corrected spectrum per ROI, one line per resident.
% Same method and layout as FIGURE 2 of Task2_fooof.m (experts):
%   per slot: log10(power), straight-line fit in log-log over the whole frequency
%   axis (the 1/f part), residual = "log power - 1/f"; mean over the slots of a
%   resident; triangle = peak (maximum) of that mean spectrum.
%   Top row: Exit epoch (window -2..0 s), bottom row: Grasp epoch (-0.5..1 s).
%   Solid line: peak in alpha (8-15 Hz), dashed: peak elsewhere (as in the experts' Exit row).
% Input : DataStructures/Task_FOOOF_Residents.mat (Task_Res_FOOOF.m): Spec_grasp, Spec_exit
%         [subj x ROI x 240 slots x freq], power already averaged over the ROI channels
%         and over the epoch window, same frequency axis as the experts.
% Output: figure on screen + PNG next to the data (DataStructures/Res_SpectraCorrected.png)

clear; close all; clc;
D = '/home/acatalano/Desktop/Intuitive/DataStructures/';
F = load([D 'Task_FOOOF_Residents.mat']);
freq = F.freq(:)';   roi_names = F.roi_names;   subjects = F.subjects;
nSubj = numel(subjects);   nROI = numel(roi_names);   NUM_SLOTS = size(F.Spec_grasp, 3);
freq_even = linspace(freq(1), freq(end), numel(freq));
colors_subj = turbo(nSubj);
SP = {F.Spec_exit, F.Spec_grasp};   epoch_names = {'Exit', 'Grasp'};

figure('Position', [50 50 1500 750], 'Color', 'w');
for e = 1:2
    for r = 1:nROI
        subplot(2, nROI, (e-1)*nROI + r); hold on;
        nPlotted = 0;
        for s = 1:nSubj
            specs = nan(NUM_SLOTS, numel(freq_even));
            for slot = 1:NUM_SLOTS
                spec_s = squeeze(SP{e}(s, r, slot, :))';
                if any(spec_s <= 0) || any(isnan(spec_s)), continue; end
                spec_even = interp1(freq, spec_s, freq_even, 'linear');
                log_f = log10(freq_even(:));  log_s = log10(spec_even(:));
                valid = ~isnan(log_s) & ~isinf(log_s);
                if sum(valid) < 5, continue; end
                p = polyfit(log_f(valid), log_s(valid), 1);
                specs(slot, :) = log_s' - polyval(p, log_f)';
            end
            mean_spec = mean(specs, 1, 'omitnan');
            if all(isnan(mean_spec)), continue; end
            [~, pk] = max(mean_spec);
            ls = '-'; if e == 1 && ~(freq_even(pk) >= 8 && freq_even(pk) < 15), ls = '--'; end
            plot(freq_even, mean_spec, ls, 'Color', [colors_subj(s,:) 0.85], 'LineWidth', 1, ...
                'DisplayName', sprintf('%s (%.1fHz)', subjects{s}, freq_even(pk)));
            scatter(freq_even(pk), mean_spec(pk), 60, colors_subj(s,:), 'v', 'filled', 'HandleVisibility', 'off');
            nPlotted = nPlotted + 1;
        end
        xline(8, 'k:', 'HandleVisibility', 'off'); xline(15, 'k:', 'HandleVisibility', 'off'); xline(25, 'k:', 'HandleVisibility', 'off');
        yline(0, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        yl = ylim;
        text(11, yl(2)*0.92, 'α','FontSize',9,'HorizontalAlignment','center');
        text(17, yl(2)*0.92, 'β','FontSize',9,'HorizontalAlignment','center');
        xlabel('Hz'); ylabel('Log power - 1/f'); grid on;
        title(sprintf('%s | %s (n=%d residents)', roi_names{r}, epoch_names{e}, nPlotted), 'Interpreter', 'none');
        xlim([freq_even(1) freq_even(end)]);
    end
end
sgtitle('RESIDENTS: aperiodic-corrected spectrum (mean over slots, one line per resident) - triangle = peak; Exit row: solid = alpha peak, dashed = other');
print(gcf, [D 'Res_SpectraCorrected.png'], '-dpng', '-r110');
