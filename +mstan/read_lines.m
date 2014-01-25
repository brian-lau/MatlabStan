function lines = read_lines(filename)
   try
      if strncmp(filename,'http',4)
         str = urlread(filename);
      else
         path = fileparts(filename);
         if isempty(path)
            filename = fullfile(pwd,filename);
         end
         str = urlread(['file:///' filename]);
      end
      lines = regexp(str,'(\r\n|\n|\r)','split')';
   catch err
      if strcmp(err.identifier,'MATLAB:urlread:ConnectionFailed')
         %fprintf('File does not exist\n');
         lines = {};
      else
         rethrow(err);
      end
   end
end
