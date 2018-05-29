const PVTSDMock = artifacts.require("./PVTSDMock.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, } = require('./testHelpers');

contract('PVTSDMock', (accounts) => {
  let PVTSDMockContract;
  const currentTime = moment().unix();
  // exchange rate is 1 szabo or 0.001
  const exchangeRate = new web3.BigNumber(1000);
  const owner = accounts[0];
  const pvtFundsWallet = owner;
  const whitelistAddresses = [
    accounts[1],
    accounts[2],
    accounts[3],
    accounts[4],
    accounts[5],
    accounts[6],
    accounts[7]
  ];
  const buyerOne = accounts[1];
  const buyerTwo = accounts[2];
  const buyerThree = accounts[3];
  const buyerFour = accounts[4];
  const buyerFive = accounts[5];
  const buyerSix = accounts[6];
  const buyerSeven = accounts[7];
  const unlistedBuyer = accounts[9];

  beforeEach('setup contract for each test', async () => {
    PVTSDMockContract = await PVTSDMock.new(
      currentTime,
      exchangeRate,
      whitelistAddresses
    );
  });

  it('has an owner', async () => {
    assert.equal(await PVTSDMockContract.owner(), owner);
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

  // exchange rate functionality

  it('sets the exchange rate upon initialization', async () => {
    // exchange rate passed in was 1 szabo or 0.000001ETH
    const exchangeRate = await PVTSDMockContract.exchangeRate();
    assert.ok(exchangeRate);
    assert.equal(numFromWei(exchangeRate, 'szabo'), 1000, 'Exchange rate should be set to 1 szabo (0.000001 ETH)')
  });

  it('can change the exchange rate if called by the owner only', async () => {
    // the exhange rate being passed in is 1 TSD => 0.002 ETH
    const newRate = new web3.BigNumber(2000);
    const beforeExchangeRate = await PVTSDMockContract.exchangeRate();
    const updatedFromOwner = await PVTSDMockContract.updateTheExchangeRate(newRate, { from: owner });
    const afterExchangeRate = await PVTSDMockContract.exchangeRate();
    // 1000 szabo is the inital amount passed to the constructor
    assert.equal(numFromWei(beforeExchangeRate, 'szabo'), 1000, 'Exchange rate should be set to the passed in value of 1 szabo');
    assert.equal(numFromWei(afterExchangeRate, 'szabo'), 2000, 'Exchange rate should be set to the new rate of 200');
    assert.ok(updatedFromOwner);
  });

  it('cannot change exchange rate from an address that isn\'t the owner', async () => {
    const newRate = new web3.BigNumber(2000);
    await assertExpectedError(PVTSDMockContract.updateTheExchangeRate(newRate, { from: accounts[6] }));
  });

  // Buy functionality

  it('refuses a sale before the private sale\'s start time', async () => {
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('refuses a sale 1 second before the private sale\'s start time', async () => {
    const startTime = await PVTSDMockContract.startTime();
    const oneSecondPriorToOpen = new Date(startTime).setSeconds(-1);
    await PVTSDMockContract.changeTime(oneSecondPriorToOpen);
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('accepts ether at the exact moment the sale opens', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 50 ether
    // discount of 40% is applied
    // echange rate becaome 600 szabo pr 0.0006ETH
    // 50ETH / 0.0006 = 83333 Tokens
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime);
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerOne));
    const balanceOfBuyer = await PVTSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await PVTSDMockContract.balanceOf(pvtFundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 83333, 'The buyers balance should 83,333 tokens')
    assert.equal(numFromWei(remainingTokens), 54916667, 'The remaining tokens should be 54,916,667')
  });

  it('transfer the ether to the funds wallet', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime);
    const balPriorEthTransfer = web3.eth.getBalance(pvtFundsWallet);
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerTwo));
    const balPostEthTransfer = web3.eth.getBalance(pvtFundsWallet);
    const ethDiff = numFromWei(balPostEthTransfer, 'ether') - numFromWei(balPriorEthTransfer, 'ether')
    assert.equal(ethDiff, 50, 'Funds wallet should have received 50 ether from the sale');
  });

  it('rejects ether from an address that isn\'t whitelisted', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime);
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(50, unlistedBuyer)))
  });

  it('rejects a transaction that is less than the minimum buy of 50 ether', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime);
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(20, buyerThree)))
  });

  it('sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO', async () => {
    // 1 szabo = 0.000003 ETH
    const inflatedExchangeRate = new web3.BigNumber(3);
    const defaultGanacheGasPrice = 100000000000;
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime);
    await PVTSDMockContract.updateTheExchangeRate(inflatedExchangeRate);
    // first purchase removes 50,000,000 tokens
    await PVTSDMockContract.sendTransaction(buyTokens(90, buyerThree));
    // // remaining tokens are now 5,000,000
    // // buyer should be allowed to purchase 5 million
    // // rate will be 5 million tokens at the rate of 1 TSD => 0.0000018 ETH (discounted rate)
    // // this should cost the user 9.0000014 ETH
    const costOfRemainingTokens = 9.0000014;
    // // buyer should be transfered the 5 million tokens
    // // 9.0000014 ether should be transfered to the funds wallet 
    // // buyer should be returned 25.9999986 eth - tx costs
    // // buyers balance before tx
    const fundsWalletEthBalPrior = web3.eth.getBalance(pvtFundsWallet);
    const buyerEThBalPrior = web3.eth.getBalance(buyerFour).toNumber();
    const tx = await PVTSDMockContract.sendTransaction(buyTokens(50, buyerFour));
    // balances after sale
    const fundsWalletEthBalPost = web3.eth.getBalance(pvtFundsWallet);
    const buyerTokenBalance = await PVTSDMockContract.balanceOf(buyerFour);
    const buyerEThBalPost = web3.eth.getBalance(buyerFour);
    const tokensRemaining = await PVTSDMockContract.balanceOf(owner);
    const totalGasSpent = tx.receipt.gasUsed * defaultGanacheGasPrice;
    const expectedEthBal = buyerEThBalPrior - numToWei(costOfRemainingTokens) - totalGasSpent;
    assert.equal(numFromWei(buyerTokenBalance), 5000000, 'Buyer should be transfered the remaining 5 million tokens');
    assert.equal(numFromWei(buyerEThBalPost), numFromWei(new web3.BigNumber(expectedEthBal)), 'The current balance should equal token cost + trasaction cost');
    assert.equal(tokensRemaining, 0, 'There should be no remaining tokens');
    assert.equal(numFromWei(fundsWalletEthBalPrior) + costOfRemainingTokens, numFromWei(fundsWalletEthBalPost));
    // icoOpen is set to false when no tokens remain
    assert.equal(await PVTSDMockContract.icoOpen(), false);
  })
});
