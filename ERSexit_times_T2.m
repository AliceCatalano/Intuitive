% ExitERS_Timestamps.m
% For each IE expert, each scenario, each suture point:
% takes the exit time (ExitTimes from NeedlePassageTimes_IE_sure.mat),
% applies the same validity filters as the entry analysis:
%   - exit must exist (not NaN)
%   - exit > entry (positive duration, min 0.5s)
%   - exit times must be monotonically increasing across points
%   - hard exclusions: IE02 Scn1&4, IE10 Scn6
% Flags problematic exits for manual review (pending video verification).
% Saves: ExitERS_Times_IE.mat

clear; clc;

mat_needle   = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE_T2.mat';
save_path    = '/home/acatalano/Desktop/Intuitive/DataStructures/ExitERS_Times_IE_T2.mat';

subjects      = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
NUM_SUBJECTS  = length(subjects);
NUM_SCENARIOS = 20;
NUM_SUTURES   = 4;
MIN_DURATION_S = 0.5;

EXCL_SCENARIO = {'IE03', 10; 'IE05', 9; 'IE07', 15; 'IE10', 4};

N = load(mat_needle);
EntryTimes = N.EntryTimes;
ExitTimes  = N.ExitTimes;

% Output: validated exit times for ERS anchoring
ValidExitTimes = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_SUTURES);

flagged_log = {};

fprintf('=== EXIT TIME VALIDATION ===\n\n');

for s = 1:NUM_SUBJECTS
    subj_name = subjects{s};

    for sc = 1:NUM_SCENARIOS

        excl_scn = false;
        for e = 1:size(EXCL_SCENARIO,1)
            if strcmp(subj_name, EXCL_SCENARIO{e,1}) && ismember(sc, EXCL_SCENARIO{e,2})
                excl_scn = true; break;
            end
        end
        if excl_scn
            continue;
        end

        en = squeeze(EntryTimes(s, sc, :))';
        ex = squeeze(ExitTimes(s,  sc, :))';

        valid = true(1, NUM_SUTURES);

        for pt = 1:NUM_SUTURES
            flag = {};

            if isnan(ex(pt))
                valid(pt) = false;
                continue;
            end

            if isnan(en(pt))
                valid(pt) = false;
                flag{end+1} = 'NO ENTRY';
            else
                dur = ex(pt) - en(pt);
                if dur <= 0
                    valid(pt) = false;
                    flag{end+1} = sprintf('EXIT BEFORE ENTRY (dur=%.2fs)', dur);
                elseif dur < MIN_DURATION_S
                    valid(pt) = false;
                    flag{end+1} = sprintf('TOO SHORT (dur=%.2fs)', dur);
                end
            end

            if pt > 1 && ~isnan(ex(pt)) && ~isnan(ex(pt-1)) && ex(pt) <= ex(pt-1)
                valid(pt) = false;
                flag{end+1} = sprintf('EXIT NOT MONOTONIC (ex%d=%.2f <= ex%d=%.2f)', ...
                    pt, ex(pt), pt-1, ex(pt-1));
            end

            if ~isempty(flag)
                flagged_log{end+1} = sprintf('  %s Scn%d Pt%d  exit=%.2f  %s', ...
                    subj_name, sc, pt, ex(pt), strjoin(flag,' | '));
            end
        end

        for pt = 1:NUM_SUTURES
            if valid(pt)
                ValidExitTimes(s, sc, pt) = ex(pt);
            end
        end

        fprintf('%s | Scn%d : exit=[%.2f %.2f %.2f %.2f]  valid=[%d %d %d %d]\n', ...
            subj_name, sc, ex(1),ex(2),ex(3),ex(4), valid(1),valid(2),valid(3),valid(4));
    end
end

fprintf('\n=== FLAGGED FOR VIDEO VERIFICATION ===\n');
for k = 1:numel(flagged_log)
    fprintf('%s\n', flagged_log{k});
end

n_valid = sum(~isnan(ValidExitTimes(:)));
n_total = NUM_SUBJECTS * NUM_SCENARIOS * NUM_SUTURES;
fprintf('\nValid exit times: %d / %d total slots\n', n_valid, n_total);

save(save_path, 'ValidExitTimes', 'subjects');
fprintf('\n=== SAVED: %s ===\n', save_path);