iverilog -g2012 -o simv ML_DSA_LIGHTWEIGHT_SHAKE.sv tb_ML_DSA_LIGHTWEIGHT_SHAKE.sv 
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] COMPILATION FAILED!
    exit /B %ERRORLEVEL%
)
echo =^> COMPILATION SUCCESSFUL!
echo.

vvp simv
move simv C:\Users\User\Downloads\HASH_FAMILY\ML_DSA_SHAKE\ML_DSA_SHAKE\sim\
move *.vcd C:\Users\User\Downloads\HASH_FAMILY\ML_DSA_SHAKE\ML_DSA_SHAKE\sim\
echo =^> FINISHED SIMULATION!
