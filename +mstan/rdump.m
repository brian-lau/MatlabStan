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
         fprintf(fid,'%s <- %d\n',vars{i},data{i});
      elseif isvector(data{i})
         fprintf(fid,'%s <- c(',vars{i});
         fprintf(fid,'%d, ',data{i}(1:end-1));
         fprintf(fid,'%d)\n',data{i}(end));
      elseif ismatrix(data{i})
         fprintf(fid,'%s <- structure(c(',vars{i});
         fprintf(fid,'%d, ',data{i}(1:end-1));
         fprintf(fid,'%d), .Dim = c(',data{i}(end));
         fprintf(fid,'%g,',size(data{i},1));
         fprintf(fid,'%g',size(data{i},2));
         fprintf(fid,'))\n');
      end
   end
   fclose(fid);
end
