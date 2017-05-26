% Write a struct or containers.Map to Rdump format
%
% mstan.rdump('test',struct('A',1,'B',[1 2 3],'C',magic(3),'D',reshape(1:24,2,3,4)))
%
% CmdStan manual Appendix C
% https://github.com/stan-dev/rstan/search?q=stan_rdump&ref=cmdform
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

assert(all(cellfun(@(x) isnumeric(x),data)),'Numeric data required');

fid = fopen(fname,'wt');
c = onCleanup(@()fclose(fid));

for i = 1:numel(vars)
   if isempty(data{i})
      continue;
   end
   if any(data{i}(:) > intmax('int32'))
      num_list = strrep(deblank(sprintf('%f ', data{i}(:))),' ',',');
   else
      num_list = strrep(deblank(sprintf('%d ', data{i}(:))),' ',',');
   end

   if isscalar(data{i})
      fprintf(fid,'%s <- %s\n',vars{i},num_list);
   elseif isvector(data{i})
      fprintf(fid,'%s <- c(%s)\n',vars{i},num_list);
   elseif isnumeric(data{i})
      fprintf(fid,'%s <- structure(c(%s), .Dim=c(',vars{i},num_list);
      [sz(:)] = deal(size(data{i}));
      for j = 1:(numel(sz)-1)
         fprintf(fid,'%g,',sz(j));
      end
      fprintf(fid,'%g))\n',sz(end));
      clear sz;
   end
end
