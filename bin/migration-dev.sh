#!/usr/bin/env bash

docker exec -i ico_truffle_1 truffle migrate --network development --reset $@