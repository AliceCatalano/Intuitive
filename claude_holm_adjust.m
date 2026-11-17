function adj = claude_holm_adjust(p)
% HOLM_ADJUST  Holm step-down adjusted p-values (NaN values are ignored).
    p = p(:);   adj = nan(size(p));
    [ps, idx] = sort(p);                     % NaN sorted last
    ok = ~isnan(ps);   n = nnz(ok);
    if n == 0, return; end
    a = cummax(ps(ok) .* (n:-1:1)');         % (m - i + 1) * p_(i), made monotone
    a = min(a, 1);
    tmp = nan(size(ps));   tmp(ok) = a;
    adj(idx) = tmp;
end
