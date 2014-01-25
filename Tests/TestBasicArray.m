% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF:
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_basic_array.py
classdef TestBasicArray < TestCase
   properties
      fit
   end
   
   methods
      function self = TestBasicArray(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         model_code = {
            'data {'
            '  int<lower=2> K;'
            '}'
            'parameters {'
            '  real beta[K,1,2];'
            '}'
            'model {'
            '  for (k in 1:K)'
            '    beta[k,1,1] ~ normal(0,1);'
            '  for (k in 1:K)'
            '    beta[k,1,2] ~ normal(100,1);'
            '}'
            };
         
         fit = stan('model_code',model_code,'data',struct('K',4),'file_overwrite',true);
         fit.block()
         self.fit = fit;
      end
      
      function test_extract_permuted(self)
         fit = self.fit;
         % extract, permuted = true
         beta = fit.extract().beta;
         assertEqual(size(beta),[4000 4 1 2]);
         beta_mean = mean(beta,1);
         assertEqual(size(beta_mean),[1 4 1 2]);
         assertTrue(all(beta_mean(:,1,1) < 4),'Should be < 4 on this dimension');
         assertTrue(all(beta_mean(:,1,2) > (100-4)),'Should be > 100 on this dimension');
      end
      function test_extract_nonpermuted(self)
         fit = self.fit;
         % extract, permuted = false
         % Rstan and pystan return an 3D array : iterations x chains x parameters
         % The Matlab interface now separates sample storage into the mcmc class
         % The following checks are specific to the Matlab interface
         extracted = fit.extract('permuted',false);
         assertEqual(size(extracted),[1 4]); % # of chains
         
         beta_mean = arrayfun(@(x) mean(x.beta,1),extracted,'uni',false);
         for i = 1:4
            assertTrue(all(beta_mean{i}(:,1,1) < 4),'Should be < 4 on this dimension');
            assertTrue(all(beta_mean{i}(:,1,2) > (100-4)),'Should be > 100 on this dimension');
         end
         lp_mean = arrayfun(@(x) mean(x.lp__,1),extracted);
         assertTrue(all(lp_mean < 4),'Should be < 4 on this dimension');
      end
      
      function tearDown(self)
         delete('anon_model*');
         delete('output*');
         delete('temp.data.R');
      end
   end
end