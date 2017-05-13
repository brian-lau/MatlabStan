% STAN - Fit a model using Stan
%
%     fit = stan(varargin);
%
%     All inputs are passed in using name/value pairs. The name is a string
%     followed by the value (described below).
%     The order of the pairs does not matter, nor does the case.
%
%     The Stan model can be passed in three ways:
%     1) as a file (use the 'file' input)
%     2) as a Matlab string (use the 'model_code' input)
%     3) as a Matlab StanModel object (use the 'fit' input)
%
% INPUTS
%     file   - string, optional
%              The string passed is the filename containing the Stan model.
%     method - string, optional
%              {'sample' 'optimize' 'variational'}, default = 'sample'
%     model_code - string, optional
%              String, or cell array of strings containing Stan model.
%              Ignored if 'file' is passed in.
%     model_name - string, optional
%              Name of the model. default = 'anon_model' 
%              However, if 'file' is passed in, then the filename is used 
%              to name the model.
%     fit    - StanModel or StanFit object, optional
%              StanFit instance from previous fit, default = []
%              If present, the Stan model instantiated in StanModel or 
%              associated with a StanFit instance is used to specify the 
%              model, which can avoid recompilation.
%     data   - struct
%              Data for Stan model. Fieldnames and associated values must 
%              correspond to Stan variable names values.
%     chains - scalar, optional, valid when method = 'sample'
%              Number of chains for . Default = 4
%     iter   - scalar, optional, valid when method = 'sample'
%              Number of iterations for each chain. 
%     warmup - scalar, optional, valid when method = 'sample'
%              Number of warmup (aka burnin) iterations.
%     thin   - scalar, optional, valid when method = 'sample'
%              Period for saving samples.
%     init   - scalar, struct or string, optional
%              0 initializes all to be zero on the unconstrained support
%              x scalar [-x,+x] uniform initial values
%              User-supplied initial values can either be supplied as a
%              string pointing to a Rdump file, or as a struct, with fields
%              corresponding to parameters to be initialized.
%              Default initializes parameters uniformly from (-2,+2)
%     seed   - scalar, optional
%              Random number generator seed. Default = round(sum(100*clock))
%              Note that this seed is different from Matlab's RNG seed, and
%              is only used to sample from Stan models. For multiple chains
%              each chain is seeded according to a deterministic function
%              of the provided seed to avoid dependency.
%     algorithm - string, optional
%              If method = 'sample', {'NUTS','HMC'}, default = 'NUTS'
%              If method = 'optimize', {'LBFGS', 'BFGS', 'NEWTON'}, default = 'LBFGS'
%              If method = 'variational', {'MEANFIELD','FULLRANK'}, default = 'MEANFIELD'
%     sample_file - string, optional
%              Name of file(s) where samples for all parameters are saved.
%              Default = 'output.csv'.
%     diagnostic_file %
%     verbose - bool, optional
%              Specifies whether output is piped to console. Default = false
%     refresh - scalar, optional
%              Number of iterations between reports of sampling progress.
%              Default = max(iter/10,1).
%     stan_home - string, optional
%              Parent directory of CmdStan installation.
%              Default = directory specified in +mstan/stan_home.m
%     working_dir - string, optional
%              Directory for reading/writing models/data.
%              Default = pwd
%     file_overwrite - bool, optional
%              Controls whether .stan files are automatically overwritten
%              when the model changes. Default = false
%              If false, a file dialog is opened when the model is changed
%              allowing the user to specify a different filename, or
%              manually overwrite the current.
%
% OUTPUTS
%     fit - StanFit instance
%     
% EXAMPLES
% 
%     $ Copyright (C) 2014 Brian Lau http://www.subcortex.net/ $
%     Released under the BSD license. The license and most recent version
%     of the code can be found on GitHub:
%     https://github.com/brian-lau/MatlabStan

% TODO
% o error checking to determine whether enough inputs for valid run
% o merging results when fit passed in. overload addition in StanFit
function fit = stan(varargin)

p = inputParser;
p.KeepUnmatched = true;
p.FunctionName = 'stan';
p.addParamValue('fit',[],@(x) isa(x,'StanFit') || isa(x,'StanModel'));
p.addParamValue('method','sample');
p.addParamValue('iter',2000,@(x) isscalar(x) && (x>0));
p.addParamValue('warmup',[],@(x) isscalar(x) && (x>=0));
p.addParamValue('refresh',[],@(x) isscalar(x) && (x>0));
p.addParamValue('algorithm','');
p.parse(varargin{:});

if isempty(p.Results.fit)
   model = StanModel();
elseif isa(p.Results.fit,'StanFit') %FIXME, stan seed is also copied...
   model = copy(p.Results.fit.model);
else
   model = copy(p.Results.fit);
end

model.method = p.Results.method;
if ~isempty(p.Results.iter)
   % Odd defaults from Pystan
   if isempty(p.Results.warmup)
      total_iters = max(round(p.Results.iter),2);
      model.warmup = max(floor(total_iters/2),1);
      model.iter = total_iters - model.warmup;
   else
      model.warmup = p.Results.warmup;
      model.iter = p.Results.iter;
   end
end
if isempty(p.Results.refresh)
   model.refresh = max(round(model.iter/10),1);
else
   model.refresh = p.Results.refresh;
end
if ~isempty(p.Results.algorithm)
   model.algorithm = p.Results.algorithm;
end

switch lower(model.method)
   case 'sample'
      fit = model.sampling(p.Unmatched);
   case 'optimize'
      fit = model.optimizing(p.Unmatched);
   case {'variational' 'vb'}
      fit = model.vb(p.Unmatched);
end

if fit.model == model
   % TODO
   % merge based on param
end
