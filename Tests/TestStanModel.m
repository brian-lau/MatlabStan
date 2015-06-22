% xUnit framework required
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework

classdef TestStanModel < TestCase
   properties
      bernoulli_stan_md5 = 'f6d9f5c95697c6beb07542db5ba81175';
      bernoulli_code
   end
   
   methods
      function self = TestStanModel(name)
         self = self@TestCase(name);
      end
      
      function setUp(self)
         self.bernoulli_code = {
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
      end
      
      function testContructorNoArgs(self)
         s = StanModel();
         assertTrue(isa(s,'StanModel'),...
            'Constructor failed to create StanModel without inputs');
      end
      
      function testContructorArgs(self)
         s = StanModel();
         
         if mstan.check_ver(s.stan_version,'2.6.1')
            model_file = fullfile(mstan.stan_home,'examples','bernoulli','bernoulli.stan');
         elseif mstan.check_ver(s.stan_version,'2.6.0')
            model_file = fullfile(mstan.stan_home,'src','test','test-models','test_model.stan');
         elseif mstan.check_ver(s.stan_version,'2.5.0')
            model_file = fullfile(mstan.stan_home,'stan','example-models','basic_estimators','bernoulli.stan');
         elseif mstan.check_ver(s.stan_version,'2.4.0')
            model_file = fullfile(mstan.stan_home,'stan','src','models','basic_estimators','bernoulli.stan');
         else
            model_file = fullfile(mstan.stan_home,'src','models','basic_estimators','bernoulli.stan');
         end
         s = StanModel('file',...
             model_file,...
             'working_dir',tempdir,...
             'method','optimize',...
             'sample_file','junk',...
             'id',100,...
             'iter',100,...
             'warmup',1000,...
             'thin',10,...
             'init',10,...
             'seed',0,...
             'chains',3,...
             'inc_warmup',true,...
             'data',struct('N',2,'y',[0 0]),...
             'verbose',true,...
             'file_overwrite',true,...
             'refresh',5000);
         
         if mstan.check_ver(s.stan_version,'2.6.2')
             assertEqual(s.model_path,...
                 model_file);
             assertEqual(s.file,'bernoulli.stan');
             assertEqual(s.model_name,'bernoulli');
         elseif mstan.check_ver(s.stan_version,'2.6.0')
             assertEqual(s.model_path,...
                 model_file);
             assertEqual(s.file,'test_model.stan');
             assertEqual(s.model_name,'test_model');
         else
             assertEqual(s.model_path,...
                 model_file);
             assertEqual(s.file,'bernoulli.stan');
             assertEqual(s.model_name,'bernoulli');
         end
         
         assertEqual(s.working_dir,fileparts(tempdir));
         % TODO check code
         assertEqual(s.id,100);
         assertEqual(s.iter,100);
         assertEqual(s.warmup,1000);
         assertEqual(s.thin,10);
         assertEqual(s.seed,0);
         assertEqual(s.chains,3);
         assertEqual(s.inc_warmup,true);
         assertEqual(s.data,struct('N',2,'y',[0 0]));
         assertEqual(s.verbose,true);
         assertEqual(s.file_overwrite,true);
         assertEqual(s.refresh,5000);
         
         %TODO checksum_binary
      end
      
      function testSet(self)
         s = StanModel();
         
         if mstan.check_ver(s.stan_version,'2.6.1')
            model_file = fullfile(mstan.stan_home,'examples','bernoulli','bernoulli.stan');
         elseif mstan.check_ver(s.stan_version,'2.6.0')
            model_file = fullfile(mstan.stan_home,'src','test','test-models','test_model.stan');
         elseif mstan.check_ver(s.stan_version,'2.5.0')
            model_file = fullfile(mstan.stan_home,'stan','example-models','basic_estimators','bernoulli.stan');
         elseif mstan.check_ver(s.stan_version,'2.4.0')
            model_file = fullfile(mstan.stan_home,'stan','src','models','basic_estimators','bernoulli.stan');
         else
            model_file = fullfile(mstan.stan_home,'src','models','basic_estimators','bernoulli.stan');
         end
         s.set('file',...
             model_file,...
             'working_dir',tempdir,...
             'method','optimize',...
             'sample_file','junk',...
             'id',100,...
             'iter',100,...
             'warmup',1000,...
             'thin',10,...
             'init',10,...
             'seed',0,...
             'chains',3,...
             'inc_warmup',true,...
             'data',struct('N',2,'y',[0 0]),...
             'verbose',true,...
             'file_overwrite',true,...
             'refresh',5000);
         
         if mstan.check_ver(s.stan_version,'2.6.2')
             assertEqual(s.model_path,...
                 model_file);
             assertEqual(s.file,'bernoulli.stan');
             assertEqual(s.model_name,'bernoulli');
         elseif mstan.check_ver(s.stan_version,'2.6.0')
             assertEqual(s.model_path,...
                 model_file);
             assertEqual(s.file,'test_model.stan');
             assertEqual(s.model_name,'test_model');
         else
             assertEqual(s.model_path,...
                 model_file);
             assertEqual(s.file,'bernoulli.stan');
             assertEqual(s.model_name,'bernoulli');
         end
         
         assertEqual(s.working_dir,fileparts(tempdir));
         % TODO check code
         assertEqual(s.id,100);
         assertEqual(s.iter,100);
         assertEqual(s.warmup,1000);
         assertEqual(s.thin,10);
         assertEqual(s.seed,0);
         assertEqual(s.chains,3);
         assertEqual(s.inc_warmup,true);
         assertEqual(s.data,struct('N',2,'y',[0 0]));
         assertEqual(s.verbose,true);
         assertEqual(s.file_overwrite,true);
         assertEqual(s.refresh,5000);
         assertEqual(s.control,[]);

         % Sampling adapt & hmc parameters
         s.method = 'sample';
         control = s.control;
         control.engaged = false;
         control.gamma = 0.1;
         control.delta = 0.1;
         control.kappa = 0.1;
         control.t0 = 15;
         control.init_buffer = 15;
         control.term_buffer = 15;
         control.window = 15;
         control.metric = 'dense_e';
         control.stepsize = 10;
         control.stepsize_jitter = 0.5;
         s.set('control',control);
         assertEqual(s.control.engaged,false);
         assertEqual(s.control.gamma,0.1);
         assertEqual(s.control.delta,0.1);
         assertEqual(s.control.kappa,0.1);
         assertEqual(s.control.t0,15);
         assertEqual(s.control.init_buffer,15);
         assertEqual(s.control.term_buffer,15);
         assertEqual(s.control.window,15);
         assertEqual(s.control.metric,'dense_e');
         assertEqual(s.control.stepsize,10);
         assertEqual(s.control.stepsize_jitter,.5);
         
         %TODO checksum_binary
      end
      
      function testModelDefineFromCode(self)
         s = StanModel('model_code',self.bernoulli_code);
         self.file_matches(s,'anon_model.stan',...
            self.bernoulli_stan_md5,self.bernoulli_code);
                  
         % rename
         s.model_name = 'bernoulli';
         self.file_matches(s,'bernoulli.stan',...
            self.bernoulli_stan_md5,self.bernoulli_code);
         
      end
      
      function testModelDefineFromCodeAndName(self)
         s = StanModel('model_code',self.bernoulli_code,'model_name','bern');
         self.file_matches(s,'bern.stan',...
            self.bernoulli_stan_md5,self.bernoulli_code);
         %keyboard
         
         % compile
         
         % change code
         %bernoulli_model_code{end+1} = 'new';
         % set file_overwrite = true
         % check that md5 for binary is gone, check that binaries deleted
         
      end
     
      function testModelDefineFromFile(self)
         code = self.bernoulli_code;
         mstan.write_lines('junk.stan',code);
         
         s = StanModel('file','junk.stan');
         self.file_matches(s,'junk.stan',...
            self.bernoulli_stan_md5,self.bernoulli_code);         
      end
      % function testBadArgs
      % % f = @() processManager('id',{'should' 'not' 'work'});
      % % assertExceptionThrown(f,'processManager:id:InputFormat');
      
      function tearDown(self)
         delete('*.stan')
      end
   end
   
   methods(Static)
      function file_matches(s,stan_name,stan_md5,stan_code)
         [~,name,ext] = fileparts(stan_name);
         assertEqual(s.file,[name ext]);
         assertEqual(s.model_name,name);
         assertTrue(exist(fullfile(pwd,stan_name))==2);
         assertEqual(s.checksum_stan,stan_md5);

         str = mstan.read_lines(stan_name);
         assertTrue(all(strcmp(str,stan_code)));
      end
   end
end

