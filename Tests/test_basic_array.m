% % Rstan help for extract method
% ex_model_code = {
% 'parameters {'
% '  real alpha[2,3];'
% '  real beta[2]; '
% '} '
% 'model {'
% '  for (i in 1:2) for (j in 1:3) '
% '    alpha[i, j] ~ normal(0, 1); '
% '  for (i in 1:2) '
% '    beta ~ normal(0, 2); '
% '} '
% };
% 
% fit = stan('model_code', ex_model_code).sampling();
% 
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
beta = fit.extract().beta;
assertEqual(size(beta),[4000 4 1 2]);
beta_mean = mean(beta,1);
assertEqual(size(beta_mean),[1 4 1 2]);
assertTrue(all(beta_mean(:,1,1) < 4),'Should be < 4 on this dimension');
assertTrue(all(beta_mean(:,1,2) > (100-4)),'Should be > 100 on this dimension');

% extract, permuted = false
% Rstan and pystan return an 3D array : iterations x chains x parameters
% I'm not sure why, so for the time being, I don't emulate this behavior
% because it makes for a confusing interface.
% The following checks are specific to the Matlab interface
extracted = fit.extract('permuted',false);
assertEqual(size(extracted),[1 4]); % # of chains

beta_mean = arrayfun(@(x) mean(x.beta,1),extracted,'uni',false);
for i = 1:4
   assertTrue(all(beta_mean{i}(:,1,1) < 4),'Should be < 4 on this dimension');
   assertTrue(all(beta_mean{i}(:,1,2) > (100-4)),'Should be > 100 on this dimension');
end
lp_mean = arrayfun(@(x) mean(x.lp__,1),extracted);
assertTrue(all(lp_mean < 4),'Should be < 4 on this dimension');
