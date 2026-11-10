% Debug_enext_order — entry/exit consistency for NeedlePassageTimes_IE.mat
% PART 1: flags exit-before-entry, non-monotonic ordering, short durations
% PART 2: for each flagged case, checks the JSON metrics file to see if the
%         same error appears in the simulation ground truth, and compares
%         point-level durations between algorithm and JSON for clean cases

clear; clc;

mat_path     = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE_T2.mat';
metrics_path = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_metrics';

A = load(mat_path);
subjects      = A.subjects;
NUM_SCENARIOS = 20;
NUM_SUTURES   = 4;
MIN_DURATION_S = 0.5;

%% Collect all flags and clean cases
flagged = {};   % {subj, sc, pt, en, ex, dur, flag_str}
clean   = {};   % {subj, sc, pt, en_algo, ex_algo, dur_algo}

for s = 1:length(subjects)
    for sc = 1:NUM_SCENARIOS
        en = squeeze(A.EntryTimes(s, sc, :))';
        ex = squeeze(A.ExitTimes(s,  sc, :))';

        for pt = 1:NUM_SUTURES
            flags = {};

            if isnan(en(pt)) && isnan(ex(pt)), continue; end

            if isnan(en(pt)) && ~isnan(ex(pt))
                flags{end+1} = 'EXIT WITHOUT ENTRY';
            elseif ~isnan(en(pt)) && isnan(ex(pt))
                flags{end+1} = 'ENTRY WITHOUT EXIT';
            else
                dur = ex(pt) - en(pt);
                if dur <= 0
                    flags{end+1} = sprintf('EXIT BEFORE ENTRY (dur=%.2fs)', dur);
                elseif dur < MIN_DURATION_S
                    flags{end+1} = sprintf('TOO SHORT (dur=%.2fs)', dur);
                end
            end

            if pt > 1
                if ~isnan(en(pt)) && ~isnan(en(pt-1)) && en(pt) <= en(pt-1)
                    flags{end+1} = sprintf('ENTRY NOT MONOTONIC (en%d=%.2f <= en%d=%.2f)', ...
                        pt, en(pt), pt-1, en(pt-1));
                end
                if ~isnan(ex(pt)) && ~isnan(ex(pt-1)) && ex(pt) <= ex(pt-1)
                    flags{end+1} = sprintf('EXIT NOT MONOTONIC (ex%d=%.2f <= ex%d=%.2f)', ...
                        pt, ex(pt), pt-1, ex(pt-1));
                end
            end

            if ~isempty(flags)
                flagged{end+1} = {subjects{s}, sc, pt, en(pt), ex(pt), ...
                    ex(pt)-en(pt), strjoin(flags,' | ')};
            else
                if ~isnan(en(pt)) && ~isnan(ex(pt))
                    clean{end+1} = {subjects{s}, sc, pt, en(pt), ex(pt), ex(pt)-en(pt)};
                end
            end
        end
    end
end

%% PART 1: print flagged cases
fprintf('=== PART 1: FLAGGED CASES (algorithm) ===\n');
fprintf('%-6s  %-4s  %-5s  %s\n','Subj','Scn','Pt','FLAG');
for k = 1:numel(flagged)
    f = flagged{k};
    fprintf('%-6s  %-4d  Pt%d  %s\n',f{1}, f{2}, f{3}, f{7});
end
if isempty(flagged)
    fprintf('No flagged cases.\n');
end

%% PART 2: cross-check flagged cases against JSON
fprintf('\n=== PART 2: JSON CROSS-CHECK FOR FLAGGED CASES ===\n');
fprintf('%-6s  %-4s  %-5s  %-10s  %-10s  %-10s  %-10s  %-10s  %s\n', ...
    'Subj','Scn','Pt','en_algo','ex_algo','dur_algo','en_json','ex_json','JSON_FLAG');

for k = 1:numel(flagged)
    f      = flagged{k};
    subj   = f{1};
    sc     = f{2};
    pt     = f{3};
    en_a   = f{4};
    ex_a   = f{5};

    json_en = NaN; json_ex = NaN; json_flag = 'no JSON';

    pattern = sprintf('%s_%d_metrics_*.json', lower(subj), sc);
    files   = dir(fullfile(metrics_path, [subj '_metrics'], pattern));

    if ~isempty(files)
        [~,newest] = max([files.datenum]);
        json = jsondecode(fileread(fullfile(metrics_path, [subj '_metrics'], files(newest).name)));

        if isfield(json,'insertion_events') && ...
           isfield(json.insertion_events,'entry_times') && ...
           isfield(json.insertion_events,'exit_times')

            en_struct = json.insertion_events.entry_times;
            ex_struct = json.insertion_events.exit_times;

            % JSON uses 0-indexed keys x0..x3, and times are in sim clock
            % Compute trial_start = last_event - time_elapsed to convert
            raw_en = nan(1,4); raw_ex = nan(1,4);
            for hole = 0:3
                fn = sprintf('x%d', hole);
                if isfield(en_struct, fn), raw_en(hole+1) = en_struct.(fn); end
                if isfield(ex_struct, fn), raw_ex(hole+1) = ex_struct.(fn); end
            end
            last_event  = max([raw_en raw_ex], [], 'omitnan');
            trial_start = last_event - json.performance.time_elapsed_seconds;
            json_en_all = raw_en - trial_start;
            json_ex_all = raw_ex - trial_start;

            json_en = json_en_all(pt);
            json_ex = json_ex_all(pt);

            % Check same flags in JSON
            jflags = {};
            if ~isnan(json_en) && ~isnan(json_ex)
                if json_ex - json_en <= 0
                    jflags{end+1} = 'EXIT BEFORE ENTRY';
                end
            end
            if pt > 1
                if ~isnan(json_en) && ~isnan(json_en_all(pt-1)) && json_en <= json_en_all(pt-1)
                    jflags{end+1} = 'ENTRY NOT MONOTONIC';
                end
                if ~isnan(json_ex) && ~isnan(json_ex_all(pt-1)) && json_ex <= json_ex_all(pt-1)
                    jflags{end+1} = 'EXIT NOT MONOTONIC';
                end
            end
            if isempty(jflags)
                json_flag = 'OK in JSON';
            else
                json_flag = strjoin(jflags,' | ');
            end
        else
            json_flag = 'no insertion_events';
        end
    end

    fprintf('%-6s  %-4d  Pt%d   %-10.2f  %-10.2f  %-10.2f  %-10.2f  %-10.2f  %s\n', ...
        subj, sc, pt, en_a, ex_a, ex_a-en_a, json_en, json_ex, json_flag);
end

%% PART 3: duration comparison for clean cases
fprintf('\n=== PART 3: DURATION COMPARISON (clean cases, algo vs JSON) ===\n');
fprintf('%-6s  %-4s  %-5s  %-12s  %-12s  %-10s\n', ...
    'Subj','Scn','Pt','dur_algo(s)','dur_json(s)','diff(s)');

for k = 1:numel(clean)
    c    = clean{k};
    subj = c{1}; sc = c{2}; pt = c{3};
    dur_algo = c{6};

    dur_json = NaN;

    pattern = sprintf('%s_%d_metrics_*.json', lower(subj), sc);
    files   = dir(fullfile(metrics_path, [subj '_metrics'], pattern));

    if ~isempty(files)
        [~,newest] = max([files.datenum]);
        json = jsondecode(fileread(fullfile(metrics_path, [subj '_metrics'], files(newest).name)));

        if isfield(json,'insertion_events') && ...
           isfield(json.insertion_events,'entry_times') && ...
           isfield(json.insertion_events,'exit_times')

            en_struct = json.insertion_events.entry_times;
            ex_struct = json.insertion_events.exit_times;
            raw_en = nan(1,4); raw_ex = nan(1,4);
            for hole = 0:3
                fn = sprintf('x%d', hole);
                if isfield(en_struct,fn), raw_en(hole+1) = en_struct.(fn); end
                if isfield(ex_struct,fn), raw_ex(hole+1) = ex_struct.(fn); end
            end
            last_event  = max([raw_en raw_ex],[],'omitnan');
            trial_start = last_event - json.performance.time_elapsed_seconds;
            json_en_all = raw_en - trial_start;
            json_ex_all = raw_ex - trial_start;

            je = json_en_all(pt);
            jx = json_ex_all(pt);
            if ~isnan(je) && ~isnan(jx)
                dur_json = jx - je;
            end
        end
    end

    diff_dur = dur_algo - dur_json;
    fprintf('%-6s  %-4d  Pt%d   %-12.3f  %-12.3f  %-10.3f\n',subj, sc, pt, dur_algo, dur_json, diff_dur);
end

fprintf('\nDone.\n');
%% PART 4: automated cleanup based on Part 2 and Part 3 findings

fprintf('\n=== PART 4: AUTOMATED CLEANUP ===\n');
clean_path     = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE_sure.mat';
A2 = load(mat_path);
EntryTimes = A2.EntryTimes;
ExitTimes  = A2.ExitTimes;

DURATION_MISMATCH_THRESH = 5.0;  % seconds: flag if algo and JSON durations differ by more than this

n_nulled = 0;
n_mismatch = 0;

for s = 1:length(subjects)
    for sc = 1:NUM_SCENARIOS
        en = squeeze(EntryTimes(s, sc, :))';
        ex = squeeze(ExitTimes(s,  sc, :))';

        pattern = sprintf('%s_%d_metrics_*.json', lower(subjects{s}), sc);
        files   = dir(fullfile(metrics_path, [subjects{s} '_metrics'], pattern));
        json_en_all = nan(1,4); json_ex_all = nan(1,4);

        if ~isempty(files)
            [~,newest] = max([files.datenum]);
            json = jsondecode(fileread(fullfile(metrics_path, ...
                [subjects{s} '_metrics'], files(newest).name)));
            if isfield(json,'insertion_events') && ...
               isfield(json.insertion_events,'entry_times') && ...
               isfield(json.insertion_events,'exit_times')
                en_s = json.insertion_events.entry_times;
                ex_s = json.insertion_events.exit_times;
                raw_en = nan(1,4); raw_ex = nan(1,4);
                for hole = 0:3
                    fn = sprintf('x%d',hole);
                    if isfield(en_s,fn), raw_en(hole+1) = en_s.(fn); end
                    if isfield(ex_s,fn), raw_ex(hole+1) = ex_s.(fn); end
                end
                last_event  = max([raw_en raw_ex],[],'omitnan');
                trial_start = last_event - json.performance.time_elapsed_seconds;
                json_en_all = raw_en - trial_start;
                json_ex_all = raw_ex - trial_start;
            end
        end

        for pt = 1:NUM_SUTURES
            algo_bad = ~isnan(en(pt)) && ~isnan(ex(pt)) && ex(pt) <= en(pt);
            json_ok  = ~isnan(json_en_all(pt)) && ~isnan(json_ex_all(pt)) && ...
                       json_ex_all(pt) > json_en_all(pt);

            if algo_bad && json_ok
                fprintf('  NaN: %s Scn%d Pt%d (algo exit<entry, JSON OK)\n', ...
                    subjects{s}, sc, pt);
                EntryTimes(s, sc, pt) = NaN;
                ExitTimes(s,  sc, pt) = NaN;
                n_nulled = n_nulled + 1;
            end

            if ~isnan(en(pt)) && ~isnan(ex(pt)) && ex(pt) > en(pt) && ...
               ~isnan(json_en_all(pt)) && ~isnan(json_ex_all(pt)) && ...
               json_ex_all(pt) > json_en_all(pt)
                dur_algo = ex(pt) - en(pt);
                dur_json = json_ex_all(pt) - json_en_all(pt);
                if abs(dur_algo - dur_json) > DURATION_MISMATCH_THRESH
                    fprintf('  MISMATCH: %s Scn%d Pt%d dur_algo=%.1fs dur_json=%.1fs diff=%.1fs\n', ...
                        subjects{s}, sc, pt, dur_algo, dur_json, dur_algo-dur_json);
                    n_mismatch = n_mismatch + 1;
                end
            end
        end
    end
end

save(clean_path, 'EntryTimes', 'ExitTimes', 'subjects');
fprintf('\nNulled %d algorithm errors confirmed by JSON.\n', n_nulled);
fprintf('Found %d duration mismatches > %.1fs for manual review.\n', n_mismatch, DURATION_MISMATCH_THRESH);
fprintf('Saved to %s\n', clean_path);