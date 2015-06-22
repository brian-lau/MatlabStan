% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF:
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_basic.py
classdef TestBernoulli < TestCase
   properties
      model
      fit
      code
      data
   end
   
   methods
      function self = TestBernoulli(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         bernoulli_model_code = {
         'data {'
         '    int<lower=0> N;'
         '    int<lower=0,upper=1> y[N];'
         '}'
         'parameters {'
         '    real<lower=0,upper=1> theta;'
         '}'
         'model {'
         'for (n in 1:N)'
         '    y[n] ~ bernoulli(theta);'
         '}'
         };

         bernoulli_data = struct('N',10,'y',[0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);

         model = StanModel('model_code',bernoulli_model_code,...
            'model_name','bernoulli','file_overwrite',true);
         fit = model.sampling('data',bernoulli_data);

         % Block until files are finished loading from
         fit.block();

         self.model = model;
         self.fit = fit;
         self.code = bernoulli_model_code;
         self.data = bernoulli_data;
      end
      
      function test_bernoulli_constructor(self)
         model = self.model;
         assertEqual(model.model_name,'bernoulli');
         assertEqual(model.model_code,self.code);
         assertTrue((exist('bernoulli.cpp','file')==2)||...
            (exist('bernoulli.hpp','file')==2),'CPP file not generated');
         if ispc
            [~,fa] = fileattrib('bernoulli.exe');
         else
            [~,fa] = fileattrib('bernoulli');
         end
         assertTrue(fa.UserExecute,'Executable file not generated correctly');
      end
      
      function test_bernoulli_sampling(self)
         fit = self.fit;
         % iter in Pystan is the sum of sampling iters and warmup
         assertEqual(fit.model.iter+fit.model.warmup,2000);
         assertTrue(all(ismember({'lp__','theta'},fieldnames(fit.sim.samples))));
         assertEqual(numel(fit.sim.samples),4);
         for i = 1:4
            assertEqual(size(fit.sim.samples(i).theta,1),1000);
            m = mean(fit.sim.samples(i).theta);
            assertTrue((0.1<m) && (m<0.4));
            v = var(fit.sim.samples(i).theta);
            assertTrue((0.01<v) && (v<0.02));
         end
      end
      
      function test_bernoulli_sampling_error(self)
         bad_data = self.model.data;
         bad_data = rmfield(bad_data,'N');
         % FIXME: currently this returns empty fit, with warnings. Make it
         % throw a proper error
         %fit = self.model.sampling('data',bad_data);
      end
      
      function test_bernoulli_extract(self)
         fit = self.fit;
         extr = fit.extract('permuted',true);
         assertTrue((-7.4<mean(extr.lp__)) && (mean(extr.lp__)<-7.0));
         assertTrue((0.1<mean(extr.theta)) && (mean(extr.theta)<0.4));
         assertTrue((0.01<var(extr.theta)) && (var(extr.theta)<0.02));
         
         % permuted=false
         % CHECK:
         extr = fit.extract('permuted',false);
         
         % permuted=true
         extr = fit.extract('pars','lp__','permuted',true);
         assertTrue((-7.4<mean(extr.lp__)) && (mean(extr.lp__)<-7.0));
         extr = fit.extract('pars','theta','permuted',true);
         assertTrue((0.1<mean(extr.theta)) && (mean(extr.theta)<0.4));
         assertTrue((0.01<var(extr.theta)) && (var(extr.theta)<0.02));
      end
      
      function test_bernoulli_random_seed_consistency(self)
         for i = 1:2
            fit(i) = self.model.sampling('data',self.data,'seed',42,...
               'sample_file',['output_' num2str(i)]);
            fit(i).block();
            theta{i} = fit(i).extract('pars','theta','permuted',true).theta;
         end
         assertEqual(theta{1},theta{2});
      end
      
      function tearDown(self)
         delete('bernoulli*');
         delete('output*');
         delete('temp.data.R');
      end
   end
   
end