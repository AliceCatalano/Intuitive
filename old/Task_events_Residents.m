clear, clc, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task';
mat_path   = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IR.mat';

subjects = {'IR02','IR04','IR05','IR06','IR07','IR08','IR09','IR10''IR11','IR12','IR13','IR14','IR16','IR17', ...
            'IR18','IR19','IR21','IR22','IR23','IR24','IR25'};

NUM_SCENARIOS = 6;
NUM_TRIALS    = 10;
NUM_SUTURES   = 4;

T = load(mat_path);
EntryTimes = T.EntryTimes;   % [21 x 6 x 10 x 4]
ExitTimes  = T.ExitTimes;    % [21 x 6 x 10 x 4]

for s = 1:length(subjects)
    subject = subjects{s};
    fprintf('\n=== %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_afterICA.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');
    EEG = eeg_checkset(EEG);

    for sc = 1:NUM_SCENARIOS
        for tr = 1:NUM_TRIALS

            nomeMS = sprintf('MS%d_%d', sc, tr);
            nomeS  = sprintf('S%d_%d',  sc, tr);

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
                        fprintf('  %s not found, using %s as fallback\n', nomeMS, nomeS);
                        break;
                    end
                end
            end

            if isempty(msLatency)
                all_nan = all(isnan(squeeze(EntryTimes(s, sc, tr, :))));
                if ~all_nan
                    warning('No anchor for %s Sc%d Tr%d but EntryTimes not NaN', subject, sc, tr);
                end
                continue;
            end

            for pt = 1:NUM_SUTURES
                tIn  = EntryTimes(s, sc, tr, pt);
                tOut = ExitTimes(s,  sc, tr, pt);

                if isnan(tIn) || isnan(tOut), continue; end

                latIn  = msLatency + round(tIn  * EEG.srate);
                latOut = msLatency + round(tOut * EEG.srate);

                if latIn > EEG.pnts || latOut > EEG.pnts
                    warning('Latency out of range: %s Sc%d Tr%d Pt%d', subject, sc, tr, pt);
                    continue;
                end

                labelIn  = sprintf('In_S%d_T%d_P%d',  sc, tr, pt);
                labelOut = sprintf('Out_S%d_T%d_P%d', sc, tr, pt);

                nEv = length(EEG.event) + 1;
                EEG.event(nEv).type     = labelIn;
                EEG.event(nEv).latency  = latIn;
                EEG.event(nEv).duration = 0;
                EEG.event(nEv).urevent  = nEv;

                nEv = length(EEG.event) + 1;
                EEG.event(nEv).type     = labelOut;
                EEG.event(nEv).latency  = latOut;
                EEG.event(nEv).duration = 0;
                EEG.event(nEv).urevent  = nEv;
            end
        end
    end

    EEG = eeg_checkset(EEG, 'eventconsistency');
    EEG = pop_saveset(EEG, 'filename', [subject '_IR_events.set'], 'filepath', base_path);
    fprintf('  Saved %s_IR_events.set\n', subject);
    eeglab redraw;
end