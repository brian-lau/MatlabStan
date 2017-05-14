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

model = StanModel('verbose',true,'model_code',schools_code,'data',schools_dat);
model.compile();

fit_vb = model.vb();

print(fit_vb);

% http://www.slideshare.net/yutakashino/automatic-variational-inference-in-stan-nips2015yomi20160120
% compare to slide 32
% Inference for Stan model: 8schools.
% 1 chains, each with iter=2000, warmup=0, thin=1;
% post-warmup draws per chain=2000, total post-warmup draws=2000.
% 
%             mean   sd  2.5%   25%   50%   75% 97.5%
% mu          7.75 4.63 -1.46  4.78  7.73 10.83 16.88
% tau         4.61 3.73  0.87  2.17  3.61  5.83 14.79
% eta[1]      0.34 0.99 -1.70 -0.33  0.37  0.99  2.26
% eta[2]     -0.10 0.87 -1.74 -0.68 -0.11  0.48  1.59
% eta[3]     -0.28 0.93 -2.12 -0.91 -0.28  0.33  1.55
% eta[4]      0.00 0.84 -1.64 -0.55  0.00  0.55  1.65
% eta[5]     -0.34 0.96 -2.27 -1.02 -0.32  0.32  1.47
% eta[6]     -0.27 0.94 -2.14 -0.93 -0.24  0.36  1.50
% eta[7]      0.49 0.95 -1.47 -0.14  0.48  1.12  2.33
% eta[8]      0.03 1.00 -1.91 -0.65  0.00  0.70  2.03
% theta[1]    9.34 7.41 -4.07  4.84  9.09 13.21 23.96
% theta[2]    7.20 6.93 -5.85  3.12  7.13 11.24 20.15
% theta[3]    6.39 7.01 -8.45  2.37  6.75 10.54 19.78
% theta[4]    7.84 6.99 -5.38  3.61  7.71 11.93 21.65
% theta[5]    6.24 7.59 -9.41  2.29  6.52 10.91 20.04
% theta[6]    6.43 7.11 -8.70  2.52  6.82 10.84 18.97
% theta[7]   10.01 7.48 -4.31  5.51  9.35 13.70 26.54
% theta[8]    7.79 7.59 -7.57  3.62  7.76 11.88 22.41
