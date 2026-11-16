D='/home/acatalano/Desktop/Intuitive/DataStructures/';
C=load([D 'Task_ClusterFirstLast_Residents.mat']);
for c={'graspERD','exitERS'}, for b={'Theta','Alpha'}
  s=C.Results.(c{1}).(b{1});
  if isfield(s,'negclusters')&&~isempty(s.negclusters)
    for k=find([s.negclusters.prob]<0.05)
      ch=find(s.negclusterslabelmat==k); fprintf('%s %s neg cluster %d: p=%.3f, %d channels: %s | mean t in cluster %.2f\n',c{1},b{1},k,s.negclusters(k).prob,numel(ch),strjoin(s.label(ch)',','),mean(s.stat(ch)));
    end
  end
end,end
w=whos('-file',[D 'ClusterStats_Esperti.mat']); for k=1:numel(w), fprintf('exp cluster var %s %s\n',w(k).name,mat2str(w(k).size)); end
w=whos('-file',[D 'Task_ClusterStats_Residents.mat']); for k=1:numel(w), fprintf('old res cluster var %s %s\n',w(k).name,mat2str(w(k).size)); end
