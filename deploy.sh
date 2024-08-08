#!/bin/sh

source .env
# --skip-simulation for preventing error 'intrinsic gas too low'
forge script DeployScript --rpc-url $RPC_URL --broadcast --skip-simulation
