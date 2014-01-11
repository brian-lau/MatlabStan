% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% ref 
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_rstan_getting_started.py
classdef TestNormal < TestCase
   properties
      model
   end
   
   methods
      function self = TestNormal(name)
         self = self@TestCase(name);
         
         model_code = {'parameters {real y;} model {y ~ normal(0,1);}'};

         model = StanModel('model_code',model_code,'model_name','normal1',...
            'verbose',true,'file_overwrite',true);
         
         self.model = model;
      end
      
      function setUp(self)
      end
      
      function test_constructor(self)
         assertEqual(self.model.model_name,'normal1');
      end
      
      function test_log_prob(self)
         fit = self.model.sampling();
         extr = fit.extract();
         [y_last,log_prob_last] = deal(extr.y(end),extr.lp__(end));
         
         % FIXME
         % don't have a log_prob method???
         % Rstan and Pystan wrap C++ code for this...
         %assertEqual(fit.log_prob(y_last), log_prob_last);
      end
            
      function teardown(self)
         delete(self.model);
      end
   end
end