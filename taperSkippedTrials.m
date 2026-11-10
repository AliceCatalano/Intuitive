function TFRhann = taperSkippedTrials(TFRhann, subject)

    % Define skipped repetitions
    switch subject
        case 'IE01'
            skipped = 13;
        case 'IE03'
            skipped = 10;
        case 'IE05'
            skipped = 9;
        case 'IE07'
            skipped = 15;
        case 'IE10'
            skipped = 4;
        otherwise
            skipped = [];
    end
    
    % Desired number of repetitions
    nTrials = 20;
    currentTrials = size(TFRhann.powspctrm, 1);
    
    % Pad powspctrm with NaNs up to nTrials
    if currentTrials < nTrials
        tmp = nan(nTrials, size(TFRhann.powspctrm,2), size(TFRhann.powspctrm,3), size(TFRhann.powspctrm,4));
        tmp(1:currentTrials, :, :, :) = TFRhann.powspctrm;
        TFRhann.powspctrm = tmp;
    end
    
    % Pad trialinfo with missing rows up to nTrials
    if isfield(TFRhann, 'trialinfo')
        oldTrialinfo = TFRhann.trialinfo;
        if currentTrials < nTrials
            emptyRows = oldTrialinfo(ones(nTrials - currentTrials, 1), :);
            % replace values with missing, matching each column's type
            for c = 1:width(emptyRows)
                if isnumeric(emptyRows.(c))
                    emptyRows.(c) = NaN(height(emptyRows), 1);
                elseif iscell(emptyRows.(c))
                    emptyRows.(c) = repmat({''}, height(emptyRows), 1);
                end
            end
            TFRhann.trialinfo = [oldTrialinfo; emptyRows];
        end
    end
    
    % Pad sampleinfo with NaNs up to nTrials
    if isfield(TFRhann, 'sampleinfo')
        tmp = nan(nTrials, 2);
        tmp(1:currentTrials, :) = TFRhann.sampleinfo;
        TFRhann.sampleinfo = tmp;
    end
    % Pad cumtapcnt with NaNs up to nTrials (rows = trials, cols = freq)
    if isfield(TFRhann, 'cumtapcnt')
        nCols = size(TFRhann.cumtapcnt, 2);
        tmp = nan(nTrials, nCols);
        tmp(1:currentTrials, :) = TFRhann.cumtapcnt;
        TFRhann.cumtapcnt = tmp;
    end
    
    % Insert a NaN row at each skipped-trial position, shifting the rest down
    % (single pass, mirrors the logic in taperRange.m)
    for idx = skipped
        if idx <= size(TFRhann.powspctrm, 1)
            TFRhann.powspctrm(idx+1:end, :, :, :) = TFRhann.powspctrm(idx:end-1, :, :, :);
            TFRhann.powspctrm(idx, :, :, :) = NaN;
        end
    
        if isfield(TFRhann, 'trialinfo') && idx <= height(TFRhann.trialinfo)
            TFRhann.trialinfo(idx+1:end, :) = TFRhann.trialinfo(idx:end-1, :);
            for c = 1:width(TFRhann.trialinfo)
                if isnumeric(TFRhann.trialinfo.(c))
                    TFRhann.trialinfo{idx, c} = NaN;
                elseif iscell(TFRhann.trialinfo.(c))
                    TFRhann.trialinfo{idx, c} = {''};
                end
            end
        end
    
        if isfield(TFRhann, 'sampleinfo') && idx <= size(TFRhann.sampleinfo, 1)
            TFRhann.sampleinfo(idx+1:end, :) = TFRhann.sampleinfo(idx:end-1, :);
            TFRhann.sampleinfo(idx, :) = NaN;
        end
        if isfield(TFRhann, 'cumtapcnt') && idx <= size(TFRhann.cumtapcnt, 1)
            TFRhann.cumtapcnt(idx+1:end, :) = TFRhann.cumtapcnt(idx:end-1, :);
            TFRhann.cumtapcnt(idx, :) = NaN;
        end
    end

end