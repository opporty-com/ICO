#!/usr/bin/env bash

cd ..

if [[ -f ./../ethernode/rinkeby/password && -s ./../ethernode/rinkeby/password ]]; then
  docker exec -i ico_truffle_1 rm -rf /usr/src/app/build
  docker exec -i ico_truffle_1 truffle migrate --network rinkeby --reset $@
else
  echo -e "Migration not start. Need set password to ./ethernode/rinkeby/password";
fi
