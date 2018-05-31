const PRETSDMock = artifacts.require("./PRETSDMock.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, } = require('./testHelpers');

contract('PRETSDMock', (accounts) => {
  let PRETSDMockContract;

  const decimalMultiplier = Math.pow(10, 18);

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
  const trancheBuyerOne = accounts[firstBuyerIndex+6];
  const trancheBuyerTwo = accounts[firstBuyerIndex+7];
  const trancheBuyerThree = accounts[firstBuyerIndex+8];
  const trancheBuyerFour = accounts[firstBuyerIndex+9];
  // // more buyers are reserved for future tests to test the tranche system fully
  const whitelistAddresses = [
    buyerOne,
    buyerTwo,
    buyerThree,
    buyerFour,
    buyerFive,
    buyerSix,
    trancheBuyerOne,
    trancheBuyerTwo,
    trancheBuyerThree,
    trancheBuyerFour
  ];

  const unlistedBuyer = accounts[firstBuyerIndex+10];

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
    const weiPostTransfer = numFromWei(balPostEthTransfer);
    const weiPriorTransfer = numFromWei(balPriorEthTransfer);
    const epsilon = 0.0000001;
    const ethDiff = (Math.abs((weiPostTransfer - weiPriorTransfer) - 50) < epsilon);
    assert.equal(ethDiff, true, 'Funds wallet should have received 50 ether from the sale');
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

  it('sells the required tokens based on the remaining tokens in the tranches', async () => {
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    // set current exchange rate to 1 ETH == 1,000,000 PRETSD
    const inflatedExchangeRate = new web3.BigNumber(1);
    await PRETSDMockContract.updateTheExchangeRate(inflatedExchangeRate);

    const buyerOneTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerOne);
    const buyerTwoTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerTwo);
    const buyerThreeTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerThree);
    const buyerFourTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerFour);
    const contractTokensPrePurchase = await PRETSDMockContract.balanceOf(owner);

    // ===== First person calculations ===== //
    // First person buys 20 ETH worth of tokens
    // First purchase is within tranche one.
    // 20 ETH == 25,000,000 PRETSD based on the first tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(20, trancheBuyerOne));
    const buyerOneTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerOne);
    const contractTokensPostPurchaseOne = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer one: 25,000,000 PRETSD
    // Total Tokens left in Contract: 140,000,000 PRETSD
    // Total Tokens left in TrancheOne: 16,250,000 PRETSD

    // ===== Second person calculations ===== //
    // Second person buys 40 ETH worth of tokens
    // 40 ETH == 50,000,000 PRETSD based on the first tranche.
    // First Tranche has 16,250,000 PRETSD remaining.
    // 16,250,000 PRETSD == 13 ETH. Tranche one is depleted.
    // 27 ETH == 31,764,705,88235294(e18) ETH based on second tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerTwo));
    const buyerTwoTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerTwo);
    const contractTokensPostPurchaseTwo = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer two: 48,014,705.88235294 PRETSD
    // Total Tokens left in Contract: 91,985,294.11764706 PRETSD
    // Total Tokens left in TrancheTwo: 9,485,294.11764706 PRETSD

    // ===== Third person calculations ===== //
    // Third person buys 40 ETH worth of tokens
    // 40 ETH == 47,058,823.529411765 PRETSD based on the Second tranche.
    // Second Tranche has 9,485,294.11764706 PRETSD remaining.
    // 9,485,294.11764706 PRETSD == 8.062500000000001000(e18) ETH. Tranche Two is depleted.
    // 31.937499999999999000(e18) ETH == 35,486,111.11111111(E+18) PRETSD based on Third tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerThree));
    const buyerThreeTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerThree);
    const contractTokensPostPurchaseThree = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer three: 44,971,405.22875817(e18) PRETSD
    // Total Tokens left in Contract: 47,013,888.888888890000000000 PRETSD
    // Total Tokens left in TrancheThree: 5,763,888.888888890000000000 PRETSD

    // ===== Third person calculations ===== //
    // Fourth person buys 40 ETH worth of tokens
    // 40 ETH == 44,444,444.444444444 PRETSD based on the Third tranche.
    // third Tranche has 5,763,888.888888890000000000 PRETSD remaining.
    // 5,763,888.888888890000000000 PRETSD == 5.187500000000001000 ETH. Tranche one is depleted.
    // 34.812499999999999000 ETH == 36,644,736.842105262105263158 (might be 7 rounded down) PRETSD based on fourth tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerFour));
    const buyerFourTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerFour);
    const contractTokensPostPurchaseFour = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer four: 42,408,625.730994152105263158 PRETSD
    // Total Tokens left in Contract: 4,605,263.157894737894736842 PRETSD
    // Total Tokens left in TrancheFour: 4,605,263.157894737894736842 PRETSD

    assert.equal(numFromWei(buyerOneTokensPostPurchase), 25000000 ,'The first buyer should have 25,000,000 PRETSD');
    assert.equal(numFromWei(buyerTwoTokensPostPurchase), 48014705.88235294 ,'The second buyer should have 48014705.88235294 PRETSD');
    assert.equal(numFromWei(buyerThreeTokensPostPurchase), 44971405.22875817 ,'The Third buyer should have 44971405.22875817 PRETSD');
    assert.equal(numFromWei(buyerFourTokensPostPurchase), 42408625.730994152105263158 ,'The Fourth buyer should have 42408625.730994152105263158 PRETSD');

    assert.equal(numFromWei(contractTokensPostPurchaseFour), 4605263.157894737, 'The remaining tokens that the contract should have 4,605,263.157894737894736842 PRETSD');
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
  });

  it('disallows a call to burn tokens from not the owner', async () => {
    const endTime = await PRETSDMockContract.endTime();
    await PRETSDMockContract.changeTime(endTime);
    await assertExpectedError(PRETSDMockContract.burnRemainingTokens({ from: buyerFive }));
  });

  // setting a reference to the main token contract
  it('can set a reference to the main token contract on from owner', async () => {
    const pvtSaleTokenWallet = accounts[firstBuyerIndex+11];
    const preSaleTokenWallet = accounts[firstBuyerIndex+12];
    const foundersAndAdvisors = accounts[firstBuyerIndex+13];
    const bountyCommunityIncentive = accounts[firstBuyerIndex+14];
    const liquidityProgram = accounts[firstBuyerIndex+15];
    // set up a reference to the main contract
    const TSDMockContract = await TSDMock.new(
      currentTime,
      exchangeRate,
      whitelistAddresses,
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentive,
      liquidityProgram,
    );

    // Check for error when sent from someone other than the owner
    await assertExpectedError(PRETSDMockContract.setMainContractAddress(PRETSDMockContract.address, { from: buyerFive }))
    await PRETSDMockContract.setMainContractAddress(TSDMockContract.address, { from: owner });
    const setRefAddress = await PRETSDMockContract.TSDContractAddress();
    assert.equal(setRefAddress, TSDMockContract.address, `Address set in the contract should be the address of the main contract ${setRefAddress}`)
  })

  it('distributes private token balances into the main contract, transfers any remaining to main funds wallet token balance', async () => {
    const pvtSaleTokenWallet = accounts[firstBuyerIndex+11];
    const preSaleTokenWallet = accounts[firstBuyerIndex+12];
    const foundersAndAdvisors = accounts[firstBuyerIndex+13];
    const bountyCommunityIncentive = accounts[firstBuyerIndex+14];
    const liquidityProgram = accounts[firstBuyerIndex+15];
    const buyerSeven = accounts[firstBuyerIndex+16];
    const buyerEight = accounts[firstBuyerIndex+17];
    const fundsWallet = owner;
    const preContractAddress = await PRETSDMockContract.address;
    // set up a reference to the main contract
    const TSDMockContract = await TSDMock.new(
      currentTime,
      exchangeRate,
      whitelistAddresses,
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentive,
      liquidityProgram,
    );

    // record the main token sale funds wallet balance prior to distribution
    console.log("first");
    const mainSaleAvailableTokens = await TSDMockContract.balanceOf(fundsWallet);
    const mainPreTokenAllocation = await TSDMockContract.balanceOf(preSaleTokenWallet);
    // make a buy in the pre sale
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    console.log("random2");
    await PRETSDMockContract.sendTransaction(buyTokens(50, buyerSeven));
    console.log("Changed time");
    await PRETSDMockContract.sendTransaction(buyTokens(50, buyerEight));
    // // change time to token release date
    // // change time in the main contract to token release date
    // // distribute the tokens for pre contract to the main contract
    console.log("random1");
    const tokensReleaseDate = await PRETSDMockContract.tokensReleaseDate();
    await PRETSDMockContract.changeTime(tokensReleaseDate);
    await TSDMockContract.changeTime(tokensReleaseDate);
    console.log("random2");
    const mainContractPreTokenAllocation = await TSDMockContract.balanceOf(preSaleTokenWallet);
    await TSDMockContract.approve(preContractAddress, mainContractPreTokenAllocation, { from: preSaleTokenWallet });
    // // set up contract reference
    await PRETSDMockContract.setMainContractAddress(TSDMockContract.address, { from: owner });
    await PRETSDMockContract.distributeTokens({ from: owner });
    console.log("random3");
    // check the balance of the pvt sale buyer in the main contract
    const firstBuyerPreBal = await PRETSDMockContract.balanceOf(buyerSeven);
    const firstBuyerMainBal = await TSDMockContract.balanceOf(buyerSeven);
    const secondBuyerPreBal = await PRETSDMockContract.balanceOf(buyerEight);
    const secondBuyerMainBal = await TSDMockContract.balanceOf(buyerEight);
    assert.equal(numFromWei(firstBuyerPreBal), numFromWei(firstBuyerMainBal));
    assert.equal(numFromWei(secondBuyerPreBal), numFromWei(secondBuyerMainBal));
    console.log("random4");

    // If there were any unsold tokens from the private sale
    // The remaining tokens from the private sale allocation
    // will be transferred to the main token sales balance
    // this keeps the total supply valid because the unallocated tokens
    // can be sold in the main sale
    const totalTokensSoldInPreSale = numFromWei(firstBuyerPreBal) + numFromWei(secondBuyerPreBal);
    const unsoldPreTokens = numFromWei(mainPreTokenAllocation) - totalTokensSoldInPreSale;
    // prior balances[fundsWallet] + totalTokensSoldInPvtSale
    const preAllocationWalletBal = await TSDMockContract.balanceOf(pvtSaleTokenWallet);
    // prior balances[fundsWallet] + totalTokensSoldInPvtSale
    console.log("random5");
    const totalExpected = numFromWei(mainSaleAvailableTokens) + unsoldPreTokens;
    const finalMainSaleTokens = await TSDMockContract.balanceOf(fundsWallet);
    console.log("random6");
    assert.equal(preAllocationWalletBal, 0, 'Private sale token allocation should be 0');
    assert.equal(totalExpected, numFromWei(finalMainSaleTokens), 'Final balance of available main tokens should include unsold private sale tokens (407833334)');
  });
});
