D='/home/acatalano/Desktop/Intuitive/DataStructures/';
files={[D 'ERD_ERS_Modulation_IR_ROI_bands.mat'],[D 'ERD_ERS_Modulation_Task2_ROI_bands.mat'],[D 'ERD_ERS_Modulation_IR_Last3.mat'],'/home/acatalano/Desktop/Intuitive/IE_Task/Task2/Task2_FOOOF_Experts.mat','/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat',[D 'Task_ClusterFirstLast_Residents.mat']};
for i=1:numel(files)
  fprintf('--- %s\n',files{i});
  if exist(files{i},'file'), w=whos('-file',files{i}); for k=1:numel(w), fprintf('  %s %s\n',w(k).name,mat2str(w(k).size)); end, else, disp('  missing'); end
end
