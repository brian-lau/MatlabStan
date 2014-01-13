stdnorm = {
'data {'
'  int N;'
'  real y[N];'
'}'
'parameters {'
'  real mu;'
'  real<lower=0> sigma;'
'}'
'model {'
'  mu ~ normal(0, 5);'
'  sigma ~ normal(0, 5);'
'  y ~ normal(mu, sigma);'
'}'
};

dat = struct('N',30,'y',randn(30,1));

sm = StanModel('model_code',stdnorm);
optim = sm.optimizing('data',dat,'verbose',true);

assertTrue((-1<optim.sim.mu) && (optim.sim.mu) < 1);
assertTrue((0<optim.sim.sigma) && (optim.sim.mu) < 2);

mstan.rdump('optim.data.R',dat);
optim = sm.optimizing('data','optim.data.R','verbose',true);

%optim = stan('model_code',stdnorm,'method','optimize','data',dat,'verbose',true);
