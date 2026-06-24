iverilog -g2012 -o sim_out.vvp *sv
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] COMPILATION FAILED!
    exit /B %ERRORLEVEL%
)
echo =^> COMPILATION SUCCESSFUL!
echo.

vvp sim_out.vvp
echo =^> FINISHED SIMULATION!
