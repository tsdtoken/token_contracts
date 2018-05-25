pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "openzeppelin-solidity/contracts/math/Math.sol";
import "./TSD.sol";

contract PRETSD is StandardToken, Ownable {
    using SafeMath for uint256;
    // set up access to main contract for the future distribution
    TSD dc;
    // when the connection is set to the main contract, save a reference for event purposes
    address public TSDContractAddress;

    string public name = "PRE TSD COIN";
    string public symbol = "PRETSD";
    uint256 public decimals = 18;
     // Helper value from 1 million and 1 thousand
    uint256 public million = 1000000 * (uint256(10) ** decimals);
    uint256 public thousand = 1000 * (uint256(10) ** decimals);

    uint256 public totalSupply = 165 * million;
    uint256 public bonusAllocation = (20 * million).add(625 * thousand);
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
    
    // token balances
    mapping (address => uint256) public balances;
    
    // Events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event DistributedAllBalancesToTSDContract(address _presd, address _tsd);
    
    constructor(
        uint256 _exchangeRate,
        address[] _whitelistAddresses,
        address _preSaleBonusWallet
    ) public {
        preFundsWallet = owner;
        exchangeRate = _exchangeRate;
        preSaleBonusWallet = _preSaleBonusWallet;
        
        // transfer suppy to the funds wallet
        balances[preFundsWallet] = totalSupply;
        emit Transfer(0x0, preFundsWallet, totalSupply);

        // transfer bonus allocations
        // transfer event emited by inherited transfer function
        // transfer(preSaleBonusWallet, bonusAllocation);
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
        exchangeRate = _newRate;
        emit ExhangeRateUpdated(currentRate, _newRate);
    }

    function isWhiteListed(address _address) public view returns (bool) {
        if (whiteListed[_address]) {
            return true;
        } else {
            return false;
        }
    }

    function removeFromWhiteList(address _address) public onlyOwner returns (bool) {
        if (whiteListed[_address]) {
            whiteListed[_address] = false;

            return true;
        }
    }

    // Buy functions

    function() payable public {
        buyTokens();
    }
    
    function buyTokens() payable public {
        require(currentTime() >= startTime && currentTime() <= endTime);
        require(whiteListed[msg.sender]);
        uint256 ethAmount = msg.value;
        uint256 tokenAmount = msg.value.mul(exchangeRate);
        uint256 bonusAmount = calculateBonus(tokenAmount);
        uint256 availableTokens;
        uint256 finalTokenAmount;
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        
        
        if (tokenAmount > balances[preFundsWallet]) {
            // subtract the remaining bal from the original token amount
            availableTokens = tokenAmount.sub(balances[preFundsWallet]);
            // calculate new bonus amount
            bonusAmount = calculateBonus(availableTokens);
            // calculate the final token sale amount
            finalTokenAmount = availableTokens.add(bonusAmount);
            // determine the unused ether amount by seeing how many tokens where
            // unavailable and dividing by the exchange rate
            ethRefund = tokenAmount.sub(availableTokens).div(exchangeRate);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // sub general token amount
            balances[preFundsWallet] = balances[preFundsWallet].sub(availableTokens);
            // sub bonus token amoutn
            balances[preSaleBonusWallet] = balances[preSaleBonusWallet].sub(bonusAmount);
            balances[msg.sender] = balances[msg.sender].add(finalTokenAmount);
            emit Transfer(preFundsWallet, msg.sender, finalTokenAmount);
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
            // calculate the final token sale amount
            finalTokenAmount = tokenAmount.add(bonusAmount);
            // make the token purchase
            // sub general token amount
            balances[preFundsWallet] = balances[preFundsWallet].sub(tokenAmount);
            // sub bonus token amoutn
            balances[preSaleBonusWallet] = balances[preSaleBonusWallet].sub(bonusAmount);
            balances[msg.sender] = balances[msg.sender].add(finalTokenAmount);
            icoParticipants.push(msg.sender);
            emit Transfer(preFundsWallet, msg.sender, finalTokenAmount);
            
            // transfer ether to the wallet and emit and event regarding eth raised
            preFundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);  
        }
    }

    function calculateBonus(uint256 _tokenAmount) public view returns (uint256) {
        uint8 bonusStage = 4;
        // Tranche rounds are 20%, 15%, 10%, 5%
        uint8[4] memory bonusRewards = [20, 15, 10, 5];
        uint256 bonusAmount = 0;
        uint256 trancheSize = totalSupply.div(4);
        uint256 sold = totalSupply.sub(balances[preFundsWallet]);

        // Calculate the bucket index based on amount of tokens sold
        if (sold < trancheSize) {
            bonusStage = 1;
        } else {
            if (sold < trancheSize.mul(2)) {
                bonusStage = 2;
            } else {
                if (sold < trancheSize.mul(3)) {
                    bonusStage = 3;
                }
            }
        }

        // Begin building the bonus
        // Accounting for zero indexed array re: 
        // if the bonus stage is 1 then the referene will be [bonusStage - 1] to account for the zeroth index in the bonusRewards array
        // there are 4 bonus rounds
        // one call could potentially run through each
        // this function will potentially break out after determining the bonus for each bonus round

        // begin accumulating the bonus amounts for the requested token amount
        bonusAmount += (_tokenAmount < trancheSize ? _tokenAmount : trancheSize).mul(bonusRewards[bonusStage - 1]);
        
        // if the bonus amount didn't cross a bonus stage then return the bonus
        if (_tokenAmount < trancheSize || bonusStage == 4) return bonusAmount;
        // if it did cross a bonus round then subtract the tranche size amount from the amount of tokens requested
        _tokenAmount.sub(trancheSize);
        // increase the bonus round by 1
        bonusStage += 1;

        // with the remaining amount of tokens calculate the bonus allocation for this bonus stage
        // repeat sequence
        bonusAmount += (_tokenAmount < trancheSize ? _tokenAmount : trancheSize).mul(bonusRewards[bonusStage - 1]);
        if (_tokenAmount < trancheSize || bonusStage == 4) return bonusAmount;
        _tokenAmount.sub(trancheSize);
        bonusStage += 1;

        // Do the same again for the next bonus round
        bonusAmount += (_tokenAmount < trancheSize ? _tokenAmount : trancheSize).mul(bonusRewards[bonusStage - 1]);
        if (_tokenAmount < trancheSize || bonusStage == 4) return bonusAmount;
        _tokenAmount.sub(trancheSize);
        bonusStage += 1;

        bonusAmount += (_tokenAmount < trancheSize ? _tokenAmount : trancheSize).mul(bonusRewards[bonusStage - 1]);

        return bonusAmount;
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