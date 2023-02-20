require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");
const secret = require("../.secret2.json")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
          version: "0.8.4",
          settings: {
            optimizer: {
              enabled: true,
              runs: 50000,
            },
          },
      },
      {
          version: "0.6.6",
          settings: {
            optimizer: {
              enabled: true,
              runs: 10000000,
            },
          },
      }
  ],
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
        gas: 1200000000000,
        blockGasLimit: 0x1fffffffffffff,
        allowUnlimitedContractSize: true,
        timeout: 1800000,
      }
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [secret.testnet]
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 5000000000,
      accounts: [secret.mainnet]
    }
  },
  etherscan:{
    apiKey: {
      bscTestnet: secret.bscscanTest
    }
  },
};




