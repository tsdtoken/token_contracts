const TSDSubsequentSupply = artifacts.require("./TSDSubsequentSupply.sol");
const TSDMock = artifacts.require("./TSDMock.sol");
const moment = require('moment');
const { numFromWei, numToWei, buyTokens, assertExpectedError, equalsWithNormalizedRounding } = require('./testHelpers');

contract('TSDSubsequentSupply', (accounts) => {
  let TSDMockContract;
  let TSDSubsequentSupplyContract;
  const currentTime = moment().unix();
  // vars for TSDSubsequentSupply
  let TSDContractAddress;
  let TSDSubsequentContractAddress;
  const firstAccountIdx = 14;
  // exchange rate is 1 szabo or 0.001
  const exchangeRate = 50000;
  // wallet that will hold all of the ether transferred
  const newFundsWallet = accounts[firstAccountIdx+1];
  const newTokensWallet = accounts[firstAccountIdx+2];
  // vars for the tsd contract
  const owner = accounts[0];
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
      pvtSaleTokenWallet,
      preSaleTokenWallet,
      foundersAndAdvisors,
      bountyCommunityIncentives,
      liquidityProgram
    );

    await TSDMockContract.createWhiteListedMapping(whitelistAddresses);

    TSDContractAddress = await TSDMockContract.address;

    TSDSubsequentSupplyContract = await TSDSubsequentSupply.new(TSDContractAddress);
    await TSDSubsequentSupplyContract.createWhiteListedMapping(whitelistAddresses);
    TSDSubsequentContractAddress = await TSDSubsequentSupplyContract.address;
  });

 it('can set the token wallet address and exchange rate by owner', async () => {
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner })
    const fundsWallet = await TSDSubsequentSupplyContract.newFundsWallet();
    const tokensWallet = await TSDSubsequentSupplyContract.newTokensWallet();
    const contractExchangeRate = await TSDSubsequentSupplyContract.exchangeRate();

    assert.ok(contractExchangeRate);
    assert.equal(numFromWei(contractExchangeRate, 'szabo'), 1000, 'Exchange rate should be set to 1 szabo (0.000001 ETH)');
    assert.equal(fundsWallet, newFundsWallet, `New funds wallet should be set to ${newFundsWallet}`);
    assert.equal(tokensWallet, newTokensWallet, `New funds wallet should be set to ${newTokensWallet}`);
  });

 it('cannot set the token wallet address and exchange rate by a different address', async () => {
    await assertExpectedError(TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: buyerOne }));
  });

 it('can change the token price as the owner', async () => {
    const tokenPricePrior = await TSDSubsequentSupplyContract.tokenPrice();
    await TSDSubsequentSupplyContract.updateTokenPrice(10, { from: owner });
    const tokenPricePost = await TSDSubsequentSupplyContract.tokenPrice();
    assert.equal(50, tokenPricePrior, 'Old Token price should be 50.');
    assert.equal(10, tokenPricePost, 'New Token price should match 10.');
  });

 it('cannot change the token price if not the owner', async () => {
    await assertExpectedError(TSDSubsequentSupplyContract.updateTokenPrice(10, { from: buyerOne }));
  });

 it('creates a mapping of all whitelisted addresses', async () => {
    // manually set up the whitelist inside the contract
    await TSDSubsequentSupplyContract.createWhiteListedMapping(whitelistAddresses, { from: owner });
    // Upon initialization of the contract, whitelisted addresses are placed into a mapping with the value of true
    const firstWhitelistAddress = await TSDSubsequentSupplyContract.isWhiteListed(buyerOne);
    const secondWhitelistAddress = await TSDSubsequentSupplyContract.isWhiteListed(buyerTwo);
    const thirdWhitelistAddress = await TSDSubsequentSupplyContract.isWhiteListed(buyerThree);

    assert.equal(firstWhitelistAddress, true, 'Address should exist in the isWhiteListed mapping with a value of true');
    assert.equal(secondWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
    assert.equal(thirdWhitelistAddress, true, 'Address should exist in the whiteListed mapping with a value of true');
  });

 it('can tell you if an address is whitelisted', async () => {
    await TSDSubsequentSupplyContract.createWhiteListedMapping(whitelistAddresses, { from: owner });
    const whitelisted = await TSDSubsequentSupplyContract.isWhiteListed(buyerOne);
    const unlisted = await TSDSubsequentSupplyContract.isWhiteListed(unlistedBuyer);
    assert.equal(whitelisted, true, 'Address should be part of the white list');
    assert.equal(unlisted, false, 'Address should not be part of the white list');
  });

 it('can increase the total supply in the main contract and allocate tokens to new token wallet', async () => {
    // set all necessary values in subsequent contract
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    // set subsequent contract address in main contract
    await TSDMockContract.setSubsequentContract(TSDSubsequentContractAddress, { from: owner });
    const totalSupply = await TSDMockContract.totalSupply();
    await TSDSubsequentSupplyContract.increaseTotalSupplyAndAllocateTokens(5000000, { from: owner });
    const updatedTotalSupply = await TSDMockContract.totalSupply();
    const newTokensWalletBal = await TSDMockContract.balanceOf(newTokensWallet);
    assert.equal(numFromWei(totalSupply), 550000000, 'Original supply of TSD should be 550 million');
    assert.equal(numFromWei(updatedTotalSupply), 555000000, 'Total supply should increase by 5 million to 555 million');
    assert.equal(numFromWei(newTokensWalletBal), 5000000, 'Balance of newTokensWallet should be 5 million');
  });

 it('can open the subsequent token sale when called by the owner', async () => {
    // set all necessary values in subsequent contract
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    await TSDSubsequentSupplyContract.openSubsequentSale({ from: owner });
    const isOpen = await TSDSubsequentSupplyContract.isOpen();
    assert.ok(isOpen);
  });

 it('cannot open the subsequent token sale when called by a different address', async () => {
    // set all necessary values in subsequent contract
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    await assertExpectedError(TSDSubsequentSupplyContract.openSubsequentSale({ from: buyerOne }));
    const isOpen = await TSDSubsequentSupplyContract.isOpen();
    assert.ok(!isOpen);
  });

 it('can close the subsequent token sale when called by the owner', async () => {
    // set all necessary values in subsequent contract
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    await TSDSubsequentSupplyContract.closeSubsequentSale({ from: owner });
    const isOpen = await TSDSubsequentSupplyContract.isOpen();
    assert.ok(!isOpen);
  });

 it('cannot close the subsequent token sale when called by a different address', async () => {
    // set all necessary values in subsequent contract
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    await TSDSubsequentSupplyContract.openSubsequentSale({ from: owner });
    await assertExpectedError(TSDSubsequentSupplyContract.closeSubsequentSale({ from: buyerOne }));
    const isOpen = await TSDSubsequentSupplyContract.isOpen();
    assert.ok(isOpen);
  });

 it('accepts ether when sale is open', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens

    // change time in main contract
    const endTime = await TSDMockContract.endTime();
    await TSDMockContract.changeTime(endTime.c[0]);

    // set all necessary values in subsequent contract
    // set correct address for the calling contract
    await TSDMockContract.setSubsequentContract(TSDSubsequentContractAddress, { from: owner });
    // set up the new tokens address, funds wallet and exachange rate
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    // increase the overall TSD total supply by the new released amount. Allocate the tokens to the new tokens address
    await TSDSubsequentSupplyContract.increaseTotalSupplyAndAllocateTokens(5000000, { from: owner });
    // create the whitelist inside the subsequent contract
    await TSDSubsequentSupplyContract.createWhiteListedMapping(whitelistAddresses, { from: owner });
    // open the sale
    await TSDSubsequentSupplyContract.openSubsequentSale({ from: owner });
    // get a ref to the new supply in order to approve that amount to be spent
    const increasedSupply = await TSDSubsequentSupplyContract.subsequentTotalSupply();
    // approve the subsequent contract to spend increased supply from the new token wallet
    await TSDMockContract.approve(TSDSubsequentContractAddress, increasedSupply, { from: newTokensWallet });
    await TSDMockContract.toggleTrading();
    // get a ref of what the new funds wallets balance is prior to the transaction
    const ethBalOfNewFundsWalletPrior = web3.eth.getBalance(newFundsWallet);
    // buy tokens
    await TSDSubsequentSupplyContract.sendTransaction(buyTokens(10, buyerOne));
    const balanceOfBuyer = await TSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await TSDMockContract.balanceOf(newTokensWallet);
    const ethBalOfNewFundsWalletPost = web3.eth.getBalance(newFundsWallet);
    assert.equal(numFromWei(balanceOfBuyer), 10000, 'The buyers balance should 10,000 tokens')
    assert.equal(numFromWei(remainingTokens), 4990000, 'The remaining tokens should be 4,990,000')
    assert.ok(equalsWithNormalizedRounding(numFromWei(ethBalOfNewFundsWalletPrior) + 10, numFromWei(ethBalOfNewFundsWalletPost)));
  });

 it('does not accept ether when sale is closed', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens

    // change time in main contract
    const endTime = await TSDMockContract.endTime();
    await TSDMockContract.changeTime(endTime.c[0]);

    // set all necessary values in subsequent contract
    // set correct address for the calling contract
    await TSDMockContract.setSubsequentContract(TSDSubsequentContractAddress, { from: owner });
    // set up the new tokens address, funds wallet and exachange rate
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    // increase the overall TSD total supply by the new released amount. Allocate the tokens to the new tokens address
    await TSDSubsequentSupplyContract.increaseTotalSupplyAndAllocateTokens(5000000, { from: owner });
    // create the whitelist inside the subsequent contract
    await TSDSubsequentSupplyContract.createWhiteListedMapping(whitelistAddresses, { from: owner });
    // get a ref to the new supply in order to approve that amount to be spent
    const increasedSupply = await TSDSubsequentSupplyContract.subsequentTotalSupply();
    // approve the subsequent contract to spend increased supply from the new token wallet
    await TSDMockContract.approve(TSDSubsequentContractAddress, increasedSupply, { from: newTokensWallet });
    await assertExpectedError(TSDSubsequentSupplyContract.sendTransaction(buyTokens(10, buyerOne)));
  });

 it('sells the last remaining tokens and issues a refund for ether unspent, closes sale', async () => {
    // exchange rate 1000 szabo or 0.001ETH
    // buyer sends in 10 ether
    // 10ETH / 0.001 = 10000 Tokens
    const defaultGanacheGasPrice = 100000000000;
    // change time in main contract
    const endTime = await TSDMockContract.endTime();
    await TSDMockContract.changeTime(endTime.c[0]);

    // set all necessary values in subsequent contract
    // set correct address for the calling contract
    await TSDMockContract.setSubsequentContract(TSDSubsequentContractAddress, { from: owner });
    // set up the new tokens address, funds wallet and exachange rate
    await TSDSubsequentSupplyContract.setTokenWalletAddressAndExchangeRate(newTokensWallet, newFundsWallet, exchangeRate, { from: owner });
    // increase the overall TSD total supply by the new released amount. Allocate the tokens to the new tokens address
    await TSDSubsequentSupplyContract.increaseTotalSupplyAndAllocateTokens(10000, { from: owner });
    // create the whitelist inside the subsequent contract
    await TSDSubsequentSupplyContract.createWhiteListedMapping(whitelistAddresses, { from: owner });
    // open the sale
    await TSDSubsequentSupplyContract.openSubsequentSale({ from: owner });
    // get a ref to the new supply in order to approve that amount to be spent
    const increasedSupply = await TSDSubsequentSupplyContract.subsequentTotalSupply();
    // approve the subsequent contract to spend increased supply from the new token wallet
    await TSDMockContract.approve(TSDSubsequentContractAddress, increasedSupply, { from: newTokensWallet });
    await TSDMockContract.toggleTrading();
    // get a ref of what the new funds wallets balance is prior to the transaction
    const ethBalOfNewFundsWalletPrior = web3.eth.getBalance(newFundsWallet);
    const ethBalOfBuyerPrior = web3.eth.getBalance(buyerOne);

    const costOfRemainingTokens = 10;
    // buy tokens
    const tx = await TSDSubsequentSupplyContract.sendTransaction(buyTokens(20, buyerOne));
    const totalGasSpent = tx.receipt.gasUsed * defaultGanacheGasPrice;
    // get post balances
    const tokenBalanceOfBuyer = await TSDMockContract.balanceOf(buyerOne);
    const remainingTokens = await TSDMockContract.balanceOf(newTokensWallet);
    const expectedEthBalOfBuyer = ethBalOfBuyerPrior - numToWei(costOfRemainingTokens) - totalGasSpent;
    const ethBalOfNewFundsWalletPost = web3.eth.getBalance(newFundsWallet);
    const ethBalOfBuyerPost = web3.eth.getBalance(buyerOne);

    // check to see if it closed the sale
    const isOpen = await TSDSubsequentSupplyContract.isOpen();
    assert.equal(numFromWei(tokenBalanceOfBuyer), 10000, 'The buyers balance should 10,000 tokens')
    assert.equal(numFromWei(remainingTokens), 0, 'The remaining tokens should be 4,990,000')
    assert.ok(equalsWithNormalizedRounding(numFromWei(ethBalOfBuyerPost), numFromWei(new web3.BigNumber(expectedEthBalOfBuyer.toString()))), 'The current balance should equal before total - (token cost + transaction cost)');
    assert.ok(equalsWithNormalizedRounding(numFromWei(ethBalOfNewFundsWalletPrior) + 10, numFromWei(ethBalOfNewFundsWalletPost)));
    assert.equal(isOpen, false, 'Sale should be automatically closed when all tokens are sold');
  });
});
