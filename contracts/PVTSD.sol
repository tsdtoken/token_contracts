pragma solidity ^0.4.23;

import "./FoundationContracts/SecondaryCrowdsaleContract.sol";

contract PVTSD is SecondaryCrowdsaleContract {

    string public name = "PRIVATE TSD COIN";
    string public symbol = "PVTSD";
    uint256 public minPurchase = 5000000; // 50,000.00 USD in cents

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    constructor(
        uint256 _ethExchangeRate
    ) public {
        // Set Total Supply
        totalSupply = 144 * million;

        tokenFundsWallet = owner;

        // transfer suppy to the tokenFundsWallet
        balances[tokenFundsWallet] = totalSupply;
        emit Transfer(0x0, tokenFundsWallet, totalSupply);

        // set up the exchangeRate
        updateTheExchangeRate(_ethExchangeRate);

        startTime = 1528984800000;
        endTime = 1531576800000;
        // Token release date 9 months post end date
        tokensReleaseDate = 1555250400000;
    }

    // Buy functions
    // This is an un-named fallback function that is set to payable to accept ether.
    function() payable public {
        buyTokens();
    }

    function buyTokens() payable public {
        uint256 _currentTime = currentTime();
        uint256 _minPurchaseInWei = minPurchase.mul(decimalMultiplier).div(ethExchangeRate);
        require(tokensAvailable, "no more tokens available");
        require(_currentTime >= startTime && _currentTime <= endTime, "current time is not in the purchase window frame");
        require(whiteListed[msg.sender], "user is not whitelisted");
        require(msg.value >= _minPurchaseInWei, "amount sent is below minimum purchase");

        // ETH received by spender
        uint256 ethAmount = msg.value;
        // token amount based on ETH / exchangeRate result
        // exchange rate is 1 TSD => x ETH
        // with a 30% discount attached
        uint256 discountedExchangeRate = exchangeRate.mul(70).div(100);
        // totalTokenAmount is the total tokens offered including the discount
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.mul(decimalMultiplier).div(discountedExchangeRate);
        // tokens avaialble to sell are the remaining tokens in the tokenFundsWallet
        uint256 availableTokens = balances[tokenFundsWallet];
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        uint256 unavailableTokens;

        if (totalTokenAmount > availableTokens) {
            // additional tokens that aren't avaialble to be sold
            // tokenAmount is the tokens requested by buyer (not including the discount)
            // availableTokens are all the tokens left in the supplying wallet i.e tokenFundsWallet
            unavailableTokens = totalTokenAmount.sub(availableTokens);

            // determine the unused ether amount by seeing how many tokens were surplus
            // i.e 'availableTokens' and reverse calculating their ETH equivalent
            // divide by decimalMultiplier as unavailableTokens are 10^18
            ethRefund = unavailableTokens.mul(discountedExchangeRate).div(decimalMultiplier);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // will equal to 0 after these substractions occur
            balances[tokenFundsWallet] = balances[tokenFundsWallet].sub(availableTokens);

            // adding the buyer to the icoParticipants ONLY if they haven't already bought before
            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }

            // add total tokens to the senders balances and Emit transfer event
            balances[msg.sender] = balances[msg.sender].add(availableTokens);
            emit Transfer(tokenFundsWallet, msg.sender, availableTokens);

            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            tokenFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            // close token sale as tokens are sold out
            tokensAvailable = false;
        } else {
            require(totalTokenAmount <= availableTokens, "totalTokenAmount is greater than availableTokens");

            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }

            // complete transfer and emit an event
            balances[tokenFundsWallet] = balances[tokenFundsWallet].sub(totalTokenAmount);
            balances[msg.sender] = balances[msg.sender].add(totalTokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            tokenFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit Transfer(tokenFundsWallet, msg.sender, totalTokenAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    // After close functions

   // Burn any remaining tokens
    function burnRemainingTokens() external onlyOwner returns (bool) {
        require(currentTime() >= endTime, "can only burn tokens after token sale has concluded");
        if (balances[tokenFundsWallet] > 0) {
            // Subtracting the unsold tokens from the total supply.
            uint256 oldSupply = totalSupply;
            totalSupply = totalSupply.sub(balances[tokenFundsWallet]);
            balances[tokenFundsWallet] = 0;
            emit UpdatedTotalSupply(oldSupply, totalSupply);
        }

        return true;
    }

    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the pvtSaleTokenWallet
    // This wallet will need to be approved in the main contract to make these distributions
    // _numberOfTransfers states the number of transfers that can happen at one time
    function distributeTokens(uint256 _numberOfTransfers) external onlyRestricted returns (bool) {
        require(currentTime() >= tokensReleaseDate, "can only distribute after tokensReleaseDate");
        address pvtSaleTokenWallet = dc.pvtSaleTokenWallet();
        uint256 finalDistributionIndex = currentDistributionIndex.add(_numberOfTransfers);

        for (uint256 i = currentDistributionIndex; i < finalDistributionIndex; i++) {
            // end for loop when currentDistributionIndex reaches the length of the icoParticipants array
            if (i == icoParticipants.length) {
                emit FinalDistributionToTSDContract(address(this), TSDContractAddress);
                finalDistributionIndex = i;
                break;
            }
            // skip transfer if balances are empty
            if (balances[icoParticipants[i]] != 0) {
                dc.transferFrom(pvtSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
                emit Transfer(pvtSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);

                // set balances to 0 to prevent re-transfer
                balances[icoParticipants[i]] = 0;
            }
        }

        // Event to say distribution is complete
        emit DistributedBalancesToTSDContract(address(this), TSDContractAddress, currentDistributionIndex, finalDistributionIndex);

        // after distribution is complete set the currentDistributionIndex to the latest finalDistributionIndex
        currentDistributionIndex = finalDistributionIndex;

        // Boolean is returned to give us a success state.
        return true;
    }
}
