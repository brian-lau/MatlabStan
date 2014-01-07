# MatlabStan

A Matlab interface to [Stan](http://mc-stan.org/), a package for Bayesian inference using the No-U-Turn sampler, a variant of Hamiltonian Monte Carlo.

For more information on Stan and its modeling language, see the Stan User's Guide and Reference Manual at http://mc-stan.org/.

## Installation
+[CmdStan 2.0.1+](http://mc-stan.org/cmdstan.html) is required. Installation instructions here.
+[MatlabStan](https://github.com/brian-lau/MatlabStan/archive/master.zip) is required.
+[MatlabProcessManager](https://github.com/brian-lau/MatlabProcessManager/archive/master.zip) is required.

processManager was developed and tested on OSX with Matlab 2012a, but should work on all platforms that Matlab supports, so long as it is running >=R2008a (for handle objects) with JDK >=1.1 (this will always be true unless you changed the default JDK).

###Optional
Installing Steve Eddins's [linewrap](http://www.mathworks.com/matlabcentral/fileexchange/9909-line-wrap-a-string) function is useful for dealing with unwrapped messages. His [xUnit test framework](http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework) is required if you want to run the unit tests.

##Examples
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

fit = stan('model_code',schools_code,'data',schools_dat).sampling();

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
