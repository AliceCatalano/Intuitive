% Task2_ExpEvents_GraspERD.m
% Inserts one event per valid suture point per repetition into the EEG:
%   'G%d_R%d' (point, rep) at the time of the last grasp before needle entry.
% This event is the anchor for the ERD epoch [-0.5, +1s].
% Reads:  IE_Task/*_Task2_final.set
%         DataStructures/GraspERD_Times_IE_T2.mat
% Writes: IE_Task/*_Task2_graspERD_events.set

clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects     = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path    = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
mat_path     = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IE_T2.mat';

% Exclusions: {subject, rep_number}
EXCL_REP = {'IE03', 10; 'IE05', 9; 'IE07', 15; 'IE10', 4};

G = load(mat_path);
LastGraspBeforeEntry = G.LastGraspBeforeEntry;  % (subjects x reps x sutures)

NUM_REPS    = 20;
NUM_SUTURES = 4;

for s = 1:length(subjects)
    subject = subjects{s};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject 'Task2_final.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');
    EEG = eeg_checkset(EEG);

    n_inserted = 0;

    for rep = 1:NUM_REPS

        % Check exclusions
        excl = false;
        for e = 1:size(EXCL_REP, 1)
            if strcmp(subject, EXCL_REP{e,1}) && rep == EXCL_REP{e,2}
                excl = true; break;
            end
        end
        if excl
            fprintf('  %s Rep%02d: excluded, skip\n', subject, rep);
            continue;
        end

        % Find the repetition marker in EEG events
        % Try 'MR%d' first, then 'R%d'
        nomeMS = sprintf('MS%d', rep);
        nomeS  = sprintf('R%d',  rep);

        msLatency = [];
        for ev = 1:length(EEG.event)
            if strcmp(EEG.event(ev).type, nomeMS)
                msLatency = EEG.event(ev).latency;
                break;
            end
        end
        if isempty(msLatency)
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, nomeS)
                    msLatency = EEG.event(ev).latency;
                    break;
                end
            end
        end

        if isempty(msLatency)
            fprintf('  %s Rep%02d: no MR/R marker found, skip\n', subject, rep);
            continue;
        end

        for pt = 1:NUM_SUTURES
            grasp_t = LastGraspBeforeEntry(s, rep, pt);

            if isnan(grasp_t)
                continue;
            end

            lat_grasp = msLatency + round(grasp_t * EEG.srate);

            if lat_grasp < 1 || lat_grasp > EEG.pnts
                fprintf('  %s Rep%02d Pt%d: grasp latency %.0f out of range, skip\n', ...
                    subject, rep, pt, lat_grasp);
                continue;
            end

            % Check for boundary inside ERD epoch window [-0.5, +1]s
            epoch_start = lat_grasp - round(0.5 * EEG.srate);
            epoch_end   = lat_grasp + round(1.0 * EEG.srate);
            has_boundary = false;
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, 'boundary') && ...
                   EEG.event(ev).latency >= epoch_start && ...
                   EEG.event(ev).latency <= epoch_end
                    has_boundary = true;
                    break;
                end
            end
            if has_boundary
                fprintf('  %s Rep%02d Pt%d: boundary inside epoch window, skip\n', ...
                    subject, rep, pt);
                continue;
            end

            label = sprintf('G%d_R%02d', pt, rep);
            nEv = length(EEG.event) + 1;
            EEG.event(nEv).type     = label;
            EEG.event(nEv).latency  = lat_grasp;
            EEG.event(nEv).duration = 0;
            EEG.event(nEv).urevent  = nEv;
            n_inserted = n_inserted + 1;

            fprintf('  Inserted %s at sample %d (t_grasp=%.2fs)\n', label, lat_grasp, grasp_t);
        end
    end

    fprintf('  Total events inserted: %d\n', n_inserted);

    EEG = eeg_checkset(EEG, 'eventconsistency');
    EEG = pop_saveset(EEG, 'filename', [subject '_Task2_graspERD_events.set'], 'filepath', base_path);
    eeglab redraw;
end