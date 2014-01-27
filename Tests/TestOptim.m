% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF:
classdef TestOptim < TestCase
   properties
      code
      data
      model
   end
   
   methods
      function self = TestOptim(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         stdnorm = {
            'data {'
            '  int N;'
            '  real y[N];'
            '}'
            'parameters {'
            '  real mu;'
            '  real<lower=0> sigma;'
            '}'
            'model {'
            '  mu ~ normal(0, 5);'
            '  sigma ~ normal(0, 5);'
            '  y ~ normal(mu, sigma);'
            '}'
            };

         self.code = stdnorm;
         self.data = struct('N',30,'y',randn(30,1));
         self.model = StanModel('model_code',stdnorm,'file_overwrite',true);
      end
      
      function test_method_call(self)
         sm = self.model;
         optim = sm.optimizing('data',self.data);
         optim.block();
         
         assertTrue((-1<optim.sim.samples.mu) && (optim.sim.samples.mu) < 1);
         assertTrue((0<optim.sim.samples.sigma) && (optim.sim.samples.mu) < 2);
      end
      
      function test_data_file(self)
         sm = self.model;
         mstan.rdump('optim.data.R',self.data);
         optim = sm.optimizing('data','optim.data.R');
         optim.block();

         assertTrue((-1<optim.sim.samples.mu) && (optim.sim.samples.mu) < 1);
         assertTrue((0<optim.sim.samples.sigma) && (optim.sim.samples.mu) < 2);
      end
      
      function test_stan(self)
         optim = stan('model_code',self.code,'method','optimize',...
            'data',self.data,'file_overwrite',true);
         optim.block();

         assertTrue((-1<optim.sim.samples.mu) && (optim.sim.samples.mu) < 1);
         assertTrue((0<optim.sim.samples.sigma) && (optim.sim.samples.mu) < 2);
      end
      
      function tearDown(self)
         delete('anon_model*');
         delete('output*');
         warning off;
         delete('optim.data.R');
         delete('temp.data.R');
         warning on;
      end
   end
   
end