pragma solidity ^0.4.23;

import "./FoundationContracts/BaseToken.sol";
import "./FoundationContracts/Ownable.sol";
import "./TSD.sol";

contract PVTSD is BaseToken, Ownable {
    using SafeMath for uint256;
    // set up access to main contract for the future distribution
    TSD dc;
    // when the connection is set to the main contract, save a reference for event purposes
    address public TSDContractAddress;
    
    string public name = "PRIVATE TSD COIN";
    string public symbol = "PVTSD";
    uint256 public decimals = 18;
    uint256 public million = 1000000 * (uint256(10) ** decimals);
    uint256 public totalSupply = 55 * million;
    uint256 public bonusAllocation = 22 * million;
    uint256 public minPurchase = 50 ether;
    // 1 ETH = exchangeRate TSD
    uint256 public exchangeRate;
    uint256 public totalEthRaised = 0;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time "Fri Jun 15 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1535724000000).toUTCString() => "Thu, 14 Jun 2018 14:00:00 GMT"
    uint256 public startTime = 1528984800000;
    // End time "Fri Jul 15 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1531576800000).toUTCString() => "Sat, 14 Jul 2018 14:00:00 GMT"
    uint256 public endTime = 1531576800000;
    // Token release date 9 months post end date
    // "Mon April 15 2019 00:00:00 GMT+1000 (AEST)"
    // new Date(1555250400000).toUTCString() => "Sun, 14 Apr 2019 14:00:00 GMT"
    uint256 public tokensReleaseDate = 1555250400000;

    // Wallets
    address public pvtFundsWallet;
    address public pvtBonusWallet;

    // Array of participants used when distributing tokens to main contract
    address[] public icoParticipants;
    
    // whitelisted addresses
    mapping (address => bool) public whiteListed;
    
    // token balances
    mapping (address => uint256) public balances;
    
    // Events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event DistributedAllBalancesToTSDContract(address _pvtsd, address _tsd);
    
    constructor(
        uint256 _exchangeRate,
        address _pvtBonusWallet,
        address[] _whitelistAddresses
    ) public {
        pvtFundsWallet = owner;
        pvtBonusWallet = _pvtBonusWallet;
        exchangeRate = _exchangeRate;

        // transfer suppy to the pvtFundsWallet
        balances[pvtFundsWallet] = totalSupply;
        emit Transfer(0x0, pvtFundsWallet, totalSupply);

        // transfer the bonus allocation to the pvtBonusWallet
        balances[pvtBonusWallet] = bonusAllocation;
        emit Transfer(0x0, pvtBonusWallet, bonusAllocation);

        // set up the white listing mapping
        createWhiteListedMapping(_whitelistAddresses);
    }

    // Contract utility functions

    function balanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }
    
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
        return true;
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
        require(msg.value >= minPurchase);
        require(whiteListed[msg.sender]);
        uint256 ethAmount = msg.value;
        // 1.4 accounts for the 40% discount.
        uint256 tokenAmount = ethAmount.mul(exchangeRate);
        uint256 bonusAmount = tokenAmount.mul(40).div(100);
        uint256 totalTokenAmount = tokenAmount.add(bonusAmount);
        uint256 availableTokens;
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        
        if (tokenAmount > balances[pvtFundsWallet]) {
            // subtract the remaining bal from the original token amount
            availableTokens = tokenAmount.sub(balances[pvtFundsWallet]);
            bonusAmount = availableTokens.mul(40).div(100);
            totalTokenAmount = availableTokens.add(bonusAmount);
            // determine the unused ether amount by seeing how many tokens where
            // unavailable and dividing by the exchange rate without the bonus
            ethRefund = tokenAmount.sub(availableTokens).div(exchangeRate.mul(40).div(100));
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            balances[pvtFundsWallet] = balances[pvtFundsWallet].sub(availableTokens);
            balances[pvtBonusWallet] = balances[pvtBonusWallet].sub(bonusAmount);
            balances[msg.sender] = balances[msg.sender].add(totalTokenAmount);
            emit Transfer(pvtFundsWallet, msg.sender, totalTokenAmount);
            icoParticipants.push(msg.sender);
            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            pvtFundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        } else {
            require(balances[pvtFundsWallet] >= tokenAmount);
            require(balances[pvtBonusWallet] >= bonusAmount);
            // complete transfer and emit an event
            balances[pvtFundsWallet] = balances[pvtFundsWallet].sub(tokenAmount);
            balances[pvtBonusWallet] = balances[pvtBonusWallet].sub(bonusAmount);
            balances[msg.sender] = balances[msg.sender].add(totalTokenAmount);
            icoParticipants.push(msg.sender);
            emit Transfer(pvtFundsWallet, msg.sender, totalTokenAmount);
            
            // transfer ether to the wallet and emit and event regarding eth raised
            pvtFundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);  
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
        if (balances[pvtFundsWallet] > 0) {
            balances[pvtFundsWallet] = 0;
        }

        return true;
    }

    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the pvtSaleTokenWallet
    // This wallet will need to be approved in the main contract to make these distributions
    
    function distrubuteTokens() onlyOwner public {
        require(currentTime() >= tokensReleaseDate);
        address pvtSaleTokenWallet = dc.pvtSaleTokenWallet();
        address mainContractFundsWallet = dc.fundsWallet();
        for (uint8 i = 0; i < icoParticipants.length; i++) {
            dc.transferFrom(pvtSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
            emit Transfer(pvtSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
        }

        if (dc.balanceOf(pvtSaleTokenWallet) > 0) {
            uint256 remainingBalace = dc.balanceOf(pvtSaleTokenWallet);
            dc.transferFrom(pvtSaleTokenWallet, mainContractFundsWallet, remainingBalace);
            emit Transfer(pvtSaleTokenWallet, mainContractFundsWallet, remainingBalace);
        }
        // Event to say distribution is complete
        emit DistributedAllBalancesToTSDContract(address(this), TSDContractAddress);
    }
}