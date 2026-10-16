@echo off
REM R2R GPU Mining Client - Windows Launcher
REM Supports NVIDIA RTX and AMD RX series

setlocal enabledelayedexpansion

echo ========================================
echo   R2R GPU Mining Client v1.0
echo   Relax Coin Network
echo ========================================
echo.

REM Check Python installation
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.9+ and add it to PATH
    pause
    exit /b 1
)

REM Check if config file exists
if not exist "r2r_mining_config.json" (
    echo ERROR: r2r_mining_config.json not found!
    echo Please create the configuration file first.
    pause
    exit /b 1
)

REM Install Python dependencies
echo Installing Python dependencies...
pip install web3 eth-account pycryptodome --quiet

REM Check for CUDA
echo.
echo Checking for NVIDIA CUDA support...
python -c "import pycuda.driver; print('CUDA: OK')" >nul 2>&1
if errorlevel 1 (
    echo CUDA not detected. Install NVIDIA CUDA Toolkit for GPU mining.
    echo Download from: https://developer.nvidia.com/cuda-toolkit
)

REM Check for OpenCL
echo Checking for AMD OpenCL support...
python -c "import pyopencl; print('OpenCL: OK')" >nul 2>&1
if errorlevel 1 (
    echo OpenCL not detected. Install AMD OpenCL drivers for GPU mining.
    echo Download from: https://www.amd.com/en/technologies/opencl
)

echo.
echo ========================================
echo   Configuration: r2r_mining_config.json
echo ========================================

REM Get mining duration (default 24 hours)
set /p DURATION="Enter mining duration in hours (default 24): "
if "!DURATION!"=="" set DURATION=24

REM Ask for auto-claim
set /p AUTO_CLAIM="Auto-claim rewards? (y/n, default y): "
if "!AUTO_CLAIM!"=="" set AUTO_CLAIM=y

REM Build command
set CMD=python r2r_gpu_miner.py --config r2r_mining_config.json --duration !DURATION!
if "!AUTO_CLAIM!"=="y" set CMD=!CMD! --claim

echo.
echo ========================================
echo   Starting Mining...
echo ========================================
echo Command: !CMD!
echo.

REM Run the miner
!CMD!

if errorlevel 1 (
    echo.
    echo Mining failed! Check error messages above.
    pause
    exit /b 1
)

echo.
echo Mining completed successfully!
pause
exit /b 0
