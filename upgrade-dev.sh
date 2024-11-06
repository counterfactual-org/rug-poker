#!/bin/sh

source .env
# --skip-simulation for preventing error 'intrinsic gas too low'
# --slow for preventing error 'nonce too low'
forge script UpgradeScript --rpc-url http://localhost:50161 --broadcast --skip-simulation --slow
