% http://semver.org/
% ver is str 'major.minor.patch' or
%        array [major minor patch]
function bool = check_ver(ver,req)

if ischar(ver)
   ver = cellfun(@str2num,regexp(ver,'\.','split'));
end
if ischar(req)
   req = cellfun(@str2num,regexp(req,'\.','split'));
end

assert((numel(ver)==3) && (numel(req)==3),...
   'Versions should be MAJOR.MINOR.PATCH');

if all(ver==req)
   bool = true;
   return;
end

bool = ver > req;
for i = 1:numel(bool)
   if bool(i)
      bool = true;
      return;
   end
end
bool = false;
