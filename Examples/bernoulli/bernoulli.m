% Import dependencies 
addpath( genpath('/Users/edelaire1/Documents/software/MatlabStan/'))
addpath( genpath('/Users/edelaire1/Documents/software/MatlabProcessManager/'))

%% Define data Model 
data = struct('N',10,...
              'y',[0,1,0,0,0,0,0,0,0,1]);

model_path = '/Users/edelaire1/Documents/software/MatlabStan/Examples/bernoulli/';
model = StanModel('file',fullfile(model_path,'bernoulli.stan'), 'method','sample','algorithm','NUTS','verbose',true, ...
    'working_dir',model_path);
model.compile();
model_fit = model.sampling('data', data);


%% 
model_fit.print()

figure;
model_fit.traceplot()

