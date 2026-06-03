clear, 
restoredefaultpath; 
addpath '/home/acatalano/Documents/fieldtrip-20241219'; 
ft_defaults; 
addpath '/home/acatalano/Documents/eeglab_current/eeglab2025.0.0'; 
eeglab; 

base_path = '/home/acatalano/Desktop/Intuitive/'; 
images_path = '/home/acatalano/Desktop/Intuitive/'; 
load(fullfile(images_path,'grandavg1_IR.mat'));
ClusterStats_Esperti = load(fullfile(images_path,'ClusterStats_Esperti.mat')); 
ClusterStats_Residents = load(fullfile(images_path,'ClusterStats_Residents.mat'));
ROI_Esperti = load(fullfile(images_path,'ROI_Esperti.mat'));
ROI_residents = load(fullfile(images_path,'ROI_residents.mat'));
EEG = pop_loadset('filename', 'IR06_EO_downS_filt.set', 'filepath', '/home/acatalano/Desktop/Intuitive/');

bands = {'Theta', 'Alpha', 'Beta', 'Gamma'}; 
freq_ranges = [4 8; 8 14; 15 25; 25 35];
nBands = 4;
%%
figure;
set(gcf,'Position',[100 100 1100 1000])

ax = gobjects(nBands,2);

for b = 1:nBands
    
    clE_band = ClusterStats_Esperti.Clusterstatistic.(bands{b}).stat;
    clR_band = ClusterStats_Residents.Clusterstatistic.(bands{b}).stat;
    
    % LEFT COLUMN
    ax(b,1) = subplot(nBands,2,(b-1)*2+1);
    topoplot(clE_band, EEG.chanlocs, ...
        'electrodes','off','gridscale',100,'headrad',0.61,...
        'maplimits',[-5 5], ...
        'emarker2',{ROI_Esperti.ROI.(bands{b}),'o',[0 0 0],5,1});
    caxis([-5 5])
    
    if b==1
        title('Cluster Experts','FontSize',18,'FontWeight','bold')
    end
    
    % RIGHT COLUMN
    ax(b,2) = subplot(nBands,2,(b-1)*2+2);
    topoplot(clR_band, EEG.chanlocs, ...
        'electrodes','off','gridscale',100,'headrad',0.61,...
        'maplimits',[-5 5], ...
        'emarker2',{ROI_residents.ROI.(bands{b}),'o',[0 0 0],5,1});
    caxis([-5 5])
    
    if b==1
        title('Cluster Residents','FontSize',18,'FontWeight','bold')
    end
    ax = subplot(nBands,2,(b-1)*2+1);
    pos = ax.Position; 
    label_ax = axes('Position',[pos(1)-0.04 pos(2) 0.01 pos(4)],'Visible','off'); 
    text(0.5,0.5,bands{b}, 'FontSize',20, 'FontWeight','bold', 'HorizontalAlignment','center', 'VerticalAlignment','middle','Rotation',90); 
end

% LEFT VERTICAL BAND LABELS 
for row = 1:nBands 
    
end

% Get all axes inside the tiledlayout
ax = findall(gcf,'type','axes');
ax = ax(~arrayfun(@(x) isa(x,'matlab.graphics.illustration.ColorBar'), ax));

colormap("jet")

cb = colorbar('Position',[0.92 0.15 0.02 0.7]);
cb.Label.String = 'T-value';
cb.Label.FontSize = 14;