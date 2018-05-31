const TSDSubsequentSupply = artifacts.require("./TSDSubsequentSupply.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError } = require('./testHelpers');

contract('TSDSubsequentSupply', (accounts) => {
  let TSDMockContract;
  let TSDSubsequentSupplyContract;
  // vars for TSDSubsequentSupply
  const TSDContractAddress;
  const firstAccountIdx = 14;
  // exchange rate is 1 szabo or 0.001
  const exchangeRate = new web3.BigNumber(1000);
  // wallet that will hold all of the ether transferred
  const newFundsWallet = accounts[firstAccountIdx+1];
  const newTokensWallet = accounts[firstAccountIdx+2];
  // vars for the tsd contract
  const owner = accounts[0];
  const fundsWallet = owner;
  const pvtSaleTokenWallet = accounts[firstAccountIdx+3];
  const preSaleTokenWallet = accounts[firstAccountIdx+4];
  const foundersAndAdvisors = accounts[firstAccountIdx+5];
  const bountyCommunityIncentives = accounts[firstAccountIdx+6];
  const liquidityProgram = accounts[firstAccountIdx+7];

  // buyers
  const buyerOne = accounts[firstAccountIdx+8];
  const buyerTwo = accounts[firstAccountIdx+9];
  const buyerThree = accounts[firstAccountIdx+10];
  const buyerFour = accounts[firstAccountIdx+11];
  const buyerFive = accounts[firstAccountIdx+12];
  const buyerSix = accounts[firstAccountIdx+13];
  const unlistedBuyer = accounts[firstAccountIdx+14];
  const whitelistAddresses = [
    buyerOne,
    buyerTwo,
    buyerThree,
    buyerFour,
    buyerFive,
    buyerSix
  ];

  beforeEach('set up contracts for each test', async () => {
    TSDMockContract = await TSDMock.new(
      currentTime,
      exchangeRate,
      whitelistAddresses,
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentives,
      liquidityProgram
    );

    TSDContractAddress = await TSDMockContract.address;

    TSDSubsequentSupplyContract = await TSDSubsequentSupply.new(TSDSubsequentSupplyContract);
  });
});