clear, close all;
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects = {'IR02','IR04','IR05','IR06','IR07','IR08','IR09','IR10','IR11','IR12', ...
            'IR13','IR14','IR16','IR17','IR18','IR19','IR21','IR22','IR23','IR24','IR25'};
base_path = '/home/acatalano/Desktop/Intuitive/';
nSubj = length(subjects);
nScen = 6;

%% LOAD SAVED EEG METRIC FILES

ERD_first  = loadSingleVar('ERD_allFirst_res.mat');
ERD_last   = loadSingleVar('ERD_allLast_res.mat');
Mod_first  = loadSingleVar('Modulation_Residents_first.mat');
Mod_last   = loadSingleVar('Modulation_Residents_Last.mat');
diff_ERD   = loadSingleVar('DeltaerD_res.mat');
diff_ERS   = loadSingleVar('DeltaerS_res.mat');
diff_Mod   = loadSingleVar('DeltaMod_res.mat');

% Sanity checks
eegVars = {ERD_first, ERD_last, Mod_first, Mod_last, diff_ERD, diff_ERS, diff_Mod};
eegNames = {'ERD_first','ERD_last','Mod_first','Mod_last','diff_ERD','diff_ERS','diff_Mod'};
for k = 1:numel(eegVars)
    if ~isequal(size(eegVars{k}), [nSubj nScen])
        warning('%s has size [%s] - expected [%d %d]. Check alignment!',eegNames{k}, num2str(size(eegVars{k})), nSubj, nScen);
    end
end

%% LOAD / RECOMPUTE BEHAVIORAL DATA (GlobalData + SutureTimesMatrix)
load('performanceStruct_IR_updated.mat');      % adjust filename if different
load('SutureTimesMatrix_IR.mat'); % adjust filename if different

RepCounts = [
     4   3  10   6   6   7   % IR02
     5   6   3   3   3   9   % IR04
     6  10   9   3   3   5   % IR05
     6   3   8   3   6   4   % IR06
     4   4   9   5   3  10   % IR07
     6  10  10   5   3   3   % IR08
     4   3  10   3   5   3   % IR09
    10  10  10  10   3   3   % IR10
     5   3   4   3   9   5   % IR11
     7   3  10   4   8   3   % IR12
    10   3   3   3   5   4   % IR13
     3   6  10   3   3   5   % IR14
     6   3   3   3   3   3   % IR16
     6   3   3   3   3   3   % IR17
    10   8   9   4   4   4   % IR18
    10   6   3  10   4  10   % IR19
     3   8   7   3   4   4   % IR21
     7   5   3   3   3   7   % IR22
     5   8   3   8   6   8   % IR23
    10   3   3   5   9   3   % IR24
    10  10   6   4   5   3   % IR25
];

offset = 0;   % <-- SET TO 1 IF GlobalData(1) IS A DUMMY ENTRY, VERIFY MANUALLY

disp(fieldnames(GlobalData(1).Scenarios(1).Trials));
% Expected something like: Score, Holes, Distance, Time, Fieldname, TrialID (verify exact names!)

Score_first = nan(nSubj, nScen); Score_last = nan(nSubj, nScen);
Holes_first = nan(nSubj, nScen); Holes_last = nan(nSubj, nScen);
Dist_first  = nan(nSubj, nScen); Dist_last  = nan(nSubj, nScen);
Time_first  = nan(nSubj, nScen); Time_last  = nan(nSubj, nScen);

% Build a lookup: match subject ID strings to GlobalData indices
allIDs = {GlobalData.ID};  % e.g. {'IR02_metrics','IR03_metrics','IR04_metrics',...}

for s = 1:nSubj
    subjID = subjects{s};  % e.g. 'IR02'

    % Match by checking if allIDs starts with subjID + '_' (avoids IR02 matching IR020 etc.)
    matchIdx = find(startsWith(allIDs, [subjID '_']));

    if isempty(matchIdx)
        warning('No GlobalData match found for subject %s', subjID);
        continue;
    elseif numel(matchIdx) > 1
        warning('Multiple GlobalData matches for subject %s - using first', subjID);
        matchIdx = matchIdx(1);
    end

    gData = GlobalData(matchIdx);

    for sc = 1:nScen
        try
            trials = gData.Scenarios(sc).Trials;  % struct array, 1xN
            nTrials = numel(trials);

            if nTrials >= 1
                Score_first(s,sc) = trials(1).Score;
                Holes_first(s,sc) = trials(1).Holes;
                Dist_first(s,sc)  = trials(1).Distance;
                Time_first(s,sc)  = trials(1).Time;
            end

            lastRep = RepCounts(s,sc);
            if nTrials >= lastRep
                Score_last(s,sc) = trials(lastRep).Score;
                Holes_last(s,sc) = trials(lastRep).Holes;
                Dist_last(s,sc)  = trials(lastRep).Distance;
                Time_last(s,sc)  = trials(lastRep).Time;
            else
                warning('Subj %s - scenario %d: requested rep %d but only %d trials available', ...
                         subjID, sc, lastRep, nTrials);
            end
        catch ME
            warning('Subj %s - scenario %d: extraction failed (%s)', subjID, sc, ME.message);
        end
    end
end

diff_Score = Score_last - Score_first;
diff_Holes = Holes_last - Holes_first;
diff_Dist  = Dist_last  - Dist_first;
diff_Time  = Time_last  - Time_first;
% --- Suture durations (first & last attempt, summed across 4 points) ---
SutureDur_first = nan(nSubj, nScen);
SutureDur_last  = nan(nSubj, nScen);

for s = 1:nSubj
    for sc = 1:nScen
        pts = squeeze(SutureTimesMatrix(s, sc, 1, :, :));  % 4x2
        SutureDur_first(s,sc) = nansum(pts(:,2) - pts(:,1));

        lastRep = RepCounts(s,sc);
        if lastRep <= size(SutureTimesMatrix,3)
            pts = squeeze(SutureTimesMatrix(s, sc, lastRep, :, :));
            SutureDur_last(s,sc) = nansum(pts(:,2) - pts(:,1));
        end
    end
end

diff_SutureDur = SutureDur_last - SutureDur_first;

%% BUILD METRIC SETS FOR CORRELATION
EEG_metrics = {ERD_first, ERD_last, Mod_first, Mod_last, diff_ERD, diff_ERS, diff_Mod};
EEG_names   = {'ERD (first)','ERD (last)','Modulation (first)','Modulation (last)','\Delta ERD','\Delta ERS','\Delta Modulation'};

Beh_metrics_first = {Score_first, Holes_first, Dist_first, Time_first, SutureDur_first};
Beh_metrics_last  = {Score_last,  Holes_last,  Dist_last,  Time_last,  SutureDur_last};
Beh_metrics_diff  = {diff_Score,  diff_Holes,  diff_Dist,  diff_Time,  diff_SutureDur};
Beh_names = {'Score','Holes','Distance','Time','SutureDuration'};

%% CORRELATION MATRICES (per scenario)
nEEG = numel(EEG_metrics);
nBeh = numel(Beh_names);

R_mat = nan(nEEG, nBeh, nScen);
P_mat = nan(nEEG, nBeh, nScen);

% Choose which behavioral set matches each EEG metric type (first/last/diff)
behSetMap = {Beh_metrics_first, Beh_metrics_first, Beh_metrics_first, Beh_metrics_first, ...
             Beh_metrics_diff, Beh_metrics_diff, Beh_metrics_diff}; % aligns w/ EEG_metrics order

for sc = 1:nScen
    for e = 1:nEEG
        behSet = behSetMap{e};
        for b = 1:nBeh
            x = EEG_metrics{e}(:,sc);
            y = behSet{b}(:,sc);
            valid = ~isnan(x) & ~isnan(y);
            if sum(valid) > 2
                [r, p] = corr(x(valid), y(valid), 'Type', 'Pearson');
                R_mat(e,b,sc) = r;
                P_mat(e,b,sc) = p;
            end
        end
    end
end

%% FDR CORRECTION ACROSS ALL TESTS
allP = P_mat(:);
validP = ~isnan(allP);
adjP = fdr_bh_simple(allP(validP));
adjP_mat = nan(size(P_mat));
adjP_mat(validP) = adjP;

%% VISUALIZE: CORRELATION HEATMAPS PER SCENARIO
for sc = 1:nScen
    figure;
    set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 0.6 0.7]);
    imagesc(R_mat(:,:,sc), [-1 1]);
    colormap(redblue_custom());
    colorbar;
    set(gca, 'XTick', 1:nBeh, 'XTickLabel', Beh_names, ...
             'YTick', 1:nEEG, 'YTickLabel', EEG_names, 'XTickLabelRotation', 30);
    title(['Correlation matrix - Scenario ' num2str(sc)]);

    for e = 1:nEEG
        for b = 1:nBeh
            r = R_mat(e,b,sc);
            p = adjP_mat(e,b,sc);
            if ~isnan(r)
                txt = sprintf('%.2f', r);
                if p < 0.05
                    txt = [txt '*'];
                end
                text(b, e, txt, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end
        end
    end
end

%% SCATTER PLOTS FOR KEY RELATIONSHIPS (e.g., Modulation vs Score)
color_Mod = [0.2000 0.4500 0.7500];

figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
for sc = 1:nScen
    subplot(2,3,sc);
    x = Mod_first(:,sc);
    y = Score_first(:,sc);
    valid = ~isnan(x) & ~isnan(y);

    scatter(x(valid), y(valid), 50, color_Mod, 'filled'); hold on;
    if sum(valid) > 2
        p = polyfit(x(valid), y(valid), 1);
        xFit = linspace(min(x(valid)), max(x(valid)), 100);
        plot(xFit, polyval(p, xFit), 'k-', 'LineWidth', 1.5);
        [r, pval] = corr(x(valid), y(valid));
        title(sprintf('Scenario %d: r=%.2f, p=%.3f', sc, r, pval));
    end
    xlabel('Beta Modulation (first)');
    ylabel('Score (first)');
end
sgtitle('Beta Modulation (first attempt) vs Score (first attempt)');

%% Helper: diverging colormap for correlation heatmaps
function cmap = redblue_custom()
    n = 128;
    r = [linspace(0,1,n) ones(1,n)];
    g = [linspace(0,1,n) linspace(1,0,n)];
    b = [ones(1,n) linspace(1,0,n)];
    cmap = [r' g' b'];
end

function data = loadSingleVar(fname)
    % Loads a .mat file assumed to contain exactly one variable
    % and returns it regardless of its internal name.
    s = load(fname);
    fn = fieldnames(s);
    if numel(fn) ~= 1
        warning('%s contains %d variables - using the first one (%s)', fname, numel(fn), fn{1});
    end
    data = s.(fn{1});
end

function adjP = fdr_bh_simple(pvals)
    % Simple Benjamini-Hochberg FDR correction
    % pvals: vector of p-values (no NaNs)
    % adjP: FDR-adjusted p-values, same order as input

    pvals = pvals(:);
    n = length(pvals);
    [sortedP, sortIdx] = sort(pvals);

    adjSorted = sortedP .* n ./ (1:n)';
    
    % Enforce monotonicity (cumulative minimum from the end)
    adjSorted = flipud(cummin(flipud(adjSorted)));
    
    % Cap at 1
    adjSorted = min(adjSorted, 1);

    % Restore original order
    adjP = nan(n,1);
    adjP(sortIdx) = adjSorted;
end
