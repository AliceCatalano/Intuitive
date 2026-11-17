% claude_ExitERS_Times_Res.m
% RESIDENTS (IR): validated needle-exit times, anchor of the exit ERS epoch.
%
% Starts from ExitTimes_Valid / EntryTimes_Valid saved by claude_ERDgrasp_Times_Res.m,
% i.e. repetitions in the skip list are ALREADY NaN (one skip list, one place).
% Repetitions never performed / without needle passage are NaN as well.
%
% For every remaining repetition and suture point an exit time is kept only if
%   - the exit exists (NaN = point not completed or exit target missed: legitimate)
%   - the entry exists
%   - exit > entry, with a duration of at least MIN_DURATION_S
%   - exit times are increasing across points (compared with the last exit
%     detected in a previous point of the same repetition)
% Points that fail are listed for manual / video verification.
%
% Saves: ExitERS_Times_IR.mat
%   ValidExitTimes  [nSubj x 6 x 10 x 4]  validated exit time (s from MS), NaN otherwise
%   ExitFlagLog     cell {subject, scenario, rep, point, exit, reason}
%   RepDur, RepStatus, subjects   (copied from GraspERD_Times_IR.mat)
% Requires: GraspERD_Times_IR.mat  (run claude_ERDgrasp_Times_Res.m first)

clear; clc;

grasp_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
save_path  = '/home/acatalano/Desktop/Intuitive/DataStructures/ExitERS_Times_IR.mat';

NUM_SCENARIOS  = 6;
NUM_TRIALS     = 10;
NUM_SUTURES    = 4;
MIN_DURATION_S = 0.5;

G          = load(grasp_file);
EntryV     = G.EntryTimes_Valid;     % [nSubj x 6 x 10 x 4], skip list applied
ExitV      = G.ExitTimes_Valid;
RepDur     = G.RepDur;
RepStatus  = G.RepStatus;
subjects   = G.subjects;
NUM_SUBJECTS = numel(subjects);

ValidExitTimes = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_TRIALS, NUM_SUTURES);
ExitFlagLog    = {};

fprintf('=== EXIT TIME VALIDATION ===\n\n');

for s = 1:NUM_SUBJECTS
    subj_name = subjects{s};

    for sc = 1:NUM_SCENARIOS
        for tr = 1:NUM_TRIALS

            en = squeeze(EntryV(s,sc,tr,:))';
            ex = squeeze(ExitV(s,sc,tr,:))';

            % skipped / not performed / no needle passage -> nothing to validate
            if all(isnan(ex)), continue; end

            valid   = true(1, NUM_SUTURES);
            prev_ex = NaN;                         % last detected exit in this repetition

            for pt = 1:NUM_SUTURES
                if isnan(ex(pt))
                    valid(pt) = false;             % exit missed / not completed: not an error
                    continue;
                end

                reasons = {};

                if isnan(en(pt))
                    valid(pt) = false;
                    reasons{end+1} = 'NO ENTRY'; %#ok<SAGROW>
                else
                    dur = ex(pt) - en(pt);
                    if dur <= 0
                        valid(pt) = false;
                        reasons{end+1} = sprintf('EXIT BEFORE ENTRY (dur=%.2fs)', dur); %#ok<SAGROW>
                    elseif dur < MIN_DURATION_S
                        valid(pt) = false;
                        reasons{end+1} = sprintf('TOO SHORT (dur=%.2fs)', dur); %#ok<SAGROW>
                    end
                end

                if ~isnan(prev_ex) && ex(pt) <= prev_ex
                    valid(pt) = false;
                    reasons{end+1} = sprintf('EXIT NOT MONOTONIC (ex%d=%.2f <= previous %.2f)', ...
                        pt, ex(pt), prev_ex); %#ok<SAGROW>
                end
                prev_ex = ex(pt);

                if ~isempty(reasons)
                    ExitFlagLog(end+1,:) = {subj_name, sc, tr, pt, ex(pt), strjoin(reasons, ' | ')}; %#ok<SAGROW>
                end
            end

            ValidExitTimes(s,sc,tr,valid) = ex(valid);

            fprintf('%s | Sc%d Rep%02d : exit=[%.2f %.2f %.2f %.2f]  valid=[%d %d %d %d]\n', ...
                subj_name, sc, tr, ex(1), ex(2), ex(3), ex(4), ...
                valid(1), valid(2), valid(3), valid(4));
        end
    end
end

fprintf('\n=== FLAGGED FOR VIDEO VERIFICATION ===\n');
for k = 1:size(ExitFlagLog,1)
    fprintf('  %s Sc%d Rep%02d Pt%d  exit=%.2f  %s\n', ExitFlagLog{k,:});
end

n_valid = nnz(~isnan(ValidExitTimes));
n_det   = nnz(~isnan(ExitV));
fprintf('\nValid exit times: %d / %d detected exits (in non-skipped repetitions)\n', n_valid, n_det);

save(save_path, 'ValidExitTimes', 'ExitFlagLog', 'RepDur', 'RepStatus', 'subjects');
fprintf('\n=== SAVED: %s ===\n', save_path);
