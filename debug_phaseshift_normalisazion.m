load(fullfile(base_path, 'Task2exit_ps_allExp_struct.mat'));

freq_axis = Task2_exit_allExp{1}.freq;
time_ERS  = Task2_exit_allExp{1}.time;
chan_idx   = [15, 20, 10];
t_s = find(time_ERS >= -2.0, 1,'first');
t_e = find(time_ERS <=  0.0, 1,'last');

% fit range: exclude below 4Hz and above 35Hz
fit_lo = find(freq_axis >= 4,  1,'first');
fit_hi = find(freq_axis <= 35, 1,'last');
freq_fit = freq_axis(fit_lo:fit_hi);

figure;
for s = 1:length(Task2_exit_allExp)
    fou  = Task2_exit_allExp{s}.fourierspctrm;
    pow  = abs(fou).^2;
    pow_mean = squeeze(nanmean(nanmean(pow(:, chan_idx, :, t_s:t_e), 4), 2));
    spec = nanmean(pow_mean, 1)';
    % [nFreq x 1]

    spec_fit = spec(fit_lo:fit_hi);

    % fit in log-log space
    log_f    = log10(freq_fit(:));
    log_s    = log10(spec_fit(:));
    valid    = ~isnan(log_s) & ~isinf(log_s);
    p        = polyfit(log_f(valid), log_s(valid), 1);
    fit_line = polyval(p, log_f);

    % aperiodic-corrected spectrum
    corrected = log_s - fit_line;

    subplot(2,5,s);
    plot(freq_fit, corrected, 'b-', 'LineWidth',1.5);
    yline(0,'k--','LineWidth',0.8);
    xlabel('Hz'); ylabel('Log power - 1/f fit');
    title(sprintf('IE%d', s));
    xline(8,'r:'); xline(14,'r:'); xline(25,'r:');
    grid on;
end
sgtitle('Aperiodic-corrected spectrum Task2 — peaks above zero are genuine');