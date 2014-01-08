function count = write_lines(filename,contents)
   fid = fopen(filename,'w');
   if fid ~= -1
      count = fprintf(fid,'%s\n',contents{1:end-1});
      count2 = fprintf(fid,'%s',contents{end});
      count = count + count2;
      fclose(fid);
   else
      error('Cannot open file to write');
   end
end