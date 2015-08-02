function y = sumlogs(x,dim)
%SUMLOGS Sum of vector where numbers are represented by their logarithms.
%
%  Description
%    Y=SUMLOGS(X) Computes Y=log(sum(exp(X))) in such a fashion that
%    it works even when elements have large magnitude.
%
%    Y=SUMLOGS(X,DIM) sums along the dimension DIM. 
%
%  Copyright (c) 2013 Aki Vehtari

% This software is distributed under the GNU General Public
% License (version 3 or later); please refer to the file
% License.txt, included with the software, for details.

if nargin<2
  dim=find(size(x)>1,1);
end
maxx=max(x(:));
y=maxx+log(sum(exp(x-maxx),dim));
