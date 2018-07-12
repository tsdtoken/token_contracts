pragma solidity ^0.4.23;

import "./FoundationContracts/SecondaryCrowdsaleContract.sol";
import "./FoundationContracts/Math.sol";

contract PRETSD is SecondaryCrowdsaleContract {
    using Math for uint256;

    string public name = "PRE TSD COIN";
    string public symbol = "PRETSD";
    uint256 public minPurchase = 500000; // 5,000.00 USD in cents

    // tranche discounts
    uint16[4] tranches = [800, 840, 880, 920];

    // tranche token size
    uint256 trancheMaxTokenSize;

    constructor(
        uint256 _ethExchangeRate
    ) public {
        // Set the Total Supply
        totalSupply = 240 * million;

        trancheMaxTokenSize = totalSupply.div(tranches.length);

        tokenFundsWallet = owner;

        // transfer suppy to the funds wallet
        balances[tokenFundsWallet] = totalSupply;
        emit Transfer(0x0, tokenFundsWallet, totalSupply);

        // set exchange rate
        updateTheExchangeRate(_ethExchangeRate);

        startTime = 1533045600000;
        endTime = 1534860000000;
        // Token release date 12 month post end date
        tokensReleaseDate = 1564581600000;
    }

    // Usage:
    // Pass in the amount of tokens and the discount rate.
    // If no discount is required pass in 100 as the rate value.
    function tokenToEth(uint256 _tokens, uint16 _discountRate) internal view returns(uint256) {
        //Using previous exchangerate
        return _tokens.mul(_discountRate).div(1000).mul(exchangeRate).div(decimalMultiplier);
    }


    // Pass in the amount of eth and the discount rate.
    // If no discount is required pass in 100 as the rate value.
    function ethToToken(uint256 _eth, uint16 _discountRate) internal view returns(uint256) {
        //return ((_eth / _rate * 100) * decimalMultiplier).div(exchangeRate);
        return _eth.mul(1000).div(_discountRate).mul(decimalMultiplier).div(exchangeRate);
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
        require(whiteListed[msg.sender], "amount sent is below minimum purchase");
        require(msg.value >= _minPurchaseInWei, "user is not whitelisted");

        uint256 ethAmount = msg.value;
        uint256 tokenAmount = calculateTokenAmountWithDiscounts(ethAmount);
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;


        // The tranching algorithm will only ever return a value equal or lower than the remainingTokens.
        // If the tokenAmount is equal to the remaining tokens we know its the last purchase.
        if (tokenAmount == balances[tokenFundsWallet]) {
            // recalculate the amount of eth that can be spent for the remaining tokens.
            uint256 totalRemainingCostOfTokens = calculateTotalRemainingTokenCost();
            // determine the refund by subtracting the the new ethamount from what was originally sent in
            ethRefund = ethAmount.sub(totalRemainingCostOfTokens);
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // sub general token amount
            uint256 remainingTokens = balances[tokenFundsWallet];
            balances[tokenFundsWallet] = balances[tokenFundsWallet].sub(remainingTokens);

            // adding the buyer to the icoParticipants ONLY if they haven't already bought before
            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }
            
            // sub bonus token amount
            balances[msg.sender] = balances[msg.sender].add(remainingTokens);
            emit Transfer(tokenFundsWallet, msg.sender, remainingTokens);
            
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
            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }
            // make the token purchase
            // sub general token amount
            balances[tokenFundsWallet] = balances[tokenFundsWallet].sub(tokenAmount);
            balances[msg.sender] = balances[msg.sender].add(tokenAmount);

            emit Transfer(tokenFundsWallet, msg.sender, tokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            tokenFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    function calculateTotalRemainingTokenCost() public view returns(uint256) {
        uint256 totalCost = 0;
        uint256 sold = totalSupply.sub(balances[tokenFundsWallet]);
        // Calculate the remaining tranche tokens.
        uint256 currentTrancheRemainder = totalSupply.sub(sold) % trancheMaxTokenSize;
        // On the first initialisation we need to set the current tranche to a full tranche;
        currentTrancheRemainder = currentTrancheRemainder == 0 ? trancheMaxTokenSize : currentTrancheRemainder;
        // Calculate the current tranche we are in.
        uint256 currentTranche = sold == 0 ? 0 : sold.sub(trancheMaxTokenSize.sub(currentTrancheRemainder)).div(trancheMaxTokenSize);
        // Check all tranches to see if they are full.
        // If they are full. Add the calculated tranche cost to the totalCost.
        if (currentTranche < 3) {
            totalCost = totalCost.add(tokenToEth(trancheMaxTokenSize, tranches[3]));
        }
        if (currentTranche < 2) {
            totalCost = totalCost.add(tokenToEth(trancheMaxTokenSize, tranches[2]));
        }
        if (currentTranche < 1) {
            totalCost = totalCost.add(tokenToEth(trancheMaxTokenSize, tranches[1]));
        }
        // Add the calculated tranche remainder costs to the totalCost.
        totalCost = totalCost.add(tokenToEth(currentTrancheRemainder, tranches[currentTranche]));
        return totalCost;
    }

    function calculateTokenAmountWithDiscounts(uint256 _ethAmount) public view returns(uint256) {
        uint256 returnTokens = 0;
        uint256 tokensFromTranche = 0;
        uint256 ethRemaining = _ethAmount;
        uint256 sold = totalSupply.sub(balances[tokenFundsWallet]);

        // Calculate the remaining tranche tokens.
        uint256 currentTrancheRemainder = totalSupply.sub(sold) % trancheMaxTokenSize;
        // On the first initialisation we need to set the current tranche to a full tranche;
        currentTrancheRemainder = currentTrancheRemainder == 0 ? trancheMaxTokenSize : currentTrancheRemainder;
        // Calculate the current tranche we are in.
        uint256 currentTranche = sold == 0 ? 0 : sold.sub(trancheMaxTokenSize.sub(currentTrancheRemainder)).div(trancheMaxTokenSize);

        // Find the first tranche that matches the current tranche.
        if (0 == currentTranche) {
            // Find the lowest value tokens of the current tranche.
            // Either return the total tranche tokens or the the tokens we can purchase with our ether.
            tokensFromTranche = Math.min256(currentTrancheRemainder, ethToToken(ethRemaining, tranches[currentTranche]));
            // Add the tokens to our return value.
            returnTokens = returnTokens.add(tokensFromTranche);
            // Subtract the ether we've spent on the tokens from the total ether we supplied.
            ethRemaining = ethRemaining.sub(tokenToEth(tokensFromTranche, tranches[currentTranche]));
            // Return the tokens if ether has reached 0;
            if (ethRemaining == 0) return returnTokens;
            // Otherwise set the next tranche remainder to a full tranche;
            currentTrancheRemainder = trancheMaxTokenSize;
            // Move us up one tranche.
            currentTranche = currentTranche.add(1);
        }
        if (1 == currentTranche) {
            tokensFromTranche = Math.min256(currentTrancheRemainder, ethToToken(ethRemaining, tranches[currentTranche]));
            returnTokens = returnTokens.add(tokensFromTranche);
            ethRemaining = ethRemaining.sub(tokenToEth(tokensFromTranche, tranches[currentTranche]));
            if (ethRemaining == 0) return returnTokens;
            currentTrancheRemainder = trancheMaxTokenSize;
            currentTranche = currentTranche.add(1);
        }
        if (2 == currentTranche) {
            tokensFromTranche = Math.min256(currentTrancheRemainder, ethToToken(ethRemaining, tranches[currentTranche]));
            returnTokens = returnTokens.add(tokensFromTranche);
            ethRemaining = ethRemaining.sub(tokenToEth(tokensFromTranche, tranches[currentTranche]));
            if (ethRemaining == 0) return returnTokens;
            currentTrancheRemainder = trancheMaxTokenSize;
            currentTranche = currentTranche.add(1);
        }
        if (3 == currentTranche) {
            tokensFromTranche = Math.min256(currentTrancheRemainder, ethToToken(ethRemaining, tranches[currentTranche]));
            returnTokens = returnTokens.add(tokensFromTranche);
            ethRemaining = ethRemaining.sub(tokenToEth(tokensFromTranche, tranches[currentTranche]));
        }
        return returnTokens;
    }
}
