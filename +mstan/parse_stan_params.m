% Generate command string from parameter structure. Very inefficient...
% root = 'sample' 'optimize' or 'diagnose'
% return a containers.Map?
function str = parse_stan_params(s,root)
   import mstan.parse_stan_params

   branch = {'sample' 'optimize' 'variational' 'diagnose' 'static' 'nuts' 'nesterov' 'bfgs' 'lbfgs'};
   if nargin == 2
      branch = branch(~strcmp(branch,root));
      fn = fieldnames(s);
      d = intersect(fn,branch);
      s = rmfield(s,d);
   end

   fn = fieldnames(s);
   val = '';
   str = {};
   for i = 1:numel(fn)
      try
         if isstruct(s.(fn{i}))
            % If any of the fieldnames match the *previous* value, assume the
            % previous value is a selector from amongst the fielnames, and
            % delete the other branches
            if any(strcmp(fieldnames(s),val))
               root = val;
               branch = branch(~strcmp(branch,root));
               d = intersect(fieldnames(s),branch);
               s = rmfield(s,d);

               str2 = parse_stan_params(s.(root));
               s = rmfield(s,root);
               str = cat(1,str,str2);
            else
               if ~strcmp(fn{i},val)
                  str = cat(1,str,{sprintf('%s ',fn{i})});
                  %fprintf('%s \\\n',fn{i});
               end
               str2 = parse_stan_params(s.(fn{i}));
               str = cat(1,str,str2);
            end
         else
            val = s.(fn{i});
            if isnumeric(val) || islogical(val)
               val = num2str(val);
            end
            str = cat(1,str,{sprintf('%s=%s ',fn{i},val)});
            %fprintf('%s=%s \\\n',fn{i},val);
         end
      catch
         % We trimmed a branch,
         %fprintf('dropping\n')
      end
   end
end
