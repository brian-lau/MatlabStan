classdef stanFit < handle
   properties
      pars
      sim

      output
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
         p.addParamValue('output',{},@iscell);
         p.parse(varargin{:});

         if ~isempty(p.Results.processes)
            % Listen for exit from processManager
            lh = addlistener(p.Results.processes,'exit',@(src,evnt)extract(self,src,evnt));
         end
         if ~isempty(p.Results.output)
            self.output = p.Results.output;
            self.exitValue = nan(size(self.output));
         end
         
      end
      function extract(self,src,evtdata)
         % need to id the chain that finished, load that data? or wait
         % until everyone is done???
         %disp('detect')
         self.exitValue(strcmp(self.output,src.id)) = src.exitValue;
         if all(self.exitValue == 0)
            disp('done');
            for i = 1:numel(self.output)
               fid = fopen(self.output{i});
               [self.hdr{i},self.varNames{i},self.samples{i}] = self.readStanCsv(fid);
               fclose(fid);
            end
         end
      end
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
