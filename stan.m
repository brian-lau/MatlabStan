% Fit a model using Stan
function fit = stan(varargin)

p = inputParser;
p.KeepUnmatched= true;
p.FunctionName = 'stan';
p.addParamValue('fit',@(x) isa(x,'StanFit'));
p.parse(varargin{:});


model = StanModel(p.Unmatched);
fit = model.sampling();

