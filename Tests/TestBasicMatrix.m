% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF:
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_basic_matrix.py
classdef TestBasicMatrix < TestCase
   properties
      fit
   end
   
   methods
      function self = TestBasicMatrix(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         model_code = {
            'data {'
            'int<lower=2> K;'
            'int<lower=1> D;'
            '}'
            'parameters {'
            'matrix[K,D] beta;'
            '}'
            'model {'
            'for (k in 1:K)'
            '    for (d in 1:D)'
            '       beta[k,d] ~ normal(if_else(d==2,100, 0),1);'
            '}'
            };
         
         % model = StanModel('model_code',model_code,'file_overwrite',true);
         % fit = model.sampling('data',struct('K',3,'D',4));
         
         fit = stan('model_code',model_code,'file_overwrite',true,...
            'data',struct('K',3,'D',4));
         fit.block();
         self.fit = fit;
      end
      
      function test_extract(self)
         fit = self.fit;
         beta = fit.extract().beta;
         assertEqual(size(beta),[4000 3 4]);
         beta_mean = mean(beta,1);
         assertTrue(all(beta_mean(:,1,1) < 4),'Should be < 4 on this dimension');
      end
      
      function tearDown(self)
         delete('anon_model*');
         delete('output*');
         delete('temp.data.R');
      end
   end
end