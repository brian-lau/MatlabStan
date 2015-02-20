% TODO: 
% x clean up and generalize for both sampling and optim
%   o separate out optim from mcmc object?
% o merge()
% o auto merge when handles equal?
% o should be able to construct stanfit object from just csv files
% o some way to periodically read or peek at incoming samples?

classdef StanFit < handle
   properties
      model     % StanModel object
      processes % processManager objects

      output_file
      verbose
      exit_value
      loaded
   end
   properties(Dependent = true)
      pars
      sim
   end
   properties(SetAccess = private, Hidden = true)
      pos_
      sim_
      %warmup_
      %iter_
   end
   events
      exit
   end
   properties(GetAccess = public, SetAccess = protected)
      version = '0.7.0';
   end
   
   methods
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %% Constructor      
      function self = StanFit(varargin)
         p = inputParser;
         p.KeepUnmatched= true;
         p.FunctionName = 'StanFit constructor';
         p.addParamValue('model','',@(x) isa(x,'StanModel'));
         p.addParamValue('processes','',@(x) isa(x,'processManager'));
         p.addParamValue('output_file',{},@(x) iscell(x));
         p.addParamValue('verbose',false);
         p.parse(varargin{:});

         if ~isempty(p.Results.model)
            self.model = p.Results.model;
         end
         
         % Listen for exit from processManager
         if ~isempty(p.Results.processes)
            if ~mstan.check_ver(p.Results.processes(1).version,'0.4.0')
               error(['You are using an old release of processManager. ' ...
                  'Upgrade to the latest at: https://github.com/brian-lau/MatlabProcessManager']);
            else
               for i = 1:numel(p.Results.processes)
                  addlistener(p.Results.processes(i).state,'exit',...
                     @(src,evnt)process_exit(self,src,evnt));
               end
            end
            self.processes = p.Results.processes;
         end
         self.verbose = p.Results.verbose;
         
         if ~isempty(p.Results.output_file)
            self.output_file = p.Results.output_file;
            self.exit_value = nan(size(self.output_file));
            self.loaded = nan(size(self.output_file));
         end

         if numel(self.processes) ~= numel(self.output_file)
            error('StanFit:constructor:InputFormat',...
               'The number of processes should match the number of expected data files.');
         end
         
         if isprop(self.model,'seed')
            self.sim_ = mcmc(self.model.seed);
         else
            self.sim_ = mcmc();
         end
      end
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      function set.verbose(self,bool)
         if isscalar(bool) && islogical(bool)
            if ~isempty(self.processes)
               [self.processes.printStdout] = deal(bool);
               self.verbose = bool;
            end
         else
            error('StanFit:verbose:InputFormat','Boolean scalar expected.');
         end
      end
      
      function stop(self)
         if ~isempty(self.processes)
            if any([self.processes.running])
               self.processes.stop();
            else
               fprintf('Stan is already finished.\n');
            end
         end
      end
      
      function check(self)
         % Print status to screen for each running chain.
         if ~isempty(self.processes)
            if any([self.processes.running])
               for i = 1:numel(self.processes)
                  if self.processes(i).running;
                     fprintf('%s \t %s\n',self.processes(i).id,self.processes(i).stdout{end});
                  end
               end
            else
               fprintf('All Stan processes finished.\n');
            end
         else
            fprintf('Nothing to check.\n');
         end
      end
      
      function sim = get.sim(self)
         if exit_with_data(self)
            sim = self.sim_;
         else
            sim = [];
         end
      end
      
      function out = extract(self,varargin)         
         if ~exit_with_data(self)
            out = [];
            return;
         end

         p = inputParser;
         p.FunctionName = 'StanFit extract';
         p.addParamValue('pars',{},@(x) iscell(x) || ischar(x));
         p.addParamValue('permuted',true,@islogical);
         p.addParamValue('inc_warmup',false,@islogical);
         p.parse(varargin{:});
         
         out = self.sim_.extract('names',p.Results.pars,...
                                 'permuted',p.Results.permuted,...
                                 'inc_warmup',p.Results.inc_warmup);
      end
      
      function process_exit(self,src,~)
         if src.exitValue == 0
            self.process_exit_success(src);
         elseif src.exitValue == 143
            % TODO: check that SIGTERM (143) is the same on windows/linux?
            self.process_exit_success(src);
         else
            self.process_exit_failure(src);
         end
      end
      
      function out = peek(self)
         if strcmp(self.model.method,'optimize')
            % FIXME, check if done before printing this
            fprintf('Nothing to peek at, optimizing');
            return;
         elseif strcmp(self.model.method,'sample')
            for ind = 1:numel(self.output_file)
               [hdr,flatNames,flatSamples,pos] =  mstan.read_stan_csv(...
                  self.output_file{ind},self.model.inc_warmup);
               
               if isempty(flatSamples)
                  disp('Stan hasn''t saved any samples for this chain yet');
               else
                  [names,dims,samples] = mstan.parse_flat_samples(flatNames,flatSamples);
                  
                  % Account for thinning
                  if self.model.inc_warmup
                     exp_warmup = ceil(self.model.warmup/self.model.thin);
                  else
                     exp_warmup = 0;
                  end
                  exp_iter = ceil(self.model.iter/self.model.thin);
                  
                  try
                     self.sim_.remove(ind);
                  catch
                  end
                  % Append to mcmc object
                  self.sim_.append(samples,names,exp_warmup,exp_iter,ind);
                  self.sim_.user_data{ind} = hdr;
               end
            end
         end
      end
      
      function process_exit_success(self,src)
         % FIXME is there ever a possibility that we get simultaneous notifications
         ind = strcmp(self.output_file,fullfile(self.model.working_dir,src.id));
         self.exit_value(ind) = src.exitValue;
         if self.verbose
            fprintf('stan started processing %s\n',src.id);
         end
         
         if any(ind)
            if strcmp(self.model.method,'optimize')
               [hdr,flatNames,flatSamples] =  mstan.read_stan_csv(...
                  self.output_file{ind},true);
            elseif strcmp(self.model.method,'sample')
               [hdr,flatNames,flatSamples,pos] =  mstan.read_stan_csv(...
                  self.output_file{ind},self.model.inc_warmup);
            end
            [names,dims,samples] = mstan.parse_flat_samples(flatNames,flatSamples);
            
            if strcmp(self.model.method,'optimize')
               exp_warmup = 0;
               exp_iter = 1;
            else
               % Account for thinning
               if self.model.inc_warmup
                  exp_warmup = ceil(self.model.warmup/self.model.thin);
               else
                  exp_warmup = 0;
               end
               exp_iter = ceil(self.model.iter/self.model.thin);
            end
            
            try
               self.sim_.remove(ind);
            catch
            end
            % Append to mcmc object
            self.sim_.append(samples,names,exp_warmup,exp_iter,ind);
            self.sim_.user_data{ind} = hdr;
         end

         if self.verbose
            fprintf('stan finished processing %s\n',src.id);
         end
         self.loaded(ind) = true;
         if nansum(self.loaded) == numel(self.loaded)
            %if any(arrayfun(@(x) isempty(x.lp__),self.iter_))
            %   % FIXME: not a good check, eventually we may not keep lp__
            %   warning('Failure to load chains correctly');
            %end
            notify(self,'exit');
         end
      end
      
      function process_exit_failure(self,src)
         % TODO, check against Stan errors, and print to screen
         % Stan error codes: https://github.com/stan-dev/stan/blob/develop/src/stan/gm/error_codes.hpp
         warning('Stan seems to have exited badly.');
      end
            
      function str = print(self,varargin)
         % TODO: 
         % o this should allow multiple files and regexp.
         % x this does not work when method=optim, should shortcut
         %       
         % note that passing regexp through in the command does not work,
         % need to implment search in matlab
         % TODO: allow print parameters
         % FIXME: ugh, if multiple fits were done with same output names
         % print will just give the results from the last one. should
         % StanModel generate unique names?
         if strcmp(self.model.method,'optimize')
            fprintf('%s\n',self.processes.stdout{:});
            return;
         end
         
         p = inputParser;
         p.FunctionName = 'StanFit print';
         p.addParamValue('file',{},@(x) iscell(x) || ischar(x));
         p.addParamValue('sig_figs',2,@isscalar);
         p.parse(varargin{:});

         if isempty(p.Results.file)
            if ~isempty(self.output_file)
               file = self.output_file;
            end
         elseif ischar(p.Results.file)
            file = {p.Results.file};
         else
            file = p.Results.file;
         end
         
         if ischar(file)
            command = [self.model.stan_home filesep 'bin/print --sig_figs='...
               num2str(p.Results.sig_figs) ' ' file];
         elseif iscell(file)
            command = [self.model.stan_home filesep 'bin/print --sig_figs='...
               num2str(p.Results.sig_figs) ' ' sprintf('%s ',file{:})];
         end
         p = processManager('command',command,...
                            'workingDir',self.model.working_dir,...
                            'wrap',100,...
                            'printStdout',false,...
                            'printStderr',false,...
                            'keepStdout',true,...
                            'keepStderr',true);
         p.block(0.05);
         if p.exitValue == 0
            str = p.stdout;
            fprintf('%s\n',str{:});
         else
            if any(strcmp(p.stdout,'Warning: non-fatal error reading adapation data'))...
               || any(strcmp(p.stdout,'Warning: non-fatal error reading samples'))
               fprintf('Looks like print got called before any samples were saved.\n');
               fprintf('Wait a bit longer, or attach a listener.\n');
            end   
            str = p.stderr;
         end
      end
      
      function summary(self)
      end
      
      function block(self)
         % FIXME: is_running can return false before self.loaded
         if ~isempty(self.processes)%is_running(self) % stan called
            % FIXME, what if callback fails??
            while nansum(self.loaded) ~= numel(self.loaded)
               % pause() in some Matlab versions leaks memory
               java.lang.Thread.sleep(0.05*1000);
            end
         end
      end

      function bool = is_running(self)
         bool = false;
         if ~isempty(self.processes)
            bool = any(isnan(self.exit_value));
         end
      end
            
      function bool = exit_with_data(self)
         bool = false;
         if ~isempty(self.processes) % stan called
            if is_running(self) % not finished
               fprintf('Stan is still working. You can either:\n');
               fprintf('  Come back later, or\n');
               fprintf('  Attach a listener to the StanFit object.\n');
            elseif all((self.exit_value == 0) | (self.exit_value == 143)) % finished cleanly
            % TODO: check that SIGTERM (143) is the same on windows/linux?
               bool = true;
            else % finished badly
               fprintf('Stan seems to have encountered a problem.\n');
               fprintf('Processes exited with codes: %g.\n',self.exit_value);
            end
         end
      end
      
      function traceplot(self,varargin)
         self.sim.traceplot(varargin{:});
      end
   end
end

