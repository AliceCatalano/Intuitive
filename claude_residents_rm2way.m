function res = claude_residents_rm2way(T, label, ax)
% RM2WAY_RESIDENTS_PAPER  Two-way repeated-measures ANOVA, Scenario (6) x Repetition (first, last), as in the paper.
%
%   res = claude_rm2way_residents_paper(T, label, ax)
%
%   T      table with the variables  subject, scenario (1..6), rep ('first' / 'last'), value
%          (one band x region x metric at a time; one row per resident x scenario x repetition)
%   label  text used in the printout and in the plot title
%   ax     axes to draw in (mean +/- SD per scenario, first and last side by side); [] = no plot
%
%   Only residents with ALL 12 cells (6 scenarios x first/last) are kept; the others are listed.
%   For each effect (Scenario, Repetition, Scenario x Repetition) it prints F, p, partial eta^2 and, for the
%   effects with more than 2 levels, Mauchly's test of sphericity and the Greenhouse-Geisser epsilon.
%   p is the Greenhouse-Geisser corrected p when Mauchly is significant (p < 0.05), otherwise the uncorrected p.
%   Post hoc (Holm-adjusted paired t-tests): all 15 scenario pairs (shown when Scenario is significant) and
%   first vs last within each scenario (shown when Repetition or the interaction is significant).
%
%   The ANOVA itself is computed from the sums of squares of the Subject x Scenario x Repetition array
%   (no fitrm/ranova needed). It was validated outside MATLAB by simulation: under the null the F tests reject
%   about 5% of the time; with non-spherical data Mauchly detects the violation and Greenhouse-Geisser restores the
%   error rate. Needs the Statistics and Machine Learning Toolbox (fcdf, chi2cdf, ttest).
%
%   res.n, res.kept, res.droppedNames, res.eff(1:3) (name, F, df1, df2, p, pGG, pUse, eta2, mauchlyW, mauchlyP, eps),
%   res.posthocScenario, res.posthocRep, res.cellMean, res.cellSD  (6 x 2)
    if nargin < 3, ax = []; end
    a = 6;   b = 2;   REPS = {'first', 'last'};

    % ---- long table -> subject x scenario x repetition array
    subj = cellstr(string(T.subject));   scn = double(T.scenario);   repc = cellstr(string(T.rep));   val = double(T.value);
    subjects = unique(subj, 'stable');   nAll = numel(subjects);
    Yall = nan(nAll, a, b);
    for k = 1:numel(val)
        s = find(strcmp(subjects, subj{k}), 1);   i = scn(k);   j = find(strcmp(REPS, repc{k}), 1);
        if ~isempty(s) && i >= 1 && i <= a && ~isempty(j), Yall(s, i, j) = val(k); end
    end
    complete = reshape(all(all(~isnan(Yall), 2), 3), [], 1);
    res = struct('n', nnz(complete), 'kept', {subjects(complete)}, 'droppedNames', {subjects(~complete)}, ...
                 'eff', struct('name', {}, 'F', {}, 'df1', {}, 'df2', {}, 'p', {}, 'pGG', {}, 'pUse', {}, 'eta2', {}, ...
                         'mauchlyW', {}, 'mauchlyP', {}, 'eps', {}), ...
                 'posthocScenario', [], 'posthocRep', [], 'cellMean', nan(a, b), 'cellSD', nan(a, b));
    fprintf('\n--- %s | %d residents with all 6 scenarios x first/last (of %d with any data) ---\n', label, res.n, nAll);
    if any(~complete), fprintf('    not in the ANOVA (incomplete): %s\n', strjoin(subjects(~complete)', ', ')); end
    n = res.n;
    if n < 4
        fprintf('    too few complete residents for the ANOVA (n = %d)\n', n);
        return;
    end
    if n < a + 2, fprintf('    WARNING: n = %d is small for a 6-level repeated factor; sphericity tests and epsilon are unstable\n', n); end
    Y = Yall(complete, :, :);

    % ---- sums of squares
    G  = mean(Y(:));
    S  = mean(mean(Y, 2), 3);                         % n x 1
    A  = reshape(mean(mean(Y, 1), 3), [], 1);         % a x 1
    B  = reshape(mean(mean(Y, 1), 2), [], 1);         % b x 1
    AB = reshape(mean(Y, 1), a, b);                   % a x b
    SA = reshape(mean(Y, 3), n, a);                   % n x a   (subject x scenario, mean over first/last)
    SB = reshape(mean(Y, 2), n, b);                   % n x b
    ssA   = n * b * sum((A - G).^2);
    ssB   = n * a * sum((B - G).^2);
    ssAB  = n * sum(sum((AB - A - B' + G).^2));
    ssSA  = b * sum(sum((SA - S - A' + G).^2));
    ssSB  = a * sum(sum((SB - S - B' + G).^2));
    ssS   = a * b * sum((S - G).^2);
    ssT   = sum((Y(:) - G).^2);
    ssSAB = ssT - ssS - ssA - ssB - ssAB - ssSA - ssSB;

    names = {'Scenario', 'Repetition', 'Scenario x Repetition'};
    ss    = [ssA ssB ssAB];   sse = [ssSA ssSB ssSAB];
    df1   = [a-1, b-1, (a-1)*(b-1)];
    df2   = [(n-1)*(a-1), (n-1)*(b-1), (n-1)*(a-1)*(b-1)];

    % ---- sphericity (Mauchly on orthonormal contrasts) and Greenhouse-Geisser epsilon
    mW = [NaN NaN NaN];   mP = [NaN NaN NaN];   ep = [1 1 1];
    [mW(1), mP(1), ep(1)] = sphericity(SA, n, a);                             % scenario effect
    [mW(3), mP(3), ep(3)] = sphericity(Y(:, :, 2) - Y(:, :, 1), n, a);        % interaction: last - first across scenarios

    for e = 1:3
        F  = (ss(e) / df1(e)) / (sse(e) / df2(e));
        pF = fcdf(F, df1(e), df2(e), 'upper');
        pG = fcdf(F, df1(e) * ep(e), df2(e) * ep(e), 'upper');
        useGG = ~isnan(mP(e)) && mP(e) < 0.05;
        res.eff(e) = struct('name', names{e}, 'F', F, 'df1', df1(e), 'df2', df2(e), 'p', pF, 'pGG', pG, ...
            'pUse', pF + useGG * (pG - pF), 'eta2', ss(e) / (ss(e) + sse(e)), 'mauchlyW', mW(e), 'mauchlyP', mP(e), 'eps', ep(e));
        if isnan(mP(e))
            sph = 'sphericity not applicable (2 levels)';
        else
            sph = sprintf('Mauchly W=%.3f (p=%.3f), GG eps=%.2f%s', mW(e), mP(e), ep(e), ternary(useGG, ' -> GG corrected', ''));
        end
        fprintf('    %-22s F(%d,%d) = %6.2f | p = %.4f%s | partial eta^2 = %.3f | %s\n', names{e}, df1(e), df2(e), F, res.eff(e).pUse, ...
            ternary(useGG, ' (GG)', ''), res.eff(e).eta2, sph);
    end

    % ---- post hoc (Holm)
    prs = nchoosek(1:a, 2);   pp = nan(size(prs, 1), 1);   dd = nan(size(prs, 1), 1);
    for k = 1:size(prs, 1)
        [~, pp(k)] = ttest(SA(:, prs(k,1)), SA(:, prs(k,2)));   dd(k) = mean(SA(:, prs(k,1)) - SA(:, prs(k,2)));
    end
    res.posthocScenario = struct('pairs', prs, 'meanDiff', dd, 'p', pp, 'pHolm', claude_holm_adjust(pp));
    pr = nan(a, 1);   dr = nan(a, 1);
    for i = 1:a
        [~, pr(i)] = ttest(Y(:, i, 2), Y(:, i, 1));   dr(i) = mean(Y(:, i, 2) - Y(:, i, 1));
    end
    res.posthocRep = struct('meanDiff', dr, 'p', pr, 'pHolm', claude_holm_adjust(pr));
    if res.eff(1).pUse < 0.05
        sig = find(res.posthocScenario.pHolm < 0.05)';
        fprintf('    post hoc scenario pairs (Holm, 15 pairs): %s\n', ternary(isempty(sig), 'none significant', ...
            strjoin(arrayfun(@(k) sprintf('Sc%d-Sc%d diff %+.3f p(Holm)=%.4f', prs(k,1), prs(k,2), dd(k), res.posthocScenario.pHolm(k)), sig, 'UniformOutput', false), '; ')));
    end
    if res.eff(2).pUse < 0.05 || res.eff(3).pUse < 0.05
        sig = find(res.posthocRep.pHolm < 0.05)';
        fprintf('    post hoc last - first within scenario (Holm, 6 tests): %s\n', ternary(isempty(sig), 'none significant', ...
            strjoin(arrayfun(@(i) sprintf('Sc%d diff %+.3f p(Holm)=%.4f', i, dr(i), res.posthocRep.pHolm(i)), sig, 'UniformOutput', false), '; ')));
    end

    % ---- cell means / SD and plot (mean +/- SD per scenario, first and last side by side)
    for j = 1:b
        res.cellMean(:, j) = reshape(mean(Y(:, :, j), 1), [], 1);
        res.cellSD(:, j)   = reshape(std(Y(:, :, j), 0, 1), [], 1);
    end
    if ~isempty(ax)
        cF = [0.40 0.60 0.90];   cL = [0.00 0.20 0.60];
        hold(ax, 'on');
        errorbar(ax, (1:a) - 0.12, res.cellMean(:,1), res.cellSD(:,1), 'o-', 'Color', cF, 'MarkerFaceColor', cF, 'LineWidth', 1.6, 'CapSize', 8);
        errorbar(ax, (1:a) + 0.12, res.cellMean(:,2), res.cellSD(:,2), 's-', 'Color', cL, 'MarkerFaceColor', cL, 'LineWidth', 1.6, 'CapSize', 8);
        xlim(ax, [0.5 a+0.5]);   xticks(ax, 1:a);   grid(ax, 'on');   box(ax, 'on');
        xlabel(ax, 'Scenario');   title(ax, sprintf('%s (n = %d)', label, n), 'Interpreter', 'none');
    end
end

function [W, pM, eps] = sphericity(Z, n, a)
    % Mauchly's test and Greenhouse-Geisser epsilon for the n x a matrix Z (one row per resident),
    % on orthonormal (Helmert) contrasts
    C  = zeros(a, a-1);
    for k = 1:a-1
        v = [ones(k, 1); -k; zeros(a-k-1, 1)];   C(:, k) = v / norm(v);
    end
    p  = a - 1;
    Sc = cov(Z * C);
    tr = trace(Sc);
    W  = det(Sc) / (tr / p)^p;
    if W <= 0 || ~isfinite(W)
        pM = 0;
    else
        chi = -(n - 1 - (2*p^2 + p + 2) / (6*p)) * log(W);
        pM  = chi2cdf(chi, p*(p+1)/2 - 1, 'upper');
    end
    eps = tr^2 / (p * trace(Sc * Sc));
end

function out = ternary(c, x, y)
    if c, out = x; else, out = y; end
end
