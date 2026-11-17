% claude_Task_events_Residents_v2.m
% Inserts events into the continuous resident EEG and saves TWO datasets per
% resident, to be epoched separately:
%   <subj>_IR_graspERD_events.set : Grasp_S#_T#_P#  last grasp start before needle
%                                                   entry (claude_ERDgrasp_Times_Res.m)
%   <subj>_IR_exitERS_events.set  : Ext_S#_T#_P#    validated needle exit
%                                                   (claude_ExitERS_Times_Res.m)
% Each dataset contains ONLY its own new events (events of previous runs / old
% scripts are removed from both).
% Replaces the old Task_events_Residents.m (kept untouched).
%
% EEG markers per repetition (continuous recording, never interrupted):
%   S<sc>_<rep>   system event: simulation launched      (NOT used as time zero)
%   MS<sc>_<rep>  keyboard: subject got the "go"         (time zero of the behaviour)
%   ME<sc>_<rep>  simulation end
%
% Behavioural times (grasp, exit) are seconds from MS.
%
% A repetition receives events ONLY if all of these hold:
%   1) it is valid in the claude_ERDgrasp_Times_Res.m / claude_ExitERS_Times_Res.m output
%      (skip list applied: skipped repetitions are NaN there)
%   2) both MS and ME exist in the EEG for that scenario/repetition
%      (no fallback to S: S is ~30 s before the real start)
%   3) the EEG duration (ME - MS) agrees with the behavioural duration RepDur
%      within DUR_TOL seconds. This catches marker numbers that do not belong
%      to the behavioural repetition (renumbering after skipped repetitions).
%   4) none of its events falls outside MS-ME (alignment check). The decision is
%      taken for the repetition as a whole, so both datasets always use the
%      same repetitions.
%
% Boundary events mark data removed from the recording. Times are converted to
% EEG samples by subtracting the removed samples lying between MS and the event.
%
% NaN grasp/exit values inside a valid repetition are legitimate (point not
% completed, exit target missed): that single event is just not inserted.
% An Ext event is also not inserted when a boundary (removed data) falls inside
% the exit-ERS epoch window ERS_WIN around it.
%
% Output log: EventInsertion_Log_IR.mat (every repetition not used, and why)

clear; clc; close all
restoredefaultpath;
addpath '/home/acatalano/Matlab/eeglab_current/eeglab2026.0.0';
eeglab nogui;

base_path  = '/home/acatalano/Desktop/Intuitive/IR_Task/ERDS';
times_file = '/home/acatalano/Desktop/Intuitive/DataStructures/GraspERD_Times_IR.mat';
exit_file  = '/home/acatalano/Desktop/Intuitive/DataStructures/ExitERS_Times_IR.mat';
log_file   = '/home/acatalano/Desktop/Intuitive/DataStructures/EventInsertion_Log_IR.mat';

EEG_IN_SUFFIX    = '_afterICA.set';              % input  : <subj><suffix>
GRASP_OUT_SUFFIX = '_IR_graspERD_events.set';    % output : grasp events only
EXIT_OUT_SUFFIX  = '_IR_exitERS_events.set';     % output : exit events only

NUM_SCENARIOS = 6;
NUM_TRIALS    = 10;
NUM_SUTURES   = 4;

DUR_TOL        = 5;     % s, max |EEG duration - behavioural duration - DUR_OFFSET|
DUR_OFFSET     = 1.1;   % s, typical (ME-MS) minus needle-stream duration
REQUIRE_DUR    = false; % true: also drop repetitions with no RepDur (no grasp file)
POST_ME_MARGIN = 1;     % s, events later than ME + margin are rejected
ERS_WIN        = [-2.5 0.5];   % s, exit epoch window (same as Task_Res_epoching.m win_exit)

T = load(times_file);
X = load(exit_file);
subjects  = T.subjects;
if ~isequal(X.subjects(:), subjects(:))
    error('Subject lists differ between %s and %s', times_file, exit_file);
end
GraspT    = T.LastGraspBeforeEntry;   % [nSubj x 6 x 10 x 4]
ValidExit = X.ValidExitTimes;         % [nSubj x 6 x 10 x 4] validated exits
RepDur    = T.RepDur;                 % [nSubj x 6 x 10]

LOG = {};   % {subject, sc, rep, reason}

for s = 1:numel(subjects)
    subject = subjects{s};
    fprintf('\n=== %s ===\n', subject);

    in_file = fullfile(base_path, [subject EEG_IN_SUFFIX]);
    if ~exist(in_file, 'file')
        warning('%s: input file not found (%s)', subject, in_file);
        LOG(end+1,:) = {subject, NaN, NaN, 'EEG file not found'}; %#ok<SAGROW>
        continue;
    end

    EEG = pop_loadset('filename', [subject EEG_IN_SUFFIX], 'filepath', base_path);
    EEG = eeg_checkset(EEG);
    sr  = EEG.srate;

    % remove events inserted by previous runs / old scripts
    types  = event_types(EEG);
    isOld  = ~cellfun(@isempty, regexp(types, '^(In|Out|Grasp|Ext)_S\d+_T\d+_P\d+$', 'once'));
    EEG.event(isOld) = [];
    types  = event_types(EEG);

    % removed-data gaps (boundary events with a duration)
    isB  = strcmp(types, 'boundary');
    bLat = arrayfun(@(e) num_or_nan(e.latency),  EEG.event(isB));
    bDur = arrayfun(@(e) num_or_nan(e.duration), EEG.event(isB));
    ok   = ~isnan(bLat) & ~isnan(bDur) & bDur > 0;
    bLat = bLat(ok); bDur = bDur(ok);
    [bLat, ord] = sort(bLat); bDur = bDur(ord);

    grEv = struct('type', {}, 'latency', {}, 'duration', {});   % grasp dataset
    exEv = struct('type', {}, 'latency', {}, 'duration', {});   % exit dataset
    nGr = 0; nExt = 0; nRep = 0;

    for sc = 1:NUM_SCENARIOS
        for tr = 1:NUM_TRIALS

            grasp = squeeze(GraspT(s,sc,tr,:))';
            exitv = squeeze(ValidExit(s,sc,tr,:))';

            % 1) skipped / never performed / nothing usable -> nothing to insert
            if all(isnan(grasp)) && all(isnan(exitv))
                continue;
            end

            % 2) MS and ME markers
            msAll = [EEG.event(strcmp(types, sprintf('MS%d_%d', sc, tr))).latency];
            meAll = [EEG.event(strcmp(types, sprintf('ME%d_%d', sc, tr))).latency];
            if isempty(msAll) || isempty(meAll)
                LOG(end+1,:) = {subject, sc, tr, sprintf('no %s%s marker', ...
                    tern(isempty(msAll),'MS ',''), tern(isempty(meAll),'ME',''))}; %#ok<SAGROW>
                fprintf('  Sc%d Rep%02d: MS/ME missing -> no events\n', sc, tr);
                continue;
            end
            meSel = meAll(end);
            msSel = max(msAll(msAll < meSel));
            if isempty(msSel)
                LOG(end+1,:) = {subject, sc, tr, 'MS after ME'}; %#ok<SAGROW>
                fprintf('  Sc%d Rep%02d: MS after ME -> no events\n', sc, tr);
                continue;
            end
            if numel(msAll) > 1 || numel(meAll) > 1
                fprintf('  Sc%d Rep%02d: duplicate MS/ME markers (using last MS before last ME)\n', sc, tr);
            end

            % 3) duration check against the behavioural duration
            gaps   = sum(bDur(bLat > msSel & bLat <= meSel));
            eegDur = (meSel - msSel + gaps) / sr;
            behDur = RepDur(s,sc,tr);
            unverified = false;
            if isnan(behDur)
                if REQUIRE_DUR
                    LOG(end+1,:) = {subject, sc, tr, 'no behavioural duration (no grasp file)'}; %#ok<SAGROW>
                    fprintf('  Sc%d Rep%02d: cannot verify duration -> no events\n', sc, tr);
                    continue;
                end
                unverified = true;      % logged below only if the repetition is kept
            else
                err = eegDur - behDur - DUR_OFFSET;
                if abs(err) > DUR_TOL
                    LOG(end+1,:) = {subject, sc, tr, sprintf('duration mismatch: EEG %.1f s vs behaviour %.1f s', eegDur, behDur)}; %#ok<SAGROW>
                    fprintf('  Sc%d Rep%02d: duration mismatch (EEG %.1f s, behaviour %.1f s) -> no events\n', ...
                        sc, tr, eegDur, behDur);
                    continue;
                end
            end

            % 4) build the events of this repetition (both datasets)
            repGr  = struct('type', {}, 'latency', {}, 'duration', {});
            repEx  = struct('type', {}, 'latency', {}, 'duration', {});
            repLog = {};
            repBad = '';
            for pt = 1:NUM_SUTURES
                % grasp
                if ~isnan(grasp(pt))
                    name = sprintf('Grasp_S%d_T%d_P%d', sc, tr, pt);
                    lat  = to_eeg_latency(msSel, grasp(pt), bLat, bDur, sr);
                    if lat < 1 || lat > EEG.pnts || lat > meSel + POST_ME_MARGIN*sr
                        repBad = name; break;      % outside the repetition: alignment is wrong
                    end
                    repGr(end+1) = struct('type', name, 'latency', lat, 'duration', 0); %#ok<SAGROW>
                end
                % validated exit
                if ~isnan(exitv(pt))
                    name = sprintf('Ext_S%d_T%d_P%d', sc, tr, pt);
                    lat  = to_eeg_latency(msSel, exitv(pt), bLat, bDur, sr);
                    if lat < 1 || lat > EEG.pnts || lat > meSel + POST_ME_MARGIN*sr
                        repBad = name; break;
                    end
                    w0 = lat + round(ERS_WIN(1)*sr);
                    w1 = lat + round(ERS_WIN(2)*sr);
                    if any(bLat >= w0 & bLat <= w1)
                        repLog(end+1,:) = {subject, sc, tr, sprintf('%s not inserted: boundary inside ERS window', name)}; %#ok<SAGROW>
                    else
                        repEx(end+1) = struct('type', name, 'latency', lat, 'duration', 0); %#ok<SAGROW>
                    end
                end
            end

            % a repetition is inserted completely (in both datasets) or not at all
            if ~isempty(repBad)
                LOG(end+1,:) = {subject, sc, tr, sprintf('%s falls outside MS-ME: markers do not match this repetition', repBad)}; %#ok<SAGROW>
                fprintf('  Sc%d Rep%02d: %s outside MS-ME -> no events\n', sc, tr, repBad);
                continue;
            end
            grEv = [grEv repGr]; %#ok<AGROW>
            exEv = [exEv repEx]; %#ok<AGROW>
            LOG  = [LOG; repLog];
            if unverified
                LOG(end+1,:) = {subject, sc, tr, 'UNVERIFIED duration (events inserted)'}; %#ok<SAGROW>
            end
            nRep = nRep + 1;
            nGr  = nGr  + numel(repGr);
            nExt = nExt + numel(repEx);
        end
    end

    % two datasets, each with only its own events
    EEG_gr = add_events(EEG, grEv);
    EEG_gr.setname = [subject '_IR_graspERD'];
    pop_saveset(EEG_gr, 'filename', [subject GRASP_OUT_SUFFIX], 'filepath', base_path);

    EEG_ex = add_events(EEG, exEv);
    EEG_ex.setname = [subject '_IR_exitERS'];
    pop_saveset(EEG_ex, 'filename', [subject EXIT_OUT_SUFFIX], 'filepath', base_path);

    fprintf('  %d repetitions used | Grasp %d -> %s%s | Ext %d -> %s%s\n', ...
        nRep, nGr, subject, GRASP_OUT_SUFFIX, nExt, subject, EXIT_OUT_SUFFIX);
end

save(log_file, 'LOG');
fprintf('\n=== REPETITIONS / EVENTS NOT USED (OR UNVERIFIED): %d ===\n', size(LOG,1));
for k = 1:size(LOG,1)
    fprintf('  %s Sc%s Rep%s : %s\n', LOG{k,1}, num2str(LOG{k,2}), num2str(LOG{k,3}), LOG{k,4});
end
fprintf('Log saved: %s\n', log_file);


%% Local functions
function EEG = add_events(EEG, evs)
    for k = 1:numel(evs)
        n = length(EEG.event) + 1;
        EEG.event(n).type     = evs(k).type;
        EEG.event(n).latency  = evs(k).latency;
        EEG.event(n).duration = 0;
        EEG.event(n).urevent  = n;
    end
    EEG = eeg_checkset(EEG, 'eventconsistency');
end

function types = event_types(EEG)
    % event types as a cell array of char (non-char types become '')
    types = cell(1, numel(EEG.event));
    for k = 1:numel(EEG.event)
        t = EEG.event(k).type;
        if ischar(t), types{k} = t;
        elseif isstring(t), types{k} = char(t);
        else, types{k} = '';
        end
    end
end

function v = num_or_nan(x)
    if isempty(x) || ~isnumeric(x), v = NaN; else, v = double(x(1)); end
end

function lat = to_eeg_latency(msLat, t, bLat, bDur, sr)
    % t: seconds from MS in the (gap-free) behavioural clock.
    % Boundaries after MS remove recorded time from the EEG sample axis, so the
    % removed samples that precede the target must be subtracted.
    target = msLat + t * sr;
    cum    = 0;
    for k = find(bLat > msLat)
        if target >= bLat(k) + cum
            cum = cum + bDur(k);
        else
            break;
        end
    end
    lat = round(target - cum);
end

function out = tern(c, a, b)
    if c, out = a; else, out = b; end
end
