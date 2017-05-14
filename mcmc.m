% Container for MCMC samples

% TODO
% x permutation index, hmm looks like the behavior should be across stanFit
% instances, need to save Matlab rng state
% o extract should allow excluding chains
% o should be way to delete chains
% o clean() should delete sample files and intermediate?
% 

classdef mcmc < handle
   properties(Dependent = true)
      names
      n_warmup
      n_samples
      permute_index
   end
   properties
      user_data
   end
   properties(SetAccess = private)
      warmup
      samples
   end
   properties(Hidden = true, SetAccess = public)
      rng_state % This is for the Matlab RNG
   end
   properties(GetAccess = public, SetAccess = protected)
      version = '0.3.2';
   end
   
   methods
      function self = mcmc(seed)
         if nargin == 1
            self.rng_state = seed;
         else
            self.rng_state = rng;
         end
      end

      function n = get.n_warmup(self)
         s = 'warmup';
         fn = fieldnames(self.(s));         
         for i = 1:numel(self.(s))
            for j = 1:length(fn)
               temp{j} = size(self.(s)(i).(fn{j}),1);
            end
            n(i) = cell2struct(temp,self.names,2);
         end
      end
      
      function n = get.n_samples(self)
         s = 'samples';
         fn = fieldnames(self.(s));         
         for i = 1:numel(self.(s))
            for j = 1:length(fn)
               temp{j} = size(self.(s)(i).(fn{j}),1);
            end
            n(i) = cell2struct(temp,self.names,2);
         end
      end
      
      function names = get.names(self)
         if ~isempty(self.samples)
            names = fieldnames(self.samples);
         else
            names = {};
         end
      end
      
      function ind = get.permute_index(self)
         % https://github.com/stan-dev/pystan/pull/26
         if ~isempty(self.samples)
            curr = rng;
            rng(self.rng_state); % state at object construction
            for i = 1:numel(self.names)
               n_total_iter(i) = sum([self.n_samples.(self.names{i})]);
            end
            ind = randperm(max(n_total_iter));
            rng(curr);
         else
            ind = [];
         end
      end

      function set.rng_state(self,r)
         if nargin == 2
            if (isstruct(r)) || (isscalar(r) && (r>=0)) 
               curr = rng;
               if strcmp(curr.Type,'Legacy')
                  rng('default');
               end
               rng(r);
               self.rng_state = rng;
            else
               error('mcmc:rng:InputFormat','Not a valid seed or struct for RNG.');
            end
         else
            % Default seed&state
            rng('default');
            self.rng_state = rng;
         end
      end
      
      function append(self,C,names,exp_warmup,exp_iter,chain_ind)
         [warmup,samples] = self.parse_combined_warmup_samples(...
            C,names,exp_warmup,exp_iter);
         
         temp(chain_ind) = cell2struct(warmup,names,2);
         self.append_helper('warmup',temp,chain_ind);
         clear temp;
         temp(chain_ind) = cell2struct(samples,names,2);
         self.append_helper('samples',temp,chain_ind);
      end
      
      function append_helper(self,s,data,chain_ind)
         if isempty(self.(s))
            self.(s) = data;
         else
            try
               % Data exists, append
               fn = fieldnames(self.(s)(chain_ind));
               for i = 1:numel(fn)
                  self.(s)(chain_ind).(fn{i}) = ... % VERTCAT???
                     cat(1,self.(s)(chain_ind).(fn{i}),data(chain_ind).(fn{i}));
               end
            catch err
               % Chain doesn't exist, add it
               if strcmp(err.identifier,'MATLAB:badsubscript')
                  self.(s)(chain_ind) = data(chain_ind);
               else
                  rethrow(err);
               end
            end
         end
      end
      
      function out = remove(self,chain_id)
         fn = fieldnames(self.samples(chain_id));
         for i = 1:numel(fn)
            self.warmup(chain_id).(fn{i}) = [];
            self.samples(chain_id).(fn{i}) = [];
         end
      end
      
      function out = extract(self,varargin)
         p = inputParser;
         p.FunctionName = 'mcmc extract';
         p.addParamValue('names',{},@(x) iscell(x) || ischar(x));
         p.addParamValue('permuted',true,@islogical);
         p.addParamValue('inc_warmup',false,@islogical);
         p.parse(varargin{:});
         
         req_names = p.Results.names;
         if ischar(req_names)
            req_names = {req_names};
         end
         if isempty(req_names)
            names = self.names;
         else
            ind = ismember(req_names,self.names);
            if ~any(ind)
               error('mcmc:extract:InputFormat','bad names');
            else
               names = req_names(ind);
               if any(~ind)
                  temp = req_names(~ind);
                  warning('%s requested but not found, dropping',temp{:});
               end
            end
         end

         % FIXME for INCLUDE WARMUP
         if p.Results.permuted
            % TODO: ability to return permuted samples when we have warmup?
            out = struct;
            for i = 1:numel(names)
               temp = cat(1,self.samples.(names{i})); %VERTCAT???
               sz = size(temp);
               temp = temp(self.permute_index(1:max(sz)),:);
               out.(names{i}) = reshape(temp,sz);
            end
            % TODO: check that this is expected behavior!!
            % x = reshape(1:6,2,1,3);
            % y = x([2,1],:); % force to 2-D
            % reshape(y,size(x)) % back to original size
         else
            if p.Results.inc_warmup
               out = rmfield(self.warmup,setxor(self.names,names));
               samples = rmfield(self.samples,setxor(self.names,names));
               fn = fieldnames(out);
               for i = 1:numel(out)
                  for j = 1:numel(fn)
                     if self.n_warmup(i).(fn{j}) == 0
                        warning('mcmc:extract:IgnoredInput',...
                           'Warmup samples requested, but were not saved when model run');
                     end
                     out(i).(fn{j}) = cat(1,out(i).(fn{j}),samples(i).(fn{j})); % VERTCAT
                  end
               end
            else
               out = rmfield(self.samples,setxor(self.names,names));
            end
         end
      end
      
      function traceplot(self)
         maxRows = 8;
         inc_warmup = true;
         
         fn = self.names;
         nPars = numel(fn);
         if nPars < maxRows;
            maxRows = nPars;
         end
         figure;
         count = 1;
         for i = 1:nPars
            % FIXME: will not work for n-D parameters! Recursion?
            for j = 1:size(self.samples(1).(fn{i}),2)
               subplot(maxRows,1,count); hold on
               % Grab all chains for given parameter index
               temp = arrayfun(@(x) x.(fn{i})(:,j),self.samples,'uni',0);
               plot(cell2mat(temp));
               %for k = 1:nChains
               %   plot(out(k).(fn{i})(:,j));
               %end
               if isvector(self.samples(1).(fn{i}))
                  title(fn{i})
               elseif ismatrix(self.samples(1).(fn{i}))
                  title([fn{i} num2str(j)])
               end
               count = count + 1;
               if count > maxRows
                  if i <= nPars
                     figure;
                     count = 1;
                  end
               end
            end
         end
      end
   end
   
   methods(Static)
      function [warmup,samples,n_warmup,n_iter] = ...
            parse_combined_warmup_samples(C,names,exp_warmup,exp_iter)
         exp_sum_iter = exp_warmup + exp_iter;
         obs_sum_iter = cellfun(@(x) size(x,1),C);
         mismatch = obs_sum_iter ~= exp_sum_iter;
         n_pars = numel(names);
         if any(mismatch)
            for i = 1:n_pars
               if exp_warmup > 0%self.model.inc_warmup
                  if obs_sum_iter(i) <= exp_warmup
                     n_warmup{i} = obs_sum_iter(i);
                     n_iter{i} = 0;
                  else
                     n_warmup{i} = exp_warmup;
                     n_iter{i} = obs_sum_iter(i) - exp_warmup;
                  end
               else
                  n_warmup{i} = 0;
                  n_iter{i} = obs_sum_iter(i);
               end
               if mismatch(i)
                  if 1%self.verbose
                     fprintf('Expected %g total iterations, read %g iterations for %s\n',...
                        exp_sum_iter,obs_sum_iter(i),names{i});
                     %fprintf('warmup: %g, iter: %g\n',warmup(i),iter(i));
                  end
               end
            end
         else
            n_warmup = repmat({exp_warmup},1,n_pars);
            n_iter = repmat({exp_iter},1,n_pars);
         end

         %http://blogs.mathworks.com/loren/2006/03/22/making-functions-suitable-for-nd-arrays/
         % In case of nd arrays, create a list to allow expansion of all
         % dimensions after the first
         dims = cellfun(@(x) ndims(x),C,'uni',0);
         expand = cellfun(@(x) repmat({':'},1,x-1),dims,'uni',0);
         
         indices = cellfun(@(x,y) {1:x y{:}},n_warmup,expand,'uni',0);
         warmup = cellfun(@(x,y) x(y{:}),C,indices,'uni',false);
         
         indices = cellfun(@(x,y,z) {(x+1):(x+y) z{:}},n_warmup,n_iter,expand,'uni',0);
         samples = cellfun(@(x,y) x(y{:}),C,indices,'uni',false);
      end
   end
   
end

