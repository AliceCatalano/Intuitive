clear, clc, close all
restoredefaultpath;
addpath '/home/acatalano/Documents/MATLAB/fieldtrip-20250106';
ft_defaults;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

base_path = '/home/acatalano/Desktop/Intuitive/IR_Task';

subjects = {'IR02','IR04','IR05','IR06','IR07','IR08','IR09','IR10','IR11','IR12','IR13','IR14','IR16','IR17',...
            'IR18','IR19','IR21','IR22','IR23','IR24','IR25'};

NUM_SCENARIOS = 6;
NUM_TRIALS    = 10;
NUM_SUTURES   = 4;
NUM_SLOTS     = NUM_SCENARIOS * NUM_TRIALS * NUM_SUTURES;  % 240

slot_idx = @(sc, tr, pt) (sc-1)*NUM_TRIALS*NUM_SUTURES + (tr-1)*NUM_SUTURES + pt;

win_grasp = [-0.8  1.5];
win_exit  = [-2.5  0.5];

for s = 1:length(subjects)
    subject = subjects{s};
    fprintf('\n=== %s ===\n', subject);

    EEG = pop_loadset('filename', [subject '_IR_events.set'], 'filepath', base_path);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', subject, 'gui', 'off');
    EEG = eeg_checkset(EEG);

    nChan = EEG.nbchan;

    % collect all In and Out labels that exist in this dataset
    all_types = {EEG.event.type};

    in_labels  = {};
    out_labels = {};

    for sc = 1:NUM_SCENARIOS
        for tr = 1:NUM_TRIALS
            for pt = 1:NUM_SUTURES
                lin  = sprintf('In_S%d_T%d_P%d',  sc, tr, pt);
                lout = sprintf('Out_S%d_T%d_P%d', sc, tr, pt);
                if any(strcmp(all_types, lin)),  in_labels{end+1}  = lin;  end
                if any(strcmp(all_types, lout)), out_labels{end+1} = lout; end
            end
        end
    end

    fprintf('  Found %d In events and %d Out events\n', numel(in_labels), numel(out_labels));

    % epoch around grasp onset (In events)
    if ~isempty(in_labels)
        EEG_grasp = pop_epoch(EEG, in_labels, win_grasp, 'newname', [subject '_grasp'], 'epochinfo', 'yes');
    else
        warning('%s: no In events found', subject);
        continue;
    end

    % epoch around needle exit (Out events)
    if ~isempty(out_labels)
        EEG_exit = pop_epoch(EEG, out_labels, win_exit, ...
            'newname', [subject '_exit'], 'epochinfo', 'yes');
    else
        warning('%s: no Out events found', subject);
        continue;
    end

    pop_saveset(EEG_grasp, 'filename', [subject '_IR_grasp_epochs.set'], 'filepath', base_path);
    pop_saveset(EEG_exit,  'filename', [subject '_IR_exit_epochs.set'],  'filepath', base_path);
    fprintf('  Saved epoch sets\n');
    eeglab redraw;
end