const PVTSD = artifacts.require("./PVTSD.sol");
const PRETSD = artifacts.require("./PRETSD.sol");
const TSD = artifacts.require("./TSD.sol");

module.exports = function(deployer, network, accounts) {
  const exchangeRate = new web3.BigNumber(1000);
  const pvtSaleTokenWallet = accounts[4]
  const preSaleTokenWallet = accounts[5]
  const foundersAndAdvisors = accounts[6]
  const bountyCommunityIncentives = accounts[7]
  const liquidityProgram = accounts[8]
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3]
  ];
  deployer.deploy(PVTSD, exchangeRate, whitelistAddresses);
  // deployer.deploy(PRETSD, exchangeRate, whitelistAddresses);
  // deployer.deploy(
  //   TSD, 
  //   exchangeRate, 
  //   whitelistAddresses,
  //   pvtSaleTokenWallet,
  //   preSaleTokenWallet,
  //   foundersAndAdvisors,
  //   bountyCommunityIncentives,
  //   liquidityProgram
  // );
}; 
