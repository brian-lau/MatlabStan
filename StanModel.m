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
%     method - string, optional
%              {'sample' 'optimize'}, default = 'sample'
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
%     seed   - scalar, optional
%              Random number generator seed. Default = round(sum(100*clock))
%              Note that this seed is different from Matlab's RNG seed, and
%              is only used to sample from Stan models. For multiple chains
%              each chain is seeded according to a deterministic function
%              of the provided seed to avoid dependency.
%              Default initializes parameters uniformly from (-2,+2)
%     algorithm - string, optional
%              If method = 'sample', {'NUTS','HMC'}, default = 'NUTS'
%              If method = 'optimize', {'BFGS','NESTEROV' 'NEWTON'}, default = 'BFGS'
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
%     stan_version - returns a vector [MAJOR MINOR PATCH] w/ Stan version
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
% unique filenames for outputs?
% expose remaining pystan parameters
% dump reader (to load data as struct)
% model definitions
% compile flags
% Windows
% x inits
% x package organization
% x update for Stan 2.1.0
% x way to determined compiled status? checksum??? force first time compile?
% o fullfile warnings on 2012b

classdef StanModel < handle
   properties(SetAccess = public)
      stan_home
      working_dir
   end
   properties(SetAccess = private)
      model_home = ''% url or path to .stan file
   end
   properties(SetAccess = public, Dependent = true)
      file = ''
      model_name
      model_code
      
      id 
      iter
      warmup
      thin
      seed

      algorithm
      %control
      
      inc_warmup
      sample_file
      diagnostic_file
      refresh
   end
   properties(SetAccess = public)
      method
      init
      data
      chains

      verbose
      file_overwrite
      checksum_stan
      checksum_binary
   end 
   properties(SetAccess = private)
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
      version = '0.5.0';
   end

   methods
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %% Constructor      
      function self = StanModel(varargin)
         p = inputParser;
         p.KeepUnmatched= true;
         p.FunctionName = 'stan constructor';
         p.addParamValue('stan_home',mstan.stan_home);
         p.addParamValue('file','');
         p.addParamValue('model_name','anon_model');
         p.addParamValue('model_code',{});
         p.addParamValue('working_dir',pwd);
         p.addParamValue('method','sample',@(x) validatestring(x,{'sample' 'optimize' 'diagnose'}));
         p.addParamValue('chains',4);
         p.addParamValue('sample_file','',@ischar);
         p.addParamValue('verbose',false,@islogical);
         p.addParamValue('file_overwrite',false,@islogical);
         p.parse(varargin{:});

         self.verbose = p.Results.verbose;
         self.file_overwrite = p.Results.file_overwrite;
         self.stan_home = p.Results.stan_home;
         
         while 1 % FIXME, occasionally stanc does not return version?
            try
               ver = self.stan_version();
               [self.defaults,self.validators] = mstan.stan_params(ver);
               break;
            catch err
               disp('Having a problem getting stan version.');
               disp('Trying again.');
            end
         end
         self.params = self.defaults;         
         
         if isempty(p.Results.file)
            self.model_name = p.Results.model_name;
            self.model_code = p.Results.model_code;
         else
            self.file = p.Results.file;
         end
         self.working_dir = p.Results.working_dir;
         
         self.method = p.Results.method;
         self.chains = p.Results.chains;
         
         if isempty(p.Results.sample_file)
            self.sample_file = self.params.output.file;
         else
            self.sample_file = p.Results.sample_file;
            self.params.output.file = self.sample_file;
         end

         % pass remaining inputs to set()
         self.set(p.Unmatched);
      end
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      function set(self,varargin)
         p = inputParser;
         p.KeepUnmatched= false;
         p.FunctionName = 'StanModel parameter setter';
         p.addParamValue('stan_home',self.stan_home);
         p.addParamValue('file',fullfile(self.model_home,self.file));
         p.addParamValue('model_name',self.model_name);
         p.addParamValue('model_code',self.model_code);
         p.addParamValue('working_dir',self.working_dir);
         p.addParamValue('method',self.method);
         p.addParamValue('sample_file',self.sample_file);
         p.addParamValue('id',self.id);
         p.addParamValue('iter',self.iter);
         p.addParamValue('warmup',self.warmup);
         p.addParamValue('thin',self.thin);
         p.addParamValue('init',self.init);
         p.addParamValue('seed',self.seed);
         p.addParamValue('chains',self.chains);
         p.addParamValue('inc_warmup',self.inc_warmup);
         p.addParamValue('data',[]);
         p.addParamValue('verbose',self.verbose);
         p.addParamValue('file_overwrite',self.file_overwrite);
         p.addParamValue('refresh',self.refresh);
         p.addParamValue('checksum_binary',self.checksum_binary,@isstr);
         p.parse(varargin{:});

         self.verbose = p.Results.verbose;
         self.file_overwrite = p.Results.file_overwrite;
         self.stan_home = p.Results.stan_home;
         if isempty(p.Results.file)
            self.model_name = p.Results.model_name;
            self.model_code = p.Results.model_code;
         else
            self.file = p.Results.file;
         end
         self.working_dir = p.Results.working_dir;
         
         self.method = p.Results.method;
         self.chains = p.Results.chains;
         
         if isempty(p.Results.sample_file)
            self.sample_file = self.params.output.file;
         else
            self.sample_file = p.Results.sample_file;
            self.params.output.file = self.sample_file;
         end
         self.id = p.Results.id;
         self.iter = p.Results.iter;
         self.warmup = p.Results.warmup;
         self.thin = p.Results.thin;
         self.init = p.Results.init;
         self.seed = p.Results.seed;
         self.chains = p.Results.chains;
         self.inc_warmup = p.Results.inc_warmup;
         self.data = p.Results.data;
         self.refresh = p.Results.refresh;
         self.checksum_binary = p.Results.checksum_binary;
      end
      
      function set.stan_home(self,d)
         [~,fa] = fileattrib(d);
         if fa.directory
            if exist(fullfile(fa.Name,'makefile'),'file') && exist(fullfile(fa.Name,'bin'),'dir')
               self.stan_home = fa.Name;
            else
               error('stan:stan_home:InputFormat',...
                  'Does not look like a proper stan setup');
            end
         else
            error('stan:stan_home:InputFormat',...
               'stan_home must be the base directory for stan');
         end
      end
      
      function set.file(self,fname)
         if isempty(fname)
            uigetfile;
         elseif ischar(fname)
            [path,name,ext] = fileparts(fname);
            if isempty(path)
               fname = fullfile(pwd,fname);
            end
            if ~exist(fname)
               error('StanModel:file:NoFile','File does not exist');
            end
            self.update_model('file',fname);
         else
            %error('stan:file:InputFormat','file must be a string');
         end  
      end
            
      function file = get.file(self)
         file = self.file_;
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
      
      function bool = isCompiled(self)
         bool = false;
         if exist(self.model_binary_path,'file')
            % MD5
            checksum = mstan.DataHash(self.model_binary_path);
            if strcmp(checksum,self.checksum_binary)
               bool = true;
            end
            return;
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
         % FIXME , should deblank lines first for leading whitespace
         if any(strncmp('data',model,4)) ...
               || any(strncmp('parameters',model,10))...
               || any(strncmp('model',model,5))
            self.update_model('model_code',model);
         else
            error('does not look like a stan model');
         end
      end
      
      function model_code = get.model_code(self)
         if isempty(self.model_home)
            model_code = {};
            return;
         end
         % Always reread file? Or checksum? or listen for property change?
         % TODO: AbortSet should fix this
         model_code = mstan.read_lines(fullfile(self.model_home,self.file));
      end
      
      function set.model_home(self,d)
         if isempty(d)
            self.model_home = pwd;
         elseif isdir(d)
            [~,fa] = fileattrib(d);
            if fa.UserWrite && fa.UserExecute
               if ~strcmp(self.model_home,fa.Name) && self.verbose
                  fprintf('New model_home set.\n');
               end
               self.model_home = fa.Name;
            else
               error('Must be able to write and execute in model_home');
            end
         else
            error('model_home must be a directory');
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
            
      function set.chains(self,nChains)
         if (nChains>java.lang.Runtime.getRuntime.availableProcessors) || (nChains<1)
            error('stan:chains:InputFormat','# of chains must be from 1 to # of cores.');
         end
         nChains = min(java.lang.Runtime.getRuntime.availableProcessors,max(1,round(nChains)));
         self.chains = nChains;
      end
      
      function set.refresh(self,refresh)
         validateattributes(refresh,self.validators.output.refresh{1},self.validators.output.refresh{2})
         self.params.output.refresh = refresh;
      end
      
      function refresh = get.refresh(self)
         refresh = self.params.output.refresh;
      end
      
      function set.id(self,id)
         validateattributes(id,self.validators.id{1},self.validators.id{2})
         self.params.id = id;
      end
      
      function id = get.id(self)
         id = self.params.id;
      end
            
      function set.iter(self,iter)
         validateattributes(iter,self.validators.sample.num_samples{1},self.validators.sample.num_samples{2})
         self.params.sample.num_samples = iter;
      end
      
      function iter = get.iter(self)
         iter = self.params.sample.num_samples;
      end
      
      function set.warmup(self,warmup)
         validateattributes(warmup,self.validators.sample.num_warmup{1},self.validators.sample.num_warmup{2})
         self.params.sample.num_warmup = warmup;
      end
      
      function warmup = get.warmup(self)
         warmup = self.params.sample.num_warmup;
      end
      
      function set.thin(self,thin)
         validateattributes(thin,self.validators.sample.thin{1},self.validators.sample.thin{2})
         self.params.sample.thin = thin;
      end
      
      function thin = get.thin(self)
         thin = self.params.sample.thin;
      end
      
      function set.init(self,init)
         if isstruct(init) || isa(init,'containers.Map')
            % FIXME: how to contruct filename? also for data
            fname = fullfile(self.working_dir,'temp.init.R');
            mstan.rdump(fname,init);
            self.init = init;
            self.params.init = fname;
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
               self.init = self.defaults.init;
               self.params.init = self.defaults.init;
            else
               validateattributes(init,self.validators.init{1},self.validators.init{2})
               self.init = init;
               self.params.init = init;
            end
         end
      end
      
      function set.seed(self,seed)
         validateattributes(seed,self.validators.random.seed{1},self.validators.random.seed{2})
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
         if strcmp(self.method,'sample')
            if strcmp(algorithm,'hmc')
               algorithm = 'static';
            end
            if any(strcmp(self.validators.sample.hmc.engine,algorithm))
               self.params.sample.hmc.engine = algorithm;
            else
               error('StanModel:algorithm:InputFormat',...
                  'Unknown algorithm for sampler');
            end
         elseif strcmp(self.method,'optimize')
            if any(strcmp(self.validators.optimize.algorithm,algorithm))
               self.params.optimize.algorithm = algorithm;
            else
               error('StanModel:algorithm:InputFormat',...
                  'Unknown algorithm for optimizer');
            end
         end
      end
      
      function algorithm = get.algorithm(self)
         if strcmp(self.method,'sample')
            algorithm = [self.params.sample.algorithm ':' ...
               self.params.sample.hmc.engine];
         elseif strcmp(self.method,'optimize')
            algorithm = self.params.optimize.algorithm;
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
         validateattributes(bool,self.validators.sample.save_warmup{1},self.validators.sample.save_warmup{2})
         self.params.sample.save_warmup = bool;
      end
      
      function bool = get.inc_warmup(self)
         bool = self.params.sample.save_warmup;
      end
      
      function set.data(self,d)
         if isstruct(d) || isa(d,'containers.Map')
            % FIXME: how to contruct filename?
            fname = fullfile(self.working_dir,'temp.data.R');
            mstan.rdump(fname,d);
            self.data = d;
            self.params.data.file = fname;
         elseif ischar(d)
            if exist(d,'file')
               % TODO: read data into struct... what a mess...
               % self.data = dump2struct()
               self.data = 'from file';
               self.params.data.file = d;
            else
               error('StanModel:data:FileNotFound','data file not found');
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
            error('stan:sampling:OutputFormat',...
               'Need to assign the fit to a variable');
         end
         self.set(varargin{:});
         self.method = 'sample';         
         if ~self.isCompiled
            if 1%self.verbose
               fprintf('We have to compile the model first...\n');
            end
            self.compile();
         end
         
         if self.verbose
            fprintf('Stan is sampling with %g chains...\n',self.chains);
         end
         chain_id = 1:self.chains; % TODO chain_id parameter?
         [~,name,ext] = fileparts(self.sample_file);
         base_name = self.sample_file;
         base_id = self.id;
         for i = 1:self.chains
            sample_file{i} = [name '-' num2str(chain_id(i)) ext];
            self.sample_file = sample_file{i};
            % Stan automatically uses the id to advance its RNG. Note that
            % Stan id defaults to 0, although you cannot actually pass this
            % in as a valid value.
            self.id = base_id + chain_id(i) - 1;
            p(i) = processManager('id',sample_file{i},...
                               'command',sprintf('%s',self.command{:}),...
                               'workingDir',self.working_dir,...
                               'wrap',100,...
                               'keepStdout',true,...
                               'pollInterval',1,...
                               'printStdout',self.verbose,...
                               'autoStart',false);
         end
         self.sample_file = base_name;
         self.id = base_id;
         
         % FIXME: should be passing full filenames here or generating them
         % in StanFit (ie, include working_dir)
         fit = StanFit('model',copy(self),'processes',p,...
                       'output_file',cellfun(@(x) fullfile(self.working_dir,x),sample_file,'uni',0),...
                       'verbose',self.verbose);
         p.start();
      end
      
      function fit = optimizing(self,varargin)
         if nargout == 0
            error('stan:optimizing:OutputFormat',...
               'Need to assign the fit to a variable');
         end
         self.set(varargin{:});
         self.method = 'optimize';
         if ~self.isCompiled
            if 1%self.verbose
               fprintf('We have to compile the model first...\n');
            end
            self.compile();
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
      
      function diagnose(self)
         error('not done');
      end
      
      function ver = stan_version(self)
         command = [fullfile(self.stan_home,'bin','stanc') ' --version'];
         p = processManager('id','stanc version','command',command,...
                            'keepStdout',true,...
                            'printStdout',false,...
                            'pollInterval',0.005);
         p.block(0.05);
         if p.exitValue == 0
            str = regexp(p.stdout{1},'\ ','split');
            ver = cellfun(@str2num,regexp(str{3},'\.','split'),'uni',0);
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
      
      function compile(self,target)
         if nargin < 2
            target = 'model';
         end
         if any(strcmp({'stanc' 'libstan.a' 'libstanc.a' 'print'},target))
            % FIXME: does Stan on windows use / or \?
            command = ['make bin/' target];
            printStderr = false;
         elseif strcmp(target,'model')
            command = ['make ' self.model_binary_path];
            printStderr = and(true,self.verbose);
         else
            error('Unknown target');
         end
         p = processManager('id','compile',...
                            'command',command,...
                            'workingDir',self.stan_home,...
                            'keepStdout',true,...
                            'keepStderr',true,...
                            'printStderr',printStderr,...
                            'printStdout',self.verbose);
         p.block(0.05);
         if p.exitValue == 0
            if strcmp(target,'model')
               self.checksum_binary = mstan.DataHash(self.model_binary_path);
            end
         else
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
         for i=1:length(props)
            % Do not copy Transient or Dependent Properties
            if meta.Properties{i}.Transient || meta.Properties{i}.Dependent
               continue;
            end
            new.(props{i}) = S.(props{i});
         end
      end
   end
   
   methods(Access = private)
      function update_model(self,flag,arg)
      % Model must exist with extension .stan, but compiling
      % requires passing the name without extension
      %
      % Pystan,
      % There are three ways to specify the model's code for `stan_model`.
      % 
      %     1. parameter `model_code`, containing a string to whose value is
      %        the Stan model specification,
      % 
      %     2. parameter `file`, indicating a file (or a connection) from
      %        which to read the Stan model specification, or
      % 
      %     3. parameter `stanc_ret`, indicating the re-use of a model
      %          generated in a previous call to `stanc`.
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
         if nargin == 3
            if isempty(arg)
               return;
            end
         end

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
               [path,name,ext] = fileparts(arg);
               if isempty(path)
                  path = pwd;
               end
               if ~strcmp(ext,'.stan')
                  error('include extension');
               end
               self.file_ = [name ext];
               self.model_name_ = name;
               self.model_home = path;
               self.checksum_stan = mstan.DataHash(self.model_path);
               if exist(self.model_binary_path,'file')
                  self.checksum_binary = mstan.DataHash(self.model_binary_path);
               else
                  self.checksum_binary = [];
               end
            case {'model_code'}
               % model name exists (default anon)
               % model home exists
               self.update_model('write',arg);
            case {'write'}
               if isempty(self.model_home)
                  self.model_home = self.working_dir;
               end
               
               fname = self.model_path;
               if exist(fname,'file') == 2
                  % Model file already exists
                  % Only write if contents different, avoid trivial recompiles
                  temp = mstan.read_lines(fname);
                  if all(strcmp(sprintf('%s\n',temp{:}),sprintf('%s\n',arg{:})))
                     self.update_model('file',fname);
                     return;
                  end
                  if self.file_overwrite
                     mstan.write_lines(fname,arg);
                     self.update_model('file',fname);
                  else
                     [filename,filepath] = uiputfile('*.stan','Name stan model');
                     [~,name] = fileparts(filename);
                     self.model_name_ = name;
                     self.model_home = filepath;

                     mstan.write_lines(self.model_path,arg);
                     self.update_model('file',self.model_path);
                  end
               else
                  mstan.write_lines(fname,arg);
                  self.update_model('file',fname);
               end
            otherwise
               error('');
         end
      end
   end
end
