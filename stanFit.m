% TODO: should be able to construct stanfit object from just csv files
classdef stanFit < handle
   properties
      model
      processes % not sure I need this, although for long runs, can stop here...

      pars
      dims
      %flat_pars
      sim

      sample_file
      sample_file_hdr
      %diagnostic_file
      
      exitValue      
   end
   properties(GetAccess = public, SetAccess = protected)
      version = '0.0.0';
   end
   
   methods
      function self = stanFit(varargin)
         if nargin == 0
            return;
         end
      
         p = inputParser;
         p.KeepUnmatched= true;
         p.FunctionName = 'stanFit constructor';
         p.addParamValue('model','',@(x) isa(x,'stan'));
         p.addParamValue('processes','',@(x) isa(x,'processManager'));
         p.addParamValue('sample_file',{},@iscell);
         p.parse(varargin{:});

         if ~isempty(p.Results.model)
            self.model = p.Results.model;
         end
         
         if ~isempty(p.Results.processes)
            % Listen for exit from processManager
            lh = addlistener(p.Results.processes,'exit',@(src,evnt)process_exit(self,src,evnt));
            self.processes = p.Results.processes;
         end
         if ~isempty(p.Results.sample_file)
            self.sample_file = p.Results.sample_file;
            self.exitValue = nan(size(self.sample_file));
         end
      end
      
      function out = extract(self,varargin)
         if ~all(self.exitValue==0)
            disp('not done')
            return;
         end
         p = inputParser;
         p.KeepUnmatched= false;
         p.FunctionName = 'stanFit extract';
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
            warning('Warmup samples requested, but were not saved when model run');
         end
         
         fn = fieldnames(self.sim);
         if p.Results.permuted

            out = struct;
            for i = 1:numel(pars)
               out.(pars{i}) = cat(1,self.sim.(pars{i}));
            end
            % TODO actually permute...
         else
            % TODO?
            % return an array of three dimensions: iterations, chains, parameters
            out = rmfield(self.sim,setxor(fn,pars));
         end
      end
      
      
      function process_exit(self,src,evtdata)
         % need to id the chain that finished, load that data? or wait
         % until everyone is done???
         
         self.exitValue(strcmp(self.sample_file,src.id)) = src.exitValue;
         if all(self.exitValue == 0)
            disp('done');
            for i = 1:numel(self.sample_file)
               % FIXME: implement checking that all chains have same parameters and settings
               [hdr,flatNames,flatSamples] =  self.read_stan_csv(self.sample_file{i},self.model.inc_warmup);
               % FIXME: function checking
               [names,dims,samples] = self.parse_flat_samples(flatNames,flatSamples);
               % Fieldnames are dynamically created, so first assignment
               % must overwrite default.
               if i == 1
                  self.sim = cell2struct(samples,names,2);
               else
                  self.sim(i) = cell2struct(samples,names,2);
               end
               self.sample_file_hdr{i} = hdr;
            end
            self.pars = names;
            self.dims = dims;
            %self.flat_pars = flatNames;
            %TODO, we need to cache a permutation index that will be
            %reproducible for each call to extract for each instance of
            %stanfit
         end
      end
      
      function self = print(self,file)
         % this should allow multiple files and regexp. 
         % note that passing regexp through in the command does not work,
         % need to implment search in matlab
         if nargin < 2
            file = self.sample_file;
         end
         if ischar(file)
            command = [self.model.stan_home filesep 'bin/print ' file];
         elseif iscell(file)
            command = [self.model.stan_home filesep 'bin/print ' sprintf('%s ',file{:})];
         end
         p = processManager('command',command,...
                            'workingDir',self.model.working_dir,...
                            'wrap',100,...
                            'keepStdout',false);
         p.block(0.05);
      end
      
      function traceplot(self,varargin)
         % check if I passed in an extracted struct already
         %out = extract(self,varargin{:});
         
         out = extract(self,'permuted',false,'inc_warmup',true);
         maxRows = 8;
         
         fn = fieldnames(out);
         nPars = numel(fn);
         if nPars < maxRows;
            maxRows = nPars;
         end
         figure;
         count = 1;
         for i = 1:nPars
            % FIXME: will not work for n-D parameters! Recursion?
            for j = 1:size(out(1).(fn{i}),2)
               subplot(maxRows,1,count); hold on
               % Grab all chains for given parameter index
               temp = arrayfun(@(x) x.(fn{i})(:,j),out,'uni',false);
               plot(cell2mat(temp));
               %for k = 1:nChains
               %   plot(out(k).(fn{i})(:,j));
               %end
               if isvector(out(1).(fn{i}))
                  title(fn{i})
               elseif ismatrix(out(1).(fn{i}))
                  title([fn{i} num2str(j)])
               end
               count = count + 1;
               if count > maxRows
                  figure;
                  count = 1;
               end
            end
         end
      end
   end
   
   methods(Static)
      function [hdr,varNames,samples] = read_stan_csv(fname,inc_warmup)
         fid = fopen(fname);
         count = 1;
         while 1
            l = fgetl(fid);
            
            if strcmp(l(1),'#')
               line{count} = l;
            else
               varNames = regexp(l, '\,', 'split');
               if ~inc_warmup
                  % As of Stan 2.0.1, these lines exist when warmup is not saved
                  for i = 1:4 % FIXME: assumes 4 lines, should generalize?
                     line{count} = fgetl(fid);
                     count = count + 1;
                  end
               end
               break
            end
            %disp(line);
            count = count + 1;
         end
         hdr = sprintf('%s\n',line{:});
         nCols = numel(varNames);
         
         cols = [repmat('%f',1,nCols)];
         samples = textscan(fid,cols,'CollectOutput',true,'CommentStyle','#','Delimiter',',');
         samples = samples{1};
         fclose(fid);
      end
      
      function [varNames,varDims,varSamples] = parse_flat_samples(flatNames,flatSamples)
         % Could probably be replaced with a few regexp expressions...
         %
         % As of Stan 2.0.1, variables may not contain periods.
         % Periods are used to separate dimensions of vector and array variables
         splitNames = regexp(flatNames, '\.', 'split');
         for j = 1:numel(splitNames)
            names{j} = splitNames{j}{1};
         end
         varNames = unique(names,'stable');
         for j = 1:numel(varNames)
            ind = strcmp(names,varNames{j});
            
            % Parse dimensionality of parameter
            temp = cat(1,splitNames{ind});
            temp(:,1) = [];
            if size(temp,2) == 0
               varDims{j} = [1 1];
            elseif size(temp,2) == 1
               varDims{j} = [max(str2num(cat(1,temp{:,1}))) 1];
            else
               for k = 1:size(temp,2)
                  varDims{j}(k) = max(str2num(cat(1,temp{:,k})));
               end
            end
            
            % Convert flat samples to correct shape
            temp = flatSamples(:,ind);
            varSamples{j} = reshape(temp,[length(temp) varDims{j}]);
         end
      end
   end
end

