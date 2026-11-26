
% claude_IR_nofilt_preprocess.m
% Residents whose dataset has no band-pass filter (IR_Task/EEG_alice/EEG_alice/IR##).
% 1) Header-only check of every subject: sampling rate must be 250 Hz (report only).
% 2) Usual preprocessing: resample to 250 Hz (only if needed), 45-50 Hz notch, 2-40 Hz band-pass,
%    save <name>_downS_filt.set in the subject folder.
% Input file per subject: *_events_correct.set if present, otherwise *_events.set
%   (see "EEG Events corretti.md"); if no .set exists (IR04) the BrainVision .vhdr is loaded.

clear; clc;
restoredefaultpath;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

baseFolderPath = '/home/acatalano/Desktop/Intuitive/IR_Task/EEG_alice/EEG_alice';
targetSrate    = 250;

d = dir(fullfile(baseFolderPath, 'IR*'));
d = d([d.isdir]);
subjects = {d.name};

%% ---- 1) pick input file per subject and verify sampling rate ----
inFile = cell(size(subjects));  isBV = false(size(subjects));  srate0 = nan(size(subjects));
fprintf('\n%-6s %-34s %8s %6s %s\n', 'ID', 'file', 'srate', 'nch', 'status');
for i = 1:numel(subjects)
    folder = fullfile(baseFolderPath, subjects{i});
    f = dir(fullfile(folder, '*_events_correct.set'));
    if isempty(f), f = dir(fullfile(folder, '*_events.set')); end
    if ~isempty(f)
        inFile{i} = f(1).name;
        h = pop_loadset('filename', inFile{i}, 'filepath', folder, 'loadmode', 'info');
    else
        f = dir(fullfile(folder, '*.vhdr'));
        if isempty(f)
            fprintf('%-6s no usable file found\n', subjects{i});  continue
        end
        inFile{i} = f(1).name;  isBV(i) = true;
        h = pop_loadbv(folder, inFile{i});
    end
    srate0(i) = h.srate;
    if h.srate == targetSrate, st = 'already downsampled';
    else,                      st = sprintf('NOT downsampled -> will resample to %d Hz', targetSrate); end
    fprintf('%-6s %-34s %8g %6d %s\n', subjects{i}, inFile{i}, h.srate, h.nbchan, st);
end

%% ---- 2) preprocessing ----
for i = 1:numel(subjects)
    if isempty(inFile{i}), continue; end
    subject = subjects{i};
    folder  = fullfile(baseFolderPath, subject);
    [~, base] = fileparts(inFile{i});

    if isBV(i)
        EEG = pop_loadbv(folder, inFile{i});
    else
        EEG = pop_loadset('filename', inFile{i}, 'filepath', folder);
    end

    if EEG.srate ~= targetSrate
        EEG = pop_resample(EEG, targetSrate);
    end
    EEG = pop_eegfiltnew(EEG, 45, 50, [], 1, [], 0);   % notch 45-50 Hz
    EEG = pop_eegfiltnew(EEG, 2, 40, [], 0, [], 0);    % band-pass 2-40 Hz

    outName = [base '_downS_filt.set'];
    EEG = pop_saveset(EEG, 'filename', outName, 'filepath', folder);
    fprintf('%s: saved %s (srate %g Hz)\n', subject, outName, EEG.srate);
end
