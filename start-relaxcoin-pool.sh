#!/usr/bin/env bash

# Launch script for RelaxCoin mining pool server.
# This assumes the pool server binary or Node service is installed and able to read relaxcoin-pool-config.json.

CONFIG_FILE="$(dirname "$0")/relaxcoin-pool-config.json"
POOL_EXEC="./relaxcoin-pool-server"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Missing config file: $CONFIG_FILE"
  exit 1
fi

if [ ! -x "$POOL_EXEC" ]; then
  echo "ERROR: Pool executable not found or not executable: $POOL_EXEC"
  echo "Place your pool server binary in the same directory or adjust POOL_EXEC."
  exit 1
fi

export POOL_CONFIG="$CONFIG_FILE"
export POOL_OWNER_PRIVATE_KEY="your_pool_owner_private_key_here"

echo "Starting RelaxCoin mining pool server..."
"$POOL_EXEC" --config "$POOL_CONFIG"
