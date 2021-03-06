const PVTSDMock = artifacts.require("./PVTSDMock.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
const TSDCrowdSaleMock = artifacts.require("./TSDCrowdSaleMock.sol");
const TSDSubsequentSupply = artifacts.require("./TSDSubsequentSupply.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, equalsWithNormalizedRounding } = require('./testHelpers');

contract('TSDMock', (accounts) => {
  let TSDMockContract;
  let TSDCrowdSaleMockContract;
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
  const projectImplementationServices = accounts[firstAccountIdx+6]

  // buyers
  const buyerOne = accounts[firstAccountIdx+7];
  const buyerTwo = accounts[firstAccountIdx+8];
  const buyerThree = accounts[firstAccountIdx+9];
  const buyerFour = accounts[firstAccountIdx+10];
  const buyerFive = accounts[firstAccountIdx+11];
  const buyerSix = accounts[firstAccountIdx+12];
  const unlistedBuyer = accounts[firstAccountIdx+13];
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
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentives,
      liquidityProgram,
      projectImplementationServices
    );

    TSDCrowdSaleMockContract = await TSDCrowdSaleMock.new(
      currentTime,
      exchangeRate,
      owner
    )

    await TSDCrowdSaleMockContract.createWhiteListedMapping(whitelistAddresses);
    await TSDMockContract.contractInitialAllocation({ from: owner });

    const crowdSaleContractAddress = await TSDCrowdSaleMockContract.address;
    const mainTokenAddress = await TSDMockContract.address;

    const fundsWalletBalance = await TSDMockContract.balanceOf(owner);

    await TSDMockContract.approve(crowdSaleContractAddress, fundsWalletBalance, { from: owner });

    await TSDCrowdSaleMockContract.setMainContractAddress(mainTokenAddress, { from: owner });
    await TSDMockContract.setAuthorisedContractAddress(crowdSaleContractAddress, { from: owner });

  });

 xit('has an owner', async () => {
    assert.equal(await TSDMockContract.owner(), owner);
  });

 xit('can only call contractInitialAllocation once', async () => {
    await assertExpectedError(TSDMockContract.contractInitialAllocation({ from: owner }));
  });

 xit('sets the owner as the fundsWallet', async () => {
    assert.equal(await TSDMockContract.fundsWallet(), owner);
  });

 xit('sets the correct pvtSaleTokenWallet address', async () => {
    assert.equal(await TSDMockContract.pvtSaleTokenWallet(), pvtSaleTokenWallet);
  });

 xit('sets the correct preSaleTokenWallet address', async () => {
    assert.equal(await TSDMockContract.preSaleTokenWallet(), preSaleTokenWallet);
  });

 xit('sets the correct foundersAndAdvisors address', async () => {
    assert.equal(await TSDMockContract.owner(), owner);
  });

 xit('sets the correct bountyCommunityIncentives address', async () => {
    assert.equal(await TSDMockContract.foundersAndAdvisors(), foundersAndAdvisors);
  });

 xit('sets the correct liquidityProgram address', async () => {
    assert.equal(await TSDMockContract.liquidityProgram(), liquidityProgram);
  });

  xit('sets the correct projectImplementationServices address', async () => {
    assert.equal(await TSDMockContract.projectImplementationServices(), projectImplementationServices);
  });

 xit('TSDCrowdSaleMockContract has a valid start time, end time', async () => {
    const startTime = await TSDCrowdSaleMockContract.startTime();
    const endTime = await TSDCrowdSaleMockContract.endTime();
    assert.equal(moment.unix(startTime.c[0]).isValid(), true);
    assert.equal(moment.unix(endTime.c[0]).isValid(), true);
  });

 xit('sets the start time of TSDCrowdSaleMockContract to be Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const startTime = await TSDCrowdSaleMockContract.startTime();
    const dateString = new Date(startTime.c[0]);
    assert.equal(dateString.getTime(), 1535724000000);
  });

 xit('sets the end time of TSDCrowdSaleMockContract to be Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)', async () => {
    const endTime = await TSDCrowdSaleMockContract.endTime();
    const dateString = new Date(endTime.c[0]);
    assert.equal(dateString.getTime(), 1538316000000);
  });

 xit('transfers the private sale token allocation to pvtSaleTokenWallet', async () => {
    const allocation = await TSDMockContract.pvtSaleSupply();
    const pvtTokenWalletBal = await TSDMockContract.balanceOf(pvtSaleTokenWallet);
    assert.equal(numFromWei(pvtTokenWalletBal), numFromWei(allocation), 'Private token wallet should be allocation 144 million tokens');
  });

 xit('transfers the pre sale token allocation to preSaleTokenWallet', async () => {
    const allocation = await TSDMockContract.preSaleSupply();
    const preTokenWalletBal = await TSDMockContract.balanceOf(preSaleTokenWallet);
    assert.equal(numFromWei(preTokenWalletBal), numFromWei(allocation), 'Pre token wallet should be allocation 240 million tokens');
  });

 xit('transfers the founders and advisors token allocation to foundersAndAdvisorsAllocation wallet after escrow', async () => {
    await assertExpectedError(TSDMockContract.withdrawFromEscrow({ from: foundersAndAdvisors }));
  
  // microsecond after escow lapses  
    await TSDMockContract.changeTime(1530528101292);
    // widthdraw from escrow
    await TSDMockContract.withdrawFromEscrow({ from: foundersAndAdvisors });
    const allocation = await TSDMockContract.foundersAndAdvisorsAllocation();
    const foundersAndAdvisorsWalletBal = await TSDMockContract.balanceOf(foundersAndAdvisors);
    assert.equal(numFromWei(foundersAndAdvisorsWalletBal), numFromWei(allocation), 'Founders and advisors wallet should be allocation 60 million tokens');
  });

 xit('transfers the bounty token allocation to bountyCommunityIncentives wallet', async () => {
    await assertExpectedError(TSDMockContract.withdrawFromEscrow({ from: bountyCommunityIncentives }));
  
  // microsecond after escow lapses  
    await TSDMockContract.changeTime(1530533101292);
    // widthdraw from escrow
    await TSDMockContract.withdrawFromEscrow({ from: bountyCommunityIncentives });
    const allocation = await TSDMockContract.bountyCommunityIncentivesAllocation();
    const bountyWalletBal = await TSDMockContract.balanceOf(bountyCommunityIncentives);
    assert.equal(numFromWei(bountyWalletBal), numFromWei(allocation), 'Bounty and community incentives wallet should be allocation 42 million tokens');
  });

 xit('transfers the liquidity program token allocation to liquidityProgram wallet', async () => {
    const allocation = await TSDMockContract.liquidityProgramAllocation();
    const liquidityWalletBal = await TSDMockContract.balanceOf(liquidityProgram);
    assert.equal(numFromWei(liquidityWalletBal), numFromWei(allocation), 'Liquidity program wallet should be allocation 18 million tokens');
  });

  xit('transfers projectImplementationServices token allocation to projectImplementationServices wallet', async () => {
    const allocation = await TSDMockContract.liquidityProgramAllocation();
    const liquidityWalletBal = await TSDMockContract.balanceOf(liquidityProgram);
    assert.equal(numFromWei(liquidityWalletBal), numFromWei(allocation), 'Liquidity program wallet should be allocation 18 million tokens');
  });

 xit('funds wallet has 96 million tokens available for public sale', async () => {
    const fundsWalletBal = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(fundsWalletBal), 96000000, 'The funds wallet should have a balance of 96 million tokens');
  });

 xit('TSDCrowdSaleMockContract can tell you if an address is whitelisted', async () => {
    const whitelisted = await TSDCrowdSaleMockContract.whiteListed(buyerOne);
    const unlisted = await TSDCrowdSaleMockContract.whiteListed(unlistedBuyer);
    assert.equal(whitelisted, true, 'Address should be part of the white list');
    assert.equal(unlisted, false, 'Address should not be part of the white list');
  });

 xit('creates a mapping of all whitelisted addresses in TSDCrowdSaleMockContract', async () => {
    // Upon initialization of the contract, whitelisted addresses are placed into a mapping with the value of true
    const firstWhitelistAddress = await TSDCrowdSaleMockContract.whiteListed(buyerOne);
    const secondWhitelistAddress = await TSDCrowdSaleMockContract.whiteListed(buyerTwo);
    const thirdWhitelistAddress = await TSDCrowdSaleMockContract.whiteListed(buyerThree);

    assert.equal(firstWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(secondWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(thirdWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
  });

  // exchange rate functionality
 xit('sets the exchange rate upon initialization in TSDCrowdSaleMockContract', async () => {
    // exchange rate passed in was 1 szabo or 0.000001ETH
    const exchangeRate = await TSDCrowdSaleMockContract.exchangeRate();
    assert.ok(exchangeRate);
    assert.equal(numFromWei(exchangeRate, 'szabo'), 1000, 'Exchange rate should be set to 1 szabo (0.000001 ETH)')
  });

 xit('can change the exchange rate of TSDCrowdSaleMockContract if called by the owner only', async () => {
    // the exchange rate being passed in is 1 TSD => 0.002 ETH
    const newRate = 25000;
    const beforeExchangeRate = await TSDCrowdSaleMockContract.exchangeRate();
    const updatedFromOwner = await TSDCrowdSaleMockContract.updateTheExchangeRate(newRate, { from: owner });
    const afterExchangeRate = await TSDCrowdSaleMockContract.exchangeRate();
    // 1000 szabo is the inital amount passed to the constructor
    assert.equal(numFromWei(beforeExchangeRate, 'szabo'), 1000, 'Exchange rate should be set to the passed in value of 1 szabo');
    assert.equal(numFromWei(afterExchangeRate, 'szabo'), 2000, 'Exchange rate should be set to the new rate of 200');
    assert.ok(updatedFromOwner);
  });

 xit('cannot change exchange rate of TSDCrowdSaleMockContract from an address that isn\'t the owner', async () => {
    const newRate = 25000;
    await assertExpectedError(TSDCrowdSaleMockContract.updateTheExchangeRate(newRate, { from: buyerTwo }));
  });

  // Buy functionality

 xit('TSDCrowdSaleMockContract refuses a sale before the public sale\'s start time', async () => {
    await assertExpectedError(TSDCrowdSaleMockContract.sendTransaction(buyTokens(1, buyerOne)))
  });

 xit('TSDCrowdSaleMockContract refuses a sale 1 second before the private sale\'s start time', async () => {
    const startTime = await TSDCrowdSaleMockContract.startTime();
    const oneSecondPriorToOpen = new Date(startTime.c[0]).setSeconds(-1);
    await TSDCrowdSaleMockContract.changeTime(oneSecondPriorToOpen);
    await assertExpectedError(TSDCrowdSaleMockContract.sendTransaction(buyTokens(10, buyerOne)))
  });

 xit('TSDCrowdSaleMockContract accepts ether at the exact moment the sale opens', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens
    const startTime = await TSDCrowdSaleMockContract.startTime();
    await TSDCrowdSaleMockContract.changeTime(startTime.c[0]);
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(10, buyerOne));
    const balanceOfBuyer = await TSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 10000, 'The buyers balance should 10,000 tokens')
    assert.equal(numFromWei(remainingTokens), 95990000, 'The remaining tokens should be 95,999,000')
  });

 xit('TSDCrowdSaleMockContract accepts ether one second before close', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens
    const endTime = await TSDCrowdSaleMockContract.endTime();
    const oneSecBeforeClose = new Date(endTime.c[0]).setSeconds(-1);
    await TSDCrowdSaleMockContract.changeTime(oneSecBeforeClose);
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(10, buyerTwo));
    const balanceOfBuyer = await TSDMockContract.balanceOf(buyerTwo);
    const remainingTokens = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 10000, 'The buyers balance should 10,000 tokens')
    assert.equal(numFromWei(remainingTokens), 95990000, 'The remaining tokens should be 95,999,000')
  });

  xit('TSDCrowdSaleMockContract rejects a transaction that is less than the minimum buy of 1 ether', async () => {
    const startTime = await TSDCrowdSaleMockContract.startTime();
    await TSDCrowdSaleMockContract.changeTime(startTime.c[0]);
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(10, buyerTwo));
    const balancebuyerTwo = await TSDMockContract.balanceOf(buyerTwo);
    // Only works if ETH >= 1
    assert.equal(numFromWei(balancebuyerTwo), 10000, 'Should allow if buy is more than minimum')
    await assertExpectedError(TSDCrowdSaleMockContract.sendTransaction(buyTokens(0.5, buyerThree)))
  });
  // --------------------
 xit('transfers the ether to the funds wallet', async () => {
    const startTime = await TSDCrowdSaleMockContract.startTime();
    await TSDCrowdSaleMockContract.changeTime(startTime.c[0]);
    const balPriorEthTransfer = web3.eth.getBalance(fundsWallet);
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(10, buyerTwo));
    const balPostEthTransfer = web3.eth.getBalance(fundsWallet);
    const ethDiff = numFromWei(balPostEthTransfer) - numFromWei(balPriorEthTransfer)
    assert.equal(ethDiff, 10, 'Funds wallet should have received 10 ether from the sale');
  });

 xit('sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO', async () => {
    // set exchange rate to 1 szabo of 0.000001 Eth
    // 1ETH === 1 million TSD
    const inflatedExchange = 50000000;
    const defaultGanacheGasPrice = 100000000000;
    await TSDCrowdSaleMockContract.updateTheExchangeRate(inflatedExchange, { from: owner });
    const startTime = await TSDCrowdSaleMockContract.startTime();
    await TSDCrowdSaleMockContract.changeTime(startTime.c[0]);
    // funds wallet contains 96,000,000
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(50, buyerThree));
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(40, buyerFour));
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(5.9627, buyerFive));

    const buyerThreeBalance = await TSDMockContract.balanceOf(buyerThree);
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
    const tx = await TSDCrowdSaleMockContract.sendTransaction(buyTokens(0.0875, buyerSix));
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
    assert.equal(await TSDCrowdSaleMockContract.tokensAvailable(), false);
  });

  // After sale
 xit('can burn any remaining tokens in the funds wallet', async () => {
    // const endTime = await TSDMockContract.endTime();
    // await TSDMockContract.changeTime(endTime);
    const tokenBal = await TSDMockContract.balanceOf(fundsWallet);
    const burnTokens = await TSDMockContract.burnRemainingTokensAfterClose(fundsWallet , { from: owner });
    const tokenBalPost = await TSDMockContract.balanceOf(fundsWallet);
    assert.equal(numFromWei(tokenBal), 96000000, 'The first token balance should be all tokens 96 million');
    assert.equal(tokenBalPost, 0, 'There should be 0 tokens after the burn');
    assert.ok(burnTokens)
  });

 xit('disallows a call to burn tokens from not the owner', async () => {
    // const endTime = await TSDMockContract.endTime();
    // await TSDMockContract.changeTime(endTime);
    await assertExpectedError(TSDMockContract.burnRemainingTokensAfterClose(buyerFive, { from: buyerFive }));
  });

  // Test the restrictions re. subsequent supply contract
 xit('the owner can set the address of the subsequent contract', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    await TSDMockContract.setSubsequentContract(subContractAddress, { from: owner });
    const subAddressInMain = await TSDMockContract.subsequentContract();
    assert.equal(subAddressInMain, subContractAddress, 'Main contract should have the correct address referencing the subsequent contract');
  });

 xit('a non owner cannot set the address of the subsequent contract', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    await assertExpectedError(TSDMockContract.setSubsequentContract(subContractAddress, { from: buyerSix }));
  });

  xit('the owner can change the start date', async () => {
    await TSDCrowdSaleMockContract.setStartTime(1535324000000);
    const startTime = await TSDCrowdSaleMockContract.startTime({ from: owner });
    assert.equal(startTime, 1535324000000, 'The start date should change');
  });

  xit('the owner can change the end date', async () => {
    await TSDCrowdSaleMockContract.setEndTime(1838316000000);
    const startTime = await TSDCrowdSaleMockContract.endTime({ from: owner });
    assert.equal(startTime, 1838316000000, 'The end date should change');
  });

  // These two functions can only be called by the subsequent contract
  // see TSDSubsequent Contract tests for the interaction
  // not even the owner of TSD can call them
  // #increaseTotalSupplyAndAllocateTokens
  // #increaseEthRaisedBySubsequentSale
 xit('owner cannot call #increaseTotalSupplyAndAllocateTokens', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    const newTokenWallet = accounts[firstAccountIdx+14];
    await assertExpectedError(TSDMockContract.increaseTotalSupplyAndAllocateTokens(newTokenWallet, 1000000, { from: owner }));
  });

 xit('owner cannot call #increaseEthRaisedBySubsequentSale', async () => {
    const mainContractAddress = await TSDMockContract.address;
    const SubsequentContract = await TSDSubsequentSupply.new(mainContractAddress);
    const subContractAddress = await SubsequentContract.address;
    const newTokenWallet = accounts[firstAccountIdx+14];
    await assertExpectedError(TSDMockContract.increaseEthRaisedBySubsequentSale(1000000, { from: owner }));
  });

 xit('only owner can call setAuthorisedContractAddress', async () => {

   await TSDMockContract.setAuthorisedContractAddress(buyerFour, { from: owner })

   const currentAuthorisedContract = await TSDMockContract.authorisedContract();

   assert.equal(currentAuthorisedContract, buyerFour, 'The authorised wallet should be buyerFour');

   await assertExpectedError(TSDMockContract.setAuthorisedContractAddress(unlistedBuyer, { from: pvtSaleTokenWallet }));
 })

 xit('can trade only when canTrade boolean is active', async () => {

    const startTime = await TSDCrowdSaleMockContract.startTime();
    await TSDCrowdSaleMockContract.changeTime(startTime.c[0]);
    await TSDCrowdSaleMockContract.sendTransaction(buyTokens(10, buyerOne));

    let canTradeState = await TSDMockContract.canTrade();

    assert.equal(canTradeState, false, 'canTrade should be false');

    await assertExpectedError(TSDMockContract.transfer(unlistedBuyer, 100, { from: buyerOne }));

    await TSDMockContract.toggleTrading({ from: owner });

    canTradeState = await TSDMockContract.canTrade();

    assert.equal(canTradeState, true, 'canTrade should be true');

    await TSDMockContract.transfer(unlistedBuyer, numToWei(100), { from: buyerOne });

    const balanceOfReceiver = await TSDMockContract.balanceOf(unlistedBuyer);

    assert.equal(numFromWei(balanceOfReceiver), 100, 'canTrade should be true');
  
  })
})
