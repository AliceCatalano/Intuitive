% Task1_ExpEvents_ExitERS.m
% Inserts one event per valid exit time per suture point per scenario:
%   'E%d_S%d' (point, scenario) at the needle exit time.
% This is the anchor for the ERS epoch [-2, 0]s.
% Reads:  IE_Task/*_Task2_graspERD_events.set
%         DataStructures/ExitERS_Times_IE.mat
% Writes: IE_Task/*_Task2_exitERS_events.set

clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects      = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path     = '/home/acatalano/Desktop/Intuitive/IE_Task/IE_sixRep_behav/EEG';
mat_path      = '/home/acatalano/Desktop/Intuitive/DataStructures/ExitERS_Times_IE.mat';

EXCL_SCENARIO = {'IE02', [1 4]; 'IE10', 6};

E = load(mat_path);
ValidExitPunctureMatrixTimes = E.ValidExitPunctureMatrix;

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
            fprintf('  %s Scn%d: excluded\n', subject, sc);
            continue;
        end

        nomeMS = sprintf('MS%d', sc);
        nomeS  = sprintf('S%d',  sc);
        msLatency = [];
        for ev = 1:length(EEG.event)
            if strcmp(EEG.event(ev).type, nomeMS)
                msLatency = EEG.event(ev).latency; break;
            end
        end
        if isempty(msLatency)
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, nomeS)
                    msLatency = EEG.event(ev).latency; break;
                end
            end
        end
        if isempty(msLatency)
            fprintf('  %s Scn%d: no MS/S marker, skip\n', subject, sc);
            continue;
        end

        for pt = 1:NUM_SUTURES
            exit_t = ValidExitPunctureMatrixTimes(s, sc, pt);
            if isnan(exit_t), continue; end

            lat_exit = msLatency + round(exit_t * EEG.srate);

            if lat_exit < 1 || lat_exit > EEG.pnts
                fprintf('  %s Scn%d Pt%d: exit latency out of range, skip\n', subject, sc, pt);
                continue;
            end

            % Check boundary inside ERS epoch window [-2, 0]s
            epoch_start = lat_exit - round(2.0 * EEG.srate);
            epoch_end   = lat_exit;
            has_boundary = false;
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, 'boundary') && ...
                   EEG.event(ev).latency >= epoch_start && ...
                   EEG.event(ev).latency <= epoch_end
                    has_boundary = true; break;
                end
            end
            if has_boundary
                fprintf('  %s Scn%d Pt%d: boundary inside ERS window, skip\n', subject, sc, pt);
                continue;
            end

            label = sprintf('Ext%d_S%d', pt, sc);
            nEv = length(EEG.event) + 1;
            EEG.event(nEv).type     = label;
            EEG.event(nEv).latency  = lat_exit;
            EEG.event(nEv).duration = 0;
            EEG.event(nEv).urevent  = nEv;
            n_inserted = n_inserted + 1;

            fprintf('  Inserted %s at sample %d (t_exit=%.2fs)\n', label, lat_exit, exit_t);
        end
    end

    fprintf('  Total events inserted: %d\n', n_inserted);
    EEG = eeg_checkset(EEG, 'eventconsistency');
    EEG = pop_saveset(EEG, 'filename', [subject '_Task1_exitERS_events.set'], 'filepath', base_path);
    eeglab redraw;
end