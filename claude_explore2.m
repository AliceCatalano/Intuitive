OUT='ex2/'; if ~exist(OUT,'dir'), mkdir(OUT); end
E2=load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');
R=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat');
G(1).n='Experts'; G(1).D=E2; G(1).ns=10; G(1).nsc=1; G(1).nr=20;
G(2).n='Residents'; G(2).D=R; G(2).ns=21; G(2).nsc=6; G(2).nr=10;
met={'ERD','ERS','Mod'}; rn={'MotorLeft','MotorRight','Visual','Frontal'}; bn={'Beta','Alpha'}; NMIN=5;
for g=1:2, for b=1:2
 nrep=G(g).nr*G(g).nsc;
 % L1
 f=figure('Visible','off','Position',[20 20 1900 900],'Color','w');
 for m=1:3, for r=1:4
  A=squeeze(G(g).D.([met{m} '_all'])(b,r,:,:)); subplot(3,4,(m-1)*4+r);
  imagesc(A,'AlphaData',~isnan(A)); v=A(~isnan(A)); cl=prctile(v,[1 99]); if cl(2)>cl(1), caxis(cl); end; colorbar;
  hold on; for k=1:G(g).nsc-1, xline(k*4*G(g).nr+.5,'k-'); end
  title(sprintf('%s %s %s',bn{b},met{m},rn{r})); xlabel('slot'); ylabel('subject');
 end,end
 sgtitle(sprintf('LEVEL 1 - %s, %s: every slot (white = no data; colour scale = 1st-99th percentile of each panel)',G(g).n,bn{b}));
 print(f,sprintf('%sL1_%s_%s.png',OUT,G(g).n,bn{b}),'-dpng','-r80'); close(f);
 % L2
 f=figure('Visible','off','Position',[20 20 1900 900],'Color','w');
 for m=1:3, for r=1:4
  A=squeeze(G(g).D.([met{m} '_all'])(b,r,:,:)); X=squeeze(mean(reshape(A,G(g).ns,4,nrep),2,'omitnan'));
  subplot(3,4,(m-1)*4+r); hold on; plot(1:nrep,X','-','Color',[.5 .5 .5 .5]); plot(1:nrep,X','k.','MarkerSize',6);
  for k=1:G(g).nsc-1, xline(k*G(g).nr+.5,'r:'); end
  title(sprintf('%s %s %s',bn{b},met{m},rn{r})); xlabel('repetition'); grid on;
 end,end
 sgtitle(sprintf('LEVEL 2 - %s, %s: one line per subject (4 points averaged)',G(g).n,bn{b}));
 print(f,sprintf('%sL2_%s_%s.png',OUT,G(g).n,bn{b}),'-dpng','-r80'); close(f);
 % L3
 f=figure('Visible','off','Position',[20 20 1900 1000],'Color','w');
 for m=1:3, for r=1:4
  A=squeeze(G(g).D.([met{m} '_all'])(b,r,:,:)); X=squeeze(mean(reshape(A,G(g).ns,4,nrep),2,'omitnan'));
  n=sum(~isnan(X),1); mu=mean(X,1,'omitnan'); se=std(X,0,1,'omitnan')./sqrt(n); ok=n>=NMIN; mu(~ok)=NaN; se(~ok)=NaN;
  subplot(4,4,(m-1)*4+r); errorbar(1:nrep,mu,se,'-o','LineWidth',1,'MarkerSize',3); grid on;
  hold on; for k=1:G(g).nsc-1, xline(k*G(g).nr+.5,'r:'); end
  title(sprintf('%s %s %s (n>=%d)',bn{b},met{m},rn{r},NMIN)); xlabel('repetition');
 end,end
 A=squeeze(G(g).D.ERS_all(b,1,:,:)); X=squeeze(mean(reshape(A,G(g).ns,4,nrep),2,'omitnan'));
 subplot(4,4,[13 14 15 16]); bar(sum(~isnan(X),1)); yline(NMIN,'r'); title('number of subjects with data per repetition'); xlabel('repetition');
 sgtitle(sprintf('LEVEL 3 - %s, %s: group mean +- SEM per repetition',G(g).n,bn{b}));
 print(f,sprintf('%sL3_%s_%s.png',OUT,G(g).n,bn{b}),'-dpng','-r80'); close(f);
end,end
disp done
