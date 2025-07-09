#!/usr/bin/env bash
set -e

# Optionally allow overriding block time via env var
BLOCK_TIME="${BLOCK_TIME:-1}"

# Print version and start anvil
anvil --version
exec anvil --block-time "$BLOCK_TIME" --host 0.0.0.0
