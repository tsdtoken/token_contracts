module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    ganache: {
      host: 'localhost',
      port: 7545,
      network_id: "5777"
    },
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '4224',
      gas: 4900000
    },
    homeskills: {
      host: 'localhost',
      port: 8545,
      network_id: '4224',
      gas: 4700000
    },
    rinkeby: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      gas: 4700000
    }
  }
};
