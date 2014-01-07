% Rstan help for extract method
ex_model_code = {
'parameters {'
'  real alpha[2,3];'
'  real beta[2]; '
'} '
'model {'
'  for (i in 1:2) for (j in 1:3) '
'    alpha[i, j] ~ normal(0, 1); '
'  for (i in 1:2) '
'    beta ~ normal(0, 2); '
'} '
};

fit = stan('model_code', ex_model_code).sampling();

%https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_basic_array.py
model_code = {
'data {'
'  int<lower=2> K;'
'}'
'parameters {'
'  real beta[K,1,2];'
'}'
'model {'
'  for (k in 1:K)'
'    beta[k,1,1] ~ normal(0,1);'
'  for (k in 1:K)'
'    beta[k,1,2] ~ normal(100,1);'
'}'
};

fit = stan('model_code',model_code).sampling('data',struct('K',4));

% extract, permuted = true
beta = fit.extract('pars','beta').beta;
assertEqual(size(beta),[4000 4 1 2]);
beta_mean = mean(beta,1);
assertEqual(size(beta_mean),[4 1 2]);
assertTrue(all(beta_mean(:,1,1) < 4),'oops');
assertTrue(all(beta_mean(:,1,2) > (100-4)),'oops');

% extract, permuted = false
% does not match pystan