OUT='ex3/'; if ~exist(OUT,'dir'), mkdir(OUT); end
S=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat');
L=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_Last3.mat');
fprintf('ERD_6d size: %s\n',mat2str(size(S.ERD_6d)));
met={'ERD','ERS','Mod'}; src={S.ERD_6d,S.ERS_6d,S.Mod_6d}; rn={'MotorLeft','MotorRight','Visual','Frontal'}; bn={'Beta','Alpha'};
nS=21; nSc=6; NMIN=5;
for b=1:2
 % slot-level matrix [roi x met] -> subj x (6 scen x 3 reps x 4 pts)
 X=nan(3,4,nS,nSc*12);
 for s=1:nS, for sc=1:nSc
  reps=L.Last3Reps{s,sc}; if isempty(reps), continue; end
  for m=1:3, for r=1:4
   v=squeeze(src{m}(b,r,s,sc,reps(:)',:)); % [3 x 4]
   X(m,r,s,(sc-1)*12+(1:12))=reshape(v',1,[]);
  end,end
 end,end
 % L1
 f=figure('Visible','off','Position',[20 20 1900 900],'Color','w');
 for m=1:3, for r=1:4
  A=squeeze(X(m,r,:,:)); subplot(3,4,(m-1)*4+r); imagesc(A,'AlphaData',~isnan(A)); v=A(~isnan(A));
  if ~isempty(v), cl=prctile(v,[1 99]); if cl(2)>cl(1), caxis(cl); end, end; colorbar; hold on;
  for k=1:nSc-1, xline(k*12+.5,'k-'); end
  title(sprintf('%s %s %s',bn{b},met{m},rn{r})); xlabel('slot (3 successful reps x 4 points, per scenario)'); ylabel('resident');
 end,end
 sgtitle(sprintf('LAST 3 SUCCESSFUL - LEVEL 1, Residents, %s: every slot of the 3 successful repetitions (white = no data)',bn{b}));
 print(f,sprintf('%sL1_last3_%s.png',OUT,bn{b}),'-dpng','-r80'); close(f);
 % L2: per resident, per scenario (mean of 12 slots) + per suture point colours
 f=figure('Visible','off','Position',[20 20 1900 900],'Color','w');
 for m=1:3, for r=1:4
  A=squeeze(X(m,r,:,:)); M=squeeze(mean(reshape(A,nS,12,nSc),2,'omitnan'));
  subplot(3,4,(m-1)*4+r); plot(1:nSc,M','-','Color',[.5 .5 .5 .5]); hold on; plot(1:nSc,M','k.','MarkerSize',9); grid on; xlim([.5 6.5]);
  title(sprintf('%s %s %s',bn{b},met{m},rn{r})); xlabel('scenario');
 end,end
 sgtitle(sprintf('LAST 3 SUCCESSFUL - LEVEL 2, Residents, %s: one line per resident, point = mean of the 3 successful repetitions of a scenario',bn{b}));
 print(f,sprintf('%sL2_last3_%s.png',OUT,bn{b}),'-dpng','-r80'); close(f);
 % L3: group mean per scenario with n
 f=figure('Visible','off','Position',[20 20 1900 1000],'Color','w');
 for m=1:3, for r=1:4
  A=squeeze(X(m,r,:,:)); M=squeeze(mean(reshape(A,nS,12,nSc),2,'omitnan')); n=sum(~isnan(M),1);
  mu=mean(M,1,'omitnan'); se=std(M,0,1,'omitnan')./sqrt(n); ok=n>=NMIN; mu(~ok)=NaN;
  subplot(4,4,(m-1)*4+r); errorbar(1:nSc,mu,se,'-o','LineWidth',1.2); grid on; xlim([.5 6.5]);
  title(sprintf('%s %s %s (n>=%d)',bn{b},met{m},rn{r},NMIN)); xlabel('scenario');
 end,end
 A=squeeze(X(2,1,:,:)); M=squeeze(mean(reshape(A,nS,12,nSc),2,'omitnan')); subplot(4,4,13:16); bar(sum(~isnan(M),1)); yline(NMIN,'r'); title('number of residents with data per scenario'); xlabel('scenario'); xlim([.5 6.5]);
 sgtitle(sprintf('LAST 3 SUCCESSFUL - LEVEL 3, Residents, %s: group mean +- SEM per scenario',bn{b}));
 print(f,sprintf('%sL3_last3_%s.png',OUT,bn{b}),'-dpng','-r80'); close(f);
 % counts
 M=squeeze(mean(reshape(squeeze(X(2,1,:,:)),nS,12,nSc),2,'omitnan')); fprintf('%s residents with data per scenario: %s\n',bn{b},mat2str(sum(~isnan(M),1)));
end
