#!/bin/bash
#https://github.com/ethereum/go-ethereum/wiki/Command-Line-Options
set -e

declare VERBOSITY=${LOG_LEVEL:=1};

echo 'rm /root/.ethereum/devnet/geth'
rm -rf /root/.ethereum/devnet/geth

#echo 'cp devnet/keystore/'
#cp -r /root/devnet/keystore/* /root/.ethereum/devnet/keystore/

echo 'geth init genesis.json'
geth \
  --datadir "/root/.ethereum/devnet" \
  --verbosity ${VERBOSITY} \
  init "/root/devnet/genesis.json"

sleep 3

echo -e "geth start devnet log_level:${VERBOSITY}"

geth \
  --networkid 58545 \
  --nodiscover \
  --verbosity ${VERBOSITY} \
  --datadir "/root/.ethereum/devnet" \
  --keystore "/root/devnet/keystore" \
  --rpcaddr 0.0.0.0 \
  --maxpeers 0 \
  --rpcapi "db,eth,net,web3,personal" \
  --rpc \
  --jspath "/root/devnet/" \
  --preload "preload.js" \
  --password "/root/devnet/password" \
  --unlock 0 \
  --ipcdisable \
  --mine \
  --minerthreads 1