% Task1_ExpEvents_GraspERD.m
% Inserts one event per valid suture point per scenario into the EEG:
%   'GraspERD_S%d_P%d' at the time of the last grasp before needle entry.
% This event is the anchor for the ERD epoch [-0.5, +1s].
% Reads:  IE_Task/*_Task1_events.set  (already has Start_S events)
%         DataStructures/GraspERD_Times_IE.mat
% Writes: IE_Task/*_Task1_graspERD_events.set

clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects     = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path    = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
mat_path     = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IE.mat';

EXCL_SCENARIO = {'IE02', [1 4]; 'IE10', 6};

G = load(mat_path);
LastGraspBeforeEntry = G.LastGraspBeforeEntry;

NUM_SCENARIOS = 6;
NUM_SUTURES   = 4;

for s = 1:length(subjects)
    subject = subjects{s};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject 'Task1_final.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');
    EEG = eeg_checkset(EEG);

    n_inserted = 0;

    for sc = 1:NUM_SCENARIOS

        excl_scn = false;
        for e = 1:size(EXCL_SCENARIO,1)
            if strcmp(subject, EXCL_SCENARIO{e,1}) && ismember(sc, EXCL_SCENARIO{e,2})
                excl_scn = true; break;
            end
        end
        if excl_scn
            fprintf('  %s Scn%d: excluded, skip\n', subject, sc);
            continue;
        end

        nomeMS = sprintf('MS%d', sc);
        nomeS  = sprintf('S%d',  sc);

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
            fprintf('  %s Scn%d: no MS/S marker found, skip\n', subject, sc);
            continue;
        end

        for pt = 1:NUM_SUTURES
            grasp_t = LastGraspBeforeEntry(s, sc, pt);

            if isnan(grasp_t)
                continue;
            end

            lat_grasp = msLatency + round(grasp_t * EEG.srate);

            if lat_grasp < 1 || lat_grasp > EEG.pnts
                fprintf('  %s Scn%d Pt%d: grasp latency %.0f out of range, skip\n', subject, sc, pt, lat_grasp);
                continue;
            end

            has_boundary = false;
            epoch_start  = lat_grasp - round(0.5 * EEG.srate);
            epoch_end    = lat_grasp + round(1.0 * EEG.srate);
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, 'boundary') && ...
                   EEG.event(ev).latency >= epoch_start && ...
                   EEG.event(ev).latency <= epoch_end
                    has_boundary = true;
                    break;
                end
            end
            if has_boundary
                fprintf('  %s Scn%d Pt%d: boundary inside epoch window, skip\n', subject, sc, pt);
                continue;
            end

            label = sprintf('G%d_S%d',pt, sc);
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
    EEG = pop_saveset(EEG, 'filename', [subject '_Task1_graspERD_events.set'], 'filepath', base_path);
    eeglab redraw;
end