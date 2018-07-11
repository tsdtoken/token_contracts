const PRETSDMock = artifacts.require("./PRETSDMock.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
const TSDCrowdSaleMock = artifacts.require("./TSDCrowdSaleMock.sol");
const moment = require('moment');
const { numFromWei, stringFromWei, numToWei, buyTokens, assertExpectedError, equalsWithNormalizedRounding } = require('./testHelpers');

contract('PRETSDMock', (accounts) => {
  let PRETSDMockContract;

  const decimalMultiplier = Math.pow(10, 18);

  const currentTime = moment().unix();
  // exchange rate is 1 szabo or 0.000001
  const exchangeRate = 50000;
  const owner = accounts[0];
  const preFundsWallet = owner;
  const firstBuyerIndex = 15;
  const buyerOne = accounts[firstBuyerIndex];
  const buyerTwo = accounts[firstBuyerIndex+1];
  const buyerThree = accounts[firstBuyerIndex+2];
  const buyerFour = accounts[firstBuyerIndex+3];
  const buyerFive = accounts[firstBuyerIndex+4];
  const buyerSix = accounts[firstBuyerIndex+5];
  const buyerSeven = accounts[firstBuyerIndex+16];
  const buyerEight = accounts[firstBuyerIndex+17];
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
    buyerSeven,
    buyerEight,
    trancheBuyerOne,
    trancheBuyerTwo,
    trancheBuyerThree,
    trancheBuyerFour
  ];

  const unlistedBuyer = accounts[firstBuyerIndex+10];

  beforeEach('setup contract for each test', async () => {
    PRETSDMockContract = await PRETSDMock.new(
      currentTime,
      exchangeRate
    );
    // The contract runs out of gas when being created with the whole whitelist mapping. So we map afterwards.
    await PRETSDMockContract.createWhiteListedMapping(whitelistAddresses, { from: owner });
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
    assert.equal(dateString.getTime(), 1533045600000);
  });

 it('sets the end time to be Wed Aug 22 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const endTime = await PRETSDMockContract.endTime();
    const dateString = new Date(endTime.c[0]);
    assert.equal(dateString.getTime(), 1534860000000);
  });

 it('sets the token release time to be Thu Aug 01 2019 00:00:00 GMT+1000 (AEST)', async () => {
    const tokensReleaseDate = await PRETSDMockContract.tokensReleaseDate();
    const dateString = new Date(tokensReleaseDate.c[0]);
    assert.equal(dateString.getTime(), 1564581600000);
  });

 it('transfers total supply of tokens (240 million) to the pre funds wallet', async () => {
    const preFundsWallet = owner;
    const preFundsWalletBalance = await PRETSDMockContract.balanceOf(preFundsWallet);
    assert.equal(numFromWei(preFundsWalletBalance), 240000000, 'Balance of preFundsWallet should be 240 million');
  });

  // exchange rate functionality

 it('sets the exchange rate upon initialization', async () => {
    // exchange rate passed in was 1 szabo or 0.000001ETH
    const exchangeRate = await PRETSDMockContract.exchangeRate();
    assert.ok(exchangeRate);
    assert.equal(numFromWei(exchangeRate), 0.001, 'Exchange rate should be set to 1 szabo (0.000001 ETH)')
  });

 it('can change the exchange rate if called by the owner only', async () => {

    const newRate = 25000
    const beforeExchangeRate = await PRETSDMockContract.exchangeRate();
    const updatedFromOwner = await PRETSDMockContract.updateTheExchangeRate(newRate, { from: owner });
    const afterExchangeRate = await PRETSDMockContract.exchangeRate();
    // 1000 szabo is the inital amount passed to the constructor
    assert.equal(numFromWei(beforeExchangeRate), 0.001, 'Exchange rate should be set to the passed in value of 1 szabo');
    assert.equal(numFromWei(afterExchangeRate), 0.002, 'Exchange rate should be set to the new rate of 200');
    assert.ok(updatedFromOwner);
  });

 it('cannot change exchange rate from an address that isn\'t the owner', async () => {
    const newRate = 25000;
    await assertExpectedError(PRETSDMockContract.updateTheExchangeRate(newRate, { from: accounts[6] }));
  });

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
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    // 10 ETH == 5,000.00 USD (min buyin)
    await PRETSDMockContract.sendTransaction(buyTokens(10, buyerOne));
    const balanceOfBuyer = await PRETSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await PRETSDMockContract.balanceOf(preFundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 12500, 'The buyers balance should 12,500 tokens')
    assert.equal(numFromWei(remainingTokens), 239987500, 'The remaining tokens should be 239,987,500')
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

 it('rejects a transaction that is less than the minimum buy of 5,000.00 USD', async () => {
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    // 3 ETH == 1,500.00 USD
    // Only works if ETH >= 10
    await assertExpectedError(PRETSDMockContract.sendTransaction(buyTokens(3, buyerThree)))
  });

 it('sells the required tokens based on the remaining tokens in the tranches', async () => {
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    // set current exchange rate to 1 ETH == 1,000,000 PRETSD
    const inflatedExchangeRate = 50000000;
    await PRETSDMockContract.updateTheExchangeRate(inflatedExchangeRate);

    const buyerOneTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerOne);
    const buyerTwoTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerTwo);
    const buyerThreeTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerThree);
    const buyerFourTokensPrePurchase = await PRETSDMockContract.balanceOf(trancheBuyerFour);
    const contractTokensPrePurchase = await PRETSDMockContract.balanceOf(owner);
    // ===== First person calculations ===== //
    // First person buys 20 ETH worth of tokens
    // First purchase is within tranche one.
    // 40 ETH == 50,000,000 PRETSD based on the first tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerOne));
    const buyerOneTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerOne);
    const contractTokensPostPurchaseOne = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer one: 50,000,000 PRETSD
    // Total Tokens left in Contract: 190,000,000 PRETSD
    // Total Tokens left in TrancheOne: 10,000,000 PRETSD

    // ===== Second person calculations ===== //
    // Second person buys 40 ETH worth of tokens
    // 40 ETH == 50,000,000 PRETSD based on the first tranche.
    // First Tranche has 10,000,000 PRETSD remaining.
    // 10,000,000 PRETSD == 8 ETH. Tranche one is depleted.
    // -> Entering tranche 2, discount is 16% or 0.84
    // 32 ETH == 38,095,238.095238095238095238 (to the smallest amount) PRETSD based on second tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerTwo));
    const buyerTwoTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerTwo);
    const contractTokensPostPurchaseTwo = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer two: 48,095,238.095238095238095238 PRETSD
    // Total Tokens sold: 98,095,238.095238095238095238 PRETSD
    // Total Tokens left in Contract: 141,904,761.904761904761904762 PRETSD
    // Total Tokens left in TrancheTwo: 21,904,761.904761904761904762 PRETSD

    // ===== Third person calculations ===== //
    // Third person buys 40 ETH worth of tokens
    // 40 ETH == 47,619,047.619047619047619047 PRETSD based on the Second tranche.
    // Second Tranche has 21,904,761.904761904761904762 PRETSD remaining.
    // 21,904,761.904761904761904762 PRETSD == 18.4(e18) ETH. Tranche Two is depleted.
    // Entering Tranche 3
    // Remaining ETH for third buyer = 
    // 21.6(e18) ETH == 24,545,454.545454545454545454 PRETSD based on Third tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerThree));
    const buyerThreeTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerThree);
    const contractTokensPostPurchaseThree = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer three: 46,450,216.450216450216450216 PRETSD
    // Total Tokens sold: 144,545,454.545454545454545454 PRETSD
    // Total Tokens left in Contract: 95454545.454545454545454546 PRETSD
    // Total Tokens left in TrancheThree: 35,454,545.454545454545454546 PRETSD

    // ===== Fourth person calculations ===== //
    // Fourth person buys 40 ETH worth of tokens
    // 40 ETH == 45,454,545.454545454545454545 PRETSD based on the Third tranche.
    // third Tranche has 35,454,545.454545454545454546 PRETSD remaining.
    // 35,454,545.454545454545454546 PRETSD == 31.20000000000000000000000048(e+18) ETH. Tranche three is depleted.
    // Entering Tranche 4
    // Remaining ETH for the fourth buyer
    // 8.79999999999999999999999952 ETH == 9,565,217.391304347826086956 (might be 7 rounded down) PRETSD based on fourth tranche.
    await PRETSDMockContract.sendTransaction(buyTokens(40, trancheBuyerFour));
    const buyerFourTokensPostPurchase = await PRETSDMockContract.balanceOf(trancheBuyerFour);
    const contractTokensPostPurchaseFour = await PRETSDMockContract.balanceOf(owner);
    // Total Tokens Bought by buyer four: 45,019,762.845849802371541502 PRETSD
    // Total Tokens sold: 189,565,217.391304347826086956 PRETSD
    // Total Tokens left in Contract: 50,434,782.608695652173913044 PRETSD
    // Total Tokens left in TrancheFour: 50,434,782.608695652173913044 PRETSD

    assert.equal(stringFromWei(buyerOneTokensPostPurchase),    50000000.00000000 ,'The first buyer should have 25,000,000 PRETSD');
    assert.equal(stringFromWei(buyerTwoTokensPostPurchase),    48095238.09523809524 ,'The second buyer should have 48095238.09523809524 PRETSD');
    assert.equal(stringFromWei(buyerThreeTokensPostPurchase),  46450216.450216450217 ,'The Third buyer should have 44971405.22875817 PRETSD');
    assert.equal(stringFromWei(buyerFourTokensPostPurchase),   45019762.845849802372 ,'The Fourth buyer should have 42408625.730994152105263158 PRETSD');

    assert.equal(stringFromWei(contractTokensPostPurchaseFour), 50434782.60869565217, 'The remaining tokens that the contract should have 4,605,263.157894737894736842 PRETSD');
  });

 it('sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO', async () => {
    // 1 szabo = 0.000001 ETH
    // set current exchange rate to 1 ETH == 1,000,000 PRETSD
    const inflatedExchangeRate = 50000000;
    // Set gas price in wei. Used for comparison calculations
    const defaultGanacheGasPrice = 100000000000;
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    await PRETSDMockContract.updateTheExchangeRate(inflatedExchangeRate);
    // Cost to but out
    // T1 => 48 ETH
    // T2 => 50.4 ETH
    // T3 => 52.8 ETH
    // T4 => 55.2 ETH

    // check the total cost of all remaining tokens (240,000,000 PRETSD)
    const totalCost = await PRETSDMockContract.calculateTotalRemainingTokenCost();
    // you'd buy out first three tranches
    await PRETSDMockContract.sendTransaction(buyTokens(151.2, buyerThree));
    // remaining tokens are now 60,000,000
    // remaining tokens cost 55.5 eth with the discount and increased exchange rate.
    const newTotalCost = await PRETSDMockContract.calculateTotalRemainingTokenCost();
    const costOfRemainingTokens = 55.2;
    // buyers balance before tx
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

    assert.equal(stringFromWei(buyerTokenBalance), 60000000, 'Buyer should be transfered the remaining 60 million tokens');
    assert.ok(equalsWithNormalizedRounding(numFromWei(buyerEThBalPost), numFromWei(new web3.BigNumber(expectedEthBal.toString()))), 'The current balance should equal token cost + trasaction cost');
    assert.equal(tokensRemaining, 0, 'There should be no remaining tokens');
    assert.ok(equalsWithNormalizedRounding(numFromWei(fundsWalletEthBalPrior) + costOfRemainingTokens, numFromWei(fundsWalletEthBalPost)));
    // icoOpen is set to false when no tokens remain
    assert.equal(await PRETSDMockContract.tokensAvailable(), false);
  });

 it('disallows a call to burn tokens from not the owner', async () => {
    const endTime = await PRETSDMockContract.endTime();
    await PRETSDMockContract.changeTime(endTime);
    await assertExpectedError(PRETSDMockContract.burnRemainingTokens({ from: buyerFive }));
  });

  // setting a reference to the main token contract
 it('can set a reference to the main token contract on from owner', async () => {
    const pvtSaleTokenWallet = accounts[0];
    const preSaleTokenWallet = accounts[0];
    const foundersAndAdvisors = accounts[firstBuyerIndex+13];
    const bountyCommunityIncentive = accounts[firstBuyerIndex+14];
    const liquidityProgram = accounts[firstBuyerIndex+15];
    const projectImplementationServices = accounts[firstBuyerIndex+16];
    // set up a reference to the main contract
    const TSDMockContract = await TSDMock.new(
      currentTime,
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentive,
      liquidityProgram,
      projectImplementationServices
    );

    const TSDCrowdSaleMockContract = await TSDCrowdSaleMock.new(
      currentTime,
      exchangeRate,
      owner
    )
    
    await TSDCrowdSaleMockContract.createWhiteListedMapping(whitelistAddresses);

    // Check for error when sent from someone other than the owner
    await assertExpectedError(PRETSDMockContract.setMainContractAddress(PRETSDMockContract.address, { from: buyerFive }))
    await PRETSDMockContract.setMainContractAddress(TSDMockContract.address, { from: owner });
    const setRefAddress = await PRETSDMockContract.TSDContractAddress();
    assert.equal(setRefAddress, TSDMockContract.address, `Address set in the contract should be the address of the main contract ${setRefAddress}`)
  })

 it('distributes private token balances into the main contract, transfers any remaining to main funds wallet token balance', async () => {
    const pvtSaleTokenWallet = accounts[0];
    const preSaleTokenWallet = accounts[0];
    const foundersAndAdvisors = accounts[firstBuyerIndex+13];
    const bountyCommunityIncentive = accounts[firstBuyerIndex+14];
    const liquidityProgram = accounts[firstBuyerIndex+15];
    const projectImplementationServices = accounts[firstBuyerIndex+16];
    const fundsWallet = owner;
    const preContractAddress = await PRETSDMockContract.address;
    // set up a reference to the main contract
    const TSDMockContract = await TSDMock.new(
      currentTime,
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentive,
      liquidityProgram,
      projectImplementationServices
    );

    const TSDCrowdSaleMockContract = await TSDCrowdSaleMock.new(
      currentTime,
      exchangeRate,
      owner
    ) 

    await TSDCrowdSaleMockContract.createWhiteListedMapping(whitelistAddresses);

    // record the main token sale funds wallet balance prior to distribution
    const mainSaleAvailableTokens = await TSDMockContract.balanceOf(fundsWallet);
    const mainPreTokenAllocation = await TSDMockContract.balanceOf(preSaleTokenWallet);
    // make a buy in the pre sale
    const startTime = await PRETSDMockContract.startTime();
    await PRETSDMockContract.changeTime(startTime);
    await PRETSDMockContract.sendTransaction(buyTokens(50, buyerSeven));
    await PRETSDMockContract.sendTransaction(buyTokens(50, buyerEight));
    // // change time to token release date
    // // change time in the main contract to token release date
    // // distribute the tokens for pre contract to the main contract
    const tokensReleaseDate = await PRETSDMockContract.tokensReleaseDate();
    await PRETSDMockContract.changeTime(tokensReleaseDate);
    await TSDMockContract.changeTime(tokensReleaseDate);
    const mainContractPreTokenAllocation = await TSDMockContract.balanceOf(preSaleTokenWallet);
    await TSDMockContract.approve(preContractAddress, mainContractPreTokenAllocation, { from: preSaleTokenWallet });
    await TSDMockContract.toggleTrading();
    // // set up contract reference
    await PRETSDMockContract.setMainContractAddress(TSDMockContract.address, { from: owner });

    // check the balance of the pvt sale buyer in the PRETSD contract
    const firstBuyerPreBal = await PRETSDMockContract.balanceOf(buyerSeven);
    const secondBuyerPreBal = await PRETSDMockContract.balanceOf(buyerEight);
    
    await PRETSDMockContract.distributeTokens(20, { from: owner });
    
    // check the balance of the pvt sale buyer in the main contract
    const firstBuyerMainBal = await TSDMockContract.balanceOf(buyerSeven);
    const secondBuyerMainBal = await TSDMockContract.balanceOf(buyerEight);

    assert.equal(numFromWei(firstBuyerPreBal), numFromWei(firstBuyerMainBal));
    assert.equal(numFromWei(secondBuyerPreBal), numFromWei(secondBuyerMainBal));
  });

  it('the owner can change the start date', async () => {
    await PRETSDMockContract.setStartTime(1533045500000, { from: owner });
    const startTime = await PRETSDMockContract.startTime();
    assert.equal(startTime, 1533045500000, 'The start date should change');
  });

  it('the owner can change the end date', async () => {
    await PRETSDMockContract.setEndTime(1534870000000, { from: owner });
    const startTime = await PRETSDMockContract.endTime();
    assert.equal(startTime, 1534870000000, 'The end date should change');
  });
});
