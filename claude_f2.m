D='/home/acatalano/Desktop/Intuitive/DataStructures/';
X=load('/home/acatalano/Desktop/Intuitive/IE_Task/Task2/Task2_FOOOF_Experts.mat');
RR=load([D 'Task_FOOOF_Residents.mat']);
rn=X.roi_names; ep={'grasp','exit'}; FX={X.FOOOF_grasp,X.FOOOF_exit}; FR={RR.FOOOF_grasp,RR.FOOOF_exit};
disp(fieldnames(X.FOOOF_grasp)');
fprintf('R2 median exp: grasp %.2f exit %.2f | res: grasp %.2f exit %.2f\n',median(X.FOOOF_grasp.r_squared(:),'omitnan'),median(X.FOOOF_exit.r_squared(:),'omitnan'),median(RR.FOOOF_grasp.r_squared(:),'omitnan'),median(RR.FOOOF_exit.r_squared(:),'omitnan'));
for e=1:2, for r=1:4
  for g=1:2
    if g==1, F=FX{e}; nS=10; nSl=80; else F=FR{e}; nS=21; nSl=240; end
    v=@(f) squeeze(F.(f)(:,r,:));
    ex=v('exponent'); of=v('offset'); ac=v('alpha_cf'); bc=v('beta_cf'); ap=v('alpha_pow'); bp=v('beta_pow'); r2=v('r_squared');
    ex(r2<0.8)=NaN; 
    sm=@(a) mean(mean(a,2,'omitnan'),'omitnan');
    sdm=@(a) std(mean(a,2,'omitnan'),'omitnan');
    fprintf('%s %-10s %s | fit ok %.0f%% | exponent %.2f (SD subj %.2f) offset %.2f | alpha found %.0f%% cf %.1f pow %.2f | beta found %.0f%% cf %.1f pow %.2f\n',ep{e},rn{r},ternary(g==1,'EXP','RES'),100*mean(~isnan(ex(:))),sm(ex),sdm(ex),sm(of),100*mean(~isnan(ac(:)))/max(mean(~isnan(ex(:))),eps)*1,sm(ac),sm(ap),100*mean(~isnan(bc(:)))/max(mean(~isnan(ex(:))),eps),sm(bc),sm(bp));
  end
end, end
% experts exponent by rep (first3 vs last3) and by point
for e=1:2, for r=[1 3]
  ex=squeeze(FX{e}.exponent(:,r,:)); ac=squeeze(FX{e}.alpha_cf(:,r,:)); bc=squeeze(FX{e}.beta_cf(:,r,:));
  re=@(a) reshape(a,10,4,20);
  e3=re(ex); a3=re(ac); b3=re(bc);
  byrep=squeeze(mean(mean(e3,2,'omitnan'),1,'omitnan')); bypt=squeeze(mean(mean(e3,3,'omitnan'),1,'omitnan'));
  fprintf('EXP %s %s exponent first3 %.2f last3 %.2f | by pt %s | alpha_cf first3 %.1f last3 %.1f | beta_cf first3 %.1f last3 %.1f\n',ep{e},rn{r},mean(byrep(1:3)),mean(byrep(18:20)),mat2str(round(bypt,2)),nm(a3(:,:,1:3)),nm(a3(:,:,18:20)),nm(b3(:,:,1:3)),nm(b3(:,:,18:20)));
end, end
% cluster results residents
C=load([D 'Task_ClusterFirstLast_Residents.mat']);
cn=fieldnames(C.Results);
for i=1:numel(cn), c=cn{i}; if ~isstruct(C.Results.(c)), continue; end
  fprintf('Cluster %s: included %d subj\n',c,numel(C.Results.(c).included));
  bn=fieldnames(C.Results.(c));
  for j=1:numel(bn), s=C.Results.(c).(bn{j}); if ~isstruct(s)||~isfield(s,'stat'), continue; end
    pp=[]; np=[]; if isfield(s,'posclusters')&&~isempty(s.posclusters), pp=[s.posclusters.prob]; end
    if isfield(s,'negclusters')&&~isempty(s.negclusters), np=[s.negclusters.prob]; end
    fprintf('  %-6s pos clusters %d (min p %.3f) neg clusters %d (min p %.3f) | max|t| %.2f\n',bn{j},numel(pp),min([pp 9]),numel(np),min([np 9]),max(abs(s.stat(:))));
  end
end
E2=exist([D 'ClusterStats_Esperti.mat'],'file'); disp(E2);
function o=ternary(c,a,b), if c,o=a;else,o=b;end,end
function o=nm(a), o=mean(a(:),'omitnan'); end
