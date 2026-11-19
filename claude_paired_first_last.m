function R = claude_paired_first_last(f, l, alphaSW, force)
% PAIRED_FIRST_LAST  Paired comparison as in the paper.
%   Shapiro-Wilk on the paired differences (last - first): p >= alphaSW -> paired t-test,
%   otherwise Wilcoxon signed-rank. Returns mean +/- SD of first and last and the test result.
%   Optional 4th input force: 't' = always paired t-test, 'wilcoxon' = always Wilcoxon (Shapiro-Wilk is still computed).
    if nargin < 4, force = ''; end
    ok = ~isnan(f) & ~isnan(l);   f = f(ok);   l = l(ok);   d = l - f;
    R = struct('n', numel(d), 'mFirst', mean(f), 'sdFirst', std(f), 'mLast', mean(l), 'sdLast', std(l), ...
               'swW', NaN, 'swP', NaN, 'test', 'n/a', 'p', NaN);
    if R.n < 3, return; end
    [R.swW, R.swP] = claude_shapiro_wilk(d);
    useT = ~isnan(R.swP) && R.swP >= alphaSW;
    if strcmp(force, 't'), useT = true; elseif strcmp(force, 'wilcoxon'), useT = false; end
    if useT
        [~, R.p] = ttest(l, f);     R.test = 't-test';
    else
        R.p = signrank(l, f);       R.test = 'Wilcoxon';
    end
end
