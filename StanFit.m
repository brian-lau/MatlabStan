% TODO: 
% x permutation index, hmm looks like the behavior should be across stanFit
% instances, need to save Matlab rng state
% x clean up and generalize for both sampling and optim
% x stop() 
% x verbose() 
% x account for thinning
% o merge()
% o auto merge when handles equal?
% o should be able to construct stanfit object from just csv files
% o extract should allow excluding chains
% o should be way to delete chains
% o clean() should delete sample files and intermediate?

% Stan error codes: https://github.com/stan-dev/stan/blob/develop/src/stan/gm/error_codes.hpp
classdef StanFit < handle
   properties
      model
      processes % not sure I need this, although for long runs, can stop here...

      pars
      dims
      warmup
      iter
      sim
      
      output_file
      output_file_hdr
      %diagnostic_file
      
      verbose
      
      exit_value
      loaded
      permute_index
   end
   properties(SetAccess = private, Hidden = true)
      sim_
      warmup_
      iter_
      rng_state = rng; % This is for the Matlab RNG
   end
   events
      exit
   end
   properties(GetAccess = public, SetAccess = protected)
      version = '0.5.0';
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
                  addlistener(p.Results.processes(i).state,'exit',@(src,evnt)process_exit(self,src,evnt));
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
         else
            self.output_file_hdr = cell(1,numel(self.output_file));
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
      
      function ind = get.permute_index(self)
         % https://github.com/stan-dev/pystan/pull/26
         % TODO : cache this
         if exit_with_data(self)
            curr = rng;
            rng(self.rng_state); % state at object construction
            
            for i = 1:numel(self.pars)
               n_total_iter(i) = sum(arrayfun(@(x) x.(self.pars{i}),self.iter));
            end
            ind = randperm(max(n_total_iter));

            rng(curr);
         else
            ind = [];
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
      
      function sim = get.sim(self)
         if exit_with_data(self)
            sim = self.sim_;
         else
            sim = [];
         end
      end
      
      function warmup = get.warmup(self)
         if exit_with_data(self)
            warmup = self.warmup_;
         else
            warmup = [];
         end
      end
      
      function iter = get.iter(self)
         if exit_with_data(self)
            iter = self.iter_;
         else
            iter = [];
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
         
         req_pars = p.Results.pars;
         if ischar(req_pars)
            req_pars = {req_pars};
         end
         if isempty(req_pars)
            pars = self.pars;
         else
            ind = ismember(req_pars,self.pars);
            if ~any(ind)
               error('bad pars');
            else
               pars = req_pars(ind);
               if any(~ind)
                  temp = req_pars(~ind);
                  warning('%s requested but not found, dropping',temp{:});
               end
            end
         end
         
         if p.Results.inc_warmup && ~self.model.params.sample.save_warmup
            warning('StanFit:extract:IgnoredInput',...
               'Warmup samples requested, but were not saved when model run');
         end

         fn = fieldnames(self.sim);
         if p.Results.permuted && ~self.model.inc_warmup
            % TODO: ability to return permuted samples when we have warmup?
            out = struct;
            for i = 1:numel(pars)
               temp = cat(1,self.sim.(pars{i}));
               sz = size(temp);
               temp = temp(self.permute_index(1:max(sz)),:);
               out.(pars{i}) = reshape(temp,sz);
            end
            % TODO: check that this is expected behavior!!
            % x = reshape(1:6,2,1,3);
            % y = x([2,1],:); % force to 2-D
            % reshape(y,size(x)) % back to original size
         else
            % TODO?
            % return an array of three dimensions: iterations, chains, parameters
            out = rmfield(self.sim,setxor(fn,pars));
         end
      end
      
      function process_exit(self,src,~)
         if src.exitValue == 0
            self.process_exit_success(src);
         elseif src.exitValue == 143
            self.process_exit_success(src);
         else
            self.process_exit_failure(src);
         end
      end
      
      function process_exit_success(self,src)
         ind = strcmp(self.output_file,fullfile(self.model.working_dir,src.id));
         self.exit_value(ind) = src.exitValue;
         if self.verbose
            fprintf('stan started processing %s\n',src.id);
         end
         
         if isempty(self.output_file_hdr{ind})
            if strcmp(self.model.method,'optimize')
               [hdr,flatNames,flatSamples] =  mstan.read_stan_csv(...
                  self.output_file{ind},true);
            elseif strcmp(self.model.method,'sample')
               [hdr,flatNames,flatSamples] =  mstan.read_stan_csv(...
                  self.output_file{ind},self.model.inc_warmup);
            end
            [names,dims,samples] = mstan.parse_flat_samples(flatNames,flatSamples);
            
            if strcmp(self.model.method,'optimize')
               warmup  = 0;
               iter = 1;
            else
               [warmup,iter] = self.check_samples(samples,names);
            end
            
            temp1(ind) = cell2struct(samples,names,2);
            temp2(ind) = cell2struct(num2cell(warmup),names,2);
            temp3(ind) = cell2struct(num2cell(iter),names,2);

            if isempty(self.sim_) 
               % First assignment, entire structure including empty fields
               % in the struct array are passed. Ensures that the indexing
               % is correct regardless of the order of chain notification.
               self.sim_ = temp1;
               self.warmup_ = temp2;
               self.iter_ = temp3;
            else
               self.sim_(ind) = temp1(ind);
               self.warmup_(ind) = temp2(ind);
               self.iter_(ind) = temp3(ind);
            end
            self.output_file_hdr{ind} = hdr;
            if isempty(self.pars)
               self.pars = names;
            end
            if isempty(self.dims)
               self.dims = dims;
            end
         end

         %self.flat_pars = flatNames;
         if self.verbose
            fprintf('stan finished processing %s\n',src.id);
         end
         self.loaded(ind) = true;
         if nansum(self.loaded) == numel(self.loaded)
            if any(arrayfun(@(x) isempty(x.lp__),self.iter_))
               warning('Failure to load chains correctly');
            end
            notify(self,'exit');
         end
      end
      
      function process_exit_failure(self,src)
         warning('Stan seems to have exited badly.');
      end
      
      function [warmup,iter] = check_samples(self,samples,names)
         if self.model.inc_warmup
            exp_warmup = ceil(self.model.warmup/self.model.thin);
         else
            exp_warmup = 0;
         end
         exp_iter = ceil(self.model.iter/self.model.thin);
         exp_sum_iter = exp_warmup + exp_iter;
         obs_sum_iter = cellfun(@(x) size(x,1),samples);
         mismatch = obs_sum_iter ~= exp_sum_iter;
         n_pars = numel(obs_sum_iter);
         if any(mismatch)
            for i = 1:n_pars
               if self.model.inc_warmup
                  if obs_sum_iter(i) <= exp_warmup
                     warmup(i) = obs_sum_iter(i);
                     iter(i) = 0;
                  else
                     warmup(i) = exp_warmup;
                     iter(i) = obs_sum_iter(i) - exp_warmup;
                  end
               else
                  warmup(i) = 0;
                  iter(i) = obs_sum_iter(i);
               end
               if mismatch(i)
                  if self.verbose
                     fprintf('Expected %g total iterations, read %g iterations for %s\n',...
                        exp_sum_iter,obs_sum_iter(i),names{i});
                     %fprintf('warmup: %g, iter: %g\n',warmup(i),iter(i));
                  end
               end
            end
         else
            warmup = repmat(exp_warmup,1,n_pars);
            iter = repmat(exp_iter,1,n_pars);
         end
      end
      
      function str = print(self,varargin)
         % TODO: 
         % o this should allow multiple files and regexp.
         % o this does not work when method=optim, should shortcut
         %       
         % note that passing regexp through in the command does not work,
         % need to implment search in matlab
         % TODO: allow print parameters
         % FIXME: ugh, if multiple fits were done with same output names
         % print will just give the results from the last one. should
         % StanModel generate unique names>>>
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
                            'keepStdout',true,...
                            'keepStderr',true);
         p.block(0.05);
         if p.exitValue == 0
            str = p.stdout;
         else
            str = p.stderr;
         end
      end
      
      function summary(self)
      end
      
      function block(self)
         % FIXME: is_running can return false before self.loaded
         if ~isempty(self.processes)%is_running(self) % stan called
            % FIXME, what if callback fails??
            count = 1;
            while nansum(self.loaded) ~= numel(self.loaded)
               java.lang.Thread.sleep(0.05*1000);
               count = count + 1;
               if count > 1000
                  warning('block() is taking too long');
                  break;
               end
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
         % check if I passed in an extracted struct already
         %out = extract(self,varargin{:});
         
         out = extract(self,'permuted',false,'inc_warmup',true);
         maxRows = 8;
         mstan.traceplot(out,maxRows);
      end
   end
end

