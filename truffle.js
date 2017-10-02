module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    privatenet: {
      host: "localhost",
      port: 8545,
      network_id: 58545,
    },
    rinkeby: {
      host: "localhost",
      port: 8545,
      network_id: 4,
      gas: 4612388 // Gas limit used for deploys
    }
  },
  mocha: {
    useColors: true
  }
};
