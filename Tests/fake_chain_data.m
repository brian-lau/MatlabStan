% for testing mcmc class
% test_mcmc.m

function dat = fake_chain_data(test)
if nargin == 0
   test = 1;
end

if test == 1
   names = {'a' 'b' 'c'};
   n_warmup = 100;
   n_iter = 200;

   warmup = {(1:n_warmup)' 2*(1:n_warmup)' 3*(1:n_warmup)'};
   iter = {(n_warmup+1:(n_warmup+n_iter))' 2*(n_warmup+1:(n_warmup+n_iter))' 3*(n_warmup+1:(n_warmup+n_iter))'};
   for i = 1:numel(names)
      C{i} = [warmup{i} ; iter{i}];
   end
   dat.names = names;
   dat.n_warmup = n_warmup;
   dat.warmup = warmup;
   dat.n_iter = n_iter;
   dat.iter = iter;
   dat.C = C;
elseif test == 2
   % multidimensional
   names = {'a' 'b' 'c'};
   n_warmup = 100;
   n_iter = 200;
   dims = [1 4 2];

   warmup = {(1:n_warmup)' 2*(1:n_warmup)' repmat(3*(1:n_warmup)',dims)};
   iter = {(n_warmup+1:(n_warmup+n_iter))' 2*(n_warmup+1:(n_warmup+n_iter))'...
      repmat(3*(n_warmup+1:(n_warmup+n_iter))',dims)};
   for i = 1:numel(names)
      C{i} = [warmup{i} ; iter{i}];
   end
   dat.names = names;
   dat.n_warmup = n_warmup;
   dat.warmup = warmup;
   dat.n_iter = n_iter;
   dat.iter = iter;
   dat.C = C;
end
