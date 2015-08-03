% Reproduces example in Appendix 3 of:
% Efficient implementation of leave-one-out cross-validation
% and WAIC for evaluating fitted Bayesian models
% Aki Vehtari, Andrew Gelman, Jonah Gabry
% 16 July 2015
% http://www.stat.columbia.edu/~gelman/research/unpublished/loo_stan.pdf

%   Author: Aki Vehtari <Aki.Vehtari@aalto.fi>
%   Last modified: 2015-07-16 15:19:17 EEST

use MatlabProcessManager
use MatlabStan

%% Fit a model, using arsenic and distance as predictors

% Read in data
load arsenic_data
y=data.xSwitch;
x=[data.arsenic data.dist];
[n,m]=size(x);

% Model
model='arsenic_logistic.stan';

% Fit the model in Stan
dat=struct('p',m,'N',n,'y',y,'x',x);
fit = stan('file',model,'data',dat,'sample_file','arsenic','file_overwrite',true,'verbose',false);
fit.block()

% Compute LOO and standard error
s = fit.extract('permuted',true);
[loo,loos,pk]=psisloo(s.log_lik);
fprintf('elpd_loo = %.1f, SE(elpd_loo) = %.1f\n',sum(loos),std(loos)*sqrt(n))

% Check the shape parameter k of the generalized Pareto distribution
if all(pk<0.5)
    fprintf('All Pareto k estimates OK (k < 0.5)\n')
else
  pkn1=sum(pk>=0.5&pk<1);
  pkn2=sum(pk>=1);
  fprintf('%d (%.0f%%) PSIS Pareto k estimates between 0.5 and 1\nand %d (%.0f%%) PSIS Pareto k estimates greater than 1\n',pkn1,pkn1/n*100,pkn2,pkn2/n*100)
end

%% Fit a second model, using log(arsenic) instead of arsenic
x2=[log(data.arsenic) data.dist];

% Fit the model in Stan
dat2=struct('p',m,'N',n,'y',y,'x',x2);
fit2 = stan('file',model,'data',dat2,'sample_file','arsenic','file_overwrite',true,'verbose',false);
fit2.block()

% Compute LOO and standard error
s2 = fit2.extract('permuted',true);
[loo2,loos2,pk2]=psisloo(s2.log_lik);
fprintf('elpd_loo = %.1f, SE(elpd_loo) = %.1f\n',sum(loos2),std(loos2)*sqrt(n))

% Check the shape parameter k of the generalized Pareto distribution
if all(pk2<0.5)
    fprintf('All Pareto k estimates OK (k < 0.5)\n')
else
  pkn1=sum(pk2>=0.5&pk2<1);
  pkn2=sum(pk2>=1);
  fprintf('%d (%.0f%%) PSIS Pareto k estimates between 0.5 and 1\nand %d (%.0f%%) PSIS Pareto k estimates greater than 1\n',pkn1,pkn1/n*100,pkn2,pkn2/n*100)
end

%% Compare the models
loodiff=loos-loos2;
fprintf('elpd_diff = %.1f, SE(elpd_diff) = %.1f\n',sum(loodiff),std(loodiff)*sqrt(n))

%% For this example, WAIC results are same as LOO results up to accuracy of at least one decimal
waic1 = mstan.waic(s.log_lik);
waic2 = mstan.waic(s2.log_lik);
fprintf('elpd_waic_diff = %.1f\n',waic1.elpd_waic-waic2.elpd_waic)

