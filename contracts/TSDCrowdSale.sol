pragma solidity ^0.4.23;

import "./FoundationContracts/BaseCrowdsaleContract.sol";

contract TSDCrowdSale is BaseCrowdsaleContract {

    uint256 public minPurchase = 50000; // 500.00 USD in cents

    // Wallets
    address public fundsWallet;

    // events
    event IncreaseTotalSupply(uint256 additionalSupply);

    constructor(
        uint256 _ethExchangeRate,
        address _fundsWallet
    ) public {
        // set up the exchangeRate and ethExchangeRate
        updateTheExchangeRate(_ethExchangeRate);
        // allocate fundsWallet
        fundsWallet = _fundsWallet;

        // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

        // Start time "Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)"
        // new Date(1535724000000).toUTCString() => "Fri, 31 Aug 2018 14:00:00 GMT"
        startTime = 1535724000000;
        // End time "Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)"
        // new Date(1538316000000).toUTCString() => "Sun, 30 Sep 2018 14:00:00 GMT"
        endTime = 1538316000000;
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
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.mul(decimalMultiplier).div(exchangeRate);
        // tokens avaialble to sell are the remaining tokens in the pvtFundsWallet
        uint256 availableTokens = dc.balanceOf(fundsWallet);
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        uint256 unavailableTokens;

        if (totalTokenAmount > availableTokens) {
            // additional tokens that aren't avaialble to be sold
            // tokenAmount is the tokens requested by buyer (not including the discount)
            // availableTokens are all the tokens left in the supplying wallet i.e pvtFundsWallet
            unavailableTokens = totalTokenAmount.sub(availableTokens);

            // determine the unused ether amount by seeing how many tokens were surplus
            // i.e 'availableTokens' and reverse calculating their ETH equivalent
            // divide by decimalMultiplier as unavailableTokens are 10^18
            ethRefund = unavailableTokens.mul(exchangeRate).div(decimalMultiplier);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // will equal to 0 after these substractions occur
            dc.safeTransferFrom(fundsWallet, msg.sender, availableTokens);
            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            fundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            // close token sale as tokens are sold out
            tokensAvailable = false;
        } else {
            require(totalTokenAmount <= availableTokens, "totalTokenAmount is greater than availableTokens");
            // complete a safeTransfer and emit an event
            dc.safeTransferFrom(fundsWallet, msg.sender, totalTokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            fundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }
}