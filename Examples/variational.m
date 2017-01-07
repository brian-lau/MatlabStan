schools_code = {
   'data {'
   '    int<lower=0> J; // number of schools '
   '    real y[J]; // estimated treatment effects'
   '    real<lower=0> sigma[J]; // s.e. of effect estimates '
   '}'
   'parameters {'
   '    real mu; '
   '    real<lower=0> tau;'
   '    real eta[J];'
   '}'
   'transformed parameters {'
   '    real theta[J];'
   '    for (j in 1:J)'
   '    theta[j] <- mu + tau * eta[j];'
   '}'
   'model {'
   '    eta ~ normal(0, 1);'
   '    y ~ normal(theta, sigma);'
   '}'
};

schools_dat = struct('J',8,...
                     'y',[28 8 -3 7 -1 1 18 12],...
                     'sigma',[15 10 16 11 9 11 10 18]);

%fit = stan('model_code',schools_code,'data',schools_dat,'verbose',true);
%fit = stan('model_code',schools_code,'data',schools_dat,'verbose',true,'method','variational');
fit = stan('model_name','anon_model','data',schools_dat,'verbose',true,'method','variational','iter',2000);
fit = stan('model_name','anon_model','data',schools_dat,'verbose',true,'method','sample');
fit = stan('model_name','anon_model','data',schools_dat,'verbose',true,'method','optimize');

print(fit);

theta = fit.extract.theta;
mean(theta)
