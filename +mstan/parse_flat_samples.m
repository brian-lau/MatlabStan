% Convert CmdStan parameters and samples as returned in csv file into matrices
% of correct dimensionality
function [varNames,varDims,varSamples] = parse_flat_samples(flatNames,flatSamples)
   % Could probably be replaced with a few regexp expressions...
   %
   % As of Stan 2.0.1, variables may not contain periods.
   % Periods are used to separate dimensions of vector and array variables
   splitNames = regexp(flatNames, '\.', 'split');
   for j = 1:numel(splitNames)
      names{j} = splitNames{j}{1};
   end
   %varNames = unique(names,'stable'); % 2012a required
   [~,I] = unique(names,'first');
   varNames = names(sort(I));
   for j = 1:numel(varNames)
      ind = strcmp(names,varNames{j});

      % Parse dimensionality of parameter
      temp = cat(1,splitNames{ind});
      temp(:,1) = [];
      if size(temp,2) == 0
         % scalar
         varDims{j} = [1 1];
      elseif size(temp,2) == 1
         % vector
         varDims{j} = [max(str2num(sprintf('%s ',temp{:}))') 1];
      else
         % matrix
         for k = 1:size(temp,2)
            varDims{j}(k) = max(str2num(sprintf('%s ',temp{:,k}))');
         end
      end

      % Convert flat samples to correct shape
      temp = flatSamples(:,ind);
      if size(temp,1) == 1 % optimizing = 1 sample
         varSamples{j} = reshape(temp,varDims{j});
      else
         varSamples{j} = reshape(temp,[size(temp,1) varDims{j}]);
      end
   end
end
