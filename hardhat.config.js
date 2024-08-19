require("@nomicfoundation/hardhat-toolbox");
const { vars } = require("hardhat/config");

const RPC_URL = vars.get("RPC_URL");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");

module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {},
    sepolia: {
      chainId: 11155111,
      url: RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },
};
