#!/usr/bin/env bash

docker exec -ti ico_ethernode_1 geth --exec 'var s = eth.syncing; console.log("\n------------ GETH SYNCING PROGRESS\nprogress: " + (s.currentBlock/s.highestBlock*100)+ " %\nblocks left to parse: "+ (s.highestBlock-s.currentBlock) + "\ncurrent Block: " + s.currentBlock + " of " + s.highestBlock+"\npeers:"+web3.net.peerCount)' attach /root/geth_ipc/geth.ipc
