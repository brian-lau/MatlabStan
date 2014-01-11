% Fit a model using Stan
function fit = stan(varargin)

p = inputParser;
p.KeepUnmatched= true;
p.FunctionName = 'stan';
p.addParamValue('fit',[],@(x) isa(x,'StanFit'));
p.parse(varargin{:});


if isempty(p.Results.fit)
   model = StanModel(p.Unmatched);
else
   model = p.Results.fit.model;
end

fit = model.sampling();

