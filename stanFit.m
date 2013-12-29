classdef stanFit < handle
   properties
      pars
      sim

      sample_file
      exitValue
      hdr
      varNames
      samples
      
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
         p.addParamValue('processes','',@(x) isa(x,'processManager'));
         p.addParamValue('sample_file',{},@iscell);
         p.parse(varargin{:});

         if ~isempty(p.Results.processes)
            % Listen for exit from processManager
            lh = addlistener(p.Results.processes,'exit',@(src,evnt)extract(self,src,evnt));
         end
         if ~isempty(p.Results.sample_file)
            self.sample_file = p.Results.sample_file;
            self.exitValue = nan(size(self.sample_file));
         end
         
      end
      function extract(self,src,evtdata)
         % need to id the chain that finished, load that data? or wait
         % until everyone is done???
         
         self.exitValue(strcmp(self.sample_file,src.id)) = src.exitValue;
         if all(self.exitValue == 0)
            disp('done');
            for i = 1:numel(self.sample_file)
               fid = fopen(self.sample_file{i});
               [self.hdr{i},self.varNames{i},self.samples{i}] = self.readStanCsv(fid);
               fclose(fid);
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
      function [hdr,varNames,samples] = readStanCsv(fid)
         count = 1;
         while 1
            l = fgetl(fid);
            
            if strcmp(l(1),'#')
               line{count} = l;
            else
               varNames = regexp(l, '\,', 'split');
               for i = 1:4 % ASSUMES 4 lines, should generalize
                  line{count} = fgetl(fid);
                  count = count + 1;
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
      end
      
   end
end
