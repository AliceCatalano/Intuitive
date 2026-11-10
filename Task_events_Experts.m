clear, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};
base_path = '/home/acatalano/Desktop/Intuitive/IE_Task/';
load('/home/acatalano/Desktop/Intuitive/Tapered_CleanedMatrix_IE_20_10subj.mat');


nSubj = length(subjects);
nReps = 20;

for subj = 1:nSubj

    subject = subjects{subj};
    fprintf('\n=== Subject %s ===\n', subject);

    EEG = pop_loadset('filename', [subject 'Task2_final.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');
    EEG = eeg_checkset(EEG);

    for scena = 1:nReps

        nomeMS = sprintf('MS%d', scena);
        nomeS  = sprintf('S%d',  scena);
       
        % --- Trova la latenza dell'evento di riferimento (MS, poi S come fallback)
        msLatency = [];
        for ev = 1:length(EEG.event)
            if strcmp(EEG.event(ev).type, nomeMS)
                msLatency = EEG.event(ev).latency;

                scenaFound = regexp(EEG.event(ev).type,'\d+','match');
                scenaFound = str2double(scenaFound{1});
                fprintf('Soggetto %d: %s trovato, uso come riferimento\n', subj, nomeMS);
                break;
            end
        end

        if isempty(msLatency)
            for ev = 1:length(EEG.event)
                if strcmp(EEG.event(ev).type, nomeS)
                    msLatency = EEG.event(ev).latency;
                    fprintf('Soggetto %d: %s non trovato, uso %s come fallback\n', subj, nomeMS, nomeS);
                    break;
                end
            end
        end

        if isempty(msLatency)
            fprintf('Soggetto %d: %s e %s non trovati ',subj, nomeMS, nomeS);
            continue;
           
        end

        % --- Controlla che la latenza sia nei limiti dell'EEG
        if msLatency > EEG.pnts
            warning('Latenza fuori range per Soggetto %d, Scena %d', subj, scena);
            continue;
        end

        % --- Crea UN evento di start per la scena, alla latenza del marker MS/S
        labelStart = sprintf('Start_S%d', scenaFound);

        nEv = length(EEG.event) + 1;
        EEG.event(nEv).type     = labelStart;
        EEG.event(nEv).latency  = msLatency;
        EEG.event(nEv).duration = 0;
        EEG.event(nEv).urevent  = nEv;


    end % fine loop scene

    % Riscalcola ureventi e controlla consistenza
    EEG = eeg_checkset(EEG, 'eventconsistency');

    % Salva EEG aggiornato
    EEG = pop_saveset(EEG, 'filename', [subject '_Task2_events.set'], 'filepath', base_path);
    eeglab redraw;

end