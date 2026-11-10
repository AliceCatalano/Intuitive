% Task2_ExpEvents_ExitERS.m
% Inserts one event per valid exit time per suture point per repetition:
%   'Ext%d_R%02d' (point, rep) at the needle exit time.
% This is the anchor for the ERS epoch [-2, 0]s.
% Reads:  IE_Task/*_Task2_graspERD_events.set
%         DataStructures/ExitERS_Times_IE_T2.mat
% Writes: IE_Task/*_Task2_exitERS_events.set

clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2';
mat_path  = '/home/acatalano/Desktop/Intuitive/DataStructures/ExitERS_Times_IE_T2.mat';

% Exclusions: {subject, rep_number}
EXCL_REP = {'IE03', 10; 'IE05', 9; 'IE07', 15; 'IE10', 4};

E = load(mat_path);
ValidExitTimes = E.ValidExitTimes;  % (subjects x reps x sutures)

NUM_REPS    = 20;
NUM_SUTURES = 4;

for s = 1:length(subjects)
    subject = subjects{s};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_Task2_graspERD_events.set'], 'filepath', base_path);
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

        % Find repetition marker
        nomeMS = sprintf('MS%d', rep);
        nomeS  = sprintf('R%d',  rep);

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
            fprintf('  %s Rep%02d: no MR/R marker found, skip\n', subject, rep);
            continue;
        end

        for pt = 1:NUM_SUTURES
            exit_t = ValidExitTimes(s, rep, pt);
            if isnan(exit_t), continue; end

            lat_exit = msLatency + round(exit_t * EEG.srate);

            if lat_exit < 1 || lat_exit > EEG.pnts
                fprintf('  %s Rep%02d Pt%d: exit latency out of range, skip\n', ...
                    subject, rep, pt);
                continue;
            end

            % Check boundary inside ERS epoch window [-2, 0]s
            epoch_start  = lat_exit - round(2.0 * EEG.srate);
            epoch_end    = lat_exit;
            has_boundary = false;
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, 'boundary') && ...
                   EEG.event(ev).latency >= epoch_start && ...
                   EEG.event(ev).latency <= epoch_end
                    has_boundary = true; break;
                end
            end
            if has_boundary
                fprintf('  %s Rep%02d Pt%d: boundary inside ERS window, skip\n', ...
                    subject, rep, pt);
                continue;
            end

            label = sprintf('Ext%d_R%02d', pt, rep);
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
    EEG = pop_saveset(EEG, 'filename', [subject '_Task2_exitERS_events.set'], 'filepath', base_path);
    eeglab redraw;
end