#!/usr/bin/env bash

docker exec -ti ico_ethernode_1 geth --exec "loadScript('/root/sync_stats.js')" attach /root/geth_ipc/geth.ipc
