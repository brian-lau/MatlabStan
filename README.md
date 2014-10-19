# MatlabStan
A Matlab interface to [Stan](http://mc-stan.org/), a package for Bayesian inference.

For more information on Stan and its modeling language, see the Stan User's Guide and Reference Manual at http://mc-stan.org/.

## Installation
Details are provided in the [Getting started](https://github.com/brian-lau/MatlabStan/wiki/Getting-Started) page of the wiki.

##Example
Examples can be found in various sections of the [wiki](https://github.com/brian-lau/MatlabStan/wiki).
The following is the classic 'eight schools' example from Section 5.5 of [Gelman et al (2003)](http://stat.columbia.edu/~gelman/book/). The following can be compared to the [Rstan](https://github.com/stan-dev/rstan/wiki/RStan-Getting-Started) and [Pystan](https://github.com/stan-dev/pystan/blob/develop/README.rst) versions.
```
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

fit = stan('model_code',schools_code,'data',schools_dat);

print(fit);

eta = fit.extract('permuted',true).eta;
mean(eta)

```
##Need help?
You may be able to find a solution in the [wiki](https://github.com/brian-lau/MatlabStan/wiki/). Otherwise, open an [issue](https://github.com/brian-lau/MatlabProcessManager/issues).

Contributions
--------------------------------
Copyright (c) 2014 Brian Lau [brian.lau@upmc.fr](mailto:brian.lau@upmc.fr), see [LICENSE](https://github.com/brian-lau/MatlabStan/blob/master/LICENSE.txt)

Please feel from to [fork](https://github.com/brian-lau/MatlabStan/fork) and contribute!
