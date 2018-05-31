const PVTSDMock = artifacts.require("./PVTSDMock.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
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
    accounts[13],
    accounts[14]
  ];
  const buyerOne = accounts[1];
  const buyerTwo = accounts[2];
  const buyerThree = accounts[3];
  const buyerFour = accounts[4];
  const buyerFive = accounts[5];
  const buyerSix = accounts[6]
  const unlistedBuyer = accounts[7];

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
  
  it('sets the release date to be Mon Apr 15 2019 00:00:00 GMT+1000 (AEST)', async () => {
    const tokensReleaseDate = await PVTSDMockContract.tokensReleaseDate();
    const dateString = new Date(tokensReleaseDate.c[0]);
    assert.equal(dateString, 'Mon Apr 15 2019 00:00:00 GMT+1000 (AEST)');
  });
  
  it('transfers total supply of tokens (55 million) to the private funds wallet', async () => {
    const pvtFundsWallet = owner;
    const pvtFundsWalletBalance = await PVTSDMockContract.balanceOf(pvtFundsWallet);
    assert.equal(numFromWei(pvtFundsWalletBalance), 55000000, 'Balance of pvtFundsWallet should be 55 million');
  });

  it('can tell you if an address is whitelisted', async () => {
    const whitelisted = await PVTSDMockContract.isWhiteListed(buyerOne);
    const unlisted = await PVTSDMockContract.isWhiteListed(unlistedBuyer);
    assert.equal(whitelisted, true, 'Address should be part of the white list');
    assert.equal(unlisted, false, 'Address should not be part of the white list');
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
    const oneSecondPriorToOpen = new Date(startTime.c[0]).setSeconds(-1);
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
    await PVTSDMockContract.changeTime(startTime.c[0]);
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerOne));
    const balanceOfBuyer = await PVTSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await PVTSDMockContract.balanceOf(pvtFundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 83333, 'The buyers balance should 83,333 tokens')
    assert.equal(numFromWei(remainingTokens), 54916667, 'The remaining tokens should be 54,916,667')
  });

  it('applies a 40% discount on token sales', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // discounted rate will end up as 0.0006ETH (40% disc)
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
    await PVTSDMockContract.sendTransaction(buyTokens(60, buyerFive));
    const buyerTokenBal = await PVTSDMockContract.balanceOf(buyerFive);
    assert.equal(numFromWei(buyerTokenBal), 100000, 'Buyer should have a balance of 100,000 tokens');
  });
  
  it('keeps a reference of all buyers address in the icoParticipants array', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerSix));
    const addressAtZeroInx = await PVTSDMockContract.icoParticipants(0);
    assert.equal(addressAtZeroInx, buyerSix, `The first address in the array should be buyer three ${buyerThree}`);
  });

  it('transfers the ether to the funds wallet', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
    const balPriorEthTransfer = web3.eth.getBalance(pvtFundsWallet);
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerTwo));
    const balPostEthTransfer = web3.eth.getBalance(pvtFundsWallet);
    const ethDiff = numFromWei(balPostEthTransfer) - numFromWei(balPriorEthTransfer)
    assert.equal(ethDiff, 50, 'Funds wallet should have received 50 ether from the sale');
  });

  it('rejects ether from an address that isn\'t whitelisted', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(50, unlistedBuyer)))
  });

  it('rejects a transaction that is less than the minimum buy of 50 ether', async () => {
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
    await assertExpectedError(PVTSDMockContract.sendTransaction(buyTokens(20, buyerThree)))
  });

  it('sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO', async () => {
    // 1 szabo = 0.000003 ETH
    const inflatedExchangeRate = new web3.BigNumber(3);
    const defaultGanacheGasPrice = 100000000000;
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
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
    // expected buyer eth balance after sale
    const expectedEthBal = buyerEThBalPrior - numToWei(costOfRemainingTokens) - totalGasSpent;
    // this is to handle a javascript rounding error
    const finalFundsWalletBal = (numFromWei(fundsWalletEthBalPrior) * 10000000 + costOfRemainingTokens * 10000000) / 10000000;
    assert.equal(numFromWei(buyerTokenBalance), 5000000, 'Buyer should be transfered the remaining 5 million tokens');
    assert.equal(numFromWei(buyerEThBalPost), numFromWei(new web3.BigNumber(expectedEthBal)), 'The current balance should equal before total - (token cost + transaction cost)');
    assert.equal(tokensRemaining, 0, 'There should be no remaining tokens');
    assert.equal(finalFundsWalletBal, numFromWei(fundsWalletEthBalPost));
    // icoOpen is set to false when no tokens remain
    assert.equal(await PVTSDMockContract.icoOpen(), false);
  })

  it('can burn any remaining tokens in the funds wallet', async () => {
    const endTime = await PVTSDMockContract.endTime();
    await PVTSDMockContract.changeTime(endTime);
    const tokenBal = await PVTSDMockContract.balanceOf(pvtFundsWallet);
    const burnTokens = await PVTSDMockContract.burnRemainingTokens({ from: owner });
    const tokenBalPost = await PVTSDMockContract.balanceOf(pvtFundsWallet);
    assert.equal(numFromWei(tokenBal), 55000000, 'The first token balance should be all tokens 55 million');
    assert.equal(tokenBalPost, 0, 'There should be 0 tokens after the burn');
    assert.ok(burnTokens)
  });

  it('disallows a call to burn tokens from not the owner', async () => {
    const endTime = await PVTSDMockContract.endTime();
    await PVTSDMockContract.changeTime(endTime);
    await assertExpectedError(PVTSDMockContract.burnRemainingTokens({ from: buyerFive }));
  });

  // setting a reference to the main token contract
  it('can set a reference to the main token contract on from owner', async () => {
    const pvtSaleTokenWallet = accounts[7];
    const preSaleTokenWallet = accounts[8];
    const foundersAndAdvisors = accounts[9];
    const bountyCommunityIncentive = accounts[10];
    const liquidityProgram = accounts[11];
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
    await assertExpectedError(PVTSDMockContract.setMainContractAddress(TSDMockContract.address, { from: buyerFive }))
    await PVTSDMockContract.setMainContractAddress(TSDMockContract.address, { from: owner });
    const setRefAddress = await PVTSDMockContract.TSDContractAddress();
    assert.equal(setRefAddress, TSDMockContract.address, `Address set in the contract should be the address of the main contract ${setRefAddress}`)
  })

  it('distributes private token balances into the main contract, burns any remaining tokens', async () => {
    const pvtSaleTokenWallet = accounts[8];
    const preSaleTokenWallet = accounts[9];
    const foundersAndAdvisors = accounts[10];
    const bountyCommunityIncentive = accounts[11];
    const liquidityProgram = accounts[12];
    const buyerSeven = accounts[13];
    const buyerEight = accounts[14];
    const fundsWallet = owner;
    const pvtContractAddress = await PVTSDMockContract.address;
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

    // make a buy in the private sale
    const startTime = await PVTSDMockContract.startTime();
    await PVTSDMockContract.changeTime(startTime.c[0]);
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerSeven));
    await PVTSDMockContract.sendTransaction(buyTokens(50, buyerEight));
    // // change time to token release date
    // // change time in the main contract to token release date
    // // distribute the tokens for pvt contract to the main contract
    const tokensReleaseDate = await PVTSDMockContract.tokensReleaseDate();
    await PVTSDMockContract.changeTime(tokensReleaseDate);
    await TSDMockContract.changeTime(tokensReleaseDate);
    const mainContractPvtTokenAllocation = await TSDMockContract.balanceOf(pvtSaleTokenWallet);
    await TSDMockContract.approve(pvtContractAddress, mainContractPvtTokenAllocation, { from: pvtSaleTokenWallet });
    // // set up contract reference
    await PVTSDMockContract.setMainContractAddress(TSDMockContract.address, { from: owner });
    await PVTSDMockContract.distributeTokens({ from: owner });
    // check the balance of the pvt sale buyer in the main contract
    const firstBuyerPvtBal = await PVTSDMockContract.balanceOf(buyerSeven);
    const firstBuyerMainBal = await TSDMockContract.balanceOf(buyerSeven);
    const secondBuyerPvtBal = await PVTSDMockContract.balanceOf(buyerEight);
    const secondBuyerMainBal = await TSDMockContract.balanceOf(buyerEight);
    assert.equal(numFromWei(firstBuyerPvtBal), numFromWei(firstBuyerMainBal));
    assert.equal(numFromWei(secondBuyerPvtBal), numFromWei(secondBuyerMainBal));
  });
});
  