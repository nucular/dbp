@echo off

if "%1"=="" (
    echo Usage: build.bat [Path to Derelict root folder]
) else (
    echo == Building dbp.d
    dmd -I%1/import -O -inline %1/lib/dmd/DerelictSDL2.lib %1/lib/dmd/DerelictUtil.lib dbp.d
    echo == Assembling start.bp from bg.png
    img2bp.py bg.png start.bp
)
