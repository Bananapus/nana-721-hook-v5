#!/bin/bash

if ! command -v forge &> /dev/null
then
    echo "Could not find foundry."
    echo "Please refer to the README.md for installation instructions."
    exit
fi

help_string="Available commands:
  help, -h, --help           - Show this help message.
  coverage:lcov              - Generate an LCOV test coverage report.
  deploy:ethereum-mainnet    - Deploy to Ethereum mainnet.
  deploy:goerli              - Deploy to Goerli testnet.

  To deploy, set up the .env variables and add a mnemonic.txt file with the mnemonic of a deployer wallet. The sender address in the .env must correspond to the mnemonic account."

if [ $# -eq 0 ]
then
  echo "$help_string"
  exit
fi

case "$1" in
  "help") echo "$help_string" ;;
  "-h") echo "$help_string" ;;
  "--help") echo "$help_string" ;;
  "coverage:lcov") forge coverage --match-path "./src/*.sol" --report lcov --report summary ;;
  "deploy:ethereum-mainnet") source .env && forge script DeployMainnet --rpc-url $MAINNET_RPC_PROVIDER_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --ledger --sender $SENDER_ADDRESS --optimize --optimizer-runs 200 -vvv ;;
  "deploy:goerli") source .env && forge script DeployGoerli --rpc-url $GOERLI_RPC_PROVIDER_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --ledger --sender $SENDER_ADDRESS --optimize --optimizer-runs 200 -vvv, ;;
  *) echo "Invalid command: $1" ;;
esac

