% GraspERD_Timestamps_T2.m
% For each IE expert, each repetition (1-20), each suture point:
% finds the last MTML or MTMR grasp START that occurs before the needle entry.
% Saves: GraspERD_Times_IE_T2.mat

clear; clc;

mat_needle   = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE_T2.mat';
base_grasp   = '/home/acatalano/Desktop/Intuitive/DataStructures';
save_path    = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IE_T2.mat';

subjects     = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
NUM_SUBJECTS = length(subjects);
NUM_REPS     = 20;
NUM_SUTURES  = 4;

% Exclusions: {subject, rep_number}
EXCL_REP = {'IE03', 10; 'IE05', 9; 'IE07', 15; 'IE10', 4};

N = load(mat_needle);
EntryTimes = N.EntryTimes;  % assumed: (NUM_SUBJECTS x NUM_REPS x NUM_SUTURES)

LastGraspBeforeEntry = nan(NUM_SUBJECTS, NUM_REPS, NUM_SUTURES);
LastGraspHand        = cell(NUM_SUBJECTS, NUM_REPS, NUM_SUTURES);

for s = 1:NUM_SUBJECTS
    subj_name = subjects{s};

    for rep = 1:NUM_REPS

        % Check exclusions
        excl = false;
        for e = 1:size(EXCL_REP, 1)
            if strcmp(subj_name, EXCL_REP{e,1}) && rep == EXCL_REP{e,2}
                excl = true; break;
            end
        end
        if excl
            fprintf('%s Rep%02d: excluded\n', subj_name, rep);
            continue;
        end

        % Build filename
        mat_file = fullfile(base_grasp, ...
            sprintf('grasp_Exp_T2_%s_rep%02d.mat', subj_name, rep));

        if ~exist(mat_file, 'file')
            fprintf('%s Rep%02d: grasp mat not found\n', subj_name, rep);
            continue;
        end

        % Load grasp data
        d  = load(mat_file);

        % Check required fields exist
        required = {'mtml_time','mtmr_time','needle_time','mtml_grasp_start','mtmr_grasp_start'};
        missing = false;
        for r = 1:length(required)
            if ~isfield(d, required{r})
                fprintf('%s Rep%02d: missing field "%s"\n', subj_name, rep, required{r});
                missing = true; break;
            end
        end
        if missing; continue; end

        % Compute time zero
        t0 = min([d.mtml_time(1), d.mtmr_time(1), d.needle_time(1)]);

        mtml_gs = d.mtml_grasp_start - t0;
        mtmr_gs = d.mtmr_grasp_start - t0;

        for pt = 1:NUM_SUTURES
            entry_t = EntryTimes(s, rep, pt);

            if isnan(entry_t)
                continue;
            end

            % Collect all grasp starts before needle entry
            candidates_t    = [];
            candidates_hand = {};

            for g = 1:numel(mtml_gs)
                if mtml_gs(g) < entry_t
                    candidates_t(end+1)    = mtml_gs(g);  %#ok<AGROW>
                    candidates_hand{end+1} = 'MTML';      %#ok<AGROW>
                end
            end
            for g = 1:numel(mtmr_gs)
                if mtmr_gs(g) < entry_t
                    candidates_t(end+1)    = mtmr_gs(g);  %#ok<AGROW>
                    candidates_hand{end+1} = 'MTMR';      %#ok<AGROW>
                end
            end

            if isempty(candidates_t)
                fprintf('%s Rep%02d Pt%d: no grasp before entry (t=%.2f)\n', ...
                    subj_name, rep, pt, entry_t);
                continue;
            end

            [~, latest_idx] = max(candidates_t);
            LastGraspBeforeEntry(s, rep, pt) = candidates_t(latest_idx);
            LastGraspHand{s, rep, pt}        = candidates_hand{latest_idx};
        end

        fprintf('%s | Rep%02d : grasp_before_entry=[%.2f %.2f %.2f %.2f] hands=[%s %s %s %s]\n', ...
            subj_name, rep, ...
            LastGraspBeforeEntry(s,rep,1), LastGraspBeforeEntry(s,rep,2), ...
            LastGraspBeforeEntry(s,rep,3), LastGraspBeforeEntry(s,rep,4), ...
            string_or_nan(LastGraspHand{s,rep,1}), string_or_nan(LastGraspHand{s,rep,2}), ...
            string_or_nan(LastGraspHand{s,rep,3}), string_or_nan(LastGraspHand{s,rep,4}));
    end
end

save(save_path, 'LastGraspBeforeEntry', 'LastGraspHand', 'subjects');
fprintf('\n=== SAVED: %s ===\n', save_path);

% Helper function
function s = string_or_nan(c)
    if isempty(c)
        s = 'NaN';
    else
        s = c;
    end
end