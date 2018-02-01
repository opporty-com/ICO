#!/usr/bin/env bash

docker exec -ti ico_ethernode_1 geth --exec "miner.stop()" attach ipc:/root/geth_ipc/geth.ipc
