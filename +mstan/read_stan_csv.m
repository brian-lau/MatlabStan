% TODO, end of csv has commented lines with timing info, should scan
% inc_warmup = true works for optimizing files as well
function [hdr,varNames,samples,pos] = read_stan_csv(fname,inc_warmup,pos)
   if nargin < 2
      inc_warmup = false;
   end

   fid = fopen(fname);
   if nargin == 3
      status = fseek(fid,pos,'bof');
      if status == -1
         error('Could not advance to requested position.');
      end
   end
   
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
      count = count + 1;
   end
   hdr = sprintf('%s\n',line{:});
   nCols = numel(varNames);

   cols = repmat('%f',1,nCols);
   % textscan slow, replace with sscanf?
   % http://boffinblogger.blogspot.fr/2012/12/faster-text-file-reading-with-matlab.html
   [samples,pos] = textscan(fid,cols,'CollectOutput',true,...
      'CommentStyle','#','Delimiter',',');
   samples = samples{1};
   
   if nargout == 4
      pos = ftell(fid);
      if pos == -1
         warning('Could not determine position in file.');
      end
   end
   
   fclose(fid);
end
