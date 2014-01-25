% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF: 
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_rstan_getting_started.py
classdef TestRstanGettingStarted < TestCase
   properties
      fit
      code
      dat
   end
   
   methods
      function self = TestRstanGettingStarted(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         schools_code = {
            'data {'
            '    int<lower=0> J; // number of schools '
            '    real y[J]; // estimated treatment effects'
            '    real<lower=0> sigma[J]; // s.e. of effect estimates '
            '}'
            'parameters {'
            '    real mu; '
            '    real<lower=0> tau;'
            '    real eta[J];'
            '}'
            'transformed parameters {'
            '    real theta[J];'
            '    for (j in 1:J)'
            '    theta[j] <- mu + tau * eta[j];'
            '}'
            'model {'
            '    eta ~ normal(0, 1);'
            '    y ~ normal(theta, sigma);'
            '}'
         };

         schools_dat = struct('J',8,...
                              'y',[28 8 -3 7 -1 1 18 12],...
                              'sigma',[15 10 16 11 9 11 10 18]);
         
         fit = stan('model_code',schools_code,'data',schools_dat,...
            'iter',1000,'chains',4,'file_overwrite',true);
         fit.block();
         
         self.fit = fit;
         self.code = schools_code;
         self.dat = schools_dat;
      end
      
      function test_stan(self)
         self.validate_data(self.fit);
      end
      
      function test_stan_reuse_fit(self)
         fit1 = self.fit;
         fit = stan('fit',fit1,'data',self.dat,'iter',1000,'chains',4,...
             'file_overwrite',true);
         fit.block();
         self.validate_data(fit);
      end
      
      function test_stan_file(self)
         contents = self.fit.model.model_code;
         tempfile = fullfile(tempdir,...
            [self.fit.model.model_name num2str(randi(intmax)) '.stan']);
         fid = fopen(tempfile,'w');
         count = fprintf(fid,'%s\n',contents{1:end-1});
         count2 = fprintf(fid,'%s',contents{end});
         fclose(fid);
         
         fit = stan('file',tempfile,'data',self.dat,'iter',1000,'chains',4,...
            'file_overwrite',true);
         fit.block();
         self.validate_data(fit);         
         
         [path,name,ext] = fileparts(tempfile);
         delete([fullfile(path,name) '*']);
      end
      
      function tearDown(self)
         delete('anon_model*');
         delete('output*');
         delete('temp.data.R');
      end
   end
   
   methods(Static)
      function validate_data(fit)
         la = fit.extract();
         [mu,tau,eta,theta] = deal(la.mu,la.tau,la.eta,la.theta);
         % NOTE: these are the 2000 rather than 4000 to follow Pystan
         % convention, which specifies that iter includes warmup
         assertEqual(size(mu),[2000 1]);
         assertEqual(size(tau),[2000 1]);
         assertEqual(size(eta),[2000 8]);
         assertTrue((-1<mean(mu)) && (mean(mu)< 17));
         assertTrue((0<mean(tau)) && (mean(tau)<17));
         assertTrue(all(-3 < mean(eta)));
         assertTrue(all(mean(eta)) < 3);
         assertTrue(all(-15 < mean(theta)));
         assertTrue(all(mean(theta)) < 30);         
      end
   end
end



