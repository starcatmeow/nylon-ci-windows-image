@echo off
setlocal

rem QEMU's first serial port: 115200 baud, 8N1, no flow control.
mode COM1: baud=115200 parity=n data=8 stop=1 xon=off odsr=off octs=off idsr=off dtr=on rts=on >nul
if errorlevel 1 exit /b 1

>\\.\COM1 echo OOBE_COMPLETE
if errorlevel 1 exit /b 1

rem Let SetupComplete.cmd return before the scheduled shutdown begins.
shutdown.exe /s /t 10 /d p:4:2 /c "Windows image setup complete"
exit /b %errorlevel%
