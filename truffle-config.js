const HDWalletProvider = require("@truffle/hdwallet-provider");
const mnemonic = "roast panic stadium average ill manual master pair mind infant decade flame";
const privateKeys = ["0x9a95b98fe7ac8586910417c890e41525b0ead1d597c4fb27f1f85dc4a877cc17"];

module.exports = {
  networks: {
     development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      // gas: 2000000
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: privateKeys,
          providerOrUrl: "https://ropsten.infura.io/v3/2ac1f90812764b18980c1b16c32734d0",
          chainId: 3,
        })
      },
      network_id: 3,
      skipDryRun: true,
      // gas: 10000000
    }
  },
  compilers: {
    solc: {
        version: '0.8.0',
        settings: { // See the solidity docs for advice about optimization and evmVersion
            optimizer: {
                enabled: true,
                runs: 200,
            },
            evmVersion: 'byzantium',
        },
    },
  },
};

