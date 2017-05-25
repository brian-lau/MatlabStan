% Generate a random UUID
% Dictionaries https://tools.ietf.org/rfc/rfc4648.txt
function uuid = randomUUID(base)

import mstan.*;

if nargin == 0
   base = 'hex';
end

uuid = char(java.util.UUID.randomUUID());

switch base
   case 'hex'
      return;
   case {'32' 32 'base32'}
      dict = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
   case {'62' 62 'base62'}
      dict = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
   case {'64' 64 'base64'}
      dict = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
end

uuid = strrep(uuid,'-','');
uuid = cnvbase(uuid,'0123456789abcdef',dict);