const PVTSDMock = artifacts.require("./PVTSDMock.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
const TSDSubsequentSupply = artifacts.require("./TSDSubsequentSupply.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, equalsWithNormalizedRounding } = require('./testHelpers');

contract('TSDMock', (accounts) => {
  let TSDMockContract;
  const currentTime = moment().unix();
  // exchange rate is 1 szabo or 0.001
  const exchangeRate = 50000;
  const owner = accounts[0];
  const fundsWallet = owner;
  const firstAccountIdx = 23;
  const pvtSaleTokenWallet = accounts[firstAccountIdx+1]
  const preSaleTokenWallet = accounts[firstAccountIdx+2]
  const foundersAndAdvisors = accounts[firstAccountIdx+3]
  const bountyCommunityIncentives = accounts[firstAccountIdx+4]
  const liquidityProgram = accounts[firstAccountIdx+5]

  // buyers
  const buyerOne = accounts[firstAccountIdx+6];
  const buyerTwo = accounts[firstAccountIdx+7];
  const buyerThree = accounts[firstAccountIdx+8];
  const buyerFour = accounts[firstAccountIdx+9];
  const buyerFive = accounts[firstAccountIdx+10];
  const buyerSix = accounts[firstAccountIdx+11];
  const unlistedBuyer = accounts[firstAccountIdx+12];
  const whitelistAddresses = [
    buyerOne,
    buyerTwo,
    buyerThree,
    buyerFour,
    buyerFive,
    buyerSix
  ];

  beforeEach('setup contract for each test', async () => {
    TSDMockContract = await TSDMock.new(
      currentTime,
      exchangeRate,
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentives,
      liquidityProgram
    );

    await TSDMockContract.createWhiteListedMapping(whitelistAddresses);
  });

  it('has an owner', async () => {
    assert.equal(await TSDMockContract.owner(), owner);
  });

  it('sets the owner as the fundsWallet', async () => {
    assert.equal(await TSDMockContract.fundsWallet(), owner);
  });

  it('sets the correct pvtSaleTokenWallet address', async () => {
    assert.equal(await TSDMockContract.pvtSaleTokenWallet(), pvtSaleTokenWallet);
  });

  it('sets the correct preSaleTokenWallet address', async () => {
    assert.equal(await TSDMockContract.preSaleTokenWallet(), preSaleTokenWallet);
  });

  it('sets the correct foundersAndAdvisors address', async () => {
    assert.equal(await TSDMockContract.owner(), owner);
  });

  it('sets the correct bountyCommunityIncentives address', async () => {
    assert.equal(await TSDMockContract.foundersAndAdvisors(), foundersAndAdvisors);
  });

  it('sets the correct liquidityProgram address', async () => {
    assert.equal(await TSDMockContract.liquidityProgram(), liquidityProgram);
  });

  it('has a valid start time, end time', async () => {
    const startTime = await TSDMockContract.startTime();
    const endTime = await TSDMockContract.endTime();
    assert.equal(moment.unix(startTime.c[0]).isValid(), true);
    assert.equal(moment.unix(endTime.c[0]).isValid(), true);
  });

  it('sets the start time to be Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const startTime = await TSDMockContract.startTime();
    const dateString = new Date(startTime.c[0]);
    assert.equal(dateString, 'Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)');
  });

  it('sets the end time to be Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const endTime = await TSDMockContract.endTime();
    const dateString = new Date(endTime.c[0]);
    assert.equal(dateString, 'Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)');
  });

  it('transfers the private sale token allocation to pvtSaleTokenWallet', async () => {
    const allocation = await TSDMockContract.pvtSaleSupply();
    const pvtTokenWalletBal = await TSDMockContract.balanceOf(pvtSaleTokenWallet);
    assert.equal(numFromWei(pvtTokenWalletBal), numFromWei(allocation), 'Private token wallet should be allocation 55 million tokens');
  });

  it('transfers the pre sale token allocation to preSaleTokenWallet', async () => {
    const allocation = await TSDMockContract.preSaleSupply();
    const preTokenWalletBal = await TSDMockContract.balanceOf(preSaleTokenWallet);
    assert.equal(numFromWei(preTokenWalletBal), numFromWei(allocation), 'Pre token wallet should be allocation 65 million tokens');
  });

  it('transfers the founders and advisors token allocation to foundersAndAdvisorsAllocation wallet', async () => {
    const allocation = await TSDMockContract.foundersAndAdvisorsAllocation();
    const foundersAndAdvisorsWalletBal = await TSDMockContract.balanceOf(foundersAndAdvisors);
    assert.equal(numFromWei(foundersAndAdvisorsWalletBal), numFromWei(allocation), 'Founders and advisors wallet should be allocation 44 million tokens');
  });

  it('transfers the bounty token allocation to bountyCommunityIncentives wallet', async () => {
    const allocation = await TSDMockContract.bountyCommunityIncentivesAllocation();
    const bountyWalletBal = await TSDMockContract.balanceOf(bountyCommunityIncentives);
    assert.equal(numFromWei(bountyWalletBal), numFromWei(allocation), 'Bounty and community incentives wallet should be allocation 16.5 million tokens');
  });

  it('transfers the liquidity program token allocation to pvtSaleTokenWallet', async () => {
    const allocation = await TSDMockContract.liquidityProgramAllocation();
    const liquidityWalletBal = await TSDMockContract.balanceOf(liquidityProgram);
    assert.equal(numFromWei(liquidityWalletBal), numFromWei(allocation), 'Liquidity program wallet should be allocation 16.5 million tokens');
  });

  it('funds wallet has 253 million tokens available for public sale', async () => {
    const fundsWalletBal = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(fundsWalletBal), 253000000, 'The funds wallet should have a balance of 253 million tokens');
  });

  it('can tell you if an address is whitelisted', async () => {
    const whitelisted = await TSDMockContract.isWhiteListed(buyerOne);
    const unlisted = await TSDMockContract.isWhiteListed(unlistedBuyer);
    assert.equal(whitelisted, true, 'Address should be part of the white list');
    assert.equal(unlisted, false, 'Address should not be part of the white list');
  });

  it('creates a mapping of all whitelisted addresses', async () => {
    // Upon initialization of the contract, whitelisted addresses are placed into a mapping with the value of true
    const firstWhitelistAddress = await TSDMockContract.whiteListed(buyerOne);
    const secondWhitelistAddress = await TSDMockContract.whiteListed(buyerTwo);
    const thirdWhitelistAddress = await TSDMockContract.whiteListed(buyerThree);

    assert.equal(firstWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(secondWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(thirdWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
  });

  // exchange rate functionality
  it('sets the exchange rate upon initialization', async () => {
    // exchange rate passed in was 1 szabo or 0.000001ETH
    const exchangeRate = await TSDMockContract.exchangeRate();
    assert.ok(exchangeRate);
    assert.equal(numFromWei(exchangeRate, 'szabo'), 1000, 'Exchange rate should be set to 1 szabo (0.000001 ETH)')
  });

  it('can change the exchange rate if called by the owner only', async () => {
    // the exhange rate being passed in is 1 TSD => 0.002 ETH
    const newRate = 25000;
    const beforeExchangeRate = await TSDMockContract.exchangeRate();
    const updatedFromOwner = await TSDMockContract.updateTheExchangeRate(newRate, { from: owner });
    const afterExchangeRate = await TSDMockContract.exchangeRate();
    // 1000 szabo is the inital amount passed to the constructor
    assert.equal(numFromWei(beforeExchangeRate, 'szabo'), 1000, 'Exchange rate should be set to the passed in value of 1 szabo');
    assert.equal(numFromWei(afterExchangeRate, 'szabo'), 2000, 'Exchange rate should be set to the new rate of 200');
    assert.ok(updatedFromOwner);
  });

  it('cannot change exchange rate from an address that isn\'t the owner', async () => {
    const newRate = 25000;
    await assertExpectedError(TSDMockContract.updateTheExchangeRate(newRate, { from: buyerTwo }));
  });

  // Buy functionality

  it('refuses a sale before the public sale\'s start time', async () => {
    await assertExpectedError(TSDMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

  it('refuses a sale 1 second before the private sale\'s start time', async () => {
    const startTime = await TSDMockContract.startTime();
    const oneSecondPriorToOpen = new Date(startTime.c[0]).setSeconds(-1);
    await TSDMockContract.changeTime(oneSecondPriorToOpen);
    await assertExpectedError(TSDMockContract.sendTransaction(buyTokens(10, buyerOne)))
  });

  it('accepts ether at the exact moment the sale opens', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens
    const startTime = await TSDMockContract.startTime();
    await TSDMockContract.changeTime(startTime.c[0]);
    await TSDMockContract.sendTransaction(buyTokens(10, buyerOne));
    const balanceOfBuyer = await TSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 10000, 'The buyers balance should 10,000 tokens')
    assert.equal(numFromWei(remainingTokens), 252990000, 'The remaining tokens should be 252,990,000')
  });

  it('accepts ether one second before close', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens
    const endTime = await TSDMockContract.endTime();
    const oneSecBeforeClose = new Date(endTime.c[0]).setSeconds(-1);
    await TSDMockContract.changeTime(oneSecBeforeClose);
    await TSDMockContract.sendTransaction(buyTokens(10, buyerTwo));
    const balanceOfBuyer = await TSDMockContract.balanceOf(buyerTwo);
    const remainingTokens = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 10000, 'The buyers balance should 10,000 tokens')
    assert.equal(numFromWei(remainingTokens), 252990000, 'The remaining tokens should be 252,990,000')
  });

  it('rejects a transaction that is less than the minimum buy of 0.0875 ether', async () => {
    const startTime = await TSDMockContract.startTime();
    await TSDMockContract.changeTime(startTime.c[0]);
    await assertExpectedError(TSDMockContract.sendTransaction(buyTokens(0.05, buyerThree)))
  });

  it('transfers the ether to the funds wallet', async () => {
    const startTime = await TSDMockContract.startTime();
    await TSDMockContract.changeTime(startTime.c[0]);
    const balPriorEthTransfer = web3.eth.getBalance(fundsWallet);
    await TSDMockContract.sendTransaction(buyTokens(10, buyerTwo));
    const balPostEthTransfer = web3.eth.getBalance(fundsWallet);
    const ethDiff = numFromWei(balPostEthTransfer) - numFromWei(balPriorEthTransfer)
    assert.equal(ethDiff, 10, 'Funds wallet should have received 10 ether from the sale');
  });

  it('sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO', async () => {
    // set exchange rate to 1 szabo of 0.000001 Eth
    // 1ETH === 1 million TSD
    const inflatedExchange = 50000000;
    const defaultGanacheGasPrice = 100000000000;
    await TSDMockContract.updateTheExchangeRate(inflatedExchange, { from: owner });
    const startTime = await TSDMockContract.startTime();
    await TSDMockContract.changeTime(startTime.c[0]);
    // funds wallet contains 253,000,000
    await TSDMockContract.sendTransaction(buyTokens(90, buyerThree));
    await TSDMockContract.sendTransaction(buyTokens(90, buyerFour));
    await TSDMockContract.sendTransaction(buyTokens(72.962700, buyerFive));
    // remaining tokens are now 37300
    const lastRemainingTokens = await TSDMockContract.balanceOf(fundsWallet);
    // buyer should be allowed to purchase the remaining tokens
    // at the rate of 1000000 TSD => 1 ETH
    // this should cost the user 0.0373 ETH
    const costOfRemainingTokens = 0.0373;
    // buyer should be transfered the 37300 tokens
    // 0.0373 ether should be transfered to the funds wallet
    // buyer should be returned 0.0505 eth - tx costs
    // buyers balance before tx
    const buyerSixEthPrior = web3.eth.getBalance(buyerSix);
    const fundsWalletPrior = web3.eth.getBalance(fundsWallet);
    const tx = await TSDMockContract.sendTransaction(buyTokens(0.0875, buyerSix));
    // balances after sale
    const fundsWalletPost = web3.eth.getBalance(fundsWallet);
    const buyerSixTokens = await TSDMockContract.balanceOf(buyerSix);
    const buyerSixEthPost = web3.eth.getBalance(buyerSix);
    const tokensRemaining = await TSDMockContract.balanceOf(fundsWallet);
    const totalGasSpent = tx.receipt.gasUsed * defaultGanacheGasPrice;

    // expected buyer eth balance after sale
    const expectedEthBal = buyerSixEthPrior - numToWei(costOfRemainingTokens) - totalGasSpent;
    // this is to handle a javascript rounding error
    const finalFundsWalletBal = (numFromWei(fundsWalletPrior) + costOfRemainingTokens);
    assert.equal(numFromWei(lastRemainingTokens), 37300, 'The tokens remaining should be 37300');
    assert.equal(numFromWei(buyerSixTokens), 37300, 'Buyers balance should be the remaining 37300 tokens');
    // assert.equal(numFromWei(buyerSixEthPost), numFromWei(new web3.BigNumber(expectedEthBal)), 'The current balance should equal before total - (token cost + transaction cost)');
    assert.equal(tokensRemaining, 0, 'There should be no remaining tokens');
    assert.ok(equalsWithNormalizedRounding(finalFundsWalletBal, numFromWei(fundsWalletPost)));
    assert.equal(await TSDMockContract.tokensAvailable(), false);
  });

  // After sale
  it('can burn any remaining tokens in the funds wallet', async () => {
    const endTime = await TSDMockContract.endTime();
    await TSDMockContract.changeTime(endTime);
    const tokenBal = await TSDMockContract.balanceOf(fundsWallet);
    const burnTokens = await TSDMockContract.burnRemainingTokensAfterClose(fundsWallet , { from: owner });
    const tokenBalPost = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(tokenBal), 253000000, 'The first token balance should be all tokens 253 million');
    assert.equal(tokenBalPost, 0, 'There should be 0 tokens after the burn');
    assert.ok(burnTokens)
  });

  it('disallows a call to burn tokens from not the owner', async () => {
    const endTime = await TSDMockContract.endTime();
    await TSDMockContract.changeTime(endTime);
    await assertExpectedError(TSDMockContract.burnRemainingTokensAfterClose(buyerFive, { from: buyerFive }));
  });

  // Test the restrictions re. subsequent supply contract
  it('the owner can set the address of the subsequent contract', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    await TSDMockContract.setSubsequentContract(subContractAddress, { from: owner });
    const subAddressInMain = await TSDMockContract.subsequentContract();
    assert.equal(subAddressInMain, subContractAddress, 'Main contract should have the correct address referencing the subsequent contract');
  });

  it('a non owner cannot set the address of the subsequent contract', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    await assertExpectedError(TSDMockContract.setSubsequentContract(subContractAddress, { from: buyerSix }));
  });

  // These two functions can only be called by the subsequent contract
  // see TSDSubsequent Contract tests for the interaction
  // not even the owner of TSD can call them
  // #increaseTotalSupplyAndAllocateTokens
  // #increaseEthRaisedBySubsequentSale
  it('owner cannot call #increaseTotalSupplyAndAllocateTokens', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    const newTokenWallet = accounts[firstAccountIdx+13];
    await assertExpectedError(TSDMockContract.increaseTotalSupplyAndAllocateTokens(newTokenWallet, 1000000, { from: owner }));
  });

  it('owner cannot call #increaseEthRaisedBySubsequentSale', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    const newTokenWallet = accounts[firstAccountIdx+13];
    await assertExpectedError(TSDMockContract.increaseEthRaisedBySubsequentSale(1000000, { from: owner }));
  });
})
