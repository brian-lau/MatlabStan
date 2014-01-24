function test_suite = test_mcmc
initTestSuite;

function test_new_chain1
d = fake_chain_data();
m = mcmc;

% add one chain
chain_ind = 1;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
assertTrue(all(ismember(m.names,d.names)))
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

% add a second chain
chain_ind = 2;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

function test_new_chain2
d = fake_chain_data();
m = mcmc;

% add one chain, but out of order
chain_ind = 2;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
assertTrue(all(ismember(m.names,d.names)))
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end
% Check that first chain is empty
chain_ind = 1;
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),[]);
   assertEqual(m.samples(chain_ind).(d.names{i}),[]);
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),0);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),0);
end

% Now add the first chain
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

function test_append_chain1
d = fake_chain_data();
m = mcmc;

% add one chain
chain_ind = 1;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
assertTrue(all(ismember(m.names,d.names)))
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

% append to the same chain
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),repmat(d.warmup{i},2,1));
   assertEqual(m.samples(chain_ind).(d.names{i}),repmat(d.iter{i},2,1));
end

function test_append_chain2
d = fake_chain_data();
m = mcmc;

% add one chain
chain_ind = 1;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
assertTrue(all(ismember(m.names,d.names)))
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

% add a second chain
chain_ind = 2;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

% append to the second chain
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),repmat(d.warmup{i},2,1));
   assertEqual(m.samples(chain_ind).(d.names{i}),repmat(d.iter{i},2,1));
end

% append to the second chain
chain_ind = 1;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),repmat(d.warmup{i},2,1));
   assertEqual(m.samples(chain_ind).(d.names{i}),repmat(d.iter{i},2,1));
end

% multidimensional parameters
function test_nd_array
d = fake_chain_data(2);
m = mcmc;

% add one chain
chain_ind = 1;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
assertTrue(all(ismember(m.names,d.names)))
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

% add a second chain
chain_ind = 2;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
   assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
   assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
   assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
end

% append to the second chain
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),repmat(d.warmup{i},2,1));
   assertEqual(m.samples(chain_ind).(d.names{i}),repmat(d.iter{i},2,1));
end

% append to the second chain
chain_ind = 1;
m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
for i = 1:numel(d.names)
   assertEqual(m.warmup(chain_ind).(d.names{i}),repmat(d.warmup{i},2,1));
   assertEqual(m.samples(chain_ind).(d.names{i}),repmat(d.iter{i},2,1));
end
