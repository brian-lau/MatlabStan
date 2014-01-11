# MatlabStan
A Matlab interface to [Stan](http://mc-stan.org/), a package for Bayesian inference using the No-U-Turn sampler, a variant of Hamiltonian Monte Carlo.

For more information on Stan and its modeling language, see the Stan User's Guide and Reference Manual at http://mc-stan.org/.

## Status
The interface is very prelimenary, and subject to changes as I get through testing. Should be cleaned up soon...

Developed on Matlab 2012a and OSX. Should work on Windows, although someone needs to test it...

## Installation
In addition to the code in this [repository](https://github.com/brian-lau/MatlabStan/archive/master.zip), the following are required
* [CmdStan 2.0.1+](http://mc-stan.org/cmdstan.html)
* [MatlabProcessManager 0.3.0+](https://github.com/brian-lau/MatlabProcessManager/)

Add the Matlab files, as well as the parent directory of the `+mstan` [package](http://www.mathworks.com/help/matlab/matlab_oop/scoping-classes-with-packages.html#brfynt_-3) folder to your path. Edit the file `stan_home.m` in the `+mstan` directory to point to the parent folder of your installation.

###Optional
Installing Steve Eddins's [linewrap](http://www.mathworks.com/matlabcentral/fileexchange/9909-line-wrap-a-string) function is useful for dealing with unwrapped messages. His [xUnit test framework](http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework) is required if you want to run the unit tests.

##Examples
This is the classic 'eight schools' example from Section 5.5 of [Gelman et al (2003)](http://stat.columbia.edu/~gelman/book/). The following can be compared to the [Rstan](https://github.com/stan-dev/rstan/wiki/RStan-Getting-Started) and [Pystan](https://github.com/stan-dev/pystan/blob/develop/README.rst) versions.
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
