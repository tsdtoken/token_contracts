const PRETSDMock = artifacts.require("./PRETSDMock.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, } = require('./testHelpers');

contract('PRETSDMock', (accounts) => {
  let PRETSDMockContract;
  const currentTime = moment().unix();
  // exchange rate is 1 szabo or 0.000001
  const exchangeRate = new web3.BigNumber(1000);
  const owner = accounts[0];
  const preFundsWallet = owner;
  const firstBuyerIndex = 15;
  const buyerOne = accounts[firstBuyerIndex];
  const buyerTwo = accounts[firstBuyerIndex+1];
  const buyerThree = accounts[firstBuyerIndex+2];
  const buyerFour = accounts[firstBuyerIndex+3];
  const buyerFive = accounts[firstBuyerIndex+4];
  const buyerSix = accounts[firstBuyerIndex+5];
  const whitelistAddresses = [
    buyerOne,
    buyerTwo,
    buyerThree,
    buyerFour,
    buyerFive,
    buyerSix
  ];

  const unlistedBuyer = accounts[firstBuyerIndex+6];

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

  it('designates the owner as the preFundsWallet', async () => {
    assert.equal(await PRETSDMockContract.preFundsWallet(), owner);
  });

  it('has a valid start time, end time and token release time', async () => {
    const startTime = await PRETSDMockContract.startTime();
    const endTime = await PRETSDMockContract.endTime();
    const tokensReleaseDate = await PRETSDMockContract.tokensReleaseDate();
    assert.equal(moment.unix(startTime.c[0]).isValid(), true);
    assert.equal(moment.unix(endTime.c[0]).isValid(), true);
    assert.equal(moment.unix(tokensReleaseDate.c[0]).isValid(), true);
  });

  it('sets the start time to be Wed Aug 01 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const startTime = await PRETSDMockContract.startTime();
    const dateString = new Date(startTime.c[0]);
    assert.equal(dateString, 'Wed Aug 01 2018 00:00:00 GMT+1000 (AEST)');
  });

  it('sets the end time to be Wed Aug 22 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const endTime = await PRETSDMockContract.endTime();
    const dateString = new Date(endTime.c[0]);
    assert.equal(dateString, 'Wed Aug 22 2018 00:00:00 GMT+1000 (AEST)');
  });

  it('sets the token release time to be Thu Aug 01 2019 00:00:00 GMT+1000 (AEST)', async () => {
    const tokensReleaseDate = await PRETSDMockContract.tokensReleaseDate();
    const dateString = new Date(tokensReleaseDate.c[0]);
    assert.equal(dateString, 'Thu Aug 01 2019 00:00:00 GMT+1000 (AEST)');
  });


  it('transfers total supply of tokens (55 million) to the pre funds wallet', async () => {
    const preFundsWallet = owner;
    const preFundsWalletBalance = await PRETSDMockContract.balanceOf(preFundsWallet);
    assert.equal(numFromWei(preFundsWalletBalance), 165000000, 'Balance of preFundsWallet should be 165 million');
  });

  // exchange rate functionality

  it('sets the exchange rate upon initialization', async () => {
    // exchange rate passed in was 1 szabo or 0.000001ETH
    const exchangeRate = await PRETSDMockContract.exchangeRate();
    assert.ok(exchangeRate);
    assert.equal(numFromWei(exchangeRate, 'szabo'), 1000, 'Exchange rate should be set to 1 szabo (0.000001 ETH)')
  });

  it('can change the exchange rate if called by the owner only', async () => {
    // the exhange rate being passed in is 1 TSD => 0.002 ETH
    const newRate = new web3.BigNumber(2000);
    const beforeExchangeRate = await PRETSDMockContract.exchangeRate();
    const updatedFromOwner = await PRETSDMockContract.updateTheExchangeRate(newRate, { from: owner });
    const afterExchangeRate = await PRETSDMockContract.exchangeRate();
    // 1000 szabo is the inital amount passed to the constructor
    assert.equal(numFromWei(beforeExchangeRate, 'szabo'), 1000, 'Exchange rate should be set to the passed in value of 1 szabo');
    assert.equal(numFromWei(afterExchangeRate, 'szabo'), 2000, 'Exchange rate should be set to the new rate of 200');
    assert.ok(updatedFromOwner);
  });

  it('cannot change exchange rate from an address that isn\'t the owner', async () => {
    const newRate = new web3.BigNumber(2000);
    await assertExpectedError(PRETSDMockContract.updateTheExchangeRate(newRate, { from: accounts[6] }));
  });

  // Buy functionality

  it('refuses a sale before the private sale\'s start time', async () => {
    await assertExpectedError(PRETSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('refuses a sale 1 second before the private sale\'s start time', async () => {
    const startTime = await PRETSDMockContract.startTime();
    const oneSecondPriorToOpen = new Date(startTime).setSeconds(-1);
    await PRETSDMockContract.changeTime(oneSecondPriorToOpen);
    await assertExpectedError(PRETSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('accepts ether at the exact moment the sale opens', async () => {
    // exchange rate is 1000 sabo. 0.001 ETH token price. / 100 * 80 == 0.0008 ETH per token.
    // current tranche is 20% discount.
    //
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    await PRETSDMockContract.sendTransaction(buyTokens(10, buyerOne));
    const balanceOfBuyer = await PRETSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await PRETSDMockContract.balanceOf(preFundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 12500, 'The buyers balance should 12,500 tokens')
    assert.equal(numFromWei(remainingTokens), 164987500, 'The remaining tokens should be 164,987,500')
  });

  it('transfer the ether to the funds wallet', async () => {
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    const balPriorEthTransfer = web3.eth.getBalance(preFundsWallet);
    await PRETSDMockContract.sendTransaction(buyTokens(50, buyerTwo));
    const balPostEthTransfer = web3.eth.getBalance(preFundsWallet);
    const ethDiff = (numFromWei(balPostEthTransfer) * 1000000 - numFromWei(balPriorEthTransfer) * 1000000) / 1000000;
    assert.equal(ethDiff, 50, 'Funds wallet should have received 50 ether from the sale');
  });

  it('rejects ether from an address that isn\'t whitelisted', async () => {
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    await assertExpectedError(PRETSDMockContract.sendTransaction(buyTokens(50, unlistedBuyer)))
  });

  it('rejects a transaction that is less than the minimum buy of 5 ether', async () => {
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    await assertExpectedError(PRETSDMockContract.sendTransaction(buyTokens(3, buyerThree)))
  });

  it('sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO', async () => {
    // 1 szabo = 0.000001 ETH
    // set current exchange rate to 1 ETH == 1,000,000 PRETSD
    const inflatedExchangeRate = new web3.BigNumber(1);
    // Set gas price in wei. Used for comparison calculations
    const defaultGanacheGasPrice = 100000000000;
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    await PRETSDMockContract.updateTheExchangeRate(inflatedExchangeRate);

    // // check the total cost of all remaining tokens (165,000,000 PRETSD)
    const totalCost = await PRETSDMockContract.calculateTotalRemainingTokenCost();
    await PRETSDMockContract.sendTransaction(buyTokens(90, buyerThree));
    // // remaining tokens are now 58,125,000
    // // remaining tokens cost 54.375 eth with the discount and increased exchange rate.
    const newTotalCost = await PRETSDMockContract.calculateTotalRemainingTokenCost();
    const costOfRemainingTokens = 54.375;
    // // buyers balance before tx
    const fundsWalletEthBalPrior = web3.eth.getBalance(preFundsWallet);
    const buyerEThBalPrior = web3.eth.getBalance(buyerFour);
    const tx = await PRETSDMockContract.sendTransaction(buyTokens(60, buyerFour));
    // balances after sale
    const fundsWalletEthBalPost = web3.eth.getBalance(preFundsWallet);
    const buyerTokenBalance = await PRETSDMockContract.balanceOf(buyerFour);
    const buyerEThBalPost = web3.eth.getBalance(buyerFour);

    const tokensRemaining = await PRETSDMockContract.balanceOf(owner);
    const totalGasSpent = tx.receipt.gasUsed * defaultGanacheGasPrice;

    const expectedEthBal = buyerEThBalPrior - numToWei(costOfRemainingTokens) - totalGasSpent;

    assert.equal(numFromWei(buyerTokenBalance), 58125000, 'Buyer should be transfered the remaining 58.125 million tokens');
    assert.equal(numFromWei(buyerEThBalPost), numFromWei(new web3.BigNumber(expectedEthBal)), 'The current balance should equal token cost + trasaction cost');
    assert.equal(tokensRemaining, 0, 'There should be no remaining tokens');
    assert.equal(numFromWei(fundsWalletEthBalPrior) + costOfRemainingTokens, numFromWei(fundsWalletEthBalPost));
    // icoOpen is set to false when no tokens remain
    assert.equal(await PRETSDMockContract.icoOpen(), false);
  })
});
