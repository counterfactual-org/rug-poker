#!/bin/sh

source .env
forge script DeployScript --rpc-url $RPC_URL --broadcast
