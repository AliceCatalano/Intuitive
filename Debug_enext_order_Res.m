clear; clc;

mat_path       = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IR.mat';
metrics_path   = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IR_metrics';

A = load(mat_path);
subjects      = A.subjects;
NUM_SCENARIOS = 6;
NUM_TRIALS    = 10;
NUM_SUTURES   = 4;
MIN_DURATION_S = 0.5;

flagged = {};
clean   = {};

for s = 1:length(subjects)
    for sc = 1:NUM_SCENARIOS
        for tr = 1:NUM_TRIALS
            en = squeeze(A.EntryTimes(s, sc, tr, :))';
            ex = squeeze(A.ExitTimes(s,  sc, tr, :))';

            if all(isnan(en)) && all(isnan(ex)), continue; end

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
                    flagged{end+1} = {subjects{s}, sc, tr, pt, en(pt), ex(pt), ...
                        ex(pt)-en(pt), strjoin(flags,' | ')};
                else
                    if ~isnan(en(pt)) && ~isnan(ex(pt))
                        clean{end+1} = {subjects{s}, sc, tr, pt, en(pt), ex(pt), ex(pt)-en(pt)};
                    end
                end
            end
        end
    end
end

%% PART 1: flagged cases
fprintf('=== PART 1: FLAGGED CASES ===\n');
fprintf('%-6s  %-4s  %-5s  %-5s  %s\n','Subj','Scn','Rep','Pt','FLAG');
for k = 1:numel(flagged)
    f = flagged{k};
    fprintf('%-6s  Sc%-2d  Tr%-2d  Pt%d  %s\n', f{1}, f{2}, f{3}, f{4}, f{8});
end
if isempty(flagged)
    fprintf('No flagged cases.\n');
end

%% PART 2: summary counts
fprintf('\n=== PART 2: FLAG SUMMARY ===\n');
fprintf('Total flagged entries : %d\n', numel(flagged));
fprintf('Total clean entries   : %d\n', numel(clean));

flag_types = {};
for k = 1:numel(flagged)
    parts = strsplit(flagged{k}{8},' | ');
    for p = 1:numel(parts)
        tag = regexprep(parts{p}, '\(.*\)', '');
        tag = strtrim(tag);
        flag_types{end+1} = tag;
    end
end
unique_flags = unique(flag_types);
fprintf('\nBreakdown by flag type:\n');
for u = 1:numel(unique_flags)
    n = sum(strcmp(flag_types, unique_flags{u}));
    fprintf('  %-40s : %d\n', unique_flags{u}, n);
end

%% PART 3: per-subject summary
fprintf('\n=== PART 3: PER-SUBJECT FLAG COUNT ===\n');
fprintf('%-8s  %-8s  %-8s\n','Subject','Flagged','Clean');
for s = 1:length(subjects)
    nf = sum(cellfun(@(x) strcmp(x{1}, subjects{s}), flagged));
    nc = sum(cellfun(@(x) strcmp(x{1}, subjects{s}), clean));
    fprintf('%-8s  %-8d  %-8d\n', subjects{s}, nf, nc);
end

%% PART 4: duration distribution for clean cases
durs = cellfun(@(x) x{7}, clean);
fprintf('\n=== PART 4: DURATION STATS (clean cases) ===\n');
fprintf('  Min  : %.2f s\n', min(durs));
fprintf('  Max  : %.2f s\n', max(durs));
fprintf('  Mean : %.2f s\n', mean(durs));
fprintf('  Median: %.2f s\n', median(durs));
fprintf('  >60s  : %d cases\n', sum(durs > 60));
fprintf('  >120s : %d cases\n', sum(durs > 120));

fprintf('\nDone.\n');