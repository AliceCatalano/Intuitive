L=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_Last3.mat');
f=fieldnames(L); for i=1:numel(f), x=L.(f{i}); fprintf('%s %s %s\n',f{i},class(x),mat2str(size(x))); end
