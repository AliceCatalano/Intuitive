% claude_check_preprocessing_IE_IR.m
% Compares the preprocessing of the two groups before any expert-vs-resident comparison.
% For every dataset it reads only the header (no EEG data) and prints
%   sampling rate, number of channels, reference field, whether the stored EEG.history contains
%   the 2-40 Hz band-pass and the 45-50 Hz notch, the channels removed, ICA.
% Datasets: experts  IE_Task/Task2/IE##Task2_final.set
%           residents IR_Task/ERDS/IR##_afterICA.set
% NOTE: it can only report what is written in EEG.history; a step done outside EEGLAB (or in a file that was
% later re-saved without it) will not appear.

clear; clc;
restoredefaultpath;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

groups(1).name = 'EXPERTS (Task 2)';  groups(1).path = '/home/acatalano/Desktop/Intuitive/IE_Task/Task2/';
groups(1).files = dir([groups(1).path 'IE*Task2_final.set']);
groups(2).name = 'RESIDENTS';          groups(2).path = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS/';
groups(2).files = dir([groups(2).path 'IR*_afterICA.set']);

for g = 1:numel(groups)
    fprintf('\n=== %s ===\n', groups(g).name);
    fprintf('%-6s %5s %4s %-8s %-9s %-9s %-34s %s\n', 'ID', 'srate', 'nch', 'ref', 'bandpass', 'notch', 'removed channels', 'ICA');
    nBand = 0;   nTot = numel(groups(g).files);
    for k = 1:nTot
        fn  = groups(g).files(k).name;
        EEG = pop_loadset('filename', fn, 'filepath', groups(g).path, 'loadmode', 'info');
        h   = EEG.history;
        hasBP    = ~isempty(regexp(h, 'locutoff''\s*,\s*2\s*,\s*''hicutoff''\s*,\s*40', 'once'));
        hasNotch = ~isempty(regexp(h, 'locutoff''\s*,\s*45\s*,\s*''hicutoff''\s*,\s*50', 'once'));
        rm  = regexp(h, '''rmchannel''\s*,\s*\{([^}]*)\}', 'tokens');
        rmStr = strjoin(cellfun(@(c) strrep(c{1}, '''', ''), rm, 'UniformOutput', false), ' | ');
        ica = ~isempty(regexp(h, 'pop_runica', 'once'));
        fprintf('%-6s %5g %4d %-8s %-9s %-9s %-34s %s\n', fn(1:4), EEG.srate, EEG.nbchan, EEG.ref, ...
            ternary(hasBP, 'yes', 'NO'), ternary(hasNotch, 'yes', 'NO'), rmStr, ternary(ica, 'yes', 'NO'));
        nBand = nBand + hasBP;
    end
    fprintf('band-pass 2-40 Hz recorded for %d of %d datasets\n', nBand, nTot);
end

function out = ternary(c, x, y)
    if c, out = x; else, out = y; end
end
