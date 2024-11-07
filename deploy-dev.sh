#!/bin/sh

source .env
rm deployments/50161.json
rm facets/50161.json
# --skip-simulation for preventing error 'intrinsic gas too low'
# --slow for preventing error 'nonce too low'
forge script DeployScript --rpc-url http://localhost:50161 --broadcast --skip-simulation --slow
