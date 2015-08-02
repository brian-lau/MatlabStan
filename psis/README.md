## Pareto smoothed importance sampling (PSIS) and PSIS leave-one-out cross-validation for Matlab/Octave


### Introduction
These m-files implement Pareto smoothed importance sampling (PSIS) and
PSIS leave-one-out cross-validation for Matlab and Octave


### Contents
- 'psislw.m'  - Pareto smoothed importance sampling smoothing of the log importance weights
   - Aki Vehtari and Andrew Gelman (2015). Pareto smoothed importance
   sampling. [arXiv preprint arXiv:1507.02646](http://arxiv.org/abs/1507.02646)
- 'psisloo.m' - Pareto smoothed importance sampling leave-one-out log predictive densities
   - Aki Vehtari, Andrew Gelman and Jonah Gabry (2015). Efficient
   implementation of leave-one-out cross-validation and WAIC for
   evaluating fitted Bayesian models. [arXiv preprint arXiv:1507.04544](http://arxiv.org/abs/1507.04544)
- 'gpdfitnew.m' - Estimate the paramaters for the Generalized Pareto Distribution
   - Jin Zhang & Michael A. Stephens (2009) A New and Efficient
     Estimation Method for the Generalized Pareto Distribution,
     Technometrics, 51:3, 316-325, DOI: 10.1198/tech.2009.08017

                 
### Corresponding R code

Corresponding R code can be found in [R package called
`loo'](https://github.com/jgabry/loo) which is also available in CRAN.
