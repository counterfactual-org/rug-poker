#!/bin/sh

source .env
# --skip-simulation for preventing error 'intrinsic gas too low'
forge script UpgradeScript --rpc-url $RPC_URL --skip-simulation
