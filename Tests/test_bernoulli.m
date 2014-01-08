%https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_basic.py
bernoulli_model_code = {
'data {'
'    int<lower=0> N;'
'    int<lower=0,upper=1> y[N];'
'}'
'parameters {'
'    real<lower=0,upper=1> theta;'
'}'
'model {'
'for (n in 1:N)'
'    y[n] ~ bernoulli(theta);'
'}'
};

bernoulli_data = struct('N',10,'y',[0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);

% model = StanModel('model_code',bernoulli_model_code,...
%    'model_name','bernoulli','file_overwrite',true);
% fit = model.sampling('data',bernoulli_data);

fit = stan('model_code',bernoulli_model_code,...
   'model_name','bernoulli','file_overwrite',true,...
   'data',bernoulli_data);