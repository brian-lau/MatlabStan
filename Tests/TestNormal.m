% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF: 
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_rstan_getting_started.py
classdef TestNormal < TestCase
   properties
      model
   end
   
   methods
      function self = TestNormal(name)
         self = self@TestCase(name);         
      end
      
      function setUp(self)
         model_code = {'parameters {real y;} model {y ~ normal(0,1);}'};

         model = StanModel('model_code',model_code,'model_name','normal1',...
            'file_overwrite',true);
         
         self.model = model;
      end
      
      function test_constructor(self)
         assertEqual(self.model.model_name,'normal1');
      end
      
      function test_log_prob(self)
         fit = self.model.sampling();
         fit.block();
         extr = fit.extract();
         [y_last,log_prob_last] = deal(extr.y(end),extr.lp__(end));
         
         % FIXME
         % don't have a log_prob method???
         % Rstan and Pystan wrap C++ code for this...
         %assertEqual(fit.log_prob(y_last), log_prob_last);
      end
            
      function tearDown(self)
         delete('normal1*');
         delete('output*');
      end
   end
end