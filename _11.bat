@echo off
setlocal enabledelayedexpansion

:: Set the path to your folder manually
set "folder=%USERPROFILE%\Downloads\itrr"

:: Change to that directory
cd /d "%folder%"

:: Initialize counter
set i=1

:: Read each line from names.txt
for /f "usebackq delims=" %%A in ("names.txt") do (
    set "name=%%A"
    set "oldname=temp_!i!.xlsx"
    set "newname=!name!.xlsx"

    if exist "!oldname!" (
        echo Renaming !oldname! to !newname!
        ren "!oldname!" "!newname!"
    ) else (
        echo File !oldname! not found.
    )
    set /a i+=1
)

echo Done.
pause
