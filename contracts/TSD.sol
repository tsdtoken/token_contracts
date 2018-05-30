pragma solidity ^0.4.23;

import "./FoundationContracts/BaseToken.sol";
import "./FoundationContracts/Ownable.sol";

contract TSD is BaseToken, Ownable {
    string public name = "TSD COIN";
    string public symbol = "TSD";
    uint256 public decimals = 18;

    // Helper value from 1 million and 1 thousand
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    uint256 public million = 1000000 * decimalMultiplier;
    uint256 public thousand = 1000 * decimalMultiplier;

    // Allocations
    uint256 public totalSupply = 550 * million;
    uint256 public pvtSaleSupply = 55 * million;
    uint256 public preSaleSupply = 65 * million;
    uint256 public foundersAndAdvisorsAllocation = 44 * million;
    uint256 public bountyCommunityIncentivesAllocation = (16 * million).add(500 * thousand);
    uint256 public liquidityProgramAllocation = (16 * million).add(500 * thousand);
    uint256 public minimumPurchase = 0.01 ether;
    // 1 TSD = x ETH
    // Unit convertsions https://github.com/ethereum/web3.js/blob/0.15.0/lib/utils/utils.js#L40
    uint256 public exchangeRate;
    uint256 public totalEthRaised = 0;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time "Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1535724000000).toUTCString() => "Fri, 31 Aug 2018 14:00:00 GMT"
    uint256 public startTime = 1535724000000;
    // End time "Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1538316000000).toUTCString() => "Sun, 30 Sep 2018 14:00:00 GMT"
    uint256 public endTime = 1538316000000;

    // Wallets
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;

    // Addresses for services and founders
    address public foundersAndAdvisors;
    address public bountyCommunityIncentives;
    address public liquidityProgram;
    
    // whitelisted addresses
    mapping (address => bool) public whiteListed;

    // ico concluded due to all tokens sold
    bool public icoOpen = true;
    
    // events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event Debugger(string variable, uint256 value);
    
    constructor(
        uint256 _exchangeRate,
        address[] _whitelistAddresses,
        address _pvtSaleTokenWallet,
        address _preSaleTokenWallet,
        address _foundersAndAdvisors,
        address _bountyCommunityIncentives,
        address _liquidityProgram
    ) public {
        fundsWallet = owner;
        pvtSaleTokenWallet = _pvtSaleTokenWallet;
        preSaleTokenWallet = _preSaleTokenWallet;
        exchangeRate = _exchangeRate;
        foundersAndAdvisors = _foundersAndAdvisors;
        bountyCommunityIncentives = _bountyCommunityIncentives;
        liquidityProgram = _liquidityProgram;
        
        // transfer suppy to the funds wallet
        balances[fundsWallet] = totalSupply;
        emit Transfer(0x0, fundsWallet, totalSupply);
        
        // transfer tokens to account for the private sale
        balances[fundsWallet] = balances[fundsWallet].sub(pvtSaleSupply);
        balances[pvtSaleTokenWallet] = balances[pvtSaleTokenWallet].add(pvtSaleSupply);
        emit Transfer(fundsWallet, pvtSaleTokenWallet, pvtSaleSupply);
        
        // transfer tokens to account for the pre sale
        balances[fundsWallet] = balances[fundsWallet].sub(preSaleSupply);
        balances[preSaleTokenWallet] = balances[preSaleTokenWallet].add(preSaleSupply);
        emit Transfer(fundsWallet, preSaleTokenWallet, preSaleSupply);

        // transfer tokens to founders account
        balances[fundsWallet] = balances[fundsWallet].sub(foundersAndAdvisorsAllocation);
        balances[foundersAndAdvisors] = balances[foundersAndAdvisors].add(foundersAndAdvisorsAllocation);
        emit Transfer(fundsWallet, foundersAndAdvisors, foundersAndAdvisorsAllocation);

        // transfer tokens to bounty and community incentives account
        balances[fundsWallet] = balances[fundsWallet].sub(bountyCommunityIncentivesAllocation);
        balances[bountyCommunityIncentives] = balances[bountyCommunityIncentives].add(bountyCommunityIncentivesAllocation);
        emit Transfer(fundsWallet, bountyCommunityIncentives, bountyCommunityIncentivesAllocation);

        // transfer tokens to the liquidity program account
        balances[fundsWallet] = balances[fundsWallet].sub(liquidityProgramAllocation);
        balances[liquidityProgram] = balances[liquidityProgram].add(liquidityProgramAllocation);
        emit Transfer(fundsWallet, liquidityProgram, liquidityProgramAllocation);
        
        // Set up the list of whitelisted addresses
        createWhiteListedMapping(_whitelistAddresses);

        // set up the exchangeRate
        updateTheExchangeRate(_exchangeRate);
    }
    
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }

    // Utility functions 
    
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
        require(currentTime() >= startTime && currentTime() <= endTime);
        require(msg.value >= minimumPurchase);
        require(whiteListed[msg.sender]);
        uint256 ethAmount = msg.value;
        uint256 tokenAmount = msg.value.mul(exchangeRate);
        uint256 availableTokens;
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        
        
        if (tokenAmount > balances[fundsWallet]) {
            // subtract the remaining bal from the original token amount
            availableTokens = tokenAmount.sub(balances[fundsWallet]);
            // determine the unused ether amount by seeing how many tokens where
            // unavailable and dividing by the exchange rate
            ethRefund = tokenAmount.sub(availableTokens).div(exchangeRate);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            balances[fundsWallet] = balances[fundsWallet].sub(availableTokens);
            balances[msg.sender] = balances[msg.sender].add(availableTokens);
            emit Transfer(fundsWallet, msg.sender, tokenAmount);

            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }

            // transfer ether to funds wallet
            fundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        } else {
            require(balances[fundsWallet] >= tokenAmount);
            balances[fundsWallet] = balances[fundsWallet].sub(tokenAmount);
            balances[msg.sender] = balances[msg.sender].add(tokenAmount);
            emit Transfer(fundsWallet, msg.sender, tokenAmount);
            
            fundsWallet.transfer(msg.value);
            totalEthRaised.add(msg.value);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    // After close
    function burnRemainingTokensAfterClose() public onlyOwner returns (bool) {
        require(currentTime() >= endTime);
        if (balances[fundsWallet] > 0) {
            // burn unsold tokens
            balances[fundsWallet] = 0;
        }

        return true;
    }
    
    // Subsequent supply functions
    function increaseTotalSupplyAndAllocateTokens(address _newTokensWallet, uint256 _amount) onlyOwner public {
        totalSupply = totalSupply + _amount;
        balances[_newTokensWallet] = _amount;
    }
    
    function increaseEthRaisedBySubsequentSale(uint256 _amount) public {
        uint256 newEthAmount = totalEthRaised + _amount;
        emit EthRaisedUpdated(totalEthRaised, newEthAmount);
    }
    
    // ERC20 function wrappers
    function transfer(address _to, uint256 _tokens) public returns (bool) {
        require(currentTime() >= endTime);
        return super.transfer(_to, _tokens);
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(currentTime() >= endTime);
        return super.transferFrom(_from, _to, _value);
    }
}