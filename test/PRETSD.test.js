const PRETSDMock = artifacts.require("./PRETSDMock.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, } = require('./testHelpers');

contract('PRETSDMock', (accounts) => {
  let PRETSDMockContract;
  const currentTime = moment().unix();
  // exchange rate is 1 szabo or 0.000001
  const exchangeRate = new web3.BigNumber(1);
  const owner = accounts[0];
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3],
    accounts[4],
    accounts[5],
    accounts[6]
  ];
  const buyerOne = accounts[1];
  const buyerTwo = accounts[2];
  const buyerThree = accounts[3];
  const buyerFour = accounts[4];
  const buyerFive = accounts[5];
  const unlistedBuyer = accounts[7];

  beforeEach('setup contract for each test', async () => {
    PRETSDMockContract = await PRETSDMock.new(
      currentTime,
      exchangeRate,
      whitelistAddresses
    );
  });

  it('has an owner', async () => {
    assert.equal(await PRETSDMockContract.owner(), owner);
  });
});
