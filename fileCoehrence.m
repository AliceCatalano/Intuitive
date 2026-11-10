% Sync_IE20_folders.m
% For each expert subject, checks the IE#_20 repetition folders (20 trials of scenario 4).
% For each trial folder, verifies that all required files are present locally.
% If any are missing, copies them from the network drive.
% Required files: needle_rigid_body.csv, mtml_cp_cartesian_position.csv,
%                 mtml_joint_state.csv, mtmr_cp_cartesian_position.csv,
%                 mtmr_joint_state.csv, summary.json

clear; clc;

local_base   = '/home/acatalano/Desktop/Intuitive/BehavioraldVRKData/IE_SaveData';
network_base = '/run/user/1001/gvfs/smb-share:server=synkjk01.local,share=home/IE_SaveData';

subjects = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};

required_files = {
    'needle_rigid_body.csv'
    'mtml_cp_cartesian_position.csv'
    'mtml_joint_state.csv'
    'mtmr_cp_cartesian_position.csv'
    'mtmr_joint_state.csv'
    'summary.json'
};

n_copied  = 0;
n_missing = 0;
n_ok      = 0;

fprintf('=== IE_20 FILE SYNC ===\n\n');

for s = 1:length(subjects)
    subj = subjects{s};
    subj_lower = lower(subj);

    local_ie20   = fullfile(local_base,   [subj '_SaveData'], [subj '_20']);
    network_ie20 = fullfile(network_base, [subj '_SaveData'], [subj '_20']);

    if ~isfolder(local_ie20)
        fprintf('%s: local IE_20 folder not found, skip\n', subj);
        continue;
    end

    if ~isfolder(network_ie20)
        fprintf('%s: network IE_20 folder not accessible, skip\n', subj);
        continue;
    end

    % Find all trial subfolders (ie01_4_1_scenario4 ... ie01_4_20_scenario4)
    trial_dirs = dir(fullfile(local_ie20, sprintf('%s_4_*_scenario4', subj_lower)));
    trial_dirs = trial_dirs([trial_dirs.isdir]);

    if isempty(trial_dirs)
        fprintf('%s: no trial folders found in IE_20\n', subj);
        continue;
    end

    fprintf('%s: checking %d trial folders\n', subj, numel(trial_dirs));

    for t = 1:numel(trial_dirs)
        folder_name = trial_dirs(t).name;

        local_analysis   = fullfile(local_ie20,   folder_name, 'analysis');
        network_analysis = fullfile(network_ie20,  folder_name, 'analysis');

        if ~isfolder(local_analysis)
            mkdir(local_analysis);
            fprintf('  Created: %s\n', local_analysis);
        end

        for f = 1:numel(required_files)
            fname      = required_files{f};
            local_file = fullfile(local_analysis, fname);
            net_file   = fullfile(network_analysis, fname);

            if isfile(local_file)
                n_ok = n_ok + 1;
            elseif isfile(net_file)
                copyfile(net_file, local_file);
                fprintf('  COPIED: %s/%s/%s\n', subj, folder_name, fname);
                n_copied = n_copied + 1;
            else
                fprintf('  MISSING on both local and network: %s/%s/%s\n', subj, folder_name, fname);
                n_missing = n_missing + 1;
            end
        end
    end
end

fprintf('\n=== SYNC COMPLETE ===\n');
fprintf('Files already present: %d\n', n_ok);
fprintf('Files copied from network: %d\n', n_copied);
fprintf('Files missing on both: %d\n', n_missing);