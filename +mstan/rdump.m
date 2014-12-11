% https://github.com/stan-dev/rstan/search?q=stan_rdump&ref=cmdform
% struct or containers.Map
function fid = rdump(fname,content)
   if isstruct(content)
      vars = fieldnames(content);
      data = struct2cell(content);
   elseif isa(content,'containers.Map')
      vars = content.keys;
      data = content.values;
   end

   fid = fopen(fname,'wt');
   for i = 1:numel(vars)
      if isscalar(data{i})
         if any(data{i}(:) > intmax('int32'))
            fprintf(fid,'%s <- %f\n',vars{i},data{i});
         else
            fprintf(fid,'%s <- %d\n',vars{i},data{i});
         end
      elseif isvector(data{i})
         fprintf(fid,'%s <- c(',vars{i});
         if any(data{i}(:) > intmax('int32'))
            fprintf(fid,'%f, ',data{i}(1:end-1));
            fprintf(fid,'%f)\n',data{i}(end));
         else
            fprintf(fid,'%d, ',data{i}(1:end-1));
            fprintf(fid,'%d)\n',data{i}(end));
         end
      elseif ismatrix(data{i})
         fprintf(fid,'%s <- structure(c(',vars{i});
         if any(data{i}(:) > intmax('int32'))
            fprintf(fid,'%f, ',data{i}(1:end-1));
            fprintf(fid,'%f), .Dim = c(',data{i}(end));
         else
            fprintf(fid,'%d, ',data{i}(1:end-1));
            fprintf(fid,'%d), .Dim = c(',data{i}(end));
         end
         fprintf(fid,'%g,',size(data{i},1));
         fprintf(fid,'%g',size(data{i},2));
         fprintf(fid,'))\n');
      end
   end
   fclose(fid);
end
