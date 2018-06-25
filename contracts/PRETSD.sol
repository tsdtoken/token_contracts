pragma solidity ^0.4.23;

import "./FoundationContracts/Ownable.sol";
import "./FoundationContracts/Math.sol";
import "./TSD.sol";

contract PRETSD is Ownable {
    using SafeMath for uint256;
    using Math for uint256;
    // set up access to main contract for the future distribution
    TSD dc;
    // when the connection is set to the main contract, save a reference for event purposes
    address public TSDContractAddress;
    address private oracleAddress;

    string public name = "PRE TSD COIN";
    string public symbol = "PRETSD";
    uint256 public decimals = 18;
     // Helper value from 1 million and 1 thousand
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    uint256 public million = 1000000 * decimalMultiplier;
    uint256 public totalSupply = 165 * million;
    uint256 public minPurchase = 500000; // 5,000.00 USD in cents
    uint256 public exchangeRate;
    uint256 public ethExchangeRate;
    uint256 public tokenPrice = 50; // 50 cents (USD)
    uint256 public totalEthRaised = 0;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time "Wed Aug 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1533045600000).toUTCString() => "Tue, 31 Jul 2018 14:00:00 GMT"
    uint256 public startTime = 1533045600000;
    // Start time "Tue Aug 21 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1534860000000).toUTCString() => "Tue, 21 Aug 2018 14:00:00 GMT"
    uint256 public endTime = 1534860000000;
    // Token release date 12 month post end date
    // "Thu Aug 01 2019 00:00:00 GMT+1000 (AEST)"
    // new Date(1564581600000).toUTCString() => "Wed, 31 Jul 2019 14:00:00 GMT"
    uint256 public tokensReleaseDate = 1564581600000;

    // Wallets
    address public preFundsWallet;

    // Array of participants used when distributing tokens to main contract
    address[] public icoParticipants;

    // whitelisted addresses
    mapping (address => bool) public whiteListed;

    // balances
    mapping(address => uint256) balances;

    // tranche discounts
    uint16[4] tranches = [800, 840, 880, 925];
    // tranche token size
    uint256 trancheMaxTokenSize = totalSupply.div(tranches.length);

    // When all tokens are sold this value will be set to false
    bool public tokensAvailable = true;

    // current distribution Index
    uint32 public currentDistributionIndex = 0;

    // Events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExchangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event DistributedAllBalancesToTSDContract(address _presd, address _tsd);
    event Transfer(address from, address to, uint256 value);
    event UpdatedTotalSupply(uint256 oldSupply, uint256 newSupply);

    constructor(
        uint256 _ethExchangeRate
    ) public {
        preFundsWallet = owner;

        // transfer suppy to the funds wallet
        balances[preFundsWallet] = totalSupply;
        emit Transfer(0x0, preFundsWallet, totalSupply);

        // set exchange rate
        updateTheExchangeRate(_ethExchangeRate);
    }

    // Contract utility functions
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }

    // Checks the balance of the address. ERC20 standard.
    function balanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }

    // Called externally to create whitelist for  sale.
    // Only whitelisted addresses can participate in the ico.
    function createWhiteListedMapping(address[] _addresses) external onlyRestricted {
        for (uint64 i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }

    // Called externally to change the address of the oracle.
    // The oracle updates the exchange rate based on the current ETH value.
    function changeOracleAddress(address _newAddress) external onlyOwner {
        oracleAddress = _newAddress;
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

     // Updates the ETH => TSD exchange rate
     // The exchange rate is in USD cents to ETH.
     // Example: 1 ETH = 500 USD then enter 50000 as the param.
    function updateTheExchangeRate(uint256 _newRate) public onlyRestricted returns (bool) {
        ethExchangeRate = _newRate;
        uint256 currentRate = exchangeRate;
        uint256 oneSzabo = 1 szabo;
        uint256 tokenPriceInSzabo = tokenPrice.mul(1000000).div(_newRate);
        // The exchangerate is saved in Szabo.
        exchangeRate = oneSzabo.mul(tokenPriceInSzabo);
        emit ExchangeRateUpdated(currentRate, exchangeRate);
        return true;
    }

    // Can check to see if an address is whitelisted
    function isWhiteListed(address _address) external view returns (bool) {
        return whiteListed[_address];
    }

    // Buy functions
    // This is an un-named fallback function that is set to payable to accept ether.
    function() payable public {
        buyTokens();
    }

    function buyTokens() payable public {
        uint256 _currentTime = currentTime();
        uint256 _minPurchaseInWei = minPurchase.mul(decimalMultiplier).div(ethExchangeRate);
        require(tokensAvailable);
        require(_currentTime >= startTime && _currentTime <= endTime);
        require(whiteListed[msg.sender]);
        require(msg.value >= _minPurchaseInWei);

        uint256 ethAmount = msg.value;
        uint256 tokenAmount = calculateTokenAmountWithDiscounts(ethAmount);
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;


        // The tranching algorithm will only ever return a value equal or lower than the remainingTokens.
        // If the tokenAmount is equal to the remaining tokens we know its the last purchase.
        if (tokenAmount == balances[preFundsWallet]) {
            // recalculate the amount of eth that can be spent for the remaining tokens.
            uint256 totalRemainingCostOfTokens = calculateTotalRemainingTokenCost();
            // determine the refund by subtracting the the new ethamount from what was originally sent in
            ethRefund = ethAmount.sub(totalRemainingCostOfTokens);
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // sub general token amount
            uint256 remainingTokens = balances[preFundsWallet];
            balances[preFundsWallet] = balances[preFundsWallet].sub(remainingTokens);
            // sub bonus token amoutn
            balances[msg.sender] = balances[msg.sender].add(remainingTokens);
            emit Transfer(preFundsWallet, msg.sender, remainingTokens);
            // adding the buyer to the icoParticipants ONLY if they haven't already bought before
            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }
            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            preFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            // close token sale as tokens are sold out
            tokensAvailable = false;
        } else {
            // make the token purchase
            // sub general token amount
            balances[preFundsWallet] = balances[preFundsWallet].sub(tokenAmount);
            balances[msg.sender] = balances[msg.sender].add(tokenAmount);
            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }
            emit Transfer(preFundsWallet, msg.sender, tokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            preFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    function calculateTotalRemainingTokenCost() public view returns(uint256) {
        uint256 totalCost = 0;
        uint256 sold = totalSupply.sub(balances[preFundsWallet]);
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
        uint256 sold = totalSupply.sub(balances[preFundsWallet]);

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

    // After close functions

    // Create an instance of the main contract
    function setMainContractAddress(address _t) external onlyOwner {
        dc = TSD(_t);
        TSDContractAddress = _t;
    }

    // Burn any remaining tokens
    function burnRemainingTokens() external onlyOwner returns (bool) {
        require(currentTime() >= endTime);
        if (balances[preFundsWallet] > 0) {
            // Subtracting the unsold tokens from the total supply.
            uint256 oldSupply = totalSupply;
            totalSupply = totalSupply.sub(balances[preFundsWallet]);
            balances[preFundsWallet] = 0;
            emit UpdatedTotalSupply(oldSupply, totalSupply);
        }

        return true;
    }

    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the preSaleTokenWallet
    // This wallet will need to be approved in the main contract to make these distributions
    function distributeTokens(uint32 _numberOfTransfers) external onlyOwner returns (bool) {
        require(currentTime() >= tokensReleaseDate);
        address preSaleTokenWallet = dc.preSaleTokenWallet();
        uint32 finalDistributionIndex = currentDistributionIndex.add(_numberOfTransfers);

        for (uint32 i = currentDistributionIndex; i < finalDistributionIndex; i++) {
            // end for loop when currentDistributionIndex reaches the length of the icoParticipants array
            if (i == icoParticipants.length) {
                return;
            }
            // skip transfer if balances are empty
            if (balances[icoParticipants[i]] != 0) {
                dc.transferFrom(preSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
                emit Transfer(preSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
                
                // set balances to 0 to prevent re-transfer
                balances[icoParticipants[i]] = 0;
            }
        }
        // after distribution is complete set the currentDistributionIndex to the latest finalDistributionIndex
        currentDistributionIndex = finalDistributionIndex;

        // Event to say distribution is complete
        emit DistributedAllBalancesToTSDContract(address(this), TSDContractAddress);

        // Boolean is returned to give us a success state.
        return true;
    }

    // sets start and end times
    function setStartTime(uint256 _startTime) external onlyOwner returns (bool) {
        // ensure the start time is before the end time
        require(_startTime < endTime);
        startTime = _startTime;
        return true;
    }

    function setEndTime(uint256 _endTime) external onlyOwner returns (bool) {
        // ensure the end time is after the start time
        // and that is after the current time
        require(_endTime > startTime && _endTime > currentTime());
        endTime = _endTime;
        return true;
    }

    // Destroys the contract
    function selfDestruct() external onlyOwner {
        selfdestruct(owner);
    }

    modifier onlyRestricted () {
        require(msg.sender == owner || msg.sender == oracleAddress);
        _;
    }

}
