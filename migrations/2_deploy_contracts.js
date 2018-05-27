var PVTSD = artifacts.require("./PVTSD.sol");

module.exports = function(deployer, network, accounts) {
  const exchangeRate = new web3.BigNumber(1000);
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3]
  ];
  const pvtBonusWallet = accounts[7];
  deployer.deploy(PVTSD, exchangeRate, whitelistAddresses);
};
