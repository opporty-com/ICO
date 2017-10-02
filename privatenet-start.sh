#!/usr/bin/env bash

geth --networkid 58545 --nodiscover --datadir ./ethernode --maxpeers=0 --ipcpath $HOME/.ethereum/geth.ipc --rpc --preload="privatenet-preload.js" console 2>> ./ethernode/geth.log