function [loo,loos,pk] = psisloo(log_lik,varargin)
%PSISLOO Pareto smoothed importance sampling leave-one-out log predictive densities
%   
%  Description
%    [LOO,LOOS,KS] = PSISLOO(LOG_LIK) computes Pareto smoothed importance
%    sampling leave-one-out log predictive densities given posterior
%    samples of the log likelihood terms p(y_i|\theta^s) in LOG_LIK.
%    Returns a sum of the leave-one-out log predictive densities LOO,
%    individual leave-one-out log predictive density terms LOOS and an
%    estimate of Pareto tail indeces KS. If tail index k>0.5, variance of
%    the raw estimate does not exist and if tail index k>1 the mean of the
%    raw estimate does not exist and the PSIS estimate is likely to
%    have large variation and some bias.
%
%    [LOO,LOOS,KS] = PSISLOO(LOG_LIK,WCPP,WCUTOFF) passes optional
%    arguments for Pareto smoothed importance sampling.
%      WCPP    - percentage of samples used for GPD fit estimate
%                (default = 20)
%      WTRUNC  - parameter for truncating very large weights to N^WTRUNC,
%                with no truncation if 0 (default = 3/4)
%
%  References:
%    Aki Vehtari, Andrew Gelman and Jonah Gabry (2015). Efficient
%    implementation of leave-one-out cross-validation and WAIC for
%    evaluating fitted Bayesian models. arXiv preprint arXiv:1507.04544.
%
%    Aki Vehtari and Andrew Gelman (2015). Pareto smoothed importance
%    sampling. arXiv preprint arXiv:1507.02646.
%
%  Copyright (c) 2015 Aki Vehtari

% This software is distributed under the GNU General Public
% License (version 3 or later); please refer to the file
% License.txt, included with the software, for details.

% log raw weights from log_lik
lw=-log_lik;
% compute Pareto smoothed log weights given raw log weights
[lw,pk]=psislw(lw,varargin{:});
% compute
loos=sumlogs(log_lik+lw);
loo=sum(loos);
