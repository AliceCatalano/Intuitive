% ERDgrasp_Times_Res.m
% RESIDENTS (IR): for each subject, scenario, repetition and suture point,
% finds the last MTML or MTMR grasp START that occurs before the needle entry.
% This is the anchor for the beta ERD epoch (grasp-locked).
%
% Residents performed up to 6 scenarios, with a variable number of
% repetitions per scenario (3 to 10: stop after 3 consecutive repetitions
% above the score threshold, otherwise max 10 attempts). Some repetitions
% are missing or were skipped, so the output keeps the fixed
% [subject x scenario x rep x suture] layout of NeedlePassageTimes_IR.mat and
% leaves NaN wherever a repetition must not be used.
%
% A repetition is used only if ALL of these hold:
%   1) it is not listed in SKIP_REP (manual skip list)
%   2) it has at least one valid EntryTimes value (i.e. it was really performed
%      and the needle passage was detected)
%   3) its grasp file exists (grasp_IR_<subj>_sc<S>_rep<RR>.mat)
%
% Time base: same as EntryTimes, i.e. seconds from the first needle sample
% with a valid pose (all of x,y,z,qx,qy,qz,qw non-NaN), as in Suture_Times_IR.m.
%
% Saves: GraspERD_Times_IR.mat
%   LastGraspBeforeEntry  [nSubj x 6 x 10 x 4]  grasp start time (s), NaN if none
%   LastGraspHand         {nSubj x 6 x 10 x 4}  'MTML' / 'MTMR' / []
%   RepStatus             [nSubj x 6 x 10]      see STATUS codes below
%   EntryTimes_Valid      [nSubj x 6 x 10 x 4]  EntryTimes with skip-list reps set to NaN
%   ExitTimes_Valid       [nSubj x 6 x 10 x 4]  ExitTimes  with skip-list reps set to NaN
%   RepDur                [nSubj x 6 x 10]      needle-stream duration (s), for EEG ME-MS check
%   subjects
% Requires: NeedlePassageTimes_IR.mat, GraspData_Res/grasp_IR_*.mat

clear; clc;

mat_needle = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IR.mat';
base_grasp = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspData_Res';
save_path  = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';

NUM_SCENARIOS = 6;
NUM_TRIALS    = 10;
NUM_SUTURES   = 4;

% Manual skip list: {subject, scenario, [reps]}. Repetitions listed here are
% ignored even if they have entry times / grasp files.
% Marks from the annotation sheet: S and X = discard; T,X = discard.
% T alone ("took too long, use the points they gave") is NOT skipped.
% IR03 and IR20 are not in the analysed subject list (harmless if kept).
SKIP_REP = {'IR03', 1, [8 10];'IR03', 2, [1 4 6 9];  'IR03', 4, 5; ...
    'IR04', 1, 1; ...
    'IR05', 3, 4; ...
    'IR06', 3, 5; ...
    'IR07', 3, [5 6];    'IR07', 6, 1; ...
    'IR08', 2, 5;        'IR08', 3, [4 9]; ...
    'IR10', 1, 7;        'IR10', 2, 2; ...
    'IR14', 3, [8 9]; ...
    'IR18', 3, [1 3]; ...
    'IR20', 1, [2 4 7];  'IR20', 2, 3; ...
    'IR21', 5, 2;        'IR21', 6, 2; ...
    'IR22', 1, [3 4]; ...
    'IR23', 1, 1;        'IR23', 6, [5 6]; ...
    'IR24', 5, 6; ...
    'IR25', 1, [1 6 8];  'IR25', 2, 2;  'IR25', 5, 4};

% RepStatus codes
ST_NOT_PERFORMED = 0;   % no EntryTimes (missing / skipped / never done)
ST_SKIPPED       = 1;   % in SKIP_REP
ST_NO_GRASP_FILE = 2;   % performed, but grasp file missing
ST_BAD_GRASP_FILE= 3;   % grasp file present but unusable (fields / pose)
ST_OK            = 4;   % processed

N          = load(mat_needle);
EntryTimes = N.EntryTimes;               % [nSubj x 6 x 10 x 4]
ExitTimes  = N.ExitTimes;                % [nSubj x 6 x 10 x 4]
subjects   = cellstr(N.subjects);
NUM_SUBJECTS = numel(subjects);

% Entry/Exit matrices masked with the SAME skip list as the grasp matrix.
% Use THESE (not the raw ones) when inserting In/Out events in the EEG, so a
% skipped repetition can never receive events. NaN inside a valid repetition
% is kept on purpose (point not completed / exit target missed).
EntryTimes_Valid = EntryTimes;
ExitTimes_Valid  = ExitTimes;

% Recording duration (s) of each repetition from the needle stream, same time
% base as EntryTimes. The EEG-side check is: (ME - MS) ~= RepDur (+~1 s).
% NaN when the grasp file is missing.
RepDur = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_TRIALS);

LastGraspBeforeEntry = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_TRIALS, NUM_SUTURES);
LastGraspHand        = cell(NUM_SUBJECTS, NUM_SCENARIOS, NUM_TRIALS, NUM_SUTURES);
RepStatus            = zeros(NUM_SUBJECTS, NUM_SCENARIOS, NUM_TRIALS);

required = {'mtml_time','mtmr_time','needle_time','mtml_grasp_start','mtmr_grasp_start', ...
            'needle_x','needle_y','needle_z','needle_qx','needle_qy','needle_qz','needle_qw'};

for s = 1:NUM_SUBJECTS
    subj_name = subjects{s};

    for sc = 1:NUM_SCENARIOS
        for tr = 1:NUM_TRIALS

            % 1) manual skip list
            if is_skipped(SKIP_REP, subj_name, sc, tr)
                RepStatus(s,sc,tr) = ST_SKIPPED;
                EntryTimes_Valid(s,sc,tr,:) = NaN;
                ExitTimes_Valid(s,sc,tr,:)  = NaN;
                fprintf('%s Sc%d Rep%02d: in skip list\n', subj_name, sc, tr);
                continue;
            end

            % 2) repetition not performed / no needle passage detected
            entry_t = squeeze(EntryTimes(s, sc, tr, :))';   % 1 x NUM_SUTURES
            if all(isnan(entry_t))
                RepStatus(s,sc,tr) = ST_NOT_PERFORMED;
                continue;
            end

            % 3) grasp file
            mat_file = fullfile(base_grasp, ...
                sprintf('grasp_IR_%s_sc%d_rep%02d.mat', subj_name, sc, tr));
            if ~exist(mat_file, 'file')
                RepStatus(s,sc,tr) = ST_NO_GRASP_FILE;
                fprintf('%s Sc%d Rep%02d: grasp mat not found\n', subj_name, sc, tr);
                continue;
            end

            d = load(mat_file);
            if ~all(isfield(d, required))
                RepStatus(s,sc,tr) = ST_BAD_GRASP_FILE;
                fprintf('%s Sc%d Rep%02d: grasp mat missing required fields\n', subj_name, sc, tr);
                continue;
            end

            % Time zero: first needle sample with a valid pose (same as EntryTimes)
            pose = [d.needle_x(:) d.needle_y(:) d.needle_z(:) ...
                    d.needle_qx(:) d.needle_qy(:) d.needle_qz(:) d.needle_qw(:)];
            first_valid = find(all(~isnan(pose), 2), 1, 'first');
            if isempty(first_valid) || size(pose,1) ~= numel(d.needle_time)
                RepStatus(s,sc,tr) = ST_BAD_GRASP_FILE;
                fprintf('%s Sc%d Rep%02d: no valid needle pose for time zero\n', subj_name, sc, tr);
                continue;
            end
            t0 = d.needle_time(first_valid);
            RepDur(s,sc,tr) = d.needle_time(end) - t0;

            mtml_gs = d.mtml_grasp_start(:)' - t0;
            mtmr_gs = d.mtmr_grasp_start(:)' - t0;

            % All grasp starts with their hand label
            all_t    = [mtml_gs, mtmr_gs];
            all_hand = [repmat({'MTML'}, 1, numel(mtml_gs)), repmat({'MTMR'}, 1, numel(mtmr_gs))];

            for pt = 1:NUM_SUTURES
                if isnan(entry_t(pt)), continue; end

                before = find(all_t < entry_t(pt));
                if isempty(before)
                    fprintf('%s Sc%d Rep%02d Pt%d: no grasp before entry (t=%.2f)\n', ...
                        subj_name, sc, tr, pt, entry_t(pt));
                    continue;
                end

                [~, k] = max(all_t(before));    % latest grasp start before entry
                LastGraspBeforeEntry(s,sc,tr,pt) = all_t(before(k));
                LastGraspHand{s,sc,tr,pt}        = all_hand{before(k)};
            end

            RepStatus(s,sc,tr) = ST_OK;

            fprintf('%s | Sc%d Rep%02d : grasp_before_entry=[%.2f %.2f %.2f %.2f] hands=[%s %s %s %s]\n', ...
                subj_name, sc, tr, ...
                LastGraspBeforeEntry(s,sc,tr,1), LastGraspBeforeEntry(s,sc,tr,2), ...
                LastGraspBeforeEntry(s,sc,tr,3), LastGraspBeforeEntry(s,sc,tr,4), ...
                hand_str(LastGraspHand{s,sc,tr,1}), hand_str(LastGraspHand{s,sc,tr,2}), ...
                hand_str(LastGraspHand{s,sc,tr,3}), hand_str(LastGraspHand{s,sc,tr,4}));
        end
    end
end

%% Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('Reps processed (OK)             : %d\n', nnz(RepStatus == ST_OK));
fprintf('Reps performed, no grasp file   : %d\n', nnz(RepStatus == ST_NO_GRASP_FILE));
fprintf('Reps with unusable grasp file   : %d\n', nnz(RepStatus == ST_BAD_GRASP_FILE));
fprintf('Reps in skip list               : %d\n', nnz(RepStatus == ST_SKIPPED));
fprintf('Sutures with a grasp anchor     : %d / %d\n', ...
    nnz(~isnan(LastGraspBeforeEntry)), nnz(~isnan(EntryTimes)));

save(save_path, 'LastGraspBeforeEntry', 'LastGraspHand', 'RepStatus', ...
     'EntryTimes_Valid', 'ExitTimes_Valid', 'RepDur', 'subjects');
fprintf('\n=== SAVED: %s ===\n', save_path);


%% Local functions
function tf = is_skipped(skip_list, subj_name, sc, tr)
    tf = false;
    for e = 1:size(skip_list, 1)
        if strcmp(subj_name, skip_list{e,1}) && skip_list{e,2} == sc && ismember(tr, skip_list{e,3})
            tf = true; return;
        end
    end
end

function s = hand_str(c)
    if isempty(c), s = 'NaN'; else, s = c; end
end
