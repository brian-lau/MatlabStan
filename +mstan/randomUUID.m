function uuid = randomUUID(base)

import mstan.*;

if nargin == 0
   base = 'hex';
end

uuid = char(java.util.UUID.randomUUID());

switch base
   case 'hex'
      return;
   case {'62' 62 'base62'}
      dict = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
   case {'64' 64 'base64'}
      dict = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-';
end

uuid = strrep(uuid,'-','');
uuid = cnvbase(uuid,'0123456789abcdef',dict);