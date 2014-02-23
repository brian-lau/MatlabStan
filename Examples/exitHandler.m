

function exitHandler(src,data)
   fprintf('\n');
   beep;
   fprintf('Listener notified!\n');
   fprintf('Stan finished. Chains exited with exitValue = \n');
   disp(src.exit_value)
   fprintf('\n');
end
