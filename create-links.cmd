@echo off
echo Creating links in %~f1
echo Links pointing to %cd%

mklink /j %~f1\MQL5\Profiles\Tester\git %cd%\testdata
mklink /j %~1\MQL5\Experts\git %cd%\myexperts 
mklink /j %~f1\MQL5\Indicators\git %cd%\myindicators

