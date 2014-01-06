classdef stanFit < handle
%    properties(GetAccess = public, SetAccess = immutable)
%    end
   properties
      model
      processes % not sure I need this, although for long runs, can stop here...
      %data
      
      pars
      sim

      sample_file
      sample_file_hdr
      diagnostic_file
      
      exitValue
      %hdr
      %varNames
      %samples
      %sim
      
   end
   
   properties
      params
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
         %self.sim = struct('hdr','','pars','','samples','');
         %self.sim = struct('hdr','','samples','');
         %self.sim = 
      end
      
      function out = extract(self,varargin)
         p = inputParser;
         p.KeepUnmatched= false;
         p.FunctionName = 'stanFit extract';
         p.addParamValue('pars',{},@(x) iscell(x) || ischar(x));
         p.addParamValue('permuted',false,@islogical);
         p.addParamValue('inc_warmup',true,@islogical);
         p.parse(varargin{:});
         
         if isempty(p.Results.pars)
            pars = self.sim(1).pars;
         else
            ind = ismember(p.Results.pars,self.sim(1).pars);
            if ~any(ind)
               error('bad pars');
            else
               pars = p.Results.pars(ind);
               if any(~ind)
                  temp = p.Results.pars(~ind);
                  warning('%s requested but not found, dropping',temp{:});
               end
            end
         end
         
         if p.Results.inc_warmup && ~self.model.params.sample.save_warmup
            warning('Warmup samples requested, but were not saved when model run');
         end
         
         keyboard
         
         %sim = self.sim;
         
         if p.Results.permuted
            
         else
            % return an array of three dimensions: iterations, chains, parameters
            out.pars = pars;
            out.samples
         end
      end
      
      
      function process_exit(self,src,evtdata)
         % need to id the chain that finished, load that data? or wait
         % until everyone is done???
         
         self.exitValue(strcmp(self.sample_file,src.id)) = src.exitValue;
         if all(self.exitValue == 0)
            disp('done');
            for i = 1:numel(self.sample_file)
               % FIXME, implement checking that all chains have same
               % parameters and settings
               [hdr,varNames,samples] =  self.read_stan_csv(self.sample_file{i},self.model.inc_warmup);
               %self.sim(i) = struct('hdr',hdr,'pars',{varNames},'samples',samples);
%               keyboard
%                self.sim(i) = struct('hdr',hdr','pars',{varNames},...
%                   'samples',cell2struct(num2cell(samples,1),varNames,2));
               if i == 1
                  self.sim = cell2struct(num2cell(samples,1),varNames,2);
               else
                  self.sim(i) = cell2struct(num2cell(samples,1),varNames,2);
%                   self.sim = cell2struct(cat(2,hdr,num2cell(samples,1)),cat(2,{'hdr'},varNames),2);
%                else
%                   self.sim(i) = cell2struct(cat(2,hdr,num2cell(samples,1)),cat(2,{'hdr'},varNames),2);
               end
               self.sample_file_hdr{i} = hdr;
               %self.sim(i) = struct('hdr',hdr,'samples',containers.Map(varNames,num2cell(samples,1)));
            end
         end
      end
%       function self = print(self,file)
%          % this should allow multiple files and regexp. 
%          % note that passing regexp through in the command does not work,
%          % need to implment search in matlab
%          if nargin < 2
%             file = self.params.output.file;
%          end
%          command = [self.stanHome 'bin/print ' file];
%          p = processManager('command',command,...
%                             'workingDir',self.workingDir,...
%                             'wrap',100,...
%                             'keepStdout',false);
%          p.block(0.05);
%       end
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
               % As of Stan 2.0.1, variables may not contain periods.
               % Periods are used to separate vector and array variables,
               % but cannot be used as fieldnames
               varNames = regexprep(varNames, '\.','_');
               if ~inc_warmup
                  % As of Stan 2.0.1, these lines exist when warmup is not
                  % saved
                  for i = 1:4 % ASSUMES 4 lines, should generalize
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
   end
end

