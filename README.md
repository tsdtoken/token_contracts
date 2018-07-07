# ReadME for Transcendence ICO!

The dApp project contains two independent yet related aspects to the successful ICO. The dApp itself is a web interface we use to connect directly to the blockchain and the targeted smart contract using Web3/portis or any Ethereum wallet enabled browser.

We also have the 4 independent contracts that will be used for **4 phases** of the the project

- The **Private Sale Contract** which will host a set of rules for the private sale buyers.
> Standard ERC20 contract with a buy in asset freeze of 9 Months from main ICO close.
	
- The **Pre Sale Contract** which will host a set of rules for the private sale buyers.
> Standard ERC20 contract with a buy in asset freeze of 12 Months from main ICO close.
	
- The **Main Sale Contract** which will host a set of rules for the private sale buyers.
> Standard ERC20 contract with rules regarding whitelisting.
> Time lockouts
> Refunds
> Transfer of ownership
> Burnable tokens
	
- The **Subsequent Sale Contract** which will host a set of rules for the private sale buyers.
> Standard ERC20 contract with the option to toggle the ability to accept Eth.
> Raise the token number in the main ICO
> Distribute tokens to subsequent purchases


# Contracts

A further discussion into the inspirations and rules of the contracts used for different stages of the ICO

## The Base Line Contract
-  It is at minimum an ERC-20 Compliant Smart Contract
- Safemath is used throughout all contracts to prevent any mathematical edge case errors
- Tokens are offered with 18 decimal places
- Initial token distribution supply which can be mutated by the owners of the smart contract, note
- Pre-allocation of tokens to accounts nominated by Maoneng
-  Whitelisting (i.e only whitelisted token users are allowed to transfer their tokens, this whitelisting is dependent upon which token period they participated in - private/pre or mainsale ICO)
-  Ability to exchange Ether for pre-allocated tokens
-  Automatically transfer ETH sent to smart contract to wallet nominated by Maoneng(this ETH is real money i.e fiat converted ETH)
-  Restrictions based on start and end dates as well as total sale value
- Tokens can only be traded once the ICO has come to a conclusion

## Private Sale Token Contract

The first of three token sales organised by Transcendence. This round offers the highest level of discount for the token. The discount is not in perspective of reduced price for a unit token but the offering of more tokens for the same price.

> Total supply of 144 Million tokens will be offered and reserved in this round

> The Token follows all ERC20 principles stated in the Base Line Contract

> Only people who have whitelisted themselves with their ETH wallet addresses can participate in the token sale

> Token value is intrinsically 50 cents but offered at 30% discount (0.35 USD)

>  If someone sends more ETH than tokens available, the rest of the ETH is refunded, and the remaining tokens are allocated

Address  | Bool
------------- | -------------
xya123hi  | true
iniof232FN231  | true

The address participating in the Private round is cross checked in the balances above before accepting ETH from it.

Upon initiation, the `exchange rate`,  `start time`, `end time` and `token release date` are passed in the constructor function. When invoked, the allocated supply is transferred from the contract to the `owner's wallet`. I.e the wallet that deployed the contract.

> Considering whitelisted addresses will be from our DB, and we'll sync it with the Private contract `createWhiteListedMapping✓` is used to populate the above mapping. An oracle has been scripted for this which will automatically execute the mapping from our database.

>  `buyTokens` acts as the fallback function and is used to allow ETH deposits. A consistent if **if-else** statement exists to confirm if the total ETH sent does not equate to more than the tokens available, and if so, **refund** the remaining ETH back to the sender.

>  All unsold tokens can be burn with `burnRemainingTokensAfterClose✓` which confirms the close of the Private ICO round before burning them.

> We keep track of the total ETH raised, to help with a easy infographic in the website

> `distrubuteTokens✓` uses instance access to the main contract to transfer tokens from the pvtSaleTokenWallet to the respective ICO participants.

> Transfer and TransferFrom are wrapped with modifications to prevent the use of them until token release date has reached.

Functions available:

- `balanceOf`
> Returns the balance of an address
- `createWhiteListedMapping✓`
> Called externally to create whitelist for sale. Only whitelisted addresses can participate in the ico.
- `changeOracleAddress✓`
> Changes the oracle address which is used to update the ethExchangeRate
- `updateTheExchangeRate`
> This is called when the contract is constructed and by the oracle to update the rate periodically, this updates the ethToUSD exchange rate, the USD is calculated and maintained in cents
- `isWhiteListed`
> Checks to see if an address is whitelisted
- `buyTokens`
> Is called through a fallback function which is payable to accept ether. It calculates the token amount, ensures the validations such as time range, minimum purchase amount, and whitelisted status of the buyer. If a buyer sends more ether than the total token amount, the remainder ETH is refunded to the buyer.
- `setMainContractAddress✓`
> Sets the main contract address reference, this instance is used during distribution of tokens
- `burnRemainingTokens✓`
> Burns the remaining tokens and updates the supply, a safety check is placed to ensure that its only called after the end time has concluded.
- `distributeTokens`
> This can only be called by the owner on or after the token release date.
> This will be a two step process.
>  This function will be called by the pvtSaleTokenWallet
>  This wallet will need to be approved in the main contract to make these distributions
- `setStartTime & setEndTime`
> Custom sets the start and end time
 - `selfDestruct`
> Kills the contract instance and its existence from the blockchain merkle tree

## Pre-Sale Token Contract

The second of three token sales organised by Transcendence. This round offers the second highest level of discount for the token. The discount is not in perspective of reduced price for a unit token but the offering of more tokens for the same price.

> Total supply of 240 Million tokens will be offered and reserved in this round

> The token is not ERC20 compliant as it doesn't contain a fair few of the methods needed to reach compliance.

> Only people who have whitelisted themselves with their ETH wallet addresses can participate in the token sale

> Tokens are sold in tranches. 4 tranches of 60M each.
- First tranche at 20% discount ($0.5 * 0.8 = $0.40)
- Second tranche at 16% discount ($0.5 * 0.84 = $0.42)
- Third tranche at 12% discount ($0.5 * 0.88 = $0.44)
- Fourth tranche at 8% discount ($0.5 * 0.925 = $0.46)

Address  | Bool
------------- | -------------
xya123hi  | true
iniof232FN231  | true

The address participating in the Presale round is cross checked in the balances above before accepting ETH from it.

Considering whitelisted addresses will be from our DB, and we'll sync it with the Private contract `createWhiteListedMapping` is used to populate the above mapping.

`buyTokens` acts as the fallback function and is used to allow ETH deposits. A consistent if **if-else** statement exists to confirm if the total ETH sent does not equate to more than the tokens available, and if so, **refund** the remaining ETH back to the sender. The tokens are sold in tranches, where when remainder tokens traverse between tranches, ETH gains power in reference to TSD. Going with a nominal rate of 50 cents, the tranches go with 20%, 16%, 12% and 8%.

All unsold tokens can be burn with `burnRemainingTokensAfterClose` which confirms the close of the Presale ICO round before burning them.

We keep track of the total ETH raised, to help with a easy infographic in the website

`distrubuteTokens✓` uses instance access to the main contract to transfer tokens from the pvtSaleTokenWallet to the respective ICO participants.

> Transfer and TransferFrom are wrapped with modifications to prevent the use of them until token release date has reached.

Functions available:

- `balanceOf`
> Returns the balance of an address
- `createWhiteListedMapping`
> Called externally to create whitelist for sale. Only whitelisted addresses can participate in the ico.
- `changeOracleAddress✓`
> Changes the oracle address which is used to update the ethExchangeRate
- `updateTheExchangeRate`
> This is called when the contract is constructed and by the oracle to update the rate periodically, this updates the ethToUSD exchange rate, the USD is calculated and maintained in cents
- `isWhiteListed`
> Checks to see if an address is whitelisted
- `buyTokens`
> Is called through a fallback function which is payable to accept ether. It calculates the token amount, ensures the validations such as time range, minimum purchase amount, and whitelisted status of the buyer. If a buyer sends more ether than the total token amount, the remainder ETH is refunded to the buyer.
- `setMainContractAddress✓`
> Sets the main contract address reference, this instance is used during distribution of tokens
- `burnRemainingTokens`
> Burns the remaining tokens and updates the supply, a safety check is placed to ensure that its only called after the end time has concluded.
- `distributeTokens✓`
> This can only be called by the owner on or after the token release date.
> This will be a two step process.
>  This function will be called by the pvtSaleTokenWallet
>  This wallet will need to be approved in the main contract to make these distributions
- `setStartTime✓ & setEndTime✓`
> Custom sets the start and end time
 - `selfDestruct`
> Kills the contract instance and its existence from the blockchain merkle tree
- `tokenToEth`
> Usage:
>  Pass in the amount of tokens and the discount rate.
>   If no discount is required pass in 100 as the rate value.
- `ethToToken`
> Usage:
>Pass in the amount of eth and the discount rate.
> If no discount is required pass in 100 as the rate value.
>  This wallet will need to be approved in the main contract to make these distributions
- `calculateTotalRemainingTokenCost`
> Calculates the cost of all the remaining tokens that can be purchased based on the diluting power of the eth in respect to the TSD that can be bought.
 - `calculateTokenAmountWithDiscounts`
> Calculates the number tokens that can be purchased based on the diluting power of the eth in respect to the TSD that can be bought.

## Main token sale Contract
This is the contract that will, in conclusion, hold **all** wallet addresses that own TSD coin. This is the contract where no bonus will be offered during sale. The length of the ICO will be subjective to which of the following milestones are achieved first:

> End of sale date

> Total supply of TSD is 550M tokens
- 144M is reserved for the private sale
- 240M is reserved for the pre sale
- 96M is reserved for the main sale
- 48M is reserved for the founders and advisors
- 42M is reserved for the bounty and allocation incentives
- 18M is reserved for the liquidity program
- 12M is reserved for projectImplementationServices

>Token depletion (all tokens sold out)

> Tokens are sold at $0.50c

Upon contract initialisation:
- The total supply is allocated to the funds wallet which is the owner wallet i.e the wallet used to deploy the contract
- Start and End dates are decided (these can be mutated)
- Exchange rate is decided (this can be changed)

Once the contract is launched, the `contractInitialAllocation` method is to be called immediately.  When this happens.

- Private and Presale supply is subtracted from the total supply to prevent over sell
- Tokens are transferred to the respective private and presale wallets
- Events are emitted
- Exchange rate is set based on the ethExchangeRate passed in to the constructor method.

Fallback payable function is used to absorb ETH and reward senders with TSD tokens based on the assigned exchange rate.

Similar refund logic to the private and pre token sale contracts is implemented here.

Subsequent supply functions which are own owner accessible are present in the mainsale to allow for an increase in token supply as well as assign the new tokens to a new holding wallet.

No tokens purchased can be traded until the ICO is closed, in perspective to the endTime, not the depletion of tokens.

Token trade can be frozen by the owner. This contract is ERC20 compliant, however the transfer and tranferFrom method have requirements, the `canTrade` boolean needs to be set to true, which is controlled by the contract owner.

Functions available:

- `balanceOf`
> Returns the balance of an address
- `toggleTrading`
> Toggles the trading ability of TSD token holders (refer to the transfer and transferFrom method)
- `createWhiteListedMapping`
> Called externally to create whitelist for sale. Only whitelisted addresses can participate in the ico.
- `changeOracleAddress`
> Changes the oracle address which is used to update the ethExchangeRate
- `updateTheExchangeRate`
> This is called when the contract is constructed and by the oracle to update the rate periodically, this updates the ethToUSD exchange rate, the USD is calculated and maintained in cents
- `isWhiteListed`
> Checks to see if an address is whitelisted
- `buyTokens`
> Is called through a fallback function which is payable to accept ether. It calculates the token amount, ensures the validations such as time range, minimum purchase amount, and whitelisted status of the buyer. If a buyer sends more ether than the total token amount, the remainder ETH is refunded to the buyer.
- `setMainContractAddress✓`
> Sets the main contract address reference, this instance is used during distribution of tokens
- `burnRemainingTokens✓`
> Burns the remaining tokens and updates the supply, a safety check is placed to ensure that its only called after the end time has concluded.
- `setSubsequentContract✓`
>  Sets the subsequent contract address
- `increaseTotalSupplyAndAllocateTokens`
>  Called by the subsequent contract, and is used to increase the total supply and allocate tokens to the new token wallet
- `increaseEthRaisedBySubsequentSale`
> Keeps track of the ETH raised and emits an event to reflect so
- `setStartTime✓ & setEndTime✓`
> Custom sets the start and end time
 - `escrowAccountAllocation`
> Called internally within `contractInitialAllocation✓` to allocate a struct with amount and cliffTime
 - `withdrawFromEscrow✓`
> Can be only called by the escrowed wallets and will only work once the respective wallet's escrow period has lapsed
- `selfDestruct✓`
> Kills the contract instance and its existence from the blockchain merkle tree
## Subsequent Contract

The uniqueness of the Transcendence project is the close tie between the utility token and assets the tokens back in the eventual platform Transcendence will create.

The use of the subsequent contract will be to increase the supply of the TSD token and offer a additional token sale. The occurrence  of this would be in situations a new asset has entered the platform that cannot be backed by the current circulatory supply of TSD tokens.

An increase in supply is thus indicative of a well performing platform.

> The subsequent contract will act as a proxy to inject more tokens into the balances mapping on the main contract with new token purchasers

Functions available:

- `setTokenHolderAddressAndExchangeRate`
> Sets the exchange rate, which is dynamic per contract round, and sets the wallet that will initially hold the tokens
- `increaseTotalSupplyAndAllocateTokens`
> Sets the new token wallet in the main contract and allocates it the designated increased supply
- `openSubsequentSale✓`
> The contract will by default state be shut, this function is accessible only by the owner (the person who deployed this contract in the first place) and sets the contract active
- `closeSubsequentSale✓`
> Closes the current active subsequent contract token sale
- `buySubsequentTokens`
> Considering we want to encourage people to buy through our dApp, we set this function to a payable modifier enabling it to receive real ETH, the tokens are calculated with the exchange rate, and the allocated to the sender in the main token sale

# Distribution of tokens
At present the logic is assumed such that tokens from private and pre sale will be held in the respective smart contracts until said release dates have not reached, which will then allow the owners of the contracts to call the distribute function, that will assign the private or pre sale token owners their equivalent TSD tokens

# Test Driven Development
Testing is a critical part of the project, we need to have the contract be as deterministic as possible, which leads to predictable results and behaviours.

**Contract: TSD**

    ✓ has an owner
    ✓ can only call contractInitialAllocation once
    ✓ sets the owner as the fundsWallet
    ✓ sets the correct pvtSaleTokenWallet address
    ✓ sets the correct preSaleTokenWallet address
    ✓ sets the correct foundersAndAdvisors address
    ✓ sets the correct bountyCommunityIncentives address
    ✓ sets the correct liquidityProgram address
    ✓ has a valid start time, end time
    ✓ sets the start time to be Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)
    ✓ sets the end time to be Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)
    ✓ transfers the private sale token allocation to pvtSaleTokenWallet
    ✓ transfers the pre sale token allocation to preSaleTokenWallet
    ✓ transfers the founders and advisors token allocation to foundersAndAdvisorsAllocation wallet
    ✓ transfers the bounty token allocation to bountyCommunityIncentives wallet
    ✓ transfers the liquidity program token allocation to pvtSaleTokenWallet
    ✓ funds wallet has 253 million tokens available for public sale
    ✓ can tell you if an address is whitelisted
    ✓ creates a mapping of all whitelisted addresses (44ms)
    ✓ sets the exchange rate upon initialization
    ✓ can change the exchange rate if called by the owner only (53ms)
    ✓ cannot change exchange rate from an address that isn't the owner
    ✓ refuses a sale before the public sale's start time
    ✓ refuses a sale 1 second before the private sale's start time (59ms)
    ✓ accepts ether at the exact moment the sale opens (115ms)
    ✓ accepts ether one second before close (100ms)
    ✓ rejects a transaction that is less than the minimum buy of 1 ether (125ms)
    ✓ transfers the ether to the funds wallet (287ms)
    ✓ sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO (786ms)
    ✓ can burn any remaining tokens in the funds wallet (95ms)
    ✓ disallows a call to burn tokens from not the owner (57ms)
    ✓ the owner can set the address of the subsequent contract (113ms)
    ✓ a non owner cannot set the address of the subsequent contract (65ms)
    ✓ the owner can change the start date (39ms)
    ✓ the owner can change the end date (39ms)
    ✓ owner cannot call #increaseTotalSupplyAndAllocateTokens (79ms)
    ✓ owner cannot call #increaseEthRaisedBySubsequentSale (70ms)

  **Contract: TSDSubsequentSupply**
  
    ✓ can set the token wallet address and exchange rate by owner (68ms)
    ✓ cannot set the token wallet address and exchange rate by a different address
    ✓ can change the token price as the owner (48ms)
    ✓ cannot change the token price if not the owner
    ✓ creates a mapping of all whitelisted addresses (66ms)
    ✓ can tell you if an address is whitelisted (55ms)
    ✓ can increase the total supply in the main contract and allocate tokens to new token wallet (129ms)
    ✓ can open the subsequent token sale when called by the owner (64ms)
    ✓ cannot open the subsequent token sale when called by a different address (54ms)
    ✓ can close the subsequent token sale when called by the owner (64ms)
    ✓ cannot close the subsequent token sale when called by a different address (82ms)
    ✓ accepts ether when sale is open (512ms)
    ✓ does not accept ether when sale is closed (245ms)
    ✓ sells the last remaining tokens and issues a refund for ether unspent, closes sale (788ms)

 **Contract: PRETSD**
 
    ✓ has an owner
    ✓ designates the owner as the preFundsWallet
    ✓ has a valid start time, end time and token release time
    ✓ sets the start time to be Wed Aug 01 2018 00:00:00 GMT+1000 (AEST)
    ✓ sets the end time to be Wed Aug 22 2018 00:00:00 GMT+1000 (AEST)
    ✓ sets the token release time to be Thu Aug 01 2019 00:00:00 GMT+1000 (AEST)
    ✓ transfers total supply of tokens (165 million) to the pre funds wallet
    ✓ sets the exchange rate upon initialization
    ✓ can change the exchange rate if called by the owner only (52ms)
    ✓ cannot change exchange rate from an address that isn't the owner
    ✓ refuses a sale before the private sale's start time
    ✓ refuses a sale 1 second before the private sale's start time (48ms)
    ✓ accepts ether at the exact moment the sale opens (95ms)
    ✓ transfer the ether to the funds wallet (258ms)
    ✓ rejects ether from an address that isn't whitelisted (55ms)
    ✓ rejects a transaction that is less than the minimum buy of 5,000.00 USD (50ms)
    ✓ sells the required tokens based on the remaining tokens in the tranches (430ms)
    ✓ sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO (630ms)
    ✓ disallows a call to burn tokens from not the owner (59ms)
    ✓ can set a reference to the main token contract on from owner (187ms)
    ✓ distributes private token balances into the main contract, transfers any remaining to main funds wallet token balance (530ms)
    ✓ the owner can change the start date
    ✓ the owner can change the end date

  **Contract: PVTSD**
  
    ✓ has an owner
    ✓ designates the owner as the pvtFundsWallet
    ✓ has a valid start time, end time and token release time
    ✓ sets the start time to be Fri Jun 15 2018 00:00:00 GMT+1000 (AEST)
    ✓ sets the end time to be Sun Jul 15 2018 00:00:00 GMT+1000 (AEST)
    ✓ sets the release date to be Mon Apr 15 2019 00:00:00 GMT+1000 (AEST)
    ✓ transfers total supply of tokens (82.5 million) to the private funds wallet
    ✓ can tell you if an address is whitelisted
    ✓ creates a mapping of all whitelisted addresses (41ms)
    ✓ sets the exchange rate upon initialization
    ✓ can change the exchange rate if called by the owner only (53ms)
    ✓ cannot change exchange rate from an address that isn't the owner
    ✓ refuses a sale before the private sale's start time
    ✓ refuses a sale 1 second before the private sale's start time (52ms)
    ✓ accepts ether at the exact moment the sale opens (126ms)
    ✓ applies a 30% discount on token sales (109ms)
    ✓ keeps a reference of all buyers address in the icoParticipants array (130ms)
    ✓ transfers the ether to the funds wallet (277ms)
    ✓ rejects ether from an address that isn't whitelisted (56ms)
    ✓ rejects a transaction that is less than the minimum buy of 50,000.00 USD (192ms)
    ✓ sells the last remaining ether if less than minimum buy, returns unspent ether to the buyer, closes ICO (541ms)
    ✓ can burn any remaining tokens in the funds wallet (91ms)
    ✓ disallows a call to burn tokens from not the owner (49ms)
    ✓ can set a reference to the main token contract on from owner (171ms)
    ✓ distributes private token balances into the main contract (572ms)
    ✓ the owner can change the start date
    ✓ the owner can change the end date
