%https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_basic.py
model_code = {
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

data = struct('N',10,'y',[0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);

% model = StanModel('model_code',model_code,...
%    'model_name','bernoulli','file_overwrite',true);
% fit = model.sampling('data',data);

% fit = stan('model_code',model_code,...
%    'model_name','bernoulli','file_overwrite',true,...
%    'data',data,'verbose',true);
% 
% fit2 = stan('fit',fit,'iter',500000,'thin',10);
% fit2.verbose = true;
%fit2 = stan('fit',fit,'iter',5000,'verbose',true);

fit = stan('model_code',model_code,'data',data);
fit.block()
print(fit);

new_data = struct('N',10,'y',[0, 1, 0, 1, 0, 1, 0, 1, 1, 1]);

fit2 = stan('fit',fit,'data',new_data);
print(fit2);

sm = StanModel('model_code',model_code,'verbose',true);
sm.compile();
fit3 = sm.sampling('data',data);
print(fit3);

fit4 = sm.sampling('data',data);
print(fit4);

data = struct('N',10,'y',[0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);
fit = stan('file','junk.stan','data',data,'iter',20000);
addlistener(fit,'exit',@exitHandler);
