:: ETL voor BRK GML met gebruik Stetl.
::
:: Dit is een front-end/wrapper batch-script om uiteindelijk Stetl met een configuratie
:: (etl-brk.cfg) en parameters (options\myoptions.args) aan te roepen. Dit script is
:: gebaseerd op het shell-script etl.sh.
::
:: Author: Frank Steggink
@echo off

setlocal

:: Gebruik Stetl meegeleverd met NLExtract (kan in theorie ook Stetl via pip install stetl zijn)
if "%STETL_HOME%"=="" (
    set STETL_HOME=../../externals/stetl
)

set NLX_HOME=../..
set BGT_HOME=../../bgt/etl

:: Nodig voor imports
if "%PYTHONPATH%"=="" (
    set PYTHONPATH=%BGT_HOME%;%NLX_HOME%;%STETL_HOME%
) else (
    set PYTHONPATH==%BGT_HOME%;%NLX_HOME%;%STETL_HOME%;%PYTHONPATH%
)

:: Default argumenten/opties
set options_file=options\default.args

:: Overrule eventueel het default optiebestand door het gebruik van een host-gebaseerd optiebestand
:: options\<hostnaam>.args. 
if exist options\%COMPUTERNAME%.args set options_file=options\%COMPUTERNAME%.args

:: Evt via commandline overrulen: etl-brk.cmd <mijn optiebestand>
if not "%~1"=="" set options_file=%1

:: Uiteindelijke commando. Kan ook gewoon "stetl -c etl-brk.cfg -a ..." worden indien Stetl installed
python %STETL_HOME%\stetl\main.py -c conf\etl-brk.cfg -a %options_file%

endlocal
