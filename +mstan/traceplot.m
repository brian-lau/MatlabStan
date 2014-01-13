function traceplot(out,maxRows)

fn = fieldnames(out);
nPars = numel(fn);
if nPars < maxRows;
   maxRows = nPars;
end
figure;
count = 1;
for i = 1:nPars
   % FIXME: will not work for n-D parameters! Recursion?
   for j = 1:size(out(1).(fn{i}),2)
      subplot(maxRows,1,count); hold on
      % Grab all chains for given parameter index
      temp = arrayfun(@(x) x.(fn{i})(:,j),out,'uni',false);
      plot(cell2mat(temp));
      %for k = 1:nChains
      %   plot(out(k).(fn{i})(:,j));
      %end
      if isvector(out(1).(fn{i}))
         title(fn{i})
      elseif ismatrix(out(1).(fn{i}))
         title([fn{i} num2str(j)])
      end
      count = count + 1;
      if count > maxRows
         if i < nPars
            figure;
            count = 1;
         end
      end
   end
end
