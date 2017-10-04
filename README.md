# Opporty ICO
- [How to use docker](#how-to-use-docker)

A service-focused,
knowledge-sharing business platform
with decentralized, crypto-enabled marketplace
that facilitates purchase and sale

![Opporty ico](https://opporty.com/assets/img/ico/opp.png)


## How to use docker
> To begin with, you need to install a docker CE and a docker-compose according to this instruction 
> [docker CE](https://docs.docker.com/engine/installation/)
> [docker-compose](https://docs.docker.com/compose/install/)

Start private net
```bash
cd bin
./dev-up.sh
```

Start private net truffle migration
```bash
cd bin
./migration-dev.sh
```

Start rinkeby net
```bash
cd bin
./rinkeby-up.sh
```

Start rinkeby net truffle migration
> You must create a file with a password in the directory $HOME/ICO/ethernode/rinkeby/password 
> and insert the password from the private key (49b7776ea56080439000fd54c45d72d3ac213020)
```bash
cd bin
./migration-rinkeby.sh
```

Connection Ethereum Wallet to private net:

> Linux
```bash
ethereumwallet --rpc http://localhost:8545
```