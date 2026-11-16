L=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_Last3.mat');
for b=1:2
 M=squeeze(L.ERS_last3(b,1,:,:)); full=all(~isnan(M),2);
 fprintf('band %d: residents with all 6 scenarios: %d\n',b,sum(full));
 fprintf(' all-subjects mean per scen: %s\n',mat2str(round(mean(M,1,'omitnan'),3)));
 fprintf(' complete-only mean per scen: %s\n',mat2str(round(mean(M(full,:),1),3)));
 % within-resident: scenario 4 minus scenario 3, residents having both
 d=M(:,4)-M(:,3); ok=~isnan(d); fprintf(' s4-s3 per resident (n=%d): mean %.3f, positive in %d\n',sum(ok),mean(d(ok)),sum(d(ok)>0));
end
