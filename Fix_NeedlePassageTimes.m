clear; clc;

mat_path = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IR.mat';

SUBJ_NAME    = 'IR10';
SCENARIO_NUM = 1;
TRIAL_NUM    = 2;
POINT_NUM    = 3;
FIX_TYPE     = 'exit';   % 'entry' or 'exit' or 'nan' to invalidate both
NEW_VALUE    = 79.8370;    % ignored if FIX_TYPE is 'nan'

A = load(mat_path);
subjects   = A.subjects;
EntryTimes = A.EntryTimes;   % [21 x 6 x 10 x 4]
ExitTimes  = A.ExitTimes;    % [21 x 6 x 10 x 4]

s_idx = find(strcmp(subjects, SUBJ_NAME));
if isempty(s_idx)
    error('Subject %s not found. Available: %s', SUBJ_NAME, strjoin(subjects, ', '));
end

fprintf('=== BEFORE FIX ===\n');
fprintf('%s | Sc%d | Tr%d | Pt%d\n', SUBJ_NAME, SCENARIO_NUM, TRIAL_NUM, POINT_NUM);
fprintf('  Entry: %.4f s\n', EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM));
fprintf('  Exit:  %.4f s\n', ExitTimes(s_idx,  SCENARIO_NUM, TRIAL_NUM, POINT_NUM));

if strcmp(FIX_TYPE, 'entry')
    old_val = EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM);
    EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM) = NEW_VALUE;
    fprintf('\nChanged ENTRY from %.4f to %.4f s\n', old_val, NEW_VALUE);
elseif strcmp(FIX_TYPE, 'exit')
    old_val = ExitTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM);
    ExitTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM) = NEW_VALUE;
    fprintf('\nChanged EXIT from %.4f to %.4f s\n', old_val, NEW_VALUE);
elseif strcmp(FIX_TYPE, 'nan')
    EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM) = NaN;
    ExitTimes(s_idx,  SCENARIO_NUM, TRIAL_NUM, POINT_NUM) = NaN;
    fprintf('\nInvalidated both entry and exit to NaN\n');
else
    error('FIX_TYPE must be ''entry'', ''exit'', or ''nan''');
end

fprintf('\n=== AFTER FIX ===\n');
fprintf('%s | Sc%d | Tr%d | Pt%d\n', SUBJ_NAME, SCENARIO_NUM, TRIAL_NUM, POINT_NUM);
fprintf('  Entry: %.4f s\n', EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM));
fprintf('  Exit:  %.4f s\n', ExitTimes(s_idx,  SCENARIO_NUM, TRIAL_NUM, POINT_NUM));

en = EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, POINT_NUM);
ex = ExitTimes(s_idx,  SCENARIO_NUM, TRIAL_NUM, POINT_NUM);
if ~isnan(en) && ~isnan(ex)
    dur = ex - en;
    if dur <= 0
        warning('EXIT BEFORE ENTRY after fix (dur=%.2fs)', dur);
    elseif dur < 0.5
        warning('Duration very short after fix (dur=%.2fs)', dur);
    else
        fprintf('\nSanity check OK: duration = %.2f s\n', dur);
    end
end

en_all = squeeze(EntryTimes(s_idx, SCENARIO_NUM, TRIAL_NUM, :))';
ex_all = squeeze(ExitTimes(s_idx,  SCENARIO_NUM, TRIAL_NUM, :))';
for pt = 2:4
    if ~isnan(en_all(pt)) && ~isnan(en_all(pt-1)) && en_all(pt) <= en_all(pt-1)
        warning('Entry NOT monotonic: en[%d]=%.2f <= en[%d]=%.2f', pt, en_all(pt), pt-1, en_all(pt-1));
    end
    if ~isnan(ex_all(pt)) && ~isnan(ex_all(pt-1)) && ex_all(pt) <= ex_all(pt-1)
        warning('Exit NOT monotonic: ex[%d]=%.2f <= ex[%d]=%.2f', pt, ex_all(pt), pt-1, ex_all(pt-1));
    end
end

fprintf('\nFull trial after fix:\n');
fprintf('  Entry: [%.2f  %.2f  %.2f  %.2f]\n', en_all(1), en_all(2), en_all(3), en_all(4));
fprintf('  Exit:  [%.2f  %.2f  %.2f  %.2f]\n', ex_all(1), ex_all(2), ex_all(3), ex_all(4));

save(mat_path, 'EntryTimes', 'ExitTimes', 'subjects');
fprintf('\n=== SAVED: %s ===\n', mat_path);