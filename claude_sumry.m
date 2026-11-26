D='/home/acatalano/Desktop/Intuitive/DataStructures/';
E2=load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');
R=load([D 'ERD_ERS_Modulation_IR_ROI_bands_avgref.mat']);
L3=load([D 'ERD_ERS_Modulation_IR_Last3_avgref.mat']);
bn={E2.BANDS.name}; rn=E2.roi_names; fprintf('bands %s | rois %s\n',strjoin(bn,','),strjoin(rn,','));
fn=@(x) fprintf('%s',x);
met={'ERD','ERS','Mod'}; 
for m=1:3
  Ex=E2.([met{m} '_all']); Re=R.([met{m} '_all']);
  fprintf('\n===== %s =====\n',met{m});
  for b=1:2, for r=1:4
    e=squeeze(Ex(b,r,:,:)); % subj x 80
    rr=squeeze(Re(b,r,:,:)); % subj x 240
    es=mean(e,2,'omitnan'); rs=mean(rr,2,'omitnan');
    % expert by rep (20) 
    eRep=squeeze(mean(reshape(e,10,4,20),2,'omitnan')); % subj x 20 (reshape order: slot=(rep-1)*4+pt -> dims pt,rep)
    e3=reshape(e,10,4,20); eRepM=squeeze(mean(mean(e3,2,'omitnan'),1,'omitnan'));
    f3=mean(eRepM(1:3)); l3=mean(eRepM(18:20));
    % per subject first3/last3
    es_f=mean(squeeze(mean(e3(:,:,1:3),2,'omitnan')),2,'omitnan'); es_l=mean(squeeze(mean(e3(:,:,18:20),2,'omitnan')),2,'omitnan');
    ePt=squeeze(mean(mean(e3,3,'omitnan'),1,'omitnan'));
    % residents: 6d [b r s sc rep pt]
    r6=squeeze(Re(b,r,:,:)); r6=reshape(r6,21,4,10,6); % slot=(sc-1)*40+(rep-1)*4+pt -> dims pt,rep,sc
    rsc=squeeze(mean(mean(mean(r6,1,'omitnan'),2,'omitnan'),3,'omitnan')); % over subj,pt,rep -> need dims order
    rscM=nan(1,6); for sc=1:6, x=r6(:,:,:,sc); rscM(sc)=mean(x(:),'omitnan'); end
    rptM=nan(1,4); for p=1:4, x=r6(:,p,:,:); rptM(p)=mean(x(:),'omitnan'); end
    rrepM=nan(1,10); for q=1:10, x=r6(:,:,q,:); rrepM(q)=mean(x(:),'omitnan'); end
    l3v=squeeze(L3.([met{m} '_last3'])(b,r,:,:)); 
    fprintf('%-5s %-10s EXP mean %.3f (SD subj %.3f) | first3 %.3f last3 %.3f | pts %s | RES mean %.3f (SD %.3f) | by scen %s | by pt %s | last3 %.3f | fill exp %.0f%% res %.0f%%\n',bn{b},rn{r},mean(es,'omitnan'),std(es,'omitnan'),f3,l3,mat2str(round(ePt,3)),mean(rs,'omitnan'),std(rs,'omitnan'),mat2str(round(rscM,3)),mat2str(round(rptM,3)),mean(l3v(:),'omitnan'),100*mean(~isnan(e(:))),100*mean(~isnan(rr(:))));
  end, end
end
% subject-level fill
fprintf('\nExpert valid slots per subject (of 80), beta MotorLeft ERD: %s\n',mat2str(sum(~isnan(squeeze(E2.ERD_all(1,1,:,:))),2)'));
fprintf('Resident valid slots per subject (of 240), beta MotorLeft ERD: %s\n',mat2str(sum(~isnan(squeeze(R.ERD_all(1,1,:,:))),2)'));
fprintf('Resident ERD valid per scenario (all subj, of 840): %s\n',mat2str(arrayfun(@(sc) sum(sum(~isnan(squeeze(R.ERD_all(1,1,:,(sc-1)*40+(1:40)))))),1:6)));
fprintf('Resident reps with data per scenario (any point), median over subj: ');
for sc=1:6, x=squeeze(R.ERD_all(1,1,:,(sc-1)*40+(1:40))); n=zeros(21,1); for s=1:21, y=reshape(x(s,:),4,10); n(s)=sum(any(~isnan(y),1)); end; fprintf('S%d=%g ',sc,median(n)); end; fprintf('\n');
% expert sign/range
for m=1:3, x=E2.([met{m} '_all'])(1,1,:,:); y=R.([met{m} '_all'])(1,1,:,:); fprintf('%s beta MotorLeft range: exp [%.2f %.2f] res [%.2f %.2f]\n',met{m},min(x(:)),max(x(:)),min(y(:)),max(y(:))); end
