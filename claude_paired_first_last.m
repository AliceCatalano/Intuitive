function R = claude_paired_first_last(f, l, alphaSW)
% PAIRED_FIRST_LAST  Paired comparison as in the paper.
%   Shapiro-Wilk on the paired differences (last - first): p >= alphaSW -> paired t-test,
%   otherwise Wilcoxon signed-rank. Returns mean +/- SD of first and last and the test result.
    ok = ~isnan(f) & ~isnan(l);   f = f(ok);   l = l(ok);   d = l - f;
    R = struct('n', numel(d), 'mFirst', mean(f), 'sdFirst', std(f), 'mLast', mean(l), 'sdLast', std(l), ...
               'swW', NaN, 'swP', NaN, 'test', 'n/a', 'p', NaN);
    if R.n < 3, return; end
    [R.swW, R.swP] = claude_shapiro_wilk(d);
    if ~isnan(R.swP) && R.swP >= alphaSW
        [~, R.p] = ttest(l, f);     R.test = 't-test';
    else
        R.p = signrank(l, f);       R.test = 'Wilcoxon';
    end
end
