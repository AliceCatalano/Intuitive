% InsertInOutEvents_RawVHDR_MultiRep.m
%
% Anchors each repetition using the "S%d" scene-start trigger from the
% downsampled+filtered dataset (confirmed to correspond to t=0 of the
% needle-tracking CSV for that repetition). Converts to real elapsed
% time, maps to the raw (1000 Hz) recording, and inserts "In"/"Out"
% events for all repetitions/points. Raw signal itself is untouched.

clear; clc; close all;
restoredefaultpath;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab;

%% ============================================================
%  USER INPUT
% ===============================================================
rawFilePath = '/home/acatalano/Downloads/IE03_Task2.vhdr';
subjectID   = 'IE03';

dsFilePath = '/home/acatalano/Downloads';
dsFileName = 'IE03_Task2_events_correct.set';

matFile = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE_T2.mat';

repMarkerPattern = 'S%d';   % CONFIRMED: scene-start trigger = CSV time zero
NUM_REPETITIONS  = 20;
NUM_SUTURES      = 4;

sceneEndPattern  = 'ME%d';
NUM_REPS_TO_KEEP = 5;

preBuffer  = 5;   % seconds of padding BEFORE rep 1's S marker
postBuffer = 5;   % seconds of padding AFTER rep 5's ME marker

%% ============================================================
%  LOAD RAW RECORDING (full, untouched)
% ===============================================================
[fPath, fName, fExt] = fileparts(rawFilePath);
EEG = pop_loadbv(fPath, [fName fExt]);
EEG = eeg_checkset(EEG);
fprintf('Raw: %d Hz, %d samples, %.1f s\n', EEG.srate, EEG.pnts, EEG.xmax-EEG.xmin);

%% ============================================================
%  LOAD DOWNSAMPLED+FILTERED DATASET (for S%d / ME%d anchors)
% ===============================================================
EEG_ds = pop_loadset('filename', dsFileName, 'filepath', dsFilePath);
fprintf('Downsampled: %d Hz, %d samples, xmin=%.3f s\n', EEG_ds.srate, EEG_ds.pnts, EEG_ds.xmin);

%% ============================================================
%  LOAD ALREADY-COMPUTED ENTRY/EXIT TIMES
% ===============================================================
load(matFile);  % EntryTimes, ExitTimes, subjects
subjIdx = find(strcmp(subjects, subjectID));
if isempty(subjIdx)
    error('Subject "%s" not found in %s', subjectID, matFile);
end

%% ============================================================
%  HELPER: get elapsed seconds (since raw recording start) for a
%  given marker label in the downsampled dataset
% ===============================================================
function elapsed_sec = get_elapsed_time(EEG_ds, markerLabel)
    lat = [];
    for ev = 1:length(EEG_ds.event)
        if strcmp(EEG_ds.event(ev).type, markerLabel)
            lat = EEG_ds.event(ev).latency;
            break;
        end
    end
    if isempty(lat)
        elapsed_sec = NaN;
        return;
    end
    elapsed_sec = (lat - 1) / EEG_ds.srate + EEG_ds.xmin;
end

%% ============================================================
%  FIND CROP WINDOW: from S1 (minus buffer) to ME5 (plus buffer)
% ===============================================================
t_S1  = get_elapsed_time(EEG_ds, sprintf(repMarkerPattern, 1));
t_ME5 = get_elapsed_time(EEG_ds, sprintf(sceneEndPattern, NUM_REPS_TO_KEEP));

if isnan(t_S1) || isnan(t_ME5)
    error('Could not find S1 or ME%d marker - check marker naming.', NUM_REPS_TO_KEEP);
end

cropStart_sec = max(0, t_S1 - preBuffer);
cropEnd_sec   = min(EEG.xmax, t_ME5 + postBuffer);

fprintf('Crop window: %.2fs to %.2fs (S1=%.2fs, ME%d=%.2fs)\n', ...
        cropStart_sec, cropEnd_sec, t_S1, NUM_REPS_TO_KEEP, t_ME5);

%% ============================================================
%  CROP THE RAW RECORDING
% ===============================================================
cropStart_sample = round((cropStart_sec - EEG.xmin) * EEG.srate) + 1;
cropEnd_sample   = round((cropEnd_sec   - EEG.xmin) * EEG.srate) + 1;

EEG_crop = pop_select(EEG, 'point', [cropStart_sample cropEnd_sample]);
EEG_crop = eeg_checkset(EEG_crop);

fprintf('Cropped raw: %d samples, %.2f s\n', EEG_crop.pnts, EEG_crop.xmax - EEG_crop.xmin);

% IMPORTANT: pop_select resets xmin to 0 and re-indexes latencies
% starting from 1 at the new crop start. All further latency math
% must be relative to this NEW timeline.

%% ============================================================
%  INSERT "In"/"Out" EVENTS FOR REPETITIONS 1-5 ONLY
% ===============================================================
n_inserted = 0;

for rep = 1:NUM_REPS_TO_KEEP

    markerLabel = sprintf(repMarkerPattern, rep);
    t_rep_start_absolute = get_elapsed_time(EEG_ds, markerLabel);  % seconds, original raw timeline

    if isnan(t_rep_start_absolute)
        fprintf('Rep %02d: marker "%s" not found - skip.\n', rep, markerLabel);
        continue;
    end

    % Convert to sample index in the CROPPED timeline
    rep_start_sample_crop = round((t_rep_start_absolute - cropStart_sec) * EEG_crop.srate) + 1;

    if rep_start_sample_crop < 1 || rep_start_sample_crop > EEG_crop.pnts
        warning('Rep %02d: start sample falls outside cropped data - skip.', rep);
        continue;
    end

    fprintf('Rep %02d: %s absolute=%.2fs -> cropped sample=%d\n', ...
            rep, markerLabel, t_rep_start_absolute, rep_start_sample_crop);

    for pt = 1:NUM_SUTURES
        entry_t = EntryTimes(subjIdx, rep, pt);
        exit_t  = ExitTimes(subjIdx, rep, pt);

        if ~isnan(entry_t)
            lat_in = rep_start_sample_crop + round(entry_t * EEG_crop.srate);
            if lat_in >= 1 && lat_in <= EEG_crop.pnts
                nEv = length(EEG_crop.event) + 1;
                EEG_crop.event(nEv).type     = 'In';
                EEG_crop.event(nEv).latency  = lat_in;
                EEG_crop.event(nEv).duration = 0;
                n_inserted = n_inserted + 1;
            end
        end

        if ~isnan(exit_t)
            lat_out = rep_start_sample_crop + round(exit_t * EEG_crop.srate);
            if lat_out >= 1 && lat_out <= EEG_crop.pnts
                nEv = length(EEG_crop.event) + 1;
                EEG_crop.event(nEv).type     = 'Out';
                EEG_crop.event(nEv).latency  = lat_out;
                EEG_crop.event(nEv).duration = 0;
                n_inserted = n_inserted + 1;
            end
        end
    end
end

fprintf('\nTotal events inserted: %d (expected up to %d)\n', n_inserted, NUM_REPS_TO_KEEP*NUM_SUTURES*2);

if n_inserted == 0
    error('No events were inserted - check marker pattern and sync assumptions.');
end

EEG_crop = eeg_checkset(EEG_crop, 'eventconsistency');

%% ============================================================
%  SAVE AS .vhdr
% ===============================================================
if isempty(which('pop_writebva'))
    error('pop_writebva not found - install the bva-io EEGLAB plugin.');
end

outName = [fName sprintf('_first%dreps_withInOutEvents', NUM_REPS_TO_KEEP)];
pop_writebva(EEG_crop, fullfile(fPath, outName));
fprintf('Saved: %s.vhdr/.vmrk/.eeg\n', fullfile(fPath, outName));

pop_eegplot(EEG_crop, 1, 1, 1);