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
        totalSupply = 625 * 100000 * decimalMultiplier;

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
}
