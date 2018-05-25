const PVTSDMock = artifacts.require("./PVTSDMock.sol");
const moment = require('moment');
const { numFromWei, buyTokens, assertExpectedError, } = require('./testHelpers');

contract('PVTSDMock', (accounts) => {
  let PVTSDMockContract;
  const currentTime = moment().unix();
  const exchangeRate = new web3.BigNumber(1000);
  const owner = accounts[0];
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3]
  ];
  const buyerOne = accounts[1];
  const buyerTwo = accounts[2];
  const buyerThree = accounts[6];

  const pvtBonusWallet = accounts[7];

  beforeEach('setup contract for each test', async () => {
    PVTSDMockContract = await PVTSDMock.new(
      currentTime,
      exchangeRate,
      pvtBonusWallet,
      whitelistAddresses
    );
  });

  it('has an owner', async () => {
    assert.equal(await PVTSDMockContract.owner(), owner);
  });

  it('has a bonus wallet address', async () => {
    console.log(await PVTSDMockContract.pvtBonusWallet())
    console.log(await PVTSDMockContract.bonusAllocation())
  });

  it('designates the owner as the pvtFundsWallet', async () => {
    assert.equal(await PVTSDMockContract.pvtFundsWallet(), owner);
  });

  it('has a valid start time, end time and token release time', async () => {
    const startTime = await PVTSDMockContract.startTime();
    const endTime = await PVTSDMockContract.endTime();
    const tokensReleaseDate = await PVTSDMockContract.tokensReleaseDate();
    assert.equal(moment.unix(startTime.c[0]).isValid(), true);
    assert.equal(moment.unix(endTime.c[0]).isValid(), true);
    assert.equal(moment.unix(tokensReleaseDate.c[0]).isValid(), true);
  });

  it('sets the start time to be Fri Jun 15 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const startTime = await PVTSDMockContract.startTime();
    const dateString = new Date(startTime.c[0]);
    assert.equal(dateString, 'Fri Jun 15 2018 00:00:00 GMT+1000 (AEST)');
  });

  it('sets the end time to be Sun Jul 15 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const endTime = await PVTSDMockContract.endTime();
    const dateString = new Date(endTime.c[0]);
    assert.equal(dateString, 'Sun Jul 15 2018 00:00:00 GMT+1000 (AEST)');
  });

  it('sets the start time to be Mon Apr 15 2019 00:00:00 GMT+1000 (AEST)', async () => {
    const tokensReleaseDate = await PVTSDMockContract.tokensReleaseDate();
    const dateString = new Date(tokensReleaseDate.c[0]);
    assert.equal(dateString, 'Mon Apr 15 2019 00:00:00 GMT+1000 (AEST)');
  });

  it('creates a mapping of all whitelisted addresses', async () => {
    // Upon initialization of the contract, whitelisted addresses are placed into a mapping with the value of true
    const firstWhitelistAddress = await PVTSDMockContract.whiteListed(accounts[1]);
    const secondWhitelistAddress = await PVTSDMockContract.whiteListed(accounts[2]);
    const thirdWhitelistAddress = await PVTSDMockContract.whiteListed(accounts[3]);
    
    assert.equal(firstWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(secondWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(thirdWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
  });

  it('transfers total supply of tokens (55 million) to the private funds wallet', async () => {
    const pvtFundsWallet = owner;
    const pvtFundsWalletBalance = await PVTSDMockContract.balanceOf(pvtFundsWallet);

    assert.equal(numFromWei(pvtFundsWalletBalance), 55000000, 'Balance of pvtFundsWallet should be 55 million');
  });

  it('sets an exchange rate upon initialization', async () => {
    // Exchange rate was passed in as 1000
    const exchangeRateInContract = await PVTSDMockContract.exchangeRate();
    assert.equal(exchangeRateInContract.toNumber(), 1000, 'Exchange rate should be set to the passed in value (1000)')
  });

  it('can change the exchange rate if called by the owner only', async () => {
    const newRate = new web3.BigNumber(200);
    const beforeExchangeRate = await PVTSDMockContract.exchangeRate();
    const updatedFromOwner = await PVTSDMockContract.updateTheExchangeRate(newRate, { from: owner });
    const afterExchangeRate = await PVTSDMockContract.exchangeRate();
    // 1000 is the inital amount passed to the constructor
    assert.equal(beforeExchangeRate.toNumber(), 1000, 'Exchange rate should be set to the passed in value of 1000');
    assert.equal(afterExchangeRate.toNumber(), 200, 'Exchange rate should be set to the new rate of 200');
    assert.ok(updatedFromOwner);
  });

  it('cannot change exchange rate from an address that isn\'t the owner', async () => {
    const newRate = new web3.BigNumber(200);
    await assertExpectedError(PVTSDMockContract.updateTheExchangeRate(newRate, { from: accounts[6] }));
  });

  // Buy functions
  it('refuses a sale before the private sale\'s start time', async () => {
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('refuses a sale 1 second before the private sale\'s start time', async () => {
    const startTime = await PVTSDMockContract.startTime();
    const oneSecondPriorToOpen = new Date(startTime).setSeconds(-1);
    await PVTSDMockContract.changeTime(oneSecondPriorToOpen);
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('accepts ether once the sale opens', async () => {
    const startTime = await PVTSDMockContract.startTime();
    // const pvtFundsWallet = owner;
    await PVTSDMockContract.changeTime(startTime);
    // console.log('=======> await PVTSDMockContact.currentTime()', await PVTSDMockContract.currentTime());
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerOne));
    const balanceOfBuyer = await PVTSDMockContract.balanceOf(buyerOne);
    // const remainingTokens = await PVTSDMockContract.balanceOf(pvtFundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 70000, 'The buyers balance should be 50,000 + a bonus of 40% = 70,000')
  });
});
