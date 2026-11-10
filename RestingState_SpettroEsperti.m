clear, close all
subjects = {'IE02','IE03','IE04', 'IE06', 'IE07', 'IE08', 'IE09', 'IE10'}; 
base_path = '/home/acatalano/Desktop/Intuitive/IE_EO_Puliti'; 
images_path = '/home/acatalano/Desktop/Intuitive/'; 
load(fullfile(images_path,'grandavg1_IE.mat'));
load(fullfile(images_path,'grandavg2_IE.mat')); 
load(fullfile(images_path,'ROI_Esperti.mat')); 

conditions = {'EO1', 'EO2'}; 
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'}; 
freq_ranges = [4 8; 8 14; 15 25; 25 35];
nBands = 4;
 figure;
for c =1:2
        roi_field = sprintf('cluster%d',c);
        
        % Check if ROI exists for this band
        if isfield(ROIs, roi_field)
            Chan = ROIs.(roi_field);
        else
            warning('No ROI defined for %s', roi_field);
            continue
        end
    
        EO1_spectrum =squeeze(nanmean(grandavg_cond1.powspctrm(:,Chan,:), [1 2])); %[sbj, chn, freq]
        EO2_spectrum =squeeze(nanmean(grandavg_cond2.powspctrm(:,Chan,:), [1 2])); %[sbj, chn, freq]
        
      % ---- Plot ----
        subplot(1,2,c)
        plot(grandavg_cond1.freq, smooth(EO1_spectrum), 'LineWidth',2)
        hold on
        plot(grandavg_cond1.freq, smooth(EO2_spectrum), 'LineWidth',2)
        
        title(sprintf('Cluster %d', c))
        xlabel('Frequency (Hz)')
        ylabel('Power')
        legend({'EO1','EO2'})
        grid on
        
        
       
end
sgtitle('Experts Spectrum over the ROI')
