var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "your mnemonic words";

module.exports = {
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/CnfOcEcTLGVQ8q3Vyowk")
      },
      network_id: 3
    },
    mainnet: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "https://mainnet.infura.io/CnfOcEcTLGVQ8q3Vyowk ")
      },
      network_id: 1
    }
  }
};