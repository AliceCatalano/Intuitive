function out = claude_fooof_peak(f, spec, fitRange, bandRng, S)
% FOOOF on ONE raw power spectrum and the peak of each band. Used by the whole-repetition peak scripts of the experts and of
% the residents, so both groups (and the trial-level FOOOF scripts Task2_fooof.m / Task_Res_FOOOF.m) use the same method.
%
%   f, spec   frequency axis (Hz, evenly spaced) and RAW power (not log, not baselined, not 1/f-corrected: FOOOF models the 1/f itself)
%   fitRange  [lo hi] Hz fitted by FOOOF (4-35, as in the trial-level scripts)
%   bandRng   nB x 2 band limits (alpha 8-15, beta 15-25: a peak with lo <= centre < hi belongs to the band)
%   S         FOOOF settings struct (default: the trial-level ones: width 1-12 Hz, max 4 peaks, min height 0.05, threshold 2, fixed)
%
% out.cf / out.pw / out.bw (1 x nB)  centre frequency (Hz), height (log10 power above the aperiodic fit) and width (Hz) of the
%                                    HIGHEST peak found by FOOOF inside each band; NaN = FOOOF found no peak there
% out.exponent, out.offset, out.r2   aperiodic fit and its quality
% out.freqs, out.resid                spectrum minus aperiodic fit (log10), on the fitted frequencies, for plotting
%                                    (computed here from offset and exponent; needs aperiodic_mode 'fixed')
    nB = size(bandRng, 1);
    out = struct('cf', nan(1, nB), 'pw', nan(1, nB), 'bw', nan(1, nB), 'exponent', NaN, 'offset', NaN, 'r2', NaN, 'freqs', [], 'resid', []);
    if nargin < 5 || isempty(S)
        S = struct('peak_width_limits', [1 12], 'max_n_peaks', 4, 'min_peak_height', 0.05, 'peak_threshold', 2.0, 'aperiodic_mode', 'fixed');
    end
    f = double(f(:)');   spec = double(spec(:)');
    if any(isnan(spec)) || any(spec <= 0), return; end
    persistent nErr pyChecked
    if isempty(nErr), nErr = 0; end
    if isempty(pyChecked)                                     % MATLAB must use the Python that has the 'fooof' package
        PY = '/home/acatalano/ros_env/bin/python';              % fooof 1.1.1 is installed here
        pe = pyenv;
        if pe.Status == "NotLoaded", pyenv('Version', PY); pe = pyenv; end
        try
            py.importlib.import_module('fooof');
        catch
            error(['MATLAB is using the Python %s, which has no "fooof" package. Restart MATLAB and run this script again first thing ' ...
                   '(the script then selects %s), or run  pyenv(''Version'', ''%s'')  in a fresh MATLAB.'], char(pe.Executable), PY, PY);
        end
        fprintf('FOOOF python: %s\n', char(pe.Executable));
        pyChecked = true;
    end
    try
        fm = fooof(f, spec, fitRange, S, false);            % same call as the trial-level scripts (no model returned)
    catch ME
        nErr = nErr + 1;
        if nErr <= 3, fprintf(2, '\nFOOOF ERROR (%d): %s\n', nErr, ME.message); end     % the first errors are printed, never silent
        return;
    end
    out.offset = fm.aperiodic_params(1);   out.exponent = fm.aperiodic_params(2);   out.r2 = fm.r_squared;
    out.freqs = f(f >= fitRange(1) & f <= fitRange(2));                                  % aperiodic fit ('fixed'): offset - exponent*log10(f)
    out.resid = log10(spec(f >= fitRange(1) & f <= fitRange(2))) - (out.offset - out.exponent * log10(out.freqs));
    pk = fm.peak_params;
    if isempty(pk), return; end
    for b = 1:nB
        m = pk(:, 1) >= bandRng(b, 1) & pk(:, 1) < bandRng(b, 2);
        if any(m)
            q = pk(m, :);   [~, k] = max(q(:, 2));
            out.cf(b) = q(k, 1);   out.pw(b) = q(k, 2);   out.bw(b) = q(k, 3);
        end
    end
end
