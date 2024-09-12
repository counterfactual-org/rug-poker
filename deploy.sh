#!/bin/sh

source .env
# --skip-simulation for preventing error 'intrinsic gas too low'
# --slow for preventing error 'nonce too low'
forge script DeployScript --rpc-url $RPC_URL --broadcast --skip-simulation --slow
