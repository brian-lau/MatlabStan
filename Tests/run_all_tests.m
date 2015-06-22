% The tests in this directory were written for Steve Eddin's xUnit test framework:
%
% http://www.mathworks.com/matlabcentral/fileexchange/22846-matlab-xunit-test-framework
%
% All the tests in this directory can be run by just calling 'runtests'.
% However, it seems that occasionally, some older versions of Matlab will 
% produce errors that are actually not relevant under normal circumstances.
% This script introduces some pauses that prevent these errors.
%
% Individual tests can be run by calling 'runtests TestCase' where TestCase
% is the name of one of the particular tests.

t = 30;
runtests TestBasicArray;
pause(t);
runtests TestBasicMatrix;
pause(t);
runtests TestBernoulli;
pause(t);
runtests TestExtract;
pause(t);
runtests TestMCMC;
pause(t);
runtests TestNormal;
pause(t);
runtests TestOptim;
pause(t);
runtests TestRstanGettingStarted;
pause(t);
runtests TestStanModel;
pause(t);
