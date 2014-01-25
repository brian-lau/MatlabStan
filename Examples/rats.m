rats = importdata('rats.txt');
y = rats.data;
x = [8 15 22 29 36];
rats_dat = struct('N',size(y,1),'TT',size(y,2),'x',x,'y',y,'xbar',mean(x));

rats_fit = stan('file','rats.stan','data',rats_dat,'verbose',true);

%
%model = StanModel('file','rats.stan','stan_home',...
%   '/Users/brian/Downloads/stan-2.0.1','verbose',true);
%fit = model.sampling('data',rats_dat);
