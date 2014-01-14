% TODO: 
% o permutation index, hmm looks like the behavior should be across stanFit
% instances, need to save Matlab rng state
% o clean up and generalize for both sampling and optim
% o stop() verbose() merge() methods
% o auto merge when handles equal
% o should be able to construct stanfit object from just csv files
% o extract should allow excluding chains
% o should be way to delete chains
classdef StanFit < handle
   properties
      model
      processes % not sure I need this, although for long runs, can stop here...

      pars
      dims
      sim
      
      seed % This is for the Stan RNG
      output_file
      output_file_hdr
      %diagnostic_file
      
      verbose
      
      exit_value
      permute_index
   end
   properties(SetAccess = private)
      rng_state = rng; % This is for the Matlab RNG
   end
   properties(GetAccess = public, SetAccess = protected)
      version = '0.3.0';
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
         p.addParamValue('seed',[],@isnumeric);
         p.addParamValue('output_file',{},@(x) iscell(x));
         p.addParamValue('verbose',false);
         p.parse(varargin{:});

         if ~isempty(p.Results.model)
            self.model = p.Results.model;
         end
         
         % Listen for exit from processManager
         if ~isempty(p.Results.processes)
            addlistener(p.Results.processes,'exit',@(src,evnt)process_exit(self,src,evnt));
            self.processes = p.Results.processes;
         end
         self.verbose = p.Results.verbose;
         self.seed = p.Results.seed;
         
         if ~isempty(p.Results.output_file)
            self.output_file = p.Results.output_file;
            self.exit_value = nan(size(self.output_file));
         end

         if numel(self.processes) ~= numel(self.output_file)
            error('must match');
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
            error('bool');
         end
      end
      
      function sim = get.sim(self)
         if ~all(self.exit_value==0)
            %disp('not done')
            self.processes.block(0.05);
         end
         sim = self.sim;
      end
      
      function ind = get.permute_index(self)
         if all(self.exit_value == 0)
            %nSamples = self.model.chains*self.model.iter;
            curr = rng;
            rng(self.rng_state); % state at object construction
            nSamples = sum([self.sim.iter]);
            ind = randperm(nSamples);
            rng(curr);
         end
      end
      
      function stop(self)
         if ~isempty(self.processes)
            % FIXME: need to update exit_values, and trigger read of what
            % managed to get written to file. 
            % FIXME: not working due to notification problem in
            % processManager
            self.processes.stop();
         else
            %error('');
         end
      end
      
      function out = extract(self,varargin)
         if ~all(self.exit_value==0)
            %disp('not done')
            self.processes.block(0.05);
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
         if p.Results.permuted
            out = struct;
            for i = 1:numel(pars)
               temp = cat(1,self.sim.(pars{i}));
               sz = size(temp);
               try
               temp = temp(self.permute_index,:);
               catch; keyboard; end
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
         ind = strcmp(self.output_file,src.id);
         self.exit_value(ind) = src.exitValue;
         
         %fprintf('Notification! Processing %s\n',src.id);
         if isempty(self.output_file_hdr{ind})
            if strcmp(self.model.method,'optimize')
               [hdr,flatNames,flatSamples] =  mstan.read_stan_csv(...
                  self.output_file{ind},true);
            elseif strcmp(self.model.method,'sample')
               [hdr,flatNames,flatSamples] =  mstan.read_stan_csv(...
                  self.output_file{ind},self.model.inc_warmup);
            end
            [names,dims,samples] = mstan.parse_flat_samples(flatNames,flatSamples);
            
            iter = unique(cellfun(@(x) size(x,1),samples));
            if numel(iter) ~= 1
               warning('different number of samples');
            end
            if self.model.inc_warmup
               if iter ~= (self.model.iter + self.model.warmup)
                  warning('wrong number of samples include warmup');
               end
            else
               if iter ~= self.model.iter
                  warning('wrong number of samples');
               end
            end
            
            temp(ind) = cell2struct([samples iter],[names 'iter'],2);
            if isempty(self.sim) % first assignment
               self.sim = temp;
            else
               self.sim(ind) = temp(ind);
            end
            self.output_file_hdr{ind} = hdr;
            if isempty(self.pars)
               self.pars = names;
            end
            if isempty(self.dims)
               self.dims = dims;
            end
         else
            % FIXME: notifications are repeated? related to processManager?
            %fprintf('%s callback triggered\n',src.id)
         end
         %self.flat_pars = flatNames;
         
         % Cache a permutation index to allow reproducible call to extract 
         % for each instance of stanfit. Do we need to worry about space?
         % Perhaps set store a rng state based on seed passed to sampler?
         % https://github.com/stan-dev/pystan/pull/26
%          if all(self.exit_value == 0)
%             nSamples = self.model.chains*self.model.iter;
%             self.permute_index = randperm(nSamples);
%          end
      end
      
      function str = print(self,varargin)
         % TODO: 
         % o this should allow multiple files and regexp.
         % o this does not work when method=optim, should shortcut
         %       
         % note that passing regexp through in the command does not work,
         % need to implment search in matlab
         % TODO: allow print parameters
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
      
      function traceplot(self,varargin)
         % check if I passed in an extracted struct already
         %out = extract(self,varargin{:});
         
         out = extract(self,'permuted',false,'inc_warmup',true);
         maxRows = 8;
         mstan.traceplot(out,maxRows);
      end
      
      function bool = is_running(self)
         bool = any(isnan(self.exit_value));
         % TODO: should actually check processes
      end      
   end
end

