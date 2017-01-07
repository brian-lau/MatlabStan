% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

% REF:
% https://github.com/stan-dev/pystan/blob/develop/pystan/tests/test_extract.py
classdef TestExtract < TestCase
   properties
      fit
   end
   
   methods
      function self = TestExtract(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         ex_model_code = {
            'parameters {'
            '     real alpha[2,3];'
            '     real beta[2];'
            '}'
            'model {'
            '     for (i in 1:2) for (j in 1:3)'
            '     alpha[i, j] ~ normal(0, 1);'
            '     for (i in 1:2)'
            '     beta ~ normal(0, 2);'
            '}'
            };
         fit = stan('model_code',ex_model_code,'file_overwrite',true);
         fit.block();
         self.fit = fit;
      end
      
      function test_extract_all(self)
         fit = self.fit;
         
         ss = fit.extract('permuted',true);
         alpha = ss.alpha;
         beta = ss.beta;
         lp__ = ss.lp__;
         
         ver = fit.model.stan_version;
         if mstan.check_ver(ver,'2.15.0')
            assertEqual(fieldnames(ss),{'lp__' 'accept_stat__' 'stepsize__' 'treedepth__' 'n_leapfrog__' 'divergent__' 'energy__' 'alpha' 'beta'}');
         elseif mstan.check_ver(ver,'2.2.0')
            assertEqual(fieldnames(ss),{'lp__' 'accept_stat__' 'stepsize__' 'treedepth__' 'n_leapfrog__' 'n_divergent__' 'alpha' 'beta'}');
         elseif mstan.check_ver(ver,'2.1.0')
            assertEqual(fieldnames(ss),{'lp__' 'accept_stat__' 'stepsize__' 'treedepth__' 'n_divergent__' 'alpha' 'beta'}');
         else
            assertEqual(fieldnames(ss),{'lp__' 'accept_stat__' 'stepsize__' 'treedepth__' 'alpha' 'beta'}');
         end
         assertEqual(size(alpha),[4000 2 3]);
         assertEqual(size(beta),[4000 2]);
         assertEqual(size(lp__),[4000 1]);
      end
      
      function test_extract_individual(self)
         fit = self.fit;
         
         ss = fit.extract('permuted',true);
         alpha = ss.alpha;

         % extract one at a time
         alpha2 = fit.extract('pars','alpha','permuted',true).alpha;
         assertEqual(size(alpha2),[4000 2 3]);
         assertEqual(alpha,alpha2);
         beta = fit.extract('pars','beta','permuted',true).beta;
         assertEqual(size(beta),[4000 2]);
         lp__ = fit.extract('pars','lp__','permuted',true).lp__;
         assertEqual(size(lp__),[4000 1]);
      end
      
      function test_permuted(self)
         fit = self.fit;
         % extract retrieves same permutation sequence
         ss = fit.extract('permuted',true);
         ss2 = fit.extract('permuted',true);
         assertEqual(ss,ss2);
      end
      
      function test_nonpermuted(self)
         fit = self.fit;
         %ss = fit.extract('permuted',false);
      end
      
      function tearDown(self)
         delete('anon_model*');
         delete('output*');
      end
   end
   
end