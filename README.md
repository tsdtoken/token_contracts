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

> Total supply of 20 Million tokens will be offered and reserved in this round

> The Token follows all ERC20 principles stated in the Base Line Contract

> Only people who have whitelisted themselves with their ETH wallet addresses can participate in the token sale

Address  | Bool
------------- | -------------
xya123hi  | true
iniof232FN231  | true

The address participating in the Private round is cross checked in the balances above before accepting ETH from it.

Upon initiation, the `exchange rate`, `array of whitelisted addresses`, `start time`, `end time` and `token release date` are passed in the constructor function. When invoked, the allocated supply is transferred from the contract to the `owner's wallet`. I.e the wallet that deployed the contract.

Considering whitelisted addresses will be from our DB, and we'll sync it with the Private contract `createWhiteListedMapping` is used to populate the above mapping.

`buyTokens` acts as the fallback function and is used to allow ETH deposits. A consistent if **if-else** statement exists to confirm if the total ETH sent does not equate to more than the tokens available, and if so, **refund** the remaining ETH back to the sender.

All unsold tokens can be burn with `burnRemainingTokensAfterClose` which confirms the close of the Private ICO round before burning them.

We keep track of the total ETH raised, to help with a easy infographic in the website

`distrubuteTokens` uses instance access to the main contract to transfer tokens from the pvtSaleTokenWallet to the respective ICO participants.

> Transfer and TransferFrom are wrapped with modifications to prevent the use of them until token release date has reached.

## Pre-Sale Token Contract

The second of three token sales organised by Transcendence. This round offers the second highest level of discount for the token. The discount is not in perspective of reduced price for a unit token but the offering of more tokens for the same price.

> Total supply of 30 Million tokens will be offered and reserved in this round

> The Token follows all ERC20 principles stated in the Base Line Contract

> Only people who have whitelisted themselves with their ETH wallet addresses can participate in the token sale

Address  | Bool
------------- | -------------
xya123hi  | true
iniof232FN231  | true

The address participating in the Presale round is cross checked in the balances above before accepting ETH from it.

Considering whitelisted addresses will be from our DB, and we'll sync it with the Private contract `createWhiteListedMapping` is used to populate the above mapping.

`buyTokens` acts as the fallback function and is used to allow ETH deposits. A consistent if **if-else** statement exists to confirm if the total ETH sent does not equate to more than the tokens available, and if so, **refund** the remaining ETH back to the sender.

All unsold tokens can be burn with `burnRemainingTokensAfterClose` which confirms the close of the Presale ICO round before burning them.

We keep track of the total ETH raised, to help with a easy infographic in the website

`distrubuteTokens` uses instance access to the main contract to transfer tokens from the pvtSaleTokenWallet to the respective ICO participants.

> Transfer and TransferFrom are wrapped with modifications to prevent the use of them until token release date has reached.

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
- `openSubsequentSale`
	> The contract will by default state be shut, this function is accessible only by the owner (the person who deployed this contract in the first place) and sets the contract active
- `closeSubsequentSale`
	> Closes the current active subsequent contract token sale
- `buySubsequentTokens`
	> Considering we want to encourage people to buy through our dApp, we set this function to a payable modifier enabling it to receive real ETH, the tokens are calculated with the exchange rate, and the allocated to the sender in the main token sale