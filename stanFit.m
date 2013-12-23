classdef stanFit < handle
   properties
      hdr
      varNames
      samples
      output_
   end
   methods
      function self = stanFit(p)
         
         % Listen for exit from processManager
         lh = addlistener(p,'exit',@(src,evnt)extract(self,src,evnt));
      end
      function extract(self,src,evtdata)
         % need to id the chain that finished, load that data? or wait
         % until everyone is done???
         disp('detect')
         fid = fopen(self.output_);
         [self.hdr,self.varNames,self.samples] = self.readStanCsv(fid);
         fclose(fid);
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
