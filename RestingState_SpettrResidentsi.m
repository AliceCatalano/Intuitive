clear, close all
subjects = {'IR02','IR04','IR05', 'IR06', 'IR07', 'IR08', 'IR09', 'IR10', 'IR11', 'IR12', 'IR13', 'IR14', 'IR16', 'IR17', 'IR18', 'IR19', 'IR21', 'IR22', 'IR23', 'IR24', 'IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/IR';
images_path = '/home/acatalano/Desktop/Intuitive/'; 
load(fullfile(images_path,'grandavg1_IR.mat'));
load(fullfile(images_path,'grandavg2_IR.mat')); 
load(fullfile(images_path,'ROI_residents.mat')); 

conditions = {'EO1', 'EO2'}; 
bands = {'Theta', 'Alpha', 'Beta', 'Gamma'}; 
freq_ranges = [4 8; 8 14; 15 25; 25 35];
nBands = 4;
figure;
for c =1:3
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
        subplot(1,3,c)
        plot(grandavg_cond1.freq, smooth(EO1_spectrum), 'LineWidth',2)
        hold on
        plot(grandavg_cond1.freq, smooth(EO2_spectrum), 'LineWidth',2)
        
        title(sprintf('Cluster %d', c))
        xlabel('Frequency (Hz)')
        ylabel('Power')
        legend({'EO1','EO2'})
        grid on
        
        
       
end
sgtitle('Residents Spectrum over the ROI')
