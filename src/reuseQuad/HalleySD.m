function [success, x_n] = HalleySD(x_n,G,p,r,xi,freq, thresh)
%Quick Newton iteration to find zeros of G
    maxIts = 30;
    for n = 1:maxIts
        x_n = x_n - 2*(-freq*G{1}(xi) - 1i*p^r + freq*G{1}(x_n))*(freq*G{2}(x_n))...
              /( 2*(freq*G{2}(x_n))^2 - (-freq*G{1}(xi) - 1i*p^r + freq*G{1}(x_n))*(freq*G{3}(x_n)));
        err = abs(freq*G{1}(xi) + 1i*p^r - freq*G{1}(x_n));
        if err < thresh
            success = true;
            return
        end
    end
    success = false;
    x_n =[];
end