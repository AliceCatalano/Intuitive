function claude_Res_FilterSensitivity()
% claude_Res_FilterSensitivity.m
% =====================================================================================================
% (STEP 2, the automatic copy of the pipeline scripts, was removed: the scripts are edited directly instead.)
% MODE = 'avgref' (new): the same machinery also re-references ALL residents to the AVERAGE reference (like the experts), on the cleaned
% data, after the filter, into IR_Task/ERDS_avgref; the earlier filter-only test (MODE = 'filter') is untouched.
% SENSITIVITY TEST FOR THE UNFILTERED RESIDENTS (IR02, IR05-IR09; IR04 excluded: components never removed): do the results change if these residents are
% band-passed 2-40 Hz and notch-filtered 45-50 Hz like the other residents?
%
% WHAT IT DOES NOW (MODE = 'avgref')
%   STEP 1  PREPARE DATA : loads IR_Task/ERDS/<resident>_afterICA.set (the originals are never touched), band-passes + notches the
%                          unfiltered residents (FILTER_RES), re-references EVERY resident to the average (channels removed in the
%                          history are left out of the average, as the experts), and saves into the NEW folder IR_Task/ERDS_avgref/
%   (between)  the 5 pipeline scripts, EDITED to read/write IR_Task/ERDS_avgref (original addresses kept as comments), run in order:
%                          claude_Task_events_Residents_v2.m -> claude_Task_Res_EpochsERDERS.m -> Task_Res_convert2Fieldtrip_ERDS_claude.m
%                          -> Task_Res_TFR_claude.m -> claude_Task_Res_ERDERS_ROI.m   (result: ..._ROI_bands_avgref.mat)
%   STEP 3  COMPARE      : (RUN_COMPARE = true, after the pipeline) original vs avgref values per resident (correlation, mean change,
%                          scatter) and DataStructures/ERD_ERS_Modulation_IR_ROI_bands_avgrefMerged.mat = the original data with the
%                          processed residents replaced (IR04 set to missing). Use it as ROI_FILE in
%                          claude_Res_Modulation_FirstLast_plot.m.
% (MODE = 'filter' is the earlier filter-only test; its new folder was deleted to save space.)
%
% READ THIS BEFORE INTERPRETING
%   - The filter is applied to the cleaned data (afterICA), not to the raw data. The ICA of these residents was computed on
%     unfiltered data, and this test cannot repair that; it only tells you whether the missing filter changes the results.
%   - The files are filtered AFTER ICA. If the afterICA files still contain the artefact components (they were saved before the
%     components were removed), this test inherits that too.
%   - Filter calls: pop_eegfiltnew 'locutoff' 2 'hicutoff' 40 and, as notch, 'locutoff' 45 'hicutoff' 50 'revfilt' 1 (the forms my
%     history search recognised). Step 1 prints the filter lines found in the history of one filtered resident (CHECK_RES) so you can
%     compare them with the ones used here and change BP / NOTCH if they differ.
%   - Disk space: for each resident the new folder receives about 7 files of 0.1-1 GB. Run time: the TFR step takes the longest.
% =====================================================================================================

%% SETTINGS --------------------------------------------------------------------------------------------
MODE         = 'avgref';               % 'filter' : only the unfiltered residents are band-passed + notched (the earlier sensitivity test)
                                       % 'avgref' : the same filter AND EVERY resident re-referenced to the AVERAGE reference, as the experts
FILTER_RES   = {'IR02', 'IR05', 'IR06', 'IR07', 'IR08', 'IR09'};   % residents without the band-pass in the original data
EXCLUDE      = {'IR04'};               % left out on purpose: its ICA components were never removed, so it cannot be compared
CHECK_RES    = 'IR10';                 % a resident that WAS filtered: its history is printed to check the filter settings
BP           = [2 40];                 % band-pass (Hz)
NOTCH        = [45 50];                % notch (Hz)
RUN_FILTER   = false;                   % STEP 1
RUN_COMPARE  = true;                  % STEP 3: set true only AFTER the 5 pipeline scripts have been run (it needs their result file)
SAVE_FIGS    = true;

repo = fileparts(mfilename('fullpath'));
D    = '/home/acatalano/Desktop/Intuitive/DataStructures/';
src  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
% which residents are processed, and the name of the new folder / output files
if strcmp(MODE, 'avgref')
    sfx = 'avgref';
    d_  = dir(fullfile(src, 'IR*_afterICA.set'));
    TARGETS = setdiff(cellfun(@(n) n(1:4), {d_.name}, 'UniformOutput', false), EXCLUDE, 'stable');   % every resident except EXCLUDE
elseif strcmp(MODE, 'filter')
    sfx = 'filtered';
    TARGETS = setdiff(FILTER_RES, EXCLUDE, 'stable');
else
    error('MODE must be ''filter'' or ''avgref''');
end
dst = ['/home/acatalano/Desktop/Intuitive/IR_Task/ERDS_' sfx];
fprintf('MODE = %s : %d residents (%s), new folder %s\n', MODE, numel(TARGETS), strjoin(TARGETS, ' '), dst);
addpath(repo);   addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';   eeglab nogui;
if strcmp(src, dst)
    error('src and dst are the same folder'); 
end

% SAFETY: remember the original files (name, size, date) so that, at the end, it is proven that nothing was changed
protect = {[D 'ERD_ERS_Modulation_IR_ROI_bands.mat'], [D 'ERD_ERS_Modulation_IR_Last3.mat'], [D 'EventInsertion_Log_IR.mat'], [D 'Epoching_Log_IR.mat'], ...
           [D 'GraspERD_Times_IR.mat'], [D 'ExitERS_Times_IR.mat'], [D 'performanceStruct_IR_updated.mat']};
if strcmp(MODE, 'avgref')      % the results of the earlier filter-only test must not be touched either
    protect = [protect, {[D 'ERD_ERS_Modulation_IR_ROI_bands_filtered.mat'], [D 'ERD_ERS_Modulation_IR_ROI_bands_filteredMerged.mat'], [D 'Figures_IR_ERDERS_filtered_scatter.png']}];
end
snapBefore = snapshot(src, protect);
fprintf('Snapshot of the original files taken (%d files in %s + %d result files)\n', nnz(snapBefore.isSrc), src, nnz(~snapBefore.isSrc));

%% STEP 1: FILTER --------------------------------------------------------------------------------------
if RUN_FILTER
    if ~exist(dst, 'dir'), mkdir(dst); end
    fprintf('\n##### STEP 1: preparing the data (filter for %s%s) into %s #####\n', strjoin(FILTER_RES, ' '), ternary(strcmp(MODE, 'avgref'), ' + average reference for all', ''), dst);
    ck = fullfile(src, [CHECK_RES '_afterICA.set']);
    if exist(ck, 'file')
        E = pop_loadset('filename', [CHECK_RES '_afterICA.set'], 'filepath', src, 'loadmode', 'info');
        calls = regexp(E.history, '[^\n]*pop_eegfiltnew[^\n]*', 'match');
        fprintf('Filter calls found in the history of %s (compare with BP = [%g %g], NOTCH = [%g %g]):\n', CHECK_RES, BP, NOTCH);
        if isempty(calls), fprintf('  (none found)\n'); else, fprintf('  %s\n', calls{:}); end
    end
    for i = 1:numel(TARGETS)
        fn = [TARGETS{i} '_afterICA.set'];
        if ~exist(fullfile(src, fn), 'file'), warning('%s not found, skipped', fn); continue; end
        fprintf('\n--- %s ---\n', TARGETS{i});
        EEG = pop_loadset('filename', fn, 'filepath', src);
        if ismember(TARGETS{i}, FILTER_RES)
            EEG = pop_eegfiltnew(EEG, 'locutoff', BP(1),    'hicutoff', BP(2));                     % band-pass
            EEG = pop_eegfiltnew(EEG, 'locutoff', NOTCH(1), 'hicutoff', NOTCH(2), 'revfilt', 1);    % notch
            fprintf('   band-pass and notch applied\n');
        end
        if strcmp(MODE, 'avgref')
            % Average reference like the experts: the experts' average was computed over the channels that were really recorded
            % (the removed channels were interpolated back AFTER it). So the channels removed in the history are left out of the average.
            rm = regexp(EEG.history, '''rmchannel''\s*,\s*\{([^}]*)\}', 'tokens');   rmNames = {};
            for q = 1:numel(rm), rmNames = [rmNames, strtrim(strsplit(strrep(rm{q}{1}, '''', ''), {' ', ','}))]; end %#ok<AGROW>
            rmNames = rmNames(~cellfun(@isempty, rmNames));
            idxRm   = find(ismember({EEG.chanlocs.labels}, rmNames));
            fprintf('   reference before: %s | channels left out of the average (removed in the history): %s\n', EEG.ref, strjoin(rmNames, ', '));
            EEG = pop_reref(EEG, [], 'exclude', idxRm);
            fprintf('   reference after: %s\n', EEG.ref);
        end
        pop_saveset(EEG, 'filename', fn, 'filepath', dst);
        fprintf('%s saved\n', fullfile(dst, fn));
    end
end

%% STEP 2 (not in this script any more): the 5 pipeline scripts are edited to read/write the new folder IR_Task/ERDS_avgref
%   (their original addresses are kept as comments). Run them in this order, then STEP 3:
%     claude_Task_events_Residents_v2.m -> claude_Task_Res_EpochsERDERS.m -> Task_Res_convert2Fieldtrip_ERDS_claude.m
%     -> Task_Res_TFR_claude.m -> claude_Task_Res_ERDERS_ROI.m

%% STEP 3: COMPARE -------------------------------------------------------------------------------------
if RUN_COMPARE
    fprintf('\n##### STEP 3: original vs %s #####\n', sfx);
    addpath(repo);
    O = load([D 'ERD_ERS_Modulation_IR_ROI_bands.mat']);
    F = load([D 'ERD_ERS_Modulation_IR_ROI_bands_' sfx '.mat']);
    subjects = O.subjects;   idx = find(ismember(subjects, TARGETS));
    metrics = {'ERD_all', 'ERS_all', 'Mod_all'};   mname = {'ERD', 'ERS', 'Modulation'};   BANDS = O.BANDS;

    % ---- numbers per resident: pairs = band x ROI x slot ----
    fprintf('\nPer resident: correlation of the original and the filtered values (Pearson, over band x ROI x slot), and the mean change (filtered - original)\n');
    fprintf('%-6s %6s | %8s %8s %8s | %10s %10s %10s\n', 'IR', 'pairs', 'corr ERD', 'corr ERS', 'corr Mod', 'dERD', 'dERS', 'dMod');
    for t = idx(:)'
        c = nan(1, 3);   dm = nan(1, 3);   np = 0;
        for m = 1:3
            x = O.(metrics{m})(:, :, t, :);   y = F.(metrics{m})(:, :, t, :);   ok = ~isnan(x) & ~isnan(y);
            if nnz(ok) > 2, r = corrcoef(x(ok), y(ok));   c(m) = r(1, 2);   dm(m) = mean(y(ok) - x(ok));   np = max(np, nnz(ok)); end
        end
        fprintf('%-6s %6d | %8.3f %8.3f %8.3f | %10.4f %10.4f %10.4f\n', subjects{t}, np, c, dm);
    end

    % ---- scatter: original (x) vs filtered (y), one colour per resident ----
    f1 = claude_figure_right('Filter sensitivity: original vs filtered', 1300, 900);   set(f1, 'Color', 'w');
    cols = lines(numel(idx));   pl = 0;
    for m = 2:3
        for b = 1:numel(BANDS)
            pl = pl + 1;   subplot(2, numel(BANDS), pl);   hold on;   h = gobjects(numel(idx), 1);
            for ii = 1:numel(idx)
                x = squeeze(O.(metrics{m})(b, :, idx(ii), :));   y = squeeze(F.(metrics{m})(b, :, idx(ii), :));
                h(ii) = scatter(x(:), y(:), 10, cols(ii, :), 'filled', 'MarkerFaceAlpha', 0.35);
            end
            lim = [min([xlim ylim]) max([xlim ylim])];   plot(lim, lim, 'k-');   xlim(lim);   ylim(lim);
            grid on;   box on;   axis square;   xlabel('original');   ylabel('filtered');
            title(sprintf('%s, %s', mname{m}, BANDS(b).name), 'FontSize', 11);
            if pl == 1, legend(h, subjects(idx), 'Location', 'southeast'); end
        end
    end
    sgtitle('Each dot = one band-ROI-slot value of a resident filtered in this test (black line = identical)');
    if SAVE_FIGS, print(f1, [D 'Figures_IR_ERDERS_' sfx '_scatter.png'], '-dpng', '-r110'); end

    % ---- merged file: original data, the target residents replaced by their filtered version ----
    Mg = O;
    for fld = {'ERD_all', 'ERS_all', 'Mod_all', 'ERD_6d', 'ERS_6d', 'Mod_6d'}
        nm = fld{1};   ix = repmat({':'}, 1, ndims(O.(nm)));   ix{3} = idx;
        Mg.(nm)(ix{:}) = F.(nm)(ix{:});
    end
    if strcmp(MODE, 'avgref')       % the excluded residents were not processed: they must not stay in the merged file with the old reference
        ex = find(ismember(subjects, EXCLUDE));
        for fld = {'ERD_all', 'ERS_all', 'Mod_all', 'ERD_6d', 'ERS_6d', 'Mod_6d'}
            nm = fld{1};   ix = repmat({':'}, 1, ndims(O.(nm)));   ix{3} = ex;   Mg.(nm)(ix{:}) = NaN;
        end
    end
    out = [D 'ERD_ERS_Modulation_IR_ROI_bands_' sfx 'Merged.mat'];
    save(out, '-struct', 'Mg', '-v7.3');
    fprintf('\nSaved %s\n(original data with %s replaced by the %s version)\n', out, strjoin(subjects(idx), ', '), sfx);
    fprintf('To rerun the group tests: in claude_Res_Modulation_FirstLast_plot.m set ROI_FILE = ''ERD_ERS_Modulation_IR_ROI_bands_%sMerged.mat''\n', sfx);
end

%% SAFETY CHECK: were the original files left untouched? ----------------------------------------------
snapAfter = snapshot(src, protect);
changed = {};
for i = 1:numel(snapBefore.name)
    j = find(strcmp(snapAfter.name, snapBefore.name{i}));
    if isempty(j), changed{end+1} = [snapBefore.name{i} ' (DISAPPEARED)']; %#ok<AGROW>
    elseif snapAfter.bytes(j) ~= snapBefore.bytes(i) || snapAfter.date(j) ~= snapBefore.date(i), changed{end+1} = [snapBefore.name{i} ' (CHANGED)']; end %#ok<AGROW>
end
if isempty(changed)
    fprintf('\nSAFETY CHECK OK: none of the %d original files was changed or removed.\n', numel(snapBefore.name));
else
    fprintf('\nSAFETY CHECK FAILED, these original files changed:\n'); fprintf('  %s\n', changed{:});
end
end

function s = snapshot(folder, extraFiles)
% name, size and date of every file of folder (not of sub-folders) and of the extra files
    d = dir(folder);   d = d(~[d.isdir]);
    s.name = {d.name}';   s.bytes = [d.bytes]';   s.date = [d.datenum]';   s.isSrc = true(numel(d), 1);
    for i = 1:numel(extraFiles)
        e = dir(extraFiles{i});
        if isempty(e), continue; end
        s.name{end+1, 1} = extraFiles{i};   s.bytes(end+1, 1) = e.bytes;   s.date(end+1, 1) = e.datenum;   s.isSrc(end+1, 1) = false;
    end
end

function o = ternary(c, x, y)
    if c, o = x; else, o = y; end
end
