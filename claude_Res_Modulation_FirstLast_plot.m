% claude_Res_Modulation_FirstLast_plot.m
% =====================================================================================================
% RESIDENTS: beta and alpha MODULATION, FIRST trial vs LAST trial, one plot per scenario and per ROI.
%
% WHAT THE PLOT SHOWS (one small panel = one band x one ROI x one scenario)
%   x = 1  -> FIRST usable trial of that scenario (earliest repetition that has a value)
%   x = 2  -> LAST  usable trial of that scenario (latest repetition that has a value; = the one that let the resident move on, or the 10th, when those have data)
%   thin lines + dots   -> every single resident (first value joined to last value)
%   big bars + squares  -> mean +/- SD over the residents shown in that panel (semi-transparent, drawn UNDER the dots)
%   panel title         -> scenario and n = number of residents in that panel (and in that mean)
%
% STEPS (each one is a numbered section below, with printed output so you can check it)
%   1. load data
%   2. build the "performed" list (which repetitions each resident really did, skip list removed)
%   3. for each resident and scenario find first and last performed repetition
%   4. find outlier residents (they are dropped, and printed)
%   5. for every band / ROI / scenario collect the first and last value, count n, plot
%   6. print the n table and who is missing and why; save the plotted numbers to a CSV
%
% PART B (sections 7-11, same file): first UNSUCCESSFUL vs first SUCCESSFUL trial, see the header of section 7.
%
% A trial with no modulation value (e.g. no needle data) is NOT replaced by another trial:
% that resident is simply left out of that panel, and the console tells you which and why.
% =====================================================================================================

clear; close all; clc;
addpath(fileparts(mfilename('fullpath')));      % so MATLAB finds claude_figure_right.m

D = '/home/acatalano/Desktop/Intuitive/DataStructures/';

% ---- settings you can change ----
REMOVE_OUTLIERS = true;
ROBUST_Z  = 3.5;      % outlier rule 1: median/MAD z-score above this
LOO_Z     = 3;        % outlier rule 2: z-score vs the mean of all OTHER residents above this
SAVE_FIGS = true;
CUTOFF    = 75;       % PART B: score (%) that defines a successful trial
CSV_FILE  = '/home/acatalano/Desktop/Intuitive/last3_successful_residents.csv';   % PART B: the 3 successful trials
FALLBACK_UNSUCC = true;   FALLBACK_SUCC = true;   % PART B: use the next trial with a value if the chosen one has none
FALLBACK  = true;     % true: first/last = earliest/latest repetition WITH a value; false: first/last performed rep only

%% 1. LOAD ---------------------------------------------------------------------------------------------
R = load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);   % Mod_6d: [band x ROI x resident x scenario x rep x point]
T = load([D 'GraspERD_Times_IR.mat']);                 % T.RepStatus(resident, scenario, rep) == 1 -> skip list
P = load([D 'performanceStruct_IR_updated.mat']);      % which trials each resident performed

subjects  = R.subjects;      % resident names
roi_names = R.roi_names;     % the ROIs
BANDS     = R.BANDS;         % BANDS(b).name = beta / alpha
Mod6      = R.Mod_6d;

[nB, nROI, nS, NS, NRep, ~] = size(Mod6);
fprintf('Loaded: %d bands, %d ROIs, %d residents, %d scenarios, %d repetitions (max)\n', nB, nROI, nS, NS, NRep);

% ONE modulation value per trial = mean of the 4 suture points (points without a value are ignored)
ModTrial = squeeze(mean(Mod6, 6, 'omitnan'));          % [band x ROI x resident x scenario x rep]

%% 2. PERFORMED LIST -----------------------------------------------------------------------------------
% performed(resident, scenario, rep) = true if the resident did that repetition AND it is not in the skip list
performed = false(nS, NS, NRep);
score     = nan(nS, NS, NRep);      % score (%) of each performed trial (used in PART B)
for g = 1:numel(P.GlobalData)
    s = find(strcmp(subjects, strtok(P.GlobalData(g).ID, '_')));   % which resident is this entry
    if isempty(s), continue; end                                    % not an analysed resident
    for k = 1:numel(P.GlobalData(g).Scenarios)
        sc  = P.GlobalData(g).Scenarios(k).ScenarioID;
        ids = [P.GlobalData(g).Scenarios(k).Trials.TrialID];        % repetition numbers that were performed
        ids = ids(ids >= 1 & ids <= NRep);
        performed(s, sc, ids) = true;
        for tr = P.GlobalData(g).Scenarios(k).Trials     % PART B: score of every trial
            if tr.TrialID >= 1 && tr.TrialID <= NRep, score(s, sc, tr.TrialID) = tr.Score; end
        end
    end
end
performed = performed & (T.RepStatus ~= 1);                         % remove skipped repetitions

%% 3. FIRST AND LAST USABLE REPETITION ----------------------------------------------------------------
% A repetition is USABLE if it was performed (section 2) AND it has a modulation value
% (trials without a value = simulation problem / no needle data / no grasp file, see your skip list).
%   FALLBACK = true : first = EARLIEST usable repetition, last = LATEST usable repetition  (this is what you asked for)
%   FALLBACK = false: first/last = first/last PERFORMED repetition; if it has no value the resident is left out
% A resident needs at least 2 different usable repetitions in a scenario, otherwise he is left out of that scenario.
% firstRep / lastRep are [resident x scenario x band] (NaN = left out). strictFirst/strictLast = first/last PERFORMED rep.
hasVal    = squeeze(any(~isnan(ModTrial), 2));      % [band x resident x scenario x rep]: any ROI with a value
firstRep  = nan(nS, NS, nB);    lastRep  = nan(nS, NS, nB);
strictF   = nan(nS, NS);        strictL  = nan(nS, NS);
for s = 1:nS
    for sc = 1:NS
        reps = find(squeeze(performed(s, sc, :)))';  % performed repetition numbers
        if ~isempty(reps), strictF(s, sc) = reps(1);   strictL(s, sc) = reps(end); end
        for b = 1:nB
            r2 = reps;
            if FALLBACK, r2 = reps(squeeze(hasVal(b, s, sc, reps))'); end   % keep only repetitions with a value
            if numel(r2) >= 2
                firstRep(s, sc, b) = r2(1);
                lastRep(s, sc, b)  = r2(end);
            end
        end
    end
end
for b = 1:nB
    fprintf('\n%s: first->last repetition used (rows = residents, columns = scenarios). * = differs from the first/last PERFORMED rep\n', BANDS(b).name);
    fprintf('%-6s', 'IR'); fprintf('%11s', 'Sc1', 'Sc2', 'Sc3', 'Sc4', 'Sc5', 'Sc6'); fprintf('\n');
    for s = 1:nS
        fprintf('%-6s', subjects{s});
        for sc = 1:NS
            if isnan(firstRep(s, sc, b)), fprintf('%11s', '-'); continue; end
            star = ' ';   if firstRep(s, sc, b) ~= strictF(s, sc) || lastRep(s, sc, b) ~= strictL(s, sc), star = '*'; end
            fprintf('%11s', sprintf('%d->%d%s', firstRep(s, sc, b), lastRep(s, sc, b), star));
        end
        fprintf('\n');
    end
end

%% 4. OUTLIER RESIDENTS --------------------------------------------------------------------------------
% For each band: take every resident's average modulation (over all ROIs, scenarios and both the first and the
% last trial). A resident is an outlier if it is far from the others (robust z > 3.5 OR leave-one-out z > 3).
% The outlier is removed from ALL the plots of that band.
isOut = false(nS, nB);
fprintf('\nOUTLIERS (rule: robust z > %.1f or leave-one-out z > %.1f on the resident''s mean modulation)\n', ROBUST_Z, LOO_Z);
for b = 1:nB
    resMean = nan(nS, 1);
    for s = 1:nS
        vals = [];
        for sc = 1:NS
            if isnan(firstRep(s, sc, b)), continue; end
            vals = [vals, squeeze(mean(ModTrial(b, :, s, sc, firstRep(s, sc, b)), 2, 'omitnan')), ...
                          squeeze(mean(ModTrial(b, :, s, sc, lastRep(s, sc, b)),  2, 'omitnan'))]; %#ok<AGROW>
        end
        resMean(s) = mean(vals, 'omitnan');
    end
    if REMOVE_OUTLIERS
        isOut(:, b) = (abs(robust_z(resMean)) > ROBUST_Z) | (abs(loo_z(resMean)) > LOO_Z);
    end
    if any(isOut(:, b))
        fprintf('  %-6s -> removed: %s\n', BANDS(b).name, strjoin(subjects(isOut(:, b)), ', '));
        for s = find(isOut(:, b))'
            fprintf('           %s mean modulation = %.3f   (all residents: median %.3f)\n', subjects{s}, resMean(s), median(resMean, 'omitnan'));
        end
    else
        fprintf('  %-6s -> no outliers\n', BANDS(b).name);
    end
end

%% 5. COLLECT VALUES, COUNT n, PLOT --------------------------------------------------------------------
colFirst = [0.40 0.60 0.90];   % 
colLast  = [0.00 0.20 0.60];  %
nTable   = nan(nB, nROI, NS);    % number of residents in each panel
dataA    = nan(nB, nROI, NS, nS, 2);   % for the TESTS: value of every resident, (:,:,:,:,1) = first, (:,:,:,:,2) = last
panelF   = cell(nB, nROI, NS);   % first-trial values of the residents in each panel (for the summary plot)
panelL   = cell(nB, nROI, NS);   % last-trial values
if SAVE_FIGS && ~exist([D 'Figures_IR_FirstLast'], 'dir'), mkdir([D 'Figures_IR_FirstLast']); end

for b = 1:nB
    f = claude_figure_right(sprintf('Residents modulation %s', BANDS(b).name), 1700, 260*nROI + 60);
    set(f, 'Color', 'w');

    for r = 1:nROI
        % common y-limits for the whole ROI row (so the 6 scenarios can be compared by eye)
        rowVals = [];

        for sc = 1:NS
            % ---- collect first/last value of every resident for this band, ROI, scenario ----
            Fv = nan(nS, 1);   Lv = nan(nS, 1);
            for s = 1:nS
                if isnan(firstRep(s, sc, b)) || isOut(s, b), continue; end   % <2 usable trials, or outlier
                Fv(s) = ModTrial(b, r, s, sc, firstRep(s, sc, b));
                Lv(s) = ModTrial(b, r, s, sc, lastRep(s, sc, b));
            end
            dataA(b, r, sc, :, 1) = Fv;   dataA(b, r, sc, :, 2) = Lv;
            use = ~isnan(Fv) & ~isnan(Lv);          % residents with BOTH values -> these are the n
            Fu = Fv(use);   Lu = Lv(use);   n = nnz(use);
            nTable(b, r, sc) = n;
            rowVals = [rowVals; Fu; Lu]; %#ok<AGROW>

            panelF{b, r, sc} = Fu;   panelL{b, r, sc} = Lu;

            % ---- draw the panel ----
            ax = subplot(nROI, NS, (r - 1) * NS + sc);   hold(ax, 'on');
            if n > 0
                % (a) mean +/- SD, semi-transparent, drawn first = underneath
                mu = [mean(Fu), mean(Lu)];   sd = [std(Fu), std(Lu)];
                errorbar(1, mu(1), sd(1), 's', 'Color', [colFirst 0.55], 'MarkerFaceColor', colFirst, ...
                         'MarkerSize', 1, 'LineWidth', 2, 'CapSize', 18);
                errorbar(2, mu(2), sd(2), 's', 'Color', [colLast 0.55],  'MarkerFaceColor', colLast, ...
                         'MarkerSize', 1, 'LineWidth', 2, 'CapSize', 18);
                % (b) every resident: thin line first->last, and dots on top
                % for i = 1:n
                %     plot([1 2], [Fu(i) Lu(i)], '-', 'Color', [0.3 0.3 0.3 0.30], 'LineWidth', 0.8);
                % end
                scatter(ones(n, 1),     Fu, 22, colFirst * 0.7, 'filled', 'MarkerFaceAlpha', 0.85, 'MarkerEdgeColor', 'none');
                scatter(2 * ones(n, 1), Lu, 22, colLast * 0.7,  'filled', 'MarkerFaceAlpha', 0.85, 'MarkerEdgeColor', 'none');
            end
            xlim([0.5 2.5]);   xticks([1 2]);   xticklabels({'First', 'Last'});   box on;   grid on;
            title(sprintf('Sc%d  (n = %d)', sc, n), 'FontSize', 10);
            if sc == 1, ylabel(sprintf('%s\nmodulation', roi_names{r})); end
        end

        % same y-limits across the 6 scenarios of this ROI
        if ~isempty(rowVals)
            pad = 0.08 * (max(rowVals) - min(rowVals) + eps);
            for sc = 1:NS, set(subplot(nROI, NS, (r - 1) * NS + sc), 'YLim', [min(rowVals) - pad, max(rowVals) + pad]); end
        end
    end
    sgtitle(sprintf('Residents - %s modulation: first vs last performed trial (squares = mean +/- SD, dots/lines = single residents)', BANDS(b).name));
    if SAVE_FIGS, print(f, [D 'Figures_IR_FirstLast/IR_modulation_firstlast_' BANDS(b).name '.png'], '-dpng', '-r110'); end
end

%% 5b. SUMMARY PLOT: scenarios on the x axis, first and last mean +/- SD side by side ------------------
% One figure per band, one panel per ROI. For each scenario: blue = first trial, red = last trial.
% Light dots = single residents (same n as the panels above). Number of residents per scenario: see the n table below.

for b = 1:nB
    f2 = claude_figure_right(sprintf('Residents modulation summary %s', BANDS(b).name), 1100, 800);   set(f2, 'Color', 'w');
    for r = 1:nROI
        subplot(2, 2, r);   hold on;
        mF = nan(1, NS);  sF = mF;  mL = mF;  sL = mF;
        for sc = 1:NS
            Fu = panelF{b, r, sc};   Lu = panelL{b, r, sc};
            if isempty(Fu), continue; end
            mF(sc) = mean(Fu);  sF(sc) = std(Fu);  mL(sc) = mean(Lu);  sL(sc) = std(Lu);
            scatter(sc - 0.18 + 0.06 * (rand(numel(Fu), 1) - 0.5), Fu, 14, colFirst * 0.7, 'filled', 'MarkerFaceAlpha', 0.30, 'MarkerEdgeColor', 'none');
            scatter(sc + 0.18 + 0.06 * (rand(numel(Lu), 1) - 0.5), Lu, 14, colLast  * 0.7, 'filled', 'MarkerFaceAlpha', 0.30, 'MarkerEdgeColor', 'none');
        end
        h1 = errorbar((1:NS) - 0.18, mF, sF, 'o-', 'Color', colFirst, 'MarkerFaceColor', colFirst, 'LineWidth', 1.8, 'CapSize', 8);
        h2 = errorbar((1:NS) + 0.18, mL, sL, 's-', 'Color', colLast,  'MarkerFaceColor', colLast,  'LineWidth', 1.8, 'CapSize', 8);
        xlim([0.5 NS + 0.5]);  xticks(1:NS);  grid on;  box on;
        xlabel('Scenario');  ylabel('Modulation');
        title(sprintf('%s   (n per scenario: %s)', roi_names{r}, strjoin(arrayfun(@num2str, squeeze(nTable(b, r, :))', 'UniformOutput', false), ',')), 'FontSize', 10);
        if r == 1, legend([h1 h2], {'First trial', 'Last trial'}, 'Location', 'best'); end
    end
    sgtitle(sprintf('Residents - %s modulation: first vs last trial per scenario (mean +/- SD)', BANDS(b).name));
    if SAVE_FIGS, print(f2, [D 'Figures_IR_FirstLast/IR_modulation_firstlast_summary_' BANDS(b).name '.png'], '-dpng', '-r110'); end
end

%% 6. WHO IS IN EACH PLOT, WHO IS MISSING AND WHY ------------------------------------------------------
fprintf('\n================ n = residents in each panel (and in each mean) ================\n');
for b = 1:nB
    fprintf('\n%s   (analysable residents: %d, outliers removed: %d)\n', BANDS(b).name, nS, nnz(isOut(:, b)));
    fprintf('%-14s', 'ROI'); fprintf('%6s', 'Sc1', 'Sc2', 'Sc3', 'Sc4', 'Sc5', 'Sc6'); fprintf('\n');
    for r = 1:nROI
        fprintf('%-14s', roi_names{r}); fprintf('%6d', squeeze(nTable(b, r, :))); fprintf('\n');
    end
end

fprintf('\n================ residents LEFT OUT of each scenario and why ================\n');
for b = 1:nB
    fprintf('\n%s\n', BANDS(b).name);
    for sc = 1:NS
        msg = {};
        for s = 1:nS
            if isOut(s, b), msg{end+1} = sprintf('%s (outlier)', subjects{s}); continue; end %#ok<AGROW>
            if isnan(firstRep(s, sc, b))
                nPerf = nnz(performed(s, sc, :));   nVal = nnz(squeeze(performed(s, sc, :)) & squeeze(hasVal(b, s, sc, :)));
                msg{end+1} = sprintf('%s (%d performed, only %d with a value)', subjects{s}, nPerf, nVal); %#ok<AGROW>
            end
        end
        if isempty(msg), fprintf('  Sc%d: nobody left out\n', sc);
        else, fprintf('  Sc%d: %s\n', sc, strjoin(msg, '; ')); end
    end
end

fprintf('\n================ SUBSTITUTIONS (first/last rep used is not the first/last performed one) ================\n');
for b = 1:nB
    for sc = 1:NS
        for s = 1:nS
            if isnan(firstRep(s, sc, b)) || isOut(s, b), continue; end
            if firstRep(s, sc, b) ~= strictF(s, sc) || lastRep(s, sc, b) ~= strictL(s, sc)
                fprintf('  %-5s Sc%d %s: performed %d..%d, used first = rep %d, last = rep %d\n', BANDS(b).name, sc, subjects{s}, strictF(s, sc), strictL(s, sc), firstRep(s, sc, b), lastRep(s, sc, b));
            end
        end
    end
end


%% =====================================================================================================
% PART B: FIRST UNSUCCESSFUL trial vs FIRST SUCCESSFUL trial of each scenario (sections 7-11)
%   successful trial   = score >= CUTOFF (75 %). "First successful" = FIRST trial of the 3 successful trials that let the
%                        resident go to the next scenario (last3_successful_residents.csv, e.g. 4-5-6 -> trial 4).
%   unsuccessful trial = performed, not skipped, score < CUTOFF, BEFORE the successful triplet. "First unsuccessful" =
%                        the earliest one with a modulation value.
%   A resident with no unsuccessful trial before the triplet (e.g. 1-2-3) is left out of that scenario (listed below).
%   FALLBACK_UNSUCC / FALLBACK_SUCC: if the chosen trial has no value take the next one with a value (printed).
%   Plot: scenarios on x, first unsuccessful (orange) and first successful (green) side by side, mean +/- SD,
%   light dots = residents, thin lines join the same resident. No test yet.
% =====================================================================================================

%% 7. PART B - SUCCESSFUL TRIPLETS FROM THE CSV -----------------------------------------------------------------
triplet = cell(nS, NS);              % triplet{s,sc} = [r1 r2 r3] repetitions of the 3 successful trials ([] = NR)
txt = splitlines(strtrim(fileread(CSV_FILE)));
for k = 2:numel(txt)
    parts = strsplit(txt{k}, ',');
    s = find(strcmp(strtrim(parts{1}), subjects));
    if isempty(s), continue; end
    for sc = 1:NS
        c = regexprep(parts{sc + 1}, '[^0-9\-NR]', '');         % drop footnote symbols
        if isempty(c) || strcmp(c, 'NR'), continue; end
        triplet{s, sc} = str2double(strsplit(c, '-'));
    end
end

%% 8. PART B - CHOOSE THE TWO TRIALS (per band, because "has a value" can differ by band) -----------------------
% repU(s,sc,b) = repetition used as FIRST UNSUCCESSFUL,  repS(s,sc,b) = repetition used as FIRST SUCCESSFUL (NaN = left out)
repU = nan(nS, NS, nB);   repS = nan(nS, NS, nB);
whyOut = cell(nS, NS, nB);          % reason when left out
subs   = {};                        % substitutions to print
for b = 1:nB
    for s = 1:nS
        for sc = 1:NS
            trip = triplet{s, sc};
            if isempty(trip), whyOut{s, sc, b} = 'no successful triplet (NR)'; continue; end

            % --- unsuccessful candidates: performed, score < CUTOFF, before the triplet ---
            cand = find(squeeze(performed(s, sc, :)) & squeeze(score(s, sc, :)) < CUTOFF)';
            cand = cand(cand < trip(1));
            if isempty(cand), whyOut{s, sc, b} = 'no unsuccessful trial before the successful triplet'; continue; end
            candV = cand(squeeze(hasVal(b, s, sc, cand))');     % those with a modulation value
            if isempty(candV), whyOut{s, sc, b} = sprintf('unsuccessful trials %s have no value', mat2str(cand)); continue; end
            if ~FALLBACK_UNSUCC && candV(1) ~= cand(1), whyOut{s, sc, b} = sprintf('first unsuccessful (rep %d) has no value', cand(1)); continue; end
            u = candV(1);

            % --- successful: first trial of the triplet (fallback: next triplet trial with a value) ---
            sv = trip(squeeze(hasVal(b, s, sc, trip))');
            if isempty(sv), whyOut{s, sc, b} = sprintf('none of the successful trials %s has a value', mat2str(trip)); continue; end
            if ~FALLBACK_SUCC && sv(1) ~= trip(1), whyOut{s, sc, b} = sprintf('first successful (rep %d) has no value', trip(1)); continue; end
            sTrial = sv(1);

            repU(s, sc, b) = u;   repS(s, sc, b) = sTrial;
            if u ~= cand(1) || sTrial ~= trip(1)
                subs(end+1, :) = {BANDS(b).name, subjects{s}, sc, cand(1), u, trip(1), sTrial}; %#ok<AGROW>
            end
        end
    end
end

for b = 1:nB
    fprintf('\n%s: first-unsuccessful -> first-successful repetition used (- = left out). * = substitution\n', BANDS(b).name);
    fprintf('%-6s', 'IR'); fprintf('%11s', 'Sc1', 'Sc2', 'Sc3', 'Sc4', 'Sc5', 'Sc6'); fprintf('\n');
    for s = 1:nS
        fprintf('%-6s', subjects{s});
        for sc = 1:NS
            if isnan(repU(s, sc, b)), fprintf('%11s', '-'); continue; end
            trip = triplet{s, sc};   cand = find(squeeze(performed(s, sc, :)) & squeeze(score(s, sc, :)) < CUTOFF)';   cand = cand(cand < trip(1));
            star = ' ';   if repU(s, sc, b) ~= cand(1) || repS(s, sc, b) ~= trip(1), star = '*'; end
            fprintf('%11s', sprintf('%d->%d%s', repU(s, sc, b), repS(s, sc, b), star));
        end
        fprintf('\n');
    end
end
fprintf('\nSUBSTITUTIONS (the trial used is not the first unsuccessful / first of the triplet):\n');
for i = 1:size(subs, 1)
    fprintf('  %-5s %s Sc%d: first unsuccessful rep %d -> used %d ; first successful rep %d -> used %d\n', subs{i, :});
end

%% 9. PART B - OUTLIER RESIDENTS --------------------------------------------------------------------------------
% per band: resident's mean modulation over all ROIs, scenarios and the two trials used; robust z / leave-one-out z
isOutB = false(nS, nB);
fprintf('\nOUTLIERS (robust z > %.1f or leave-one-out z > %.1f on the resident''s mean modulation)\n', ROBUST_Z, LOO_Z);
for b = 1:nB
    resMean = nan(nS, 1);
    for s = 1:nS
        vals = [];
        for sc = 1:NS
            if isnan(repU(s, sc, b)), continue; end
            vals = [vals, mean(ModTrial(b, :, s, sc, repU(s, sc, b)), 2, 'omitnan'), mean(ModTrial(b, :, s, sc, repS(s, sc, b)), 2, 'omitnan')]; %#ok<AGROW>
        end
        resMean(s) = mean(vals, 'omitnan');
    end
    if REMOVE_OUTLIERS, isOutB(:, b) = (abs(robust_z(resMean)) > ROBUST_Z) | (abs(loo_z(resMean)) > LOO_Z); end
    if any(isOutB(:, b))
        fprintf('  %-6s -> removed: %s\n', BANDS(b).name, strjoin(subjects(isOutB(:, b)), ', '));
        for s = find(isOutB(:, b))', fprintf('           %s mean modulation = %.3f (median of residents %.3f)\n', subjects{s}, resMean(s), median(resMean, 'omitnan')); end
    else
        fprintf('  %-6s -> no outliers\n', BANDS(b).name);
    end
end

%% 10. PART B - COLLECT VALUES, COUNT n, PLOT --------------------------------------------------------------------
  % orange = first unsuccessful  % green  = first successful
nTableB = nan(nB, nROI, NS);
dataB   = nan(nB, nROI, NS, nS, 2);   % for the TESTS: (:,:,:,:,1) = first unsuccessful, (:,:,:,:,2) = first successful
if SAVE_FIGS && ~exist([D 'Figures_IR_FirstLast'], 'dir'), mkdir([D 'Figures_IR_FirstLast']); end

for b = 1:nB
    f = claude_figure_right(sprintf('Residents modulation unsuccessful vs successful %s', BANDS(b).name), 1100, 800);   set(f, 'Color', 'w');
    for r = 1:nROI
        subplot(2, 2, r);   hold on;
        mU = nan(1, NS);  sU = mU;  mS = mU;  sS = mU;
        for sc = 1:NS
            Uv = nan(nS, 1);   Sv = nan(nS, 1);
            for s = 1:nS
                if isnan(repU(s, sc, b)) || isOutB(s, b), continue; end
                Uv(s) = ModTrial(b, r, s, sc, repU(s, sc, b));
                Sv(s) = ModTrial(b, r, s, sc, repS(s, sc, b));
            end
            dataB(b, r, sc, :, 1) = Uv;   dataB(b, r, sc, :, 2) = Sv;
            use = ~isnan(Uv) & ~isnan(Sv);   Uu = Uv(use);   Su = Sv(use);   n = nnz(use);
            nTableB(b, r, sc) = n;
            if n == 0, continue; end
            mU(sc) = mean(Uu);  sU(sc) = std(Uu);  mS(sc) = mean(Su);  sS(sc) = std(Su);
            xU = sc - 0.18;   xS = sc + 0.18;
            % for i = 1:n, plot([xU xS], [Uu(i) Su(i)], '-', 'Color', [0.4 0.4 0.4 0.20], 'LineWidth', 0.7); end
            scatter(xU * ones(n, 1), Uu, 14, colFirst * 0.8, 'filled', 'MarkerFaceAlpha', 0.35, 'MarkerEdgeColor', 'none');
            scatter(xS * ones(n, 1), Su, 14, colLast * 0.8, 'filled', 'MarkerFaceAlpha', 0.35, 'MarkerEdgeColor', 'none');
        end
        h1 = errorbar((1:NS) - 0.18, mU, sU, 'o-', 'Color', colFirst, 'MarkerFaceColor', colFirst, 'LineWidth', 1.8, 'CapSize', 8);
        h2 = errorbar((1:NS) + 0.18, mS, sS, 's-', 'Color', colLast, 'MarkerFaceColor', colLast, 'LineWidth', 1.8, 'CapSize', 8);
        xlim([0.5 NS + 0.5]);  xticks(1:NS);  grid on;  box on;  xlabel('Scenario');  ylabel('Modulation');
        title(sprintf('%s   (n per scenario: %s)', roi_names{r}, strjoin(arrayfun(@num2str, squeeze(nTableB(b, r, :))', 'UniformOutput', false), ',')), 'FontSize', 10);
        if r == 1, legend([h1 h2], {'First unsuccessful', 'First successful'}, 'Location', 'best'); end
    end
    sgtitle(sprintf('Residents - %s modulation: first unsuccessful vs first successful trial per scenario (mean +/- SD)', BANDS(b).name));
    if SAVE_FIGS, print(f, [D 'Figures_IR_FirstLast/IR_modulation_unsucc_succ_' BANDS(b).name '.png'], '-dpng', '-r110'); end
end

%% 11. PART B - n TABLE AND WHO IS LEFT OUT ----------------------------------------------------------------------
fprintf('\n================ n = residents in each panel ================\n');
for b = 1:nB
    fprintf('\n%s   (outliers removed: %d)\n', BANDS(b).name, nnz(isOutB(:, b)));
    fprintf('%-14s', 'ROI'); fprintf('%6s', 'Sc1', 'Sc2', 'Sc3', 'Sc4', 'Sc5', 'Sc6'); fprintf('\n');
    for r = 1:nROI, fprintf('%-14s', roi_names{r}); fprintf('%6d', squeeze(nTableB(b, r, :))); fprintf('\n'); end
end

fprintf('\n================ residents LEFT OUT of each scenario and why ================\n');
for b = 1:nB
    fprintf('\n%s\n', BANDS(b).name);
    for sc = 1:NS
        msg = {};
        for s = 1:nS
            if isOutB(s, b), msg{end+1} = sprintf('%s (outlier)', subjects{s}); %#ok<AGROW>
            elseif isnan(repU(s, sc, b)), msg{end+1} = sprintf('%s (%s)', subjects{s}, whyOut{s, sc, b}); end %#ok<AGROW>
        end
        fprintf('  Sc%d: %d left out\n', sc, numel(msg));
        for i = 1:numel(msg), fprintf('        %s\n', msg{i}); end
    end
end


%% =====================================================================================================
% 12. TESTS (paper-style, paired). Same residents as in the plots (outliers already removed).
%   For every comparison: Shapiro-Wilk on the paired differences of ALL sets; if any set is non-normal ALL tests are
%   Wilcoxon signed-rank, otherwise ALL are paired t-tests (one test type per comparison, printed at the top).
%   (a) POOLED over scenarios: each resident's mean over the scenarios where he has BOTH trials -> one pair per resident.
%       8 tests (2 bands x 4 ROIs), Holm over these 8.  This is the headline test.
%   (b) PER SCENARIO (exploratory): Holm over the 6 scenarios, separately for each band and ROI.
% =====================================================================================================
ALPHA = 0.05;
runTests(dataA, 'first',  'last',       'PART A: first vs last trial',                        BANDS, roi_names, ALPHA);
runTests(dataB, 'unsucc', 'succ',       'PART B: first unsuccessful vs first successful trial', BANDS, roi_names, ALPHA);


%% =====================================================================================================
% 13. PART A - TWO-WAY REPEATED-MEASURES ANOVA, Scenario (6) x Repetition (first, last), as in the paper
%   Uses the SAME first/last trials as the plots (earliest / latest repetition WITH a value, outliers removed).
%   A classic rmANOVA needs every resident to have all 12 cells (6 scenarios x first/last): residents with a
%   missing cell are left out of THIS test only and listed. (Part B cannot be done this way: too few residents
%   have all 6 scenarios with an unsuccessful and a successful trial.)
%   p = Greenhouse-Geisser p if Mauchly is significant, otherwise the plain p. Holm over the 8 band x ROI tests
%   for each effect.
% =====================================================================================================
effNames = {'Scenario', 'Repetition', 'Scenario x Repetition'};
PUa = nan(nB, nROI, 3);   NNa = nan(nB, nROI);
for b = 1:nB
    fA = claude_figure_right(sprintf('rmANOVA modulation %s', BANDS(b).name), 1100, 800);   set(fA, 'Color', 'w');
    for r = 1:nROI
        subjV = {};   scnV = [];   repV = {};   valV = [];
        for s = 1:nS
            for sc = 1:NS
                vals = [dataA(b, r, sc, s, 1), dataA(b, r, sc, s, 2)];
                if any(isnan(vals)), vals = [NaN NaN]; end
                subjV = [subjV; repmat(subjects(s), 2, 1)];  scnV = [scnV; sc; sc];  repV = [repV; {'first'; 'last'}];  valV = [valV; vals(:)]; %#ok<AGROW>
            end
        end
        Tl  = table(subjV, scnV, repV, valV, 'VariableNames', {'subject', 'scenario', 'rep', 'value'});
        axA = subplot(2, 2, r);
        resA = claude_residents_rm2way(Tl, sprintf('Modulation | %s %s', BANDS(b).name, roi_names{r}), axA);
        ylabel(axA, 'Modulation');
        if r == 1, legend(axA, {'First trial', 'Last trial'}, 'Location', 'best'); end
        NNa(b, r) = resA.n;
        for e = 1:numel(resA.eff), PUa(b, r, e) = resA.eff(e).pUse; end
    end
    sgtitle(sprintf('Residents, %s modulation: first vs last trial by scenario (mean +/- SD, residents with all 6 scenarios)', BANDS(b).name));
    if SAVE_FIGS, print(fA, [D 'Figures_IR_FirstLast/IR_modulation_rmANOVA_' BANDS(b).name '.png'], '-dpng', '-r110'); end
end
fprintf('\n=== rmANOVA summary: p used (Greenhouse-Geisser if Mauchly significant) and Holm p over the %d band x ROI tests ===\n', nB * nROI);
for e = 1:3
    pv = reshape(PUa(:, :, e), [], 1);   padj = reshape(claude_holm_adjust(pv), nB, nROI);
    fprintf('\n--- effect: %s ---\n', effNames{e});
    for b = 1:nB
        for r = 1:nROI
            fprintf('%-6s %-12s n=%2d | p=%.4f | p(Holm)=%.4f %s\n', BANDS(b).name, roi_names{r}, NNa(b, r), PUa(b, r, e), padj(b, r), tern(padj(b, r) < 0.05, '<-- significant', ''));
        end
    end
end


%% ---------------------------------------------------------------------
function z = robust_z(x)      % z-score based on median and MAD (not moved by the outlier itself)
    md = median(x, 'omitnan');   s = median(abs(x - md), 'omitnan');
    if s == 0, z = zeros(size(x)); else, z = 0.6745 * (x - md) / s; end
end

function z = loo_z(x)         % z-score of each resident against the mean/SD of all the OTHERS
    n = numel(x);   z = nan(n, 1);
    for i = 1:n
        o = x([1:i-1, i+1:n]);   z(i) = (x(i) - mean(o, 'omitnan')) / std(o, 'omitnan');
    end
end


function runTests(data, name1, name2, titleStr, BANDS, roi_names, ALPHA)
% data = [band x ROI x scenario x resident x 2]; (...,1) = condition 1, (...,2) = condition 2 (NaN = resident not in this comparison)
% ONE test type for ALL the tests of this comparison: Shapiro-Wilk is run on the paired differences of every set
% (8 pooled + 48 per-scenario); if ANY set is non-normal, ALL tests are Wilcoxon signed-rank, otherwise ALL are paired t-tests.
    [nB, nROI, NS, nS, ~] = size(data);
    fprintf('\n\n############ %s ############\n', titleStr);
    fprintf('Change = %s - %s. "+" means higher in %s.\n', name2, name1, name2);

    % ---- the sets: pooled over scenarios (one pair per resident) and every scenario ----
    V1 = cell(nB, nROI, NS + 1);   V2 = cell(nB, nROI, NS + 1);     % index NS+1 = pooled
    for b = 1:nB
        for r = 1:nROI
            for sc = 1:NS, V1{b, r, sc} = squeeze(data(b, r, sc, :, 1));   V2{b, r, sc} = squeeze(data(b, r, sc, :, 2)); end
            v1 = nan(nS, 1);   v2 = nan(nS, 1);
            for s = 1:nS
                a = squeeze(data(b, r, :, s, 1));   c = squeeze(data(b, r, :, s, 2));   ok = ~isnan(a) & ~isnan(c);
                if any(ok), v1(s) = mean(a(ok));   v2(s) = mean(c(ok)); end
            end
            V1{b, r, NS + 1} = v1;   V2{b, r, NS + 1} = v2;
        end
    end

    % ---- step 1: normality of every set -> one decision for everyone ----
    swP = nan(nB, nROI, NS + 1);
    for b = 1:nB, for r = 1:nROI, for k = 1:NS + 1
        swP(b, r, k) = claude_paired_first_last(V1{b, r, k}, V2{b, r, k}, ALPHA).swP;
    end, end, end
    nSets = nnz(~isnan(swP));   nNon = nnz(swP < ALPHA);
    if nNon > 0, force = 'wilcoxon'; else, force = 't'; end
    fprintf('\nNormality (Shapiro-Wilk on the paired differences): %d of %d sets are NOT normal (p < %.2f)\n', nNon, nSets, ALPHA);
    fprintf('  -> ALL tests below use the %s\n', tern(strcmp(force, 't'), 'paired t-test', 'Wilcoxon signed-rank test'));
    fprintf('  Non-normal pooled sets: '); idx = 0;
    for b = 1:nB, for r = 1:nROI
        if swP(b, r, NS + 1) < ALPHA, fprintf('%s %s (p=%.3f)  ', BANDS(b).name, roi_names{r}, swP(b, r, NS + 1)); idx = idx + 1; end
    end, end
    if idx == 0, fprintf('none'); end
    fprintf('\n');

    % ---- (a) pooled over scenarios ----
    fprintf('\n(a) POOLED over scenarios, one pair per resident (Holm over %d tests)\n', nB * nROI);
    fprintf('%-6s %-12s %4s %16s %16s %9s %9s %9s\n', 'band', 'ROI', 'n', ['mean+-SD ' name1], ['mean+-SD ' name2], 'ShapiroP', 'p', 'p Holm');
    rowsQ = {};   pp = [];
    for b = 1:nB
        for r = 1:nROI
            Q = claude_paired_first_last(V1{b, r, NS + 1}, V2{b, r, NS + 1}, ALPHA, force);
            rowsQ(end+1, :) = {BANDS(b).name, roi_names{r}, Q}; %#ok<AGROW>
            pp(end+1) = Q.p; %#ok<AGROW>
        end
    end
    ph = claude_holm_adjust(pp(:))';
    for i = 1:size(rowsQ, 1)
        Q = rowsQ{i, 3};
        fprintf('%-6s %-12s %4d %16s %16s %9.3f %9.4f %9.4f %s\n', rowsQ{i, 1}, rowsQ{i, 2}, Q.n, ...
            sprintf('%.3f+-%.3f', Q.mFirst, Q.sdFirst), sprintf('%.3f+-%.3f', Q.mLast, Q.sdLast), Q.swP, Q.p, ph(i), tern(ph(i) < ALPHA, '<-- significant after Holm', ''));
    end

    % ---- (b) per scenario ----
    fprintf('\n(b) PER SCENARIO (%s). Entry = n, sign of the change, raw p; * = Holm p < %.2f over the 6 scenarios\n', tern(strcmp(force, 't'), 'paired t-test', 'Wilcoxon'), ALPHA);
    fprintf('%-6s %-12s', 'band', 'ROI'); fprintf(' %17s', 'Sc1', 'Sc2', 'Sc3', 'Sc4', 'Sc5', 'Sc6'); fprintf('\n');
    for b = 1:nB
        for r = 1:nROI
            Qs = cell(1, NS);   p = nan(1, NS);
            for sc = 1:NS
                Qs{sc} = claude_paired_first_last(V1{b, r, sc}, V2{b, r, sc}, ALPHA, force);   p(sc) = Qs{sc}.p;
            end
            padj = claude_holm_adjust(p(:))';
            fprintf('%-6s %-12s', BANDS(b).name, roi_names{r});
            for sc = 1:NS
                if isnan(p(sc)), fprintf(' %17s', sprintf('n=%d n/a', Qs{sc}.n)); continue; end
                fprintf(' %17s', sprintf('n=%d %s%.3f%s', Qs{sc}.n, tern(Qs{sc}.mLast >= Qs{sc}.mFirst, '+', '-'), p(sc), tern(padj(sc) < ALPHA, '*', ' ')));
            end
            fprintf('\n');
        end
    end
end

function o = tern(c, x, y)
    if c, o = x; else, o = y; end
end

