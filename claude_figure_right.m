function fig = claude_figure_right(name, w, h)
% FIGURE_RIGHT  Open a new figure centred on the RIGHTMOST monitor.
%   fig = claude_figure_right(name, width, height)   size in pixels; shrunk if it does not fit.
%   The rightmost monitor is the one whose right edge is furthest to the right
%   in MATLAB's global screen coordinates (get(0,'MonitorPositions')).
    mp = get(0, 'MonitorPositions');            % one row per monitor: [left bottom width height]
    [~, k] = max(mp(:,1) + mp(:,3));            % largest right edge = rightmost screen
    m  = mp(k, :);
    w  = min(w, m(3) - 40);                     % keep it inside the monitor
    h  = min(h, m(4) - 120);                    % leave room for title bar / taskbar
    left   = m(1) + (m(3) - w) / 2;
    bottom = m(2) + (m(4) - h) / 2;
    fig = figure('Name', name, 'NumberTitle', 'off', 'Position', [left bottom w h]);
end
