% see https://github.com/brian-lau/MatlabStan/wiki/Using-listeners-to-notify-when-sampling-is-complete

function exitHandler(src,data)
   fprintf('\n');
   beep;
   fprintf('Listener notified!\n');
   fprintf('Stan finished. Chains exited with exitValue = \n');
   disp(src.exit_value)
   fprintf('\n');
end
