E2=load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');
R=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat');
disp(fieldnames(E2)'); disp(fieldnames(R)');
disp(size(E2.ERD_all)); disp(size(R.ERD_all)); disp(E2.roi_names); 
if isfield(E2,'band_names'), disp(E2.band_names); end
if isfield(R,'band_names'), disp(R.band_names); end
