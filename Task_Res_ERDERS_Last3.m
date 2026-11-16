% Task_Res_ERDERS_Last3.m
% RESIDENTS (IR): beta / alpha ERD, ERS and modulation computed ONLY on the
% three successful repetitions that allowed the resident to move to the next
% scene (score >= 75% on three consecutive trials).
%
% Which repetitions: last3_successful_residents.csv (one row per resident, one
% column per scenario, e.g. "4-5-6", "1-3-4" when a repetition in between was
% skipped; "NR" = never reached the criterion in 10 attempts -> no value).
% Numbers are the ORIGINAL repetition numbers, so they index the 10-repetition
% grid directly. Footnote symbols (* dagger etc.) in the CSV are ignored.
%
% Values come from Task_Res_ERDERS_ROI.m (same definitions: ROI, bands, windows),
% already NaN for skipped repetitions / repetitions without usable EEG events.
%
% Output (ERD_ERS_Modulation_IR_Last3.mat), per band x ROI x subject x scenario:
%   ERD_last3, ERS_last3, Mod_last3      mean over the 3 repetitions x 4 points
%   ERD_last3_pt, ERS_last3_pt, Mod_last3_pt   ... x 4 points (mean over the 3 reps)
%   N_ERD, N_ERS, N_Mod                  slots actually available (max 12) [subj x 6]
%   Last3Reps                            {subject, scenario} -> repetitions used
% Requires: ERD_ERS_Modulation_IR_ROI_bands.mat (run Task_Res_ERDERS_ROI.m first)

clear; close all; clc;

erd_file = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_ROI_bands.mat';
csv_file = '/home/acatalano/Desktop/Intuitive/last3_successful_residents.csv';
out_file = '/home/acatalano/Desktop/Intuitive/DataStructures/ERD_ERS_Modulation_IR_Last3.mat';
fig_dir  = '/home/acatalano/Desktop/Intuitive/DataStructures/Figures_IR_ERDERS_Last3';

MAKE_PLOTS = true;
SAVE_FIGS  = false;   % true: save every figure as PNG in fig_dir
MIN_N      = 3;       % minimum number of subjects to draw a point of a curve

S        = load(erd_file);
subjects = S.subjects;
roi_names = S.roi_names;
BANDS    = S.BANDS;
nSubj    = numel(subjects);
[nB, nR, ~, nSc, ~, nPt] = size(S.ERD_6d);
metrics  = {'ERD', 'ERS', 'Mod'};
src      = {S.ERD_6d, S.ERS_6d, S.Mod_6d};

%% 1) read the successful repetitions
txt   = splitlines(strtrim(fileread(csv_file)));
Last3Reps = cell(nSubj, nSc);
seenInCsv = false(1, nSubj);
for k = 2:numel(txt)
    parts = strsplit(txt{k}, ',');
    sidx  = find(strcmp(strtrim(parts{1}), subjects));
    if isempty(sidx)
        fprintf('  %s is not in the analysed subjects, ignored\n', strtrim(parts{1}));
        continue;
    end
    seenInCsv(sidx) = true;
    for sc = 1:nSc
        cellTxt = regexprep(parts{sc+1}, '[^0-9\-NR]', '');      % drop footnote symbols
        if isempty(cellTxt) || strcmp(cellTxt, 'NR'), continue; end
        reps = str2double(strsplit(cellTxt, '-'));
        if numel(reps) ~= 3 || any(isnan(reps)) || any(reps < 1) || any(reps > size(S.ERD_6d,5))
            error('Unreadable entry "%s" for %s Scenario %d', parts{sc+1}, subjects{sidx}, sc);
        end
        Last3Reps{sidx, sc} = reps;
    end
end
if any(~seenInCsv)
    warning('Subjects without a row in the CSV: %s', strjoin(subjects(~seenInCsv), ', '));
end

%% 2) average over the successful repetitions
res    = struct();
for m = 1:3
    res.(metrics{m})      = nan(nB, nR, nSubj, nSc);
    res.([metrics{m} '_pt']) = nan(nB, nR, nSubj, nSc, nPt);
end
Ncount = nan(nSubj, nSc, 3);

for s = 1:nSubj
    for sc = 1:nSc
        reps = Last3Reps{s, sc};
        if isempty(reps), continue; end
        for m = 1:3
            X = reshape(src{m}(:, :, s, sc, reps, :), nB, nR, numel(reps), nPt);   % [band roi rep pt]
            res.(metrics{m})(:, :, s, sc)    = mean(mean(X, 4, 'omitnan'), 3, 'omitnan');
            res.([metrics{m} '_pt'])(:, :, s, sc, :) = reshape(mean(X, 3, 'omitnan'), nB, nR, 1, 1, nPt);
            Ncount(s, sc, m) = nnz(~isnan(squeeze(X(1, 1, :, :))));
        end
    end
end

ERD_last3 = res.ERD;  ERS_last3 = res.ERS;  Mod_last3 = res.Mod;
ERD_last3_pt = res.ERD_pt;  ERS_last3_pt = res.ERS_pt;  Mod_last3_pt = res.Mod_pt;
N_ERD = Ncount(:,:,1);  N_ERS = Ncount(:,:,2);  N_Mod = Ncount(:,:,3);

save(out_file, 'ERD_last3', 'ERS_last3', 'Mod_last3', 'ERD_last3_pt', 'ERS_last3_pt', 'Mod_last3_pt', ...
    'N_ERD', 'N_ERS', 'N_Mod', 'Last3Reps', 'roi_names', 'BANDS', 'subjects', '-v7.3');
fprintf('=== SAVED: %s ===\n', out_file);

%% 3) coverage report: slots available out of 12 (3 repetitions x 4 points), ERD/ERS/Mod
fprintf('\nCoverage (ERD/ERS/Mod slots available out of 12; -- = no successful triplet):\n');
fprintf('%-6s', 'Subj'); for sc = 1:nSc, fprintf('  %-11s', sprintf('Sc%d', sc)); end; fprintf('\n');
for s = 1:nSubj
    fprintf('%-6s', subjects{s});
    for sc = 1:nSc
        if isempty(Last3Reps{s,sc}), fprintf('  %-11s', '--');
        else, fprintf('  %-11s', sprintf('%d/%d/%d', N_ERD(s,sc), N_ERS(s,sc), N_Mod(s,sc))); end
    end
    fprintf('\n');
end
nTrip = nnz(~cellfun(@isempty, Last3Reps));
fprintf('\nSuccessful triplets: %d of %d subject-scenarios | with >=1 modulation slot: %d | fully covered (12/12): %d\n', ...
    nTrip, nSubj*nSc, nnz(N_Mod >= 1), nnz(N_Mod == nPt*3));

if MAKE_PLOTS
    plot_last3(ERD_last3, ERS_last3, Mod_last3, ERD_last3_pt, ERS_last3_pt, Mod_last3_pt, ...
        roi_names, BANDS, SAVE_FIGS, fig_dir, MIN_N);
end


%% ---------------------------------------------------------------------
%  Plotting: rows = ROI, columns = ERD | ERS | Modulation, one figure per band.
%  Thin grey lines = single residents, coloured = mean +/- SD across residents
%  (drawn where at least minN residents have a value).
%% ---------------------------------------------------------------------
function plot_last3(ERD, ERS, Mod, ERDp, ERSp, Modp, roi_names, BANDS, saveFigs, figDir, minN)
    metrics = {'ERD', 'ERS', 'Modulation |ERS-ERD|'};
    A  = {ERD, ERS, Mod};          % [band roi subj scenario]
    Ap = {ERDp, ERSp, Modp};       % [band roi subj scenario point]
    nB = size(ERD,1); nR = size(ERD,2); nSubj = size(ERD,3); nSc = size(ERD,4); nPt = size(ERDp,5);
    COL = lines(nR);
    if saveFigs && ~exist(figDir, 'dir'), mkdir(figDir); end

    for b = 1:nB
        for view = 1:2
            fig = figure('Name', sprintf('IR Last3 %s %d', BANDS(b).name, view), 'Position', [50 50 1200 900]);
            ylc = nan(3,2);
            for r = 1:nR
                for m = 1:3
                    ax = subplot(nR, 3, (r-1)*3 + m); hold on;
                    if view == 1            % by scenario
                        M = reshape(A{m}(b, r, :, :), nSubj, nSc);
                        x = 1:nSc; lab = arrayfun(@(k) sprintf('Sc%d', k), x, 'UniformOutput', false); mk = 'o-';
                    else                    % by suture point (mean over scenarios)
                        M = reshape(mean(Ap{m}(b, r, :, :, :), 4, 'omitnan'), nSubj, nPt);
                        x = 1:nPt; lab = arrayfun(@(k) sprintf('Pt%d', k), x, 'UniformOutput', false); mk = 's-';
                    end
                    for s = 1:nSubj
                        plot(x, M(s,:), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6);
                    end
                    n  = sum(~isnan(M), 1);
                    mn = mean(M, 1, 'omitnan'); sd = std(M, 0, 1, 'omitnan');
                    bad = n < minN; mn(bad) = NaN; sd(bad) = NaN;
                    ok = ~isnan(mn);
                    if any(ok)
                        xv = x(ok); mv = mn(ok); sv = sd(ok); sv(isnan(sv)) = 0;
                        fill([xv fliplr(xv)], [mv+sv fliplr(mv-sv)], COL(r,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
                        plot(xv, mv, mk, 'LineWidth', 2.2, 'Color', COL(r,:));
                    end
                    xlim([0.5 x(end)+0.5]); xticks(x); xticklabels(lab); grid on; box on;
                    if r == 1, title(metrics{m}, 'FontSize', 11, 'FontWeight', 'bold'); end
                    if m == 1, ylabel(roi_names{r}, 'FontSize', 10, 'FontWeight', 'bold'); end
                    yl = ylim(ax);
                    ylc(m,:) = [min([ylc(m,1) yl(1)], [], 'omitnan'), max([ylc(m,2) yl(2)], [], 'omitnan')];
                end
            end
            for r = 1:nR
                for m = 1:3
                    subplot(nR, 3, (r-1)*3 + m); ylim(ylc(m,:));
                end
            end
            vname = {'by scenario', 'by suture point (mean over scenarios)'};
            sgtitle(sprintf('Residents, 3 successful repetitions - %s (%d-%d Hz): %s', ...
                BANDS(b).name, BANDS(b).fmin, BANDS(b).fmax, vname{view}), 'FontSize', 13);
            if saveFigs
                saveas(fig, fullfile(figDir, sprintf('IR_Last3_%s_%d.png', BANDS(b).name, view)));
            end
        end
    end
end
