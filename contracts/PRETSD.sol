pragma solidity ^0.4.23;

import "./FoundationContracts/BaseToken.sol";
import "./FoundationContracts/Ownable.sol";
import "./TSD.sol";

contract PRETSD is BaseToken, Ownable {
    // set up access to main contract for the future distribution
    TSD dc;
    // tranche return values struct.
    // used when evaluating the discounts for sales
    struct TrancheState {
        uint256 tokens;
        uint256 eth;
    }

    // when the connection is set to the main contract, save a reference for event purposes
    address public TSDContractAddress;

    string public name = "PRE TSD COIN";
    string public symbol = "PRETSD";
    uint256 public decimals = 18;
     // Helper value from 1 million and 1 thousand
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    uint256 public million = 1000000 * decimalMultiplier;
    uint256 public totalSupply = 165 * million;
    uint256 public minPurchase = 5 ether;
    uint256 public exchangeRate;
    uint256 public totalEthRaised = 0;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time "Wed Aug 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1533045600000).toUTCString() => "Tue, 31 Jul 2018 14:00:00 GMT"
    uint256 public startTime = 1533045600000;
    // Start time "Wed Aug 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1534860000000).toUTCString() => "Tue, 21 Aug 2018 14:00:00 GMT"
    uint256 public endTime = 1534860000000;
    // Token release date 12 month post end date
    // "Thu Aug 01 2019 00:00:00 GMT+1000 (AEST)"
    // new Date(1564581600000).toUTCString() => "Wed, 31 Jul 2019 14:00:00 GMT"
    uint256 public tokensReleaseDate = 1564581600000;

    // Wallets
    address public preFundsWallet;
    address public preSaleBonusWallet;
    
    // Array of participants used when distributing tokens to main contract
    address[] public icoParticipants;
    
    // whitelisted addresses
    mapping (address => bool) public whiteListed;

    // tranche discounts
    uint8[4] tranches = [80, 85, 90, 95];

    // ico concluded
    bool icoOpen = true;

    // Events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event DistributedAllBalancesToTSDContract(address _presd, address _tsd);
    
    constructor(
        uint256 _exchangeRate,
        address[] _whitelistAddresses
    ) public {
        preFundsWallet = owner;
        exchangeRate = _exchangeRate;
        
        // transfer suppy to the funds wallet
        balances[preFundsWallet] = totalSupply;
        emit Transfer(0x0, preFundsWallet, totalSupply);

        // set up the white listing mapping
        createWhiteListedMapping(_whitelistAddresses);
    }

    // Contract utility functions
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }
    
    function createWhiteListedMapping(address[] _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }

     // Updates the ETH => TSD exchange rate
    function updateTheExchangeRate(uint256 _newRate) public onlyOwner returns (bool) {
        uint256 currentRate = exchangeRate;
        // 0.000001 ETHER
        uint256 oneSzabo = 1 szabo;
        // 0.00001 ETH OTHERWISE 0.000001
        exchangeRate = (oneSzabo).mul(_newRate);
        emit ExhangeRateUpdated(currentRate, _newRate);
        return true;
    }

    function isWhiteListed(address _address) public view returns (bool) {
        if (whiteListed[_address]) {
            return true;
        } else {
            return false;
        }
    }

    // Buy functions

    function() payable public {
        buyTokens();
    }
    
    function buyTokens() payable public {
        require(icoOpen);
        require(currentTime() >= startTime && currentTime() <= endTime);
        require(whiteListed[msg.sender]);
        uint256 ethAmount = msg.value;
        uint256 tokenAmount = calculateTokenAmountWithDiscounts(ethAmount);
        uint256 availableTokens;
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        
        
        if (tokenAmount > balances[preFundsWallet]) {
            // recalculate the amount of eth that can be spent
            uint256 totalCostOfTokens = (totalSupply / 4 * tranches[0] + totalSupply / 4 * tranches[1] + totalSupply / 4 * tranches[2] + totalSupply / 4 * tranches[3]) * exchangeRate;
            // this eth amount is what we will take for the remaining tokens
            ethAmount = totalCostOfTokens.sub(totalEthRaised);
            // determine the refund by subtracting the the new ethamount from what was originally sent in
            ethRefund = msg.value.sub(ethAmount);
            // make the token purchase
            // sub general token amount
            uint256 remainingTokens = balances[preFundsWallet];
            balances[preFundsWallet] = balances[preFundsWallet].sub(remainingTokens);
            // sub bonus token amoutn
            balances[msg.sender] = balances[msg.sender].add(remainingTokens);
            emit Transfer(preFundsWallet, msg.sender, remainingTokens);
            icoParticipants.push(msg.sender);
            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            preFundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        } else {
            require(balances[preFundsWallet] >= tokenAmount);
            // make the token purchase
            // sub general token amount
            balances[preFundsWallet] = balances[preFundsWallet].sub(tokenAmount);
            balances[msg.sender] = balances[msg.sender].add(tokenAmount);
            icoParticipants.push(msg.sender);
            emit Transfer(preFundsWallet, msg.sender, tokenAmount);
            
            // transfer ether to the wallet and emit and event regarding eth raised
            preFundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);  
        // }
    }

    function calculateTokenAmountWithDiscounts(uint256 _ethAmount) private view returns(uint256) {
        uint256 returnTokens = 0;
        uint256 remainingEth = _ethAmount;
        uint256 sold = totalSupply.sub(balances[preFundsWallet]);
        TrancheState memory result;
        
        // First Trench
        if (sold + returnTokens < totalSupply / 4) {
            result = calculateAndSubtractTranches(remainingEth, returnTokens, 0);
            returnTokens += result.tokens;
            remainingEth = result.eth;
            if (remainingEth == 0) return returnTokens;
        }
        // Second Trench
        if (sold+returnTokens < 2 * totalSupply / 4){
            result = calculateAndSubtractTranches(remainingEth, returnTokens, 1);
            returnTokens += result.tokens;
            remainingEth = result.eth;
            if (remainingEth == 0) return returnTokens;
        } 
        
        // Third Trench
        if (sold+returnTokens < 3 * totalSupply / 4){
            result = calculateAndSubtractTranches(remainingEth, returnTokens, 2);
            returnTokens += result.tokens;
            remainingEth = result.eth;
            if (remainingEth == 0) return returnTokens;
        }
        
        // Fourth Trench
        result = calculateAndSubtractTranches(remainingEth, returnTokens, 3);
        returnTokens += result.tokens;
        remainingEth = result.eth;
        if (remainingEth == 0) return returnTokens;
    }

    function calculateAndSubtractTranches(uint256 _eth, uint256 _tokens, uint8 _index) internal view returns (TrancheState) {
        uint256 trancheRemainder = totalSupply / 4 * (_index+1) - sold + _tokens;
        uint256 trancheBuyingPower = (_eth * 100) / tranches[_index] * exchangeRate;
        
        if (trancheRemainder >= trancheBuyingPower) {
            return TrancheState(trancheBuyingPower, 0);
        } else {
            uint256 newEthAmount = _eth - (trancheRemainder / 100 * tranches[_index]) / exchangeRate;  
            return TrancheState(trancheRemainder, newEthAmount);
        }
    }

    // After close functions

    // Create an instance of the main contract
    function setMainContractAddress(address _t) onlyOwner public {
        dc = TSD(_t);
        TSDContractAddress = _t;
    }

    // Burn any remaining tokens 
    function burnRemainingTokens() public onlyOwner returns (bool) {
        require(currentTime() >= endTime);
        if (balances[preFundsWallet] > 0) {
            balances[preFundsWallet] = 0;
        }

        return true;
    }
    
    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the preSaleTokenWallet
    // This wallet will need to be approved in the main contract to make these distributions
    
    function distrubuteTokens() onlyOwner public {
        require(currentTime() >= tokensReleaseDate);
        address preSaleTokenWallet = dc.preSaleTokenWallet();
        address mainContractFundsWallet = dc.fundsWallet();
        for (uint8 i = 0; i < icoParticipants.length; i++) {
            dc.transferFrom(preSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
            emit Transfer(preSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
        }

        if (dc.balanceOf(preSaleTokenWallet) > 0) {
            uint256 remainingBalace = dc.balanceOf(preSaleTokenWallet);
            dc.transferFrom(preSaleTokenWallet, mainContractFundsWallet, remainingBalace);
            emit Transfer(preSaleTokenWallet, mainContractFundsWallet, remainingBalace);
        }
        // Event to say distribution is complete
        emit DistributedAllBalancesToTSDContract(address(this), TSDContractAddress);
    }
    
}