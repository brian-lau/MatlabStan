% STANMODEL - Class defining a Stan model
%
%     obj = StanModel(varargin);
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
% ATTRIBUTES
%     file   - string, optional
%              The string passed is the filename containing the Stan model.
%     stan_version - [MAJOR MINOR PATCH] w/ Stan version
%              This is typically set automatically, but can be set
%              explicitly as a vector [MAJOR MINOR PATCH] if needed
%     method - string, optional
%              {'sample' 'optimize' 'variational'}, default = 'sample'
%     model_code - string, optional
%              String, or cell array of strings containing Stan model.
%              Ignored if 'file' is passed in.
%     model_name - string, optional
%              Name of the model. default = 'anon_model' 
%              However, if 'file' is passed in, then the filename is used 
%              to name the model.
%     data   - struct
%              Data for Stan model. Fieldnames and associated values must 
%              correspond to Stan variable names values.
%     chains - scalar, optional, valid when method = 'sample'
%              Number of chains for . Default = 4
%     iter   - scalar, optional, valid when method = 'sample'
%              Number of iterations for each chain. Default = 1000
%     warmup - scalar, optional, valid when method = 'sample'
%              Number of warmup (aka burnin) iterations. Default = 1000
%     thin   - scalar, optional, valid when method = 'sample'
%              Period for saving samples. Default = 1
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
%              If method = 'optimize', {'BFGS','NESTEROV' 'NEWTON'}, default = 'BFGS'
%              If method = 'variational', {'MEANFIELD','FULLRANK'}, default = 'MEANFIELD'
%     sample_file - string, optional
%              Name of file(s) where samples for all parameters are saved.
%              Default = 'output.csv'.
%     diagnostic_file % not done
%     verbose - bool, optional
%              Specifies whether output is piped to console. Default = false
%     refresh - scalar, optional
%              Number of iterations between reports of sampling progress.
%              Default = 100.
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
% METHODS
%     set    - Set multiple properties (as name/value pairs)
%     compile - string
%              One of 'stanc' 'libstan.a' 'libstanc.a' 'print', which
%              compiles the corresponding elements of CmdStan.
%              Or 'model', which compiles the defined model. Default = 'model'
%     optimizing
%     sampling
%     help
%     command - displays the Stan commandline parameters for current model
%     model_binary_path - returns the path to C++ binary for current model
%     copy - returns a shallow copy of the current model
%
% EXAMPLES
% 
%     $ Copyright (C) 2014 Brian Lau http://www.subcortex.net/ $
%     Released under the BSD license. The license and most recent version
%     of the code can be found on GitHub:
%     https://github.com/brian-lau/MatlabStan

% TODO
% expose remaining pystan parameters
% dump reader (to load data as struct)
% model definitions
% Windows
% o hash for binary doesn't make sense as dependent

classdef StanModel < handle
   properties
      stan_home
      stan_version
      working_dir
      id 
   end
   properties(SetAccess = private)
      model_home = ''% url or path to .stan file
   end
   properties(Dependent = true)
      file = ''
      model_name
      model_code
      
      iter
      warmup
      thin
      seed

      algorithm
      control
      
      inc_warmup
      sample_file
      diagnostic_file
      refresh
   end
   properties
      method
      init
      data
      chains

      verbose
      file_overwrite
   end 
   properties(SetAccess = private, Dependent = true)
      checksum_stan
      checksum_binary
      command
   end
   properties(SetAccess = private, Hidden = true)
      params
      defaults
      validators
      
      file_
      model_name_
   end
   properties(SetAccess = protected)
      version = '0.9.0';
   end

   methods
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %% Constructor      
      function self = StanModel(varargin)
         p = inputParser;
         p.KeepUnmatched = true;
         p.FunctionName = 'StanModel constructor';
         p.addParamValue('stan_home',mstan.stan_home);
         p.addParamValue('stan_version',[],@(x) isnumeric(x) && numel(x)==3);
         p.addParamValue('file','');
         p.addParamValue('model_name','anon_model');
         p.addParamValue('model_code',{});
         p.addParamValue('id','',@ischar);
         p.addParamValue('working_dir',pwd);
         p.addParamValue('method','sample',@(x) any(strcmp(x,...
            {'sample' 'optimize' 'variational' 'diagnose'})));
         p.addParamValue('chains',4);
         p.addParamValue('sample_file','',@ischar);
         p.addParamValue('verbose',false,@islogical);
         p.addParamValue('file_overwrite',false,@islogical);
         p.parse(varargin{:});

         self.verbose = p.Results.verbose;
         self.file_overwrite = p.Results.file_overwrite;
         self.stan_home = p.Results.stan_home;

         if ~exist('processManager')
            error('StanModel:constructor:MissingFunction',...
               'processManager (https://github.com/brian-lau/MatlabProcessManager) is required');
         end

         if isempty(p.Results.id)
            self.random_id();
         else
            self.id = p.Results.id;
         end
         
         if isempty(p.Results.stan_version)
            self.stan_version = self.get_stan_version();
         else
            self.stan_version = p.Results.stan_version;
         end
         
         [self.defaults,self.validators] = mstan.stan_params(self.stan_version);
         self.params = self.defaults;
         
         if isempty(p.Results.file)
            self.file = '';
            self.model_name = p.Results.model_name;
            self.model_code = p.Results.model_code;
         else
            self.file = p.Results.file;
         end
         self.working_dir = p.Results.working_dir;
         
         self.method = p.Results.method;
         self.chains = p.Results.chains;
         
         if isempty(p.Results.sample_file)
            self.params.output.file = [self.id '-output.csv'];
         end

         % pass remaining inputs to set()
         self.set(p.Unmatched);
      end
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      function set(self,varargin)
         p = inputParser;
         p.KeepUnmatched = false;
         p.FunctionName = 'StanModel parameter setter';
         p.addParamValue('stan_home',self.stan_home);
         p.addParamValue('file',self.file);
         p.addParamValue('model_name',self.model_name);
         p.addParamValue('model_code',self.model_code);
         p.addParamValue('id',self.id);
         p.addParamValue('working_dir',self.working_dir);
         p.addParamValue('method',self.method);
         p.addParamValue('sample_file',self.sample_file);
         p.addParamValue('iter',self.iter);
         p.addParamValue('warmup',self.warmup);
         p.addParamValue('thin',self.thin);
         p.addParamValue('init',self.init);
         p.addParamValue('seed',self.seed);
         p.addParamValue('control',self.control);
         p.addParamValue('chains',self.chains);
         p.addParamValue('inc_warmup',self.inc_warmup);
         p.addParamValue('data',[]);
         p.addParamValue('verbose',self.verbose);
         p.addParamValue('file_overwrite',self.file_overwrite);
         p.addParamValue('refresh',self.refresh);
         p.parse(varargin{:});

         self.verbose = p.Results.verbose;
         self.file_overwrite = p.Results.file_overwrite;
         self.stan_home = p.Results.stan_home;
         if isempty(p.Results.file)
            self.model_name = p.Results.model_name;
            self.model_code = p.Results.model_code;
         else
            % Update only if we are not pointing to the same file
            if ~strcmp(fullfile(self.model_home,self.file),self.model_path)
               self.file = p.Results.file;
            end
         end
         self.working_dir = p.Results.working_dir;
         
         if ~isempty(p.Results.id)
            self.id = p.Results.id;
         end
         self.params.output.file = [self.id '-output.csv'];
        
         self.method = p.Results.method;
         self.chains = p.Results.chains;
         self.iter = p.Results.iter;
         self.warmup = p.Results.warmup;
         self.thin = p.Results.thin;
         self.init = p.Results.init;
         self.seed = p.Results.seed;
         self.control = p.Results.control;
         self.chains = p.Results.chains;
         self.inc_warmup = p.Results.inc_warmup;
         self.data = p.Results.data;
         self.refresh = p.Results.refresh;
      end
      
      function set.stan_home(self,d)
         [success,fa] = fileattrib(d);
         if ~success
            error('StanModel:stan_home:InputFormat',...
               'Can''t parse stan_home. Is it set correctly?');
         end
         if fa.directory
            if exist(fullfile(fa.Name,'makefile'),'file') ...
                  && exist(fullfile(fa.Name,'bin'),'dir')
               self.stan_home = fa.Name;
            else
               % TODO make this message more informative
               error('StanModel:stan_home:InputFormat',...
                  'Does not look like a proper stan setup');
            end
         else
            error('StanModel:stan_home:InputFormat',...
               'stan_home must be the base directory for stan');
         end
      end
      
      function set.file(self,fname)
         if isempty(fname)
            self.update_model('file','');
         elseif ischar(fname)
            [path,name,ext] = fileparts(fname);
            if isempty(path)
               fname = fullfile(pwd,fname);
            end
            if ~exist(fname,'file')
               error('StanModel:file:NoFile','File does not exist');
            end
            self.update_model('file',fname);
         else
            %error('StanModel:file:InputFormat','file must be a string');
         end  
      end
      
      function file = get.file(self)
         file = self.file_;
      end
      
      function select_file(self)
         [name,path] = uigetfile('*.stan','Name stan model');
         self.update_model('file',fullfile(path,name));
      end
 
      function set.model_name(self,model_name)
         if ischar(model_name) && (numel(model_name)>0)
            if isempty(self.file)
               self.model_name_ = model_name;
            else
               self.update_model('model_name',model_name);
            end
            
         else
            error('stan:model_name:InputFormat',...
               'model_name should be a non-empty string');
         end
      end
            
      function model_name = get.model_name(self)
         model_name = self.model_name_;
      end
      
      function path = model_path(self)
         path = fullfile(self.model_home,[self.model_name '.stan']);
      end
      
      function binary_path = model_binary_path(self)
         if ispc % FIXME is this necessary in Stan 2.1?
            binary_path = fullfile(self.model_home,[self.model_name '.exe']);
         else
            binary_path = fullfile(self.model_home,self.model_name);
         end
      end
      
      function bool = is_compiled(self)
         bool = false;
         if ~isempty(dir(self.model_binary_path))
            % MD5
            chk = mstan.DataHash(self.model_binary_path,struct('Input','file'));
            if strcmp(chk,self.checksum_binary)
               bool = true;
            end
            return;
         end
      end
      
      function chk = get.checksum_stan(self)
         if exist(self.model_path,'file')
            chk = mstan.DataHash(self.model_path,struct('Input','file'));
         else
            chk = '';
         end
      end
      
      function chk = get.checksum_binary(self)
         if exist(self.model_binary_path,'file')
            chk = mstan.DataHash(self.model_binary_path,struct('Input','file'));
         else
            chk = '';
         end
      end      
      
      function set.model_code(self,model)
         if isempty(model)
            return;
         end
         if ischar(model)
            % Convert a char array into a cell array of strings split by line
            model = regexp(model,'(\r\n|\n|\r)','split')';
         end
         temp = strtrim(model);
         if any(strncmp('data',temp,4)) ...
               || any(strncmp('parameters',temp,10))...
               || any(strncmp('model',temp,5))
            self.update_model('model_code',model);
         else
            error('StanModel:model_code:InputFormat',...
               'does not look like a stan model');
         end
      end
      
      function model_code = get.model_code(self)
         if isempty(self.file_)%isempty(self.model_home)
            model_code = {};
         else
            % Always reread file? Or checksum? or listen for property change?
            % TODO: AbortSet should fix this
            model_code = mstan.read_lines(fullfile(self.model_home,self.file));
         end
      end
      
      function set.model_home(self,d)
         if isempty(d)
            self.model_home = pwd;
         elseif isdir(d)
            [~,fa] = fileattrib(d);
            if fa.UserWrite && fa.UserExecute
               self.model_home = fa.Name;
            else
               error('StanModel:model_home:NoWritePermission',... 
                  'Must be able to write and execute in model_home');
            end
         else
            error('StanModel:model_home:InputFormat',... 
               'model_home must be a directory');
         end
      end
      
      function set.working_dir(self,d)
         if isdir(d)
            [~,fa] = fileattrib(d);
            if fa.directory && fa.UserWrite && fa.UserRead
               self.working_dir = fa.Name;
            else
               self.working_dir = tempdir;
            end
         else
            error('StanModel:working_dir:InputFormat',...
               'working_dir must be a directory');
         end
      end
      
      function set.method(self,method)
         assert(ischar(method),'Method must be a string');
         method = lower(method);
         assert(any(strcmp(method,{'sample','optimize','variational'})),...
            'Method must be one of ''sample'', ''optimize'', ''variational''');
         
         if any(strcmp(method,{'optimize' 'variational'}))
            self.chains = 1;
         end
         self.method = method;
      end
      
      function set.chains(self,n_chains)
         n_processors = java.lang.Runtime.getRuntime.availableProcessors;
         if n_chains < 1
            fprintf('Setting # of chains = 1\n');
            n_chains = 1;
         elseif n_chains > n_processors
            warning('stan:chains:InputFormat','# of chains > # of cores.');
         end
         
         if any(strcmp(self.method,{'optimize' 'variational'}))
            self.chains = 1;
         else
            self.chains = round(n_chains);
         end
         
         if self.chains < numel(self.init)
            self.init = self.init(1:self.chains);
         elseif self.chains > numel(self.init)
            % TODO
            if isempty(self.init)
               self.init = []; % Default
            elseif numel(self.init) == 1
               self.init(2:n_chains) = self.init;
            elseif isstruct(self.init)
               temp = num2cell(self.init);
               if isequal(temp{:})
                  self.init(numel(self.init):n_chains) = self.init(1);
               else
                  self.init = [];
               end
            elseif all(self.init == self.init(1))
               self.init(numel(self.init)+1:n_chains) = self.init(1);
            else
               self.init = []; % Default
            end
         end
      end
      
      function set.refresh(self,refresh)
         validateattributes(refresh,self.validators.output.refresh{1},...
            self.validators.output.refresh{2})
         self.params.output.refresh = refresh;
      end
      
      function refresh = get.refresh(self)
         refresh = self.params.output.refresh;
      end
      
      function set.id(self,id)
         if ischar(id) && ~isempty(id)
            self.id = id;
            % Update the output filename
            self.params.output.file = [self.id '-output.csv'];
         else
            error('bad id');
         end
      end
      
      function random_id(self)
         self.id = mstan.randomUUID('base62');
      end
                  
      function set.iter(self,iter)
         validateattributes(iter,self.validators.sample.num_samples{1},...
            self.validators.sample.num_samples{2})
         self.params.sample.num_samples = iter;
      end
      
      function iter = get.iter(self)
         iter = self.params.sample.num_samples;
      end
      
      function set.warmup(self,warmup)
         validateattributes(warmup,self.validators.sample.num_warmup{1},...
            self.validators.sample.num_warmup{2})
         self.params.sample.num_warmup = warmup;
      end
      
      function warmup = get.warmup(self)
         warmup = self.params.sample.num_warmup;
      end
      
      function set.thin(self,thin)
         validateattributes(thin,self.validators.sample.thin{1},...
            self.validators.sample.thin{2})
         self.params.sample.thin = thin;
      end
      
      function thin = get.thin(self)
         thin = self.params.sample.thin;
      end
      
      function set.init(self,init)
         % Set initial conditions for chains
         % Can have different inits for each chain
         if isstruct(init) || isa(init,'containers.Map')
            nChains = numel(init);
            for i = 1:nChains
               fname = fullfile(self.working_dir,[self.id '-init-' num2str(i) '.R']);
               mstan.rdump(fname,init(i));
               fnames{i} = fname;
            end
            self.init = init(:)';
            self.params.init = fnames;
         elseif ischar(init)
            if exist(init,'file') %% FIXME: exist checks in entire Matlabpath
               % TODO: read data into struct... what a mess...
               % self.data = dump2struct()
               self.init = 'from file';
               self.params.init = init;
            else
               error('StanModel:init:FileNotFound','init file not found');
            end
         else
            if isempty(init)
               nChains = self.chains;
               self.init = repmat(self.defaults.init,1,nChains);
               self.params.init = self.defaults.init;
            else
               nChains = numel(init);
               for i = 1:nChains
                  validateattributes(init(i),self.validators.init{1},...
                     self.validators.init{2});
               end
               self.init = init(:)';
               self.params.init = init(:)';
            end
         end
         
         if self.chains ~= nChains
            % TODO, setter getting called repeatedly?
            self.chains = nChains;
         end
      end
      
      function set.seed(self,seed)
         validateattributes(seed,self.validators.random.seed{1},...
            self.validators.random.seed{2})
         if seed < 0
            self.params.random.seed = round(sum(100*clock));
         else
            self.params.random.seed = seed;
         end
      end
      
      function seed = get.seed(self)
         seed = self.params.random.seed;
      end
      
      function set.algorithm(self,algorithm)
         algorithm = lower(algorithm);
         switch lower(self.method)
            case 'optimize'
               if any(strcmp(self.validators.optimize.algorithm,algorithm))
                  self.params.optimize.algorithm = algorithm;
               else
                  error('StanModel:algorithm:InputFormat',...
                     'Unknown algorithm for optimizer');
               end
            case 'sample'
               if strcmp(algorithm,'hmc')
                  algorithm = 'static';
               end
               if any(strcmp(self.validators.sample.hmc.engine,algorithm))
                  self.params.sample.hmc.engine = algorithm;
               else
                  error('StanModel:algorithm:InputFormat',...
                     'Unknown algorithm for sampler');
               end
            case 'variational'
               if any(strcmp(self.validators.variational.algorithm,algorithm))
                  self.params.variational.algorithm = algorithm;
               else
                  error('StanModel:algorithm:InputFormat',...
                     'Unknown algorithm for variational inference');
               end
         end
      end
      
      function algorithm = get.algorithm(self)
         switch lower(self.method)
            case 'optimize'
               algorithm = self.params.optimize.algorithm;
            case 'sample'
               algorithm = [self.params.sample.algorithm ':' ...
                  self.params.sample.hmc.engine];
            case 'variational'
               algorithm = self.params.variational.algorithm;
         end
      end
      
      function set.control(self,control)
         if ~isempty(control)
            assert(isstruct(control),'StanModel:control:InputFormat',...
               'control must be a structure');
            fn = fieldnames(control);
            for i = 1:numel(fn)
               switch lower(fn{i})
                  case {'engaged' 'adapt_engaged'}
                     set_adapt_engaged(self,control.(fn{i}));
                  case {'gamma' 'adapt_gamma'}
                     set_adapt_gamma(self,control.(fn{i}));
                  case {'delta' 'adapt_delta'}
                     set_adapt_delta(self,control.(fn{i}));
                  case {'kappa' 'adapt_kappa'}
                     set_adapt_kappa(self,control.(fn{i}));
                  case {'t0' 'adapt_t0'}
                     set_adapt_t0(self,control.(fn{i}));
                  case {'init_buffer' 'adapt_init_buffer'}
                     set_adapt_init_buffer(self,control.(fn{i}));
                  case {'term_buffer' 'adapt_term_buffer'}
                     set_adapt_term_buffer(self,control.(fn{i}));
                  case {'window' 'adapt_window'}
                     set_adapt_window(self,control.(fn{i}));
                  case {'metric' 'hmc_metric'}
                     set_hmc_metric(self,control.(fn{i}));
                  case {'stepsize' 'hmc_stepsize'}
                     set_hmc_stepsize(self,control.(fn{i}));
                  case {'stepsize_jitter' 'hmc_stepsize_jitter'}
                     set_hmc_stepsize_jitter(self,control.(fn{i}));
                  otherwise
                     fprintf('%s is not an adapt or hmc parameter\n',fn{i});
               end
            end
         end
      end
      
      function control = get.control(self)
         switch lower(self.method)
            case 'optimize'
               control = [];
            case 'sample'
               control = self.params.sample.adapt;
               if strncmp(self.algorithm,'hmc',3)
                  control.metric = self.params.sample.hmc.metric;
                  control.stepsize = self.params.sample.hmc.stepsize;
                  control.stepsize_jitter = self.params.sample.hmc.stepsize_jitter;
               end
            case 'variational'
               control = [];
         end
      end
      
      function set.diagnostic_file(self,name)
         if ischar(name)
            self.params.output.diagnostic_file = name;
         end
      end
      
      function name = get.diagnostic_file(self)
         name = self.params.output.diagnostic_file;
      end
      
      function set.sample_file(self,name)
         if ischar(name)
            self.params.output.file = name;
         end
      end
      
      function name = get.sample_file(self)
         name = self.params.output.file;
      end
      
      function set.inc_warmup(self,bool)
         validateattributes(bool,self.validators.sample.save_warmup{1},...
            self.validators.sample.save_warmup{2})
         self.params.sample.save_warmup = bool;
      end
      
      function bool = get.inc_warmup(self)
         bool = self.params.sample.save_warmup;
      end
      
      function set.data(self,d)
         if isstruct(d) || isa(d,'containers.Map') || isa(d,'RData')
            % FIXME: how to contruct filename?
            fname = fullfile(self.working_dir,[self.id '-data.R']);
            if isa(d,'RData')
               rdump(d,fname);
            else
               mstan.rdump(fname,d);
            end               
            self.data = d;
            self.params.data.file = fname;
         elseif ischar(d)
            if exist(d,'file')
               % TODO: read data into struct... what a mess...
               % self.data = dump2struct()
               self.data = 'from file';
               self.params.data.file = d;
            else
               %error('StanModel:data:FileNotFound','data file not found');
            end
         else
            %error('StanModel:data:InputFormat','not done');
         end
      end            
            
      function command = get.command(self)
         command = {[self.model_binary_path ' ']};
         str = mstan.parse_stan_params(self.params,self.method);
         command = cat(1,command,str);
      end
      
      function fit = sampling(self,varargin)
         if nargout == 0
            error('StanModel:sampling:OutputFormat',...
               'Need to assign the fit to a variable');
         end
         self.set(varargin{:});
         self.method = 'sample';         
         if ~self.is_compiled
            if self.verbose
               fprintf('We have to compile the model first...\n');
            end
            self.compile('model');
         end
         
         if self.verbose
            fprintf('Stan is sampling with %g chains...\n',self.chains);
         end
         
         [~,name,ext] = fileparts(self.sample_file);
         base_name = self.sample_file;
         for i = 1:self.chains
            % Set a filename for each chain
            sample_file{i} = [name '-' num2str(i) ext];
            self.sample_file = sample_file{i};
            
            % Give Stan a different id for each chain. This is used to advance 
            % Stan's RNG to ensure that draws come from non-overlapping sequences.
            self.params.id = i;
            
            % Chain specific inits
            if isstruct(self.init) || isa(self.init,'containers.Map')
               self.params.init = fullfile(self.working_dir,[self.id '-init-' num2str(i) '.R']);
            else
               self.params.init = self.init(i);
            end
            
            p(i) = processManager('id',sample_file{i},...
                               'command',sprintf('%s',self.command{:}),...
                               'workingDir',self.working_dir,...
                               'wrap',100,...
                               'keepStdout',true,...
                               'pollInterval',1,...
                               'printStdout',self.verbose,...
                               'autoStart',false);
         end
         
         % Reset base name
         self.sample_file = base_name;
         self.params.init = self.init;
         
         fit = StanFit('model',copy(self),'processes',p,...
                       'output_file',cellfun(@(x) fullfile(self.working_dir,x),sample_file,'uni',0),...
                       'verbose',self.verbose);
         p.start();
      end
      
      function fit = optimizing(self,varargin)
         if nargout == 0
            error('StanModel:optimizing:OutputFormat',...
               'Need to assign the fit to a variable');
         end
         self.set(varargin{:});
         self.method = 'optimize';
         if ~self.is_compiled
            if self.verbose
               fprintf('We have to compile the model first...\n');
            end
            self.compile('model');
         end
         
         if self.verbose
            fprintf('Stan is optimizing ...\n');
         end
         
         p = processManager('id',self.sample_file,...
                            'command',sprintf('%s',self.command{:}),...
                            'workingDir',self.working_dir,...
                            'wrap',100,...
                            'keepStdout',true,...
                            'pollInterval',1,...
                            'printStdout',self.verbose,...
                            'autoStart',false);

         fit = StanFit('model',copy(self),'processes',p,...
                       'output_file',{fullfile(self.working_dir,self.sample_file)},...
                       'verbose',self.verbose);
         p.start();
      end
      
      function fit = vb(self,varargin)
         if nargout == 0
            error('StanModel:vb:OutputFormat',...
               'Need to assign the fit to a variable');
         end
         self.set(varargin{:});
         self.method = 'variational';
         if ~self.is_compiled
            if self.verbose
               fprintf('We have to compile the model first...\n');
            end
            self.compile('model');
         end
         
         if self.verbose
            fprintf('Stan is performing variational inference ...\n');
         end
         
         p = processManager('id',self.sample_file,...
                            'command',sprintf('%s',self.command{:}),...
                            'workingDir',self.working_dir,...
                            'wrap',100,...
                            'keepStdout',true,...
                            'pollInterval',1,...
                            'printStdout',self.verbose,...
                            'autoStart',false);

         fit = StanFit('model',copy(self),'processes',p,...
                       'output_file',{fullfile(self.working_dir,self.sample_file)},...
                       'verbose',self.verbose);
         p.start();
      end
      
      function diagnose(self)
         error('not done');
      end

      function ver = get_stan_version(self)
         % Get Stan version by calling stanc
         count = 0;
         while 1 % Occasionally stanc does not return version?
            try
               ver = self.get_stan_version_();
               if count > 0
                  disp('Succeeded in getting stan version.');
               end
               break;
            catch err
               if count == 0
                  disp('Having a problem getting stan version.');
                  disp('This is likely a problem with Java running out of file descriptors');
               end
               if count <= 5
                   disp('Trying again.');
                   pause(0.25);
               else
                   disp('Giving up.');
                   disp('You can try setting the Stan version explicitly using the stan_version attribute.');
                   disp('i.e. StanModel.stan_version = [2 15 0]');
                   rethrow(err);
               end
               count = count + 1;
            end
         end        
      end
      
      function ver = get_stan_version_(self)
         command = [fullfile(self.stan_home,'bin','stanc') ' --version'];
         p = processManager('id','stanc version','command',command,...
                            'keepStdout',true,...
                            'printStdout',false,...
                            'pollInterval',0.005);
         p.block(0.05);
         if p.exitValue == 0
            str = regexp(p.stdout{1},'\ ','split');
            ver = cellfun(@str2num,regexp(str{3},'\.','split'));
         else
            fprintf('%s\n',p.stdout{:});
         end
      end
      
      function help(self,str)
         % TODO: 
         % if str is stanc or other basic binary
         %else
         % need to check that model binary exists
         command = [self.model_binary_path ' ' str ' help'];
         p = processManager('id','stan help','command',command,...
                            'workingDir',self.model_home,...
                            'wrap',100,...
                            'keepStdout',true,...
                            'printStdout',false);
         p.block(0.05);
         if p.exitValue == 0
            % Trim off the boilerplate
            ind = find(strncmp('Usage: ',p.stdout,7));
            fprintf('%s\n',p.stdout{1:ind-1});
         else
            fprintf('%s\n',p.stdout{:});
         end
      end
      
      function config(self)
         % Get CmdStan configuration
         p = processManager('id','stan help','command','make help-dev',...
                            'workingDir',self.stan_home,...
                            'wrap',100,...
                            'keepStdout',true,...
                            'printStdout',false);
         p.block(0.05);
         fprintf('%s\n',p.stdout{:});
      end
      
      function compile(self,target,flags)
         % Compile CmdStan components and models
         if nargin < 3
            flags = '';
         elseif iscell(flags) && all(cellfun(@(x) ischar(x),flags))
            flags = sprintf('%s ',flags{:});
         elseif ischar(flags)
            flags = sprintf('%s ',flags);
         else
            error('StanModel:compile:InputFormat',...
               'flags should be formatted as a string or cell array of strings');
         end
         
         if nargin < 2
            target = 'model';
         end
         
         switch lower(target)
            case {'stanc' 'libstan.a' 'libstanc.a' 'print' 'stansummary'}
               % FIXME: does Stan on windows use / or \?
               command = ['make ' flags 'bin/' target];
               printStderr = false;
            case 'model'
               if ispc
                  command = ['make ' flags regexprep(self.model_binary_path,'\','/')];
               else
                  command = ['make ' flags self.model_binary_path];
               end
               printStderr = and(true,self.verbose);
            otherwise
               error('StanModel:compile:InputFormat',...
                  'Unknown target');
         end

         p = processManager('id','compile',...
                            'command',command,...
                            'workingDir',self.stan_home,...
                            'keepStdout',true,...
                            'keepStderr',true,...
                            'printStderr',printStderr,...
                            'printStdout',self.verbose);
         p.block(0.05);
         if p.exitValue ~= 0
            fprintf('Compile failed with exit value: %g\n',p.exitValue);
            error('StanModel:compile:failure','%s\n',p.stderr{:});
         end
      end
      
%       function disp(self)
% 
%       end

      function new = copy(self)
         % Shallow copy handle object
         %http://www.mathworks.com/matlabcentral/newsreader/view_thread/257925
         meta = metaclass(self);
         props = cellfun(@(x) x.Name,meta.Properties,'uni',0);
         
         new = eval(class(self));
         warning off MATLAB:structOnObject
         S = struct(self);
         warning on MATLAB:structOnObject
         for i = 1:length(props)
            % Do not copy Transient or Dependent Properties
            if meta.Properties{i}.Transient || meta.Properties{i}.Dependent
               continue;
            end
            new.(props{i}) = S.(props{i});
         end
      end
   end
   
   methods(Access = private)
      function set_adapt_engaged(self,bool)
         validateattributes(bool,self.validators.sample.adapt.engaged{1},...
            self.validators.sample.adapt.engaged{2})
         self.params.sample.adapt.engaged = bool;
      end
      
      function set_adapt_gamma(self,val)
         validateattributes(val,self.validators.sample.adapt.gamma{1},...
            self.validators.sample.adapt.gamma{2})
         self.params.sample.adapt.gamma = val;
      end
            
      function set_adapt_delta(self,val)
         validateattributes(val,self.validators.sample.adapt.delta{1},...
            self.validators.sample.adapt.delta{2})
         self.params.sample.adapt.delta = val;
      end
            
      function set_adapt_kappa(self,val)
         validateattributes(val,self.validators.sample.adapt.kappa{1},...
            self.validators.sample.adapt.kappa{2})
         self.params.sample.adapt.kappa = val;
      end
            
      function set_adapt_t0(self,val)
         validateattributes(val,self.validators.sample.adapt.t0{1},...
            self.validators.sample.adapt.t0{2})
         self.params.sample.adapt.t0 = val;
      end
      
      function set_adapt_init_buffer(self,val)
         validateattributes(val,self.validators.sample.adapt.init_buffer{1},...
            self.validators.sample.adapt.init_buffer{2})
         self.params.sample.adapt.init_buffer = val;
      end
      
      function set_adapt_term_buffer(self,val)
         validateattributes(val,self.validators.sample.adapt.term_buffer{1},...
            self.validators.sample.adapt.term_buffer{2})
         self.params.sample.adapt.term_buffer = val;
      end
      
      function set_adapt_window(self,val)
         validateattributes(val,self.validators.sample.adapt.window{1},...
            self.validators.sample.adapt.window{2})
         self.params.sample.adapt.window = val;
      end
      
      function set_hmc_metric(self,val)
         assert(any(strcmp(self.validators.sample.hmc.metric,val)),...
            'StanModel:set_hmc_metric:InputFormat','Invalid value for hmc_metric');
         self.params.sample.hmc.metric = val;
      end
      
      function set_hmc_stepsize(self,val)
         validateattributes(val,self.validators.sample.hmc.stepsize{1},...
            self.validators.sample.hmc.stepsize{2})
         self.params.sample.hmc.stepsize = val;
      end
      
      function set_hmc_stepsize_jitter(self,val)
         validateattributes(val,self.validators.sample.hmc.stepsize_jitter{1},...
            self.validators.sample.hmc.stepsize_jitter{2})
         self.params.sample.hmc.stepsize_jitter = val;
      end
      
      function update_model(self,flag,arg)
      % Model must exist with extension .stan, but compiling
      % requires passing the name without extension
      %
      % in stan object, model is defined by three attributes,
      %   1) a name
      %   2) a file on disk (or url)
      %   3) code
      % 1) does not include the .stan extension, and should always match the 
      % name of the file (2, sans extension). 3) is always read directly from
      % 2). This means, when either 1) or 2) change, we have to update 2) and 
      % 1), respectively.
      % Changing the model_name
      %    write a new file matching model_name (check overwrite)
      % Changing the file
      %    set file, model_name, model_home
      % Changing the code
      %    write a new file matching model_name (check overwrite)

         switch lower(flag)
            case {'model_name'}
               [~,name,ext] = fileparts(arg);
               if isempty(self.model_code)
                  % no code, model not defined
                  self.model_name_ = name;
               else
                  % have code
                  self.model_name_ = name;
                  self.update_model('write',self.model_code);
               end
            case {'file'}
               if isempty(arg)
                  self.file_ = '';
                  self.model_name_ = '';
                  self.model_home = '';
               else
                  [path,name,ext] = fileparts(arg);
                  if isempty(path)
                     path = pwd;
                  end
                  if ~strcmp(ext,'.stan')
                     if exist(fullfile(path,[name '.stan']))
                        ext = '.stan';
                     else
                        error('StanModel:update_model:InputFormat',...
                           'File defining Stan modelmust include .stan extension');
                     end
                  end
                  self.file_ = [name ext];
                  self.model_name_ = name;
                  self.model_home = path;
               end
            case {'model_code'}
               % model name exists (default anon)
               % model home exists
               if ~isempty(arg)
                  self.update_model('write',arg);
               end
            case {'write'}
               if isempty(self.model_home)
                  self.model_home = self.working_dir;
               end
               
               fname = self.model_path;
               if exist(fname,'file')
                  % Model file already exists
                  % Only write if contents different, avoid trivial recompiles
                  % Cannot be certain that binary did not change?
%                   temp = mstan.read_lines(fname);
%                   if all(strcmp(sprintf('%s\n',temp{:}),sprintf('%s\n',arg{:})))%all(strcmp(temp,arg))
%                      self.update_model('file',fname);
%                      return;
%                   end
                  if self.file_overwrite
                     mstan.write_lines(fname,arg);
                     self.update_model('file',fname);
                     self.delete_binary();
                  else
                     [filename,filepath] = uiputfile('*.stan','Name stan model');
                     [~,name] = fileparts(filename);
                     self.model_name_ = name;
                     self.model_home = filepath;

                     mstan.write_lines(self.model_path,arg);
                     self.update_model('file',self.model_path);
                     self.delete_binary();
                  end
               else
                  mstan.write_lines(fname,arg);
                  self.update_model('file',fname);
                  self.delete_binary();
               end
            otherwise
               error('');
         end
      end
      
      function delete_binary(self)
         if exist([self.model_binary_path],'file')
            delete(self.model_binary_path);
         end
         if exist([self.model_binary_path '.cpp'],'file')
            delete([self.model_binary_path '.cpp']);
         end
         if exist([self.model_binary_path '.d'],'file')
            delete([self.model_binary_path '.d']);
         end
         if exist([self.model_binary_path '.o'],'file')
            delete([self.model_binary_path '.o']);
         end
      end
   end
end
