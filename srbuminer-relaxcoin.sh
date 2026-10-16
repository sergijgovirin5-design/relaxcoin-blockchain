#!/usr/bin/env bash
# SRBMiner-MULTI template for macOS / Apple Silicon
# Supports RandomX for Apple Silicon M1/M2/M3/M4 and other compatible hardware.

POOL_HOST="127.0.0.1"
POOL_PORT="5555"
WALLET="0xYourMetaMaskAddress.SRBWorker"
ALGO="randomx"
SRB_PATH="/path/to/SRBMiner-MULTI"

if [ ! -x "$SRB_PATH" ]; then
  echo "ERROR: SRBMiner-MULTI not found at $SRB_PATH"
  exit 1
fi

$SRB_PATH --algorithm $ALGO --pool stratum+tcp://$POOL_HOST:$POOL_PORT --user $WALLET --pass x --cpu 4 --donate-level 1
