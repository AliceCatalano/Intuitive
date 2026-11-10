% GraspERD_Timestamps.m
% For each IE expert, each scenario, each suture point:
% finds the last MTML or MTMR grasp START that occurs before the needle entry.
% This is the anchor for the beta ERD epoch [-0.5, +1s].
% Saves: GraspERD_Times_IE.mat
% Requires: NeedlePassageTimes_IE.mat, grasp_data_scn%d.mat

clear; clc;

mat_needle   = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE_T2.mat';
base_grasp   = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav';
save_path    = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IE_T2.mat';

subjects     = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
NUM_SUBJECTS = length(subjects);
NUM_SCENARIOS = 6;
NUM_SUTURES   = 4;

EXCL_SCENARIO = {'IE02', [1 4]; 'IE10', 6};

N = load(mat_needle);
EntryPunctureMatrix = N.EntryPunctureMatrix;

LastGraspBeforeEntry = nan(NUM_SUBJECTS, NUM_SCENARIOS, NUM_SUTURES);
LastGraspHand        = cell(NUM_SUBJECTS, NUM_SCENARIOS, NUM_SUTURES);

for s = 1:NUM_SUBJECTS
    subj_name = subjects{s};
    subj_path = fullfile(base_grasp, subj_name);

    for sc = 1:NUM_SCENARIOS

        excl_scn = false;
        for e = 1:size(EXCL_SCENARIO,1)
            if strcmp(subj_name, EXCL_SCENARIO{e,1}) && ismember(sc, EXCL_SCENARIO{e,2})
                excl_scn = true; break;
            end
        end
        if excl_scn
            fprintf('%s Scn%d: excluded\n', subj_name, sc);
            continue;
        end

        mat_file = fullfile(subj_path, sprintf('grasp_data_scn%d.mat', sc));
        if ~exist(mat_file,'file')
            fprintf('%s Scn%d: grasp mat not found\n', subj_name, sc);
            continue;
        end

        d  = load(mat_file);
        t0 = min([d.mtml_time(1), d.mtmr_time(1), d.needle_time(1)]);

        mtml_gs = d.mtml_grasp_start - t0;
        mtmr_gs = d.mtmr_grasp_start - t0;

        for pt = 1:NUM_SUTURES
            entry_t = EntryPunctureMatrix(s, sc, pt);

            if isnan(entry_t)
                continue;
            end

            candidates_t    = [];
            candidates_hand = {};

            for g = 1:numel(mtml_gs)
                if mtml_gs(g) < entry_t
                    candidates_t(end+1)    = mtml_gs(g); %#ok<AGROW>
                    candidates_hand{end+1} = 'MTML';     %#ok<AGROW>
                end
            end
            for g = 1:numel(mtmr_gs)
                if mtmr_gs(g) < entry_t
                    candidates_t(end+1)    = mtmr_gs(g); %#ok<AGROW>
                    candidates_hand{end+1} = 'MTMR';     %#ok<AGROW>
                end
            end

            if isempty(candidates_t)
                fprintf('%s Scn%d Pt%d: no grasp before entry (t=%.2f)\n', ...
                    subj_name, sc, pt, entry_t);
                continue;
            end

            [~, latest_idx] = max(candidates_t);
            LastGraspBeforeEntry(s, sc, pt) = candidates_t(latest_idx);
            LastGraspHand{s, sc, pt}        = candidates_hand{latest_idx};
        end

        fprintf('%s | Scn%d : grasp_before_entry=[%.2f %.2f %.2f %.2f] hands=[%s %s %s %s]\n', ...
            subj_name, sc, ...
            LastGraspBeforeEntry(s,sc,1), LastGraspBeforeEntry(s,sc,2), ...
            LastGraspBeforeEntry(s,sc,3), LastGraspBeforeEntry(s,sc,4), ...
            string_or_nan(LastGraspHand{s,sc,1}), string_or_nan(LastGraspHand{s,sc,2}), ...
            string_or_nan(LastGraspHand{s,sc,3}), string_or_nan(LastGraspHand{s,sc,4}));
    end
end

save(save_path, 'LastGraspBeforeEntry', 'LastGraspHand', 'subjects');
fprintf('\n=== SAVED: %s ===\n', save_path);

function s = string_or_nan(c)
    if isempty(c) || (iscell(c) && isempty(c{1}))
        s = 'NaN';
    else
        s = c;
    end
end