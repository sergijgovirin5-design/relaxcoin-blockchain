@echo off
REM Rigel Miner template for Windows connecting to the RelaxCoin mining pool
SET POOL_HOST=127.0.0.1
SET POOL_PORT=5555
SET WALLET=0xYourMetaMaskAddress.RigelGPU
SET ALGO=kawpow
SET POOL_URL=stratum+tcp://%POOL_HOST%:%POOL_PORT%

REM Replace rigelminer.exe with the actual executable path if needed.
rigelminer.exe --algo %ALGO% --url %POOL_URL% --user %WALLET% --pass x --intensity 20
pause
