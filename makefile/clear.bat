IF exist *.vvp (
    del *.vvp
)
IF exist *.vcd (
    del *.vcd
)

echo "Deleting all .vvp and .vcd files"
echo "NEXT STEP: Run the simulation by executing run.bat"
cls