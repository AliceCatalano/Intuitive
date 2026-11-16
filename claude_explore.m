OUT='ex/'; if ~exist(OUT,'dir'), mkdir(OUT); end
E2=load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/ERD_ERS_Modulation_Task2_ROI_bands.mat');
R=load('/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat');
G(1).n='Experts'; G(1).D=E2; G(1).ns=10; G(1).nsc=1; G(1).nr=20; 
G(2).n='Residents'; G(2).D=R; G(2).ns=21; G(2).nsc=6; G(2).nr=10;
met={'ERD','ERS','Mod'}; side={'Motor LEFT','Motor RIGHT'}; bn={'Beta','Alpha'};
lim=struct('ERD',[-1 0],'ERS',[-1 1.5],'Mod',[0 2.5]);
% ---- Level 1: every slot (subject x slot) ----
for g=1:2, for b=1:2
 f=figure('Visible','off','Position',[20 20 1700 800],'Color','w');
 for m=1:3, for r=1:2
  A=squeeze(G(g).D.([met{m} '_all'])(b,r,:,:));
  subplot(3,2,(m-1)*2+r); imagesc(A,'AlphaData',~isnan(A)); set(gca,'Color',[.85 .85 .85]); caxis(lim.(met{m})); colorbar;
  hold on; step=4*G(g).nr; for k=1:G(g).nsc-1, xline(k*step+.5,'k-','LineWidth',1.2); end
  title(sprintf('%s | %s | %s',G(g).n,bn{b},[met{m} ' ' side{r}])); xlabel('slot (4 points x reps, scenario blocks)'); ylabel('subject');
 end,end
 sgtitle(sprintf('LEVEL 1 - %s, %s: every slot of every subject (grey = no data)',G(g).n,bn{b}));
 print(f,sprintf('%sL1_%s_%s.png',OUT,G(g).n,bn{b}),'-dpng','-r90'); close(f);
end,end
% ---- Level 2: per-subject trace per repetition (4 points averaged), both sides ----
for g=1:2, for b=1:2
 f=figure('Visible','off','Position',[20 20 1700 900],'Color','w'); nrep=G(g).nr*G(g).nsc;
 for m=1:3, for r=1:2
  A=squeeze(G(g).D.([met{m} '_all'])(b,r,:,:)); X=squeeze(mean(reshape(A,G(g).ns,4,nrep),2,'omitnan'));
  subplot(3,2,(m-1)*2+r); hold on; plot(1:nrep,X','-','Color',[.5 .5 .5 .5]); plot(1:nrep,X','.','Color',[.2 .2 .2],'MarkerSize',8);
  for k=1:G(g).nsc-1, xline(k*G(g).nr+.5,'r:'); end
  title(sprintf('%s | %s',bn{b},[met{m} ' ' side{r}])); xlabel('repetition (global order)'); grid on;
 end,end
 sgtitle(sprintf('LEVEL 2 - %s: one grey line per subject, point = one repetition (4 points averaged)',G(g).n));
 print(f,sprintf('%sL2_%s_%s.png',OUT,G(g).n,bn{b}),'-dpng','-r90'); close(f);
end,end
% ---- Level 3: group mean per repetition, with n, only where n>=NMIN ----
NMIN=5;
for g=1:2, for b=1:2
 f=figure('Visible','off','Position',[20 20 1700 900],'Color','w'); nrep=G(g).nr*G(g).nsc;
 for m=1:3
  subplot(4,2,[(m-1)*2+1 (m-1)*2+2]*0+ (m-1)*2+1); hold on;
  for r=1:2
   A=squeeze(G(g).D.([met{m} '_all'])(b,r,:,:)); X=squeeze(mean(reshape(A,G(g).ns,4,nrep),2,'omitnan'));
   n=sum(~isnan(X),1); mu=mean(X,1,'omitnan'); se=std(X,0,1,'omitnan')./sqrt(n); ok=n>=NMIN;
   mu(~ok)=NaN; se(~ok)=NaN; errorbar(1:nrep,mu,se,'-o','LineWidth',1.2,'DisplayName',side{r});
  end
  legend; title([bn{b} ' ' met{m} ' (mean+-SEM, reps with n>=' num2str(NMIN) ' subjects)']); grid on; xlabel('repetition');
  for k=1:G(g).nsc-1, xline(k*G(g).nr+.5,'r:','HandleVisibility','off'); end
 end
 subplot(4,2,7); A=squeeze(G(g).D.ERS_all(b,1,:,:)); X=squeeze(mean(reshape(A,G(g).ns,4,nrep),2,'omitnan')); bar(sum(~isnan(X),1)); yline(NMIN,'r'); title('number of subjects with data per repetition'); xlabel('repetition');
 sgtitle(sprintf('LEVEL 3 - %s, %s: both motor sides, n shown',G(g).n,bn{b}));
 print(f,sprintf('%sL3_%s_%s.png',OUT,G(g).n,bn{b}),'-dpng','-r90'); close(f);
end,end
disp done
