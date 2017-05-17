% CmdStan manual Appendix C
% https://github.com/stan-dev/rstan/search?q=stan_rdump&ref=cmdform
% struct or containers.Map
%
% mstan.rdump('test',struct('test',reshape(1:24,2,3,4)))
function fid = rdump(fname,content)
   if isstruct(content)
      vars = fieldnames(content);
      data = struct2cell(content);
   elseif isa(content,'containers.Map')
      vars = content.keys;
      data = content.values;
   else
      error('mstan.rdump content must be a struct or containers.Map');
   end

   fid = fopen(fname,'wt');
   c = onCleanup(@()fclose(fid));
   
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
      elseif isnumeric(data{i})
         fprintf(fid,'%s <- structure(c(',vars{i});
         if any(data{i}(:) > intmax('int32'))
            fprintf(fid,'%f, ',data{i}(1:end-1));
            fprintf(fid,'%f), .Dim = c(',data{i}(end));
         else
            fprintf(fid,'%d, ',data{i}(1:end-1));
            fprintf(fid,'%d), .Dim = c(',data{i}(end));
         end
         [sz(:)] = deal(size(data{i}));
         for j = 1:(numel(sz)-1)
            fprintf(fid,'%g,',sz(j));
         end
         fprintf(fid,'%g))\n',sz(end));
      end
   end
end
