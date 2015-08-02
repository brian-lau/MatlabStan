% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

classdef TestMCMC < TestCase
   properties
   end
   
   methods
      function self = TestMCMC(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
      end
      
      function test_rng_state(self)
         d = self.fake_chain_data();
         m = mcmc(1234);

         assertEqual(m.rng_state.Seed,uint32(1234));
         
         % add one chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         assertTrue(all(ismember(m.names,d.names)))
         self.validate_data(m,d,chain_ind);

         % Check that repeated extractions yield same sequence
         temp1 = m.extract;
         temp2 = m.extract;
         temp3 = m.extract('permuted',false);
         assertTrue(isequal(temp1,temp2));
         assertFalse(isequal(temp1,temp3));
         assertFalse(isequal(temp2,temp3));

         m.rng_state = 4321;
         
         assertEqual(m.rng_state.Seed,uint32(4321));
         
         % Check that new seed yields new permutations
         temp4 = m.extract;
         temp5 = m.extract;
         temp6 = m.extract('permuted',false);
         assertTrue(isequal(temp4,temp5));
         assertFalse(isequal(temp4,temp6));
         assertFalse(isequal(temp5,temp6));
         assertFalse(isequal(temp1,temp4));
         assertTrue(isequal(temp3,temp6));
      end
      
      function test_new_chain1(self)
         d = self.fake_chain_data();
         m = mcmc;

         % add one chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         assertTrue(all(ismember(m.names,d.names)))
         self.validate_data(m,d,chain_ind);
         
         % add a second chain
         chain_ind = 2;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data(m,d,chain_ind);
         
         assertTrue(isprop(m,'n_warmup'));
         assertTrue(isprop(m,'n_samples'));
      end
      function test_new_chain2(self)
         d = self.fake_chain_data();
         m = mcmc;
         
         % add one chain, but out of order
         chain_ind = 2;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         assertTrue(all(ismember(m.names,d.names)))
         self.validate_data(m,d,chain_ind);

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
         self.validate_data(m,d,chain_ind);
         
         assertTrue(isprop(m,'n_warmup'));
         assertTrue(isprop(m,'n_samples'));
      end
      function test_append_chain1(self)
         d = self.fake_chain_data();
         m = mcmc;
         
         % add one chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         assertTrue(all(ismember(m.names,d.names)))
         self.validate_data(m,d,chain_ind);
         
         % append to the same chain
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data2(m,d,chain_ind);
                  
         assertTrue(isprop(m,'n_warmup'));
         assertTrue(isprop(m,'n_samples'));
      end
      function test_append_chain2(self)
         d = self.fake_chain_data();
         m = mcmc;
         
         % add one chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         assertTrue(all(ismember(m.names,d.names)))
         self.validate_data(m,d,chain_ind);
         
         % add a second chain
         chain_ind = 2;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data(m,d,chain_ind);
         
         % append to the second chain
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data2(m,d,chain_ind);
         
         % append to the first chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data2(m,d,chain_ind);

         assertTrue(isprop(m,'n_warmup'));
         assertTrue(isprop(m,'n_samples'));
      end
      % multidimensional parameters
      function test_nd_array(self)
         d = self.fake_chain_data(2);
         m = mcmc;
         
         % add one chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         assertTrue(all(ismember(m.names,d.names)))
         self.validate_data(m,d,chain_ind);
         
         % add a second chain
         chain_ind = 2;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data(m,d,chain_ind);
         
         % append to the second chain
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data2(m,d,chain_ind);
         
         % append to the second chain
         chain_ind = 1;
         m.append(d.C,d.names,d.n_warmup,d.n_iter,chain_ind);
         self.validate_data2(m,d,chain_ind);

         assertTrue(isprop(m,'n_warmup'));
         assertTrue(isprop(m,'n_samples'));
      end
      
      function tearDown(self)
      end
   end
   
   methods(Static)
      function validate_data(m,d,chain_ind)
         for i = 1:numel(d.names)
            assertEqual(m.warmup(chain_ind).(d.names{i}),d.warmup{i});
            assertEqual(m.samples(chain_ind).(d.names{i}),d.iter{i});
            assertEqual(m.n_warmup(chain_ind).(d.names{i}),d.n_warmup);
            assertEqual(m.n_samples(chain_ind).(d.names{i}),d.n_iter);
         end
      end
      function validate_data2(m,d,chain_ind)
         for i = 1:numel(d.names)
            assertEqual(m.warmup(chain_ind).(d.names{i}),repmat(d.warmup{i},2,1));
            assertEqual(m.samples(chain_ind).(d.names{i}),repmat(d.iter{i},2,1));
         end
      end
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
      end
   end
end

