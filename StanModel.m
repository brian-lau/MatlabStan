% note how init is handled for multiple chains
% https://groups.google.com/forum/?fromgroups#!searchin/stan-users/command$20line/stan-users/2YNalzIGgEs/NbbDsM9R9PMJ
% bash script for stan
% https://groups.google.com/forum/?fromgroups#!topic/stan-dev/awcXvXxIfHg
%
% TODO
% expose remaining pystan parameters
% clean up parameter handling
% package organization, should classes be in package?
% inits
% update for Stan 2.1.0
% dump reader (to load data as struct)
% model definitions
% x way to determined compiled status? checksum??? force first time compile?
%
classdef StanModel < handle
   properties(SetAccess = public)
      stan_home = mstan.stan_home
      working_dir
   end
   properties(SetAccess = private)
      model_home % url or path to .stan file
   end
   properties(SetAccess = public, Dependent = true)
      file
      model_name
      model_code
      
      id 
      iter
      warmup
      thin
      seed

      %algorithm
      init
      
      inc_warmup
      sample_file
      diagnostic_file
      refresh
   end
   properties(SetAccess = public)
      method
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
      version = '0.1.0';
   end

   methods
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %% Constructor      
      function self = StanModel(varargin)
         [self.defaults,self.validators] = mstan.stan_params();
         self.params = self.defaults;
         self.working_dir = pwd;

         p = inputParser;
         p.KeepUnmatched= true;
         p.FunctionName = 'stan constructor';
         p.addParamValue('stan_home',self.stan_home);
         p.addParamValue('file','');
         p.addParamValue('model_name','anon_model');
         p.addParamValue('model_code',{});
         p.addParamValue('working_dir',pwd);
         p.addParamValue('method','sample',@(x) validatestring(x,{'sample' 'optimize' 'diagnose'}));
         p.addParamValue('chains',4);
         p.addParamValue('inc_warmup',false);
         p.addParamValue('sample_file','',@ischar);
         p.addParamValue('refresh',self.defaults.output.refresh,@isnumeric);
         p.addParamValue('verbose',false,@islogical);
         p.addParamValue('file_overwrite',false,@islogical);
         p.parse(varargin{:});

         self.verbose = p.Results.verbose;
         self.file_overwrite = p.Results.file_overwrite;
         self.stan_home = p.Results.stan_home;
         self.file = p.Results.file;
         if isempty(self.file)
            self.model_name = p.Results.model_name;
         end
         self.model_code = p.Results.model_code;
         self.working_dir = p.Results.working_dir;
         
         self.method = p.Results.method;
         self.inc_warmup = p.Results.inc_warmup;
         self.chains = p.Results.chains;
         
         self.refresh = p.Results.refresh;
         if isempty(p.Results.sample_file)
            self.sample_file = self.params.output.file;
         else
            self.sample_file = p.Results.sample_file;
            self.params.output.file = self.sample_file;
         end
         
         % pass remaining inputs to set()
         self.set(p.Unmatched);
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
         if ischar(fname)
            self.update_model('file',fname);
         else
            error('stan:file:InputFormat','file must be a string');
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
         binary_path = fullfile(self.model_home,self.model_name);
      end
      
%       function bool = isValid(self)
%       end
      function bool = isCompiled(self)
         %binary exists else false
         %md5 matches cached md5 else false
         bool = false;
         if exist(self.model_binary_path,'file')
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
         if any(strncmp('data',model,4)) || any(strncmp('parameters',model,10)) || any(strncmp('model',model,5))
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
            error('working_dir must be a directory');
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
         self.params.output.refresh = refresh;
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
         % handle vector case, looks like it will require writing to dump
         % file as well
         validateattributes(init,self.validators.init{1},self.validators.init{2})
         self.params.init = init;
      end
      
      function init = get.init(self)
         init = self.params.init;
      end
      
      function set.seed(self,seed)
         % handle chains > 1
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
            % how to contruct filename?
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
               error('data file not found');
            end
         else
            
         end
      end
      
      function set(self,varargin)
         p = inputParser;
         p.KeepUnmatched= false;
         p.FunctionName = 'stan parameter setter';
         p.addParamValue('id',self.id);
         p.addParamValue('iter',self.iter);
         p.addParamValue('warmup',self.warmup);
         p.addParamValue('thin',self.thin);
         p.addParamValue('init',self.init);
         p.addParamValue('seed',self.seed);
         p.addParamValue('chains',self.chains);
         p.addParamValue('inc_warmup',self.inc_warmup);
         p.addParamValue('data',[]);
         p.addParamValue('checksum_binary',self.checksum_binary,@isstr);
         p.parse(varargin{:});

         self.id = p.Results.id;
         self.iter = p.Results.iter;
         self.warmup = p.Results.warmup;
         self.thin = p.Results.thin;
         self.init = p.Results.init;
         self.seed = p.Results.seed;
         self.chains = p.Results.chains;
         self.inc_warmup = p.Results.inc_warmup;
         self.data = p.Results.data;
         self.checksum_binary = p.Results.checksum_binary;
      end
      
      function command = get.command(self)
         % FIXME: add a prefix and postfix property according to os?
         command = {[fullfile(self.model_home,self.model_name) ' ']};
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
         
         chain_id = 1:self.chains;
         [~,name,ext] = fileparts(self.sample_file);
         base_name = self.sample_file;
         base_seed = self.seed;
         for i = 1:self.chains
            sample_file{i} = [name '-' num2str(chain_id(i)) ext];
            self.sample_file = sample_file{i};
            % Advance seed according to some rule
            self.seed = base_seed + chain_id(i);
            seed(i) = self.seed;
            p(i) = processManager('id',sample_file{i},...
                               'command',sprintf('%s',self.command{:}),...
                               'workingDir',self.model_home,...
                               'wrap',100,...
                               'keepStdout',false,...
                               'pollInterval',1,...
                               'printStdout',self.verbose,...
                               'autoStart',false);
         end
         self.sample_file = base_name;
         self.seed = base_seed;

         fit = StanFit('model',self,'processes',p,'seed',seed,'sample_file',sample_file);
         
         p.start();
      end
      
      function optimizing(self)
      end
      function diagnose(self)
      end
      
      function help(self,str)
         % TODO: 
         % if str is stanc or other basic binary
         
         %else
         % need to check that model binary exists
         command = [fullfile(self.model_home,self.model_name) ' ' str ' help'];
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
            command = ['make bin/' target];
            printStderr = false;
         elseif strcmp(target,'model')
            command = ['make ' fullfile(self.model_home,self.model_name)];
            printStderr = and(true,self.verbose);
         else
            error('Unknown target');
         end
         p = processManager('id','compile',...
                            'command',command,...
                            'workingDir',self.stan_home,...
                            'printStderr',printStderr,...
                            'printStdout',self.verbose);
         p.block(0.05);
         if strcmp(target,'model')
            self.checksum_binary = mstan.DataHash(fullfile(self.model_home,self.model_name));
         end
      end
      
%       function disp(self)
% 
%       end
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
               if ~strcmp(ext,'.stan')
                  error('include extension');
               end
               %if ~((exist([name ext],'file')==2) || strncmp(path,'http',4))
               if ~((exist(arg,'file')==2) || strncmp(path,'http',4))
                  error('file does not exist');
               end
               self.file_ = [name ext];
               self.model_name_ = name;
               self.model_home = path;
               self.checksum_stan = mstan.DataHash(self.model_path);
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
