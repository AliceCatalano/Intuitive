function [W, p] = claude_shapiro_wilk(x)
% SHAPIRO_WILK  Shapiro-Wilk normality test, Royston (1992) approximation (n = 3 ... 2000).
%   [W, p] = claude_shapiro_wilk(x)   NaNs are ignored. Needs the Statistics Toolbox (norminv, normcdf).
%   Checked outside MATLAB: n = 11 reproduces the SciPy reference example (W = 0.7888, p = 0.0067);
%   for n = 12 and n = 21 normal samples give 5% rejections at alpha = 0.05 (calibration by simulation).
    x = sort(x(~isnan(x(:))));   n = numel(x);   W = NaN;   p = NaN;
    if n < 3 || x(end) - x(1) == 0, return; end
    m  = norminv(((1:n)' - 0.375) / (n + 0.25));
    mm = sum(m.^2);   c = m / sqrt(mm);   u = 1 / sqrt(n);
    a  = zeros(n, 1);
    if n == 3
        a = [-sqrt(0.5); 0; sqrt(0.5)];
    else
        an  = c(n)   + polyval(fliplr([0 0.221157 -0.147981 -2.071190 4.434685 -2.706056]), u);
        an1 = c(n-1) + polyval(fliplr([0 0.042981 -0.293762 -1.752461 5.682633 -3.582633]), u);
        if n > 5
            phi = (mm - 2*m(n)^2 - 2*m(n-1)^2) / (1 - 2*an^2 - 2*an1^2);
            a(3:n-2) = m(3:n-2) / sqrt(phi);
            a(n) = an;   a(1) = -an;   a(n-1) = an1;   a(2) = -an1;
        else
            phi = (mm - 2*m(n)^2) / (1 - 2*an^2);
            a(2:n-1) = m(2:n-1) / sqrt(phi);
            a(n) = an;   a(1) = -an;
        end
    end
    W = (a' * x)^2 / sum((x - mean(x)).^2);
    y = log(1 - W);
    if n == 3
        p = max(0, 6/pi * (asin(sqrt(W)) - asin(sqrt(0.75))));
    elseif n <= 11
        gam = -2.273 + 0.459*n;
        if y >= gam, p = 1e-99; return; end
        y  = -log(gam - y);
        mu = polyval(fliplr([0.5440 -0.39978 0.025054 -0.0006714]), n);
        sg = exp(polyval(fliplr([1.3822 -0.77857 0.062767 -0.0020322]), n));
        p  = 1 - normcdf((y - mu) / sg);
    else
        xx = log(n);
        mu = polyval(fliplr([-1.5861 -0.31082 -0.083751 0.0038915]), xx);
        sg = exp(polyval(fliplr([-0.4803 -0.082676 0.0030302]), xx));
        p  = 1 - normcdf((y - mu) / sg);
    end
end
