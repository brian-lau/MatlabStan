classdef RData < handle
   %RData
   % usage
   %   d = RData( map_or_struct );
   %   d.value('N') = 15;      % create or over-write value of 'N'
   %   d.type('N') = 'matrix'; % override auto-typed value of 'scalar' with a 1x1 matrix
   %   d.rdump(file)           %
   %
   % Mike Boedigheimer
   
   properties
      value;
      type;
   end
   
   methods
      function a = RData( map_or_struct )
         a.value = map_or_struct;
      end
      
      function set.value(a,dat)
         if isempty(dat)
            a.value = containers.Map('KeyType', 'char', 'KeyValue', 'any');
            a.type = containers.Map('KeyType', 'char', 'KeyValue', 'char');
            return;
         end
         if isa(dat, 'struct')
            names = fieldnames(dat);
            values = struct2cell(dat);
            a.value = containers.Map( names, values );
            a.init_data_type();
         elseif isa(dat, 'containers.Map')
            a.value = dat;
            a.init_data_type();
         end
      end
      function rdump(a,fname)
         try
            fid = fopen(fname,'wt');
            vars = a.value.keys;
            data = a.value.values;
            types = a.type.values;
            for i = 1:length(vars)
               if isempty(data{i})
                  continue;
               end
               if any(data{i}(:) > intmax('int32'))
                  ts = textscan( sprintf( '%f\n', data{i}(:) ), '%s', 'delimiter', '\n' );
               else
                  ts = textscan( sprintf( '%d\n', data{i}(:) ), '%s', 'delimiter', '\n' );
               end
               num_list = strjoin( ts{1}, ',');
               switch( types{i} )
                  case 'scalar'
                     fprintf(fid,'%s <- %s\n',vars{i},num_list);
                  case 'vector'
                     fprintf(fid,'%s <- c(%s)\n',vars{i},num_list);
                  case 'matrix'
                     fprintf(fid,'%s <- structure(c(%s), .Dim=c(%g, %g))\n', vars{i}, num_list, size(data{i},1), size(data{i},2));
               end
            end
            fclose(fid);
         catch
            if strcmp(ME.identifier, 'MATLAB:FileIO:InvalidFid')
               disp('Could not find the specified file.');
               rethrow(ME);
            end
         end
      end
   end
   
   methods( Access=protected)
      function vartype = init_data_type( a )
         x = a.value.values;
         n = length(x);
         vartype = repmat({''}, n,1);
         for i = 1:n
            if isscalar(x{i})
               vartype{i}= 'scalar';
            elseif isvector(x{i})
               vartype{i} = 'vector';
            elseif ismatrix(x{i})
               vartype{i} = 'matrix';
            end
         end
         a.type = containers.Map( a.value.keys, vartype );
      end
   end
end


