% Calculate Watanabe-Akaike information criterion (WAIC)
% 
% Based on R code in:
% Vehtari & Gelman (2014). WAIC and cross-validation in Stan
% http://www.stat.columbia.edu/~gelman/research/unpublished/waic_stan.pdf
%

function [total,se,pointwise] = waic(log_lik)

[S,n] = size(log_lik);

lpd = log(mean(exp(log_lik)));
p_waic = var(log_lik);
elpd_waic = lpd - p_waic;
waic = -2*elpd_waic;

loo_weights_raw = 1./exp(log_lik - max(log_lik(:)));
loo_weights_normalized = bsxfun(@rdivide,loo_weights_raw,mean(loo_weights_raw));
loo_weights_regularized = min(loo_weights_normalized,sqrt(S));
elpd_loo = log( mean(exp(log_lik).*loo_weights_regularized )./ mean(loo_weights_regularized) );
p_loo = lpd - elpd_loo;

names = {'waic' 'lpd' 'p_waic' 'elpd_waic' 'p_loo' 'elpd_loo'};
temp = eval(['[' sprintf('%s;',names{:}) '];']);
%temp = [waic;lpd;p_waic;elpd_waic;p_loo;elpd_loo];

pointwise = cell2struct(mat2cell(temp,ones(1,size(temp,1)),n),names);
total = cell2struct(num2cell(sum(temp,2)),names);
se = cell2struct(num2cell(sqrt(n*var(temp,[],2))),names);
