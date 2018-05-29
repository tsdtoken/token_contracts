const PVTSD = artifacts.require("./PVTSD.sol");
const PRETSD = artifacts.require("./PRETSD.sol");

module.exports = function(deployer, network, accounts) {
  const exchangeRate = new web3.BigNumber(1000);
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3]
  ];
  deployer.deploy(PVTSD, exchangeRate, whitelistAddresses);
  deployer.deploy(PRETSD, exchangeRate, whitelistAddresses);
};
