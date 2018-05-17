pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/ERC20/Standard.sol";

contract TSD is ERC20Interface, Ownable {
    using SafeMath for uint;
    
    string public name = "PRE TSD COIN";
    string public symbol = "PRETSD";
    uint public decimals = 18;
    uint public million = 1000000 * (uint(10) ** decimals);
    uint public totalSupply = 100 * million;
    uint public preSaleSupply = 20 * million;
    uint public pvtSaleSupply = 10 * million;
    uint public exchangeRate;
    uint public totalEthRaised = 0;
    uint public startTime;
    uint public endTime;
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;
    
    mapping (address => bool) public whiteListed;
    mapping (address => uint) public balances;
    
    event EthRaisedUpdated(uint oldEthRaisedVal, uint newEthRaisedVal);
    
    constructor(
        uint _exchangeRate,
        address[] _whitelistAddresses,
        uint _startTime,
        uint _endTime,
        address _pvtSaleTokenWallet,
        address _preSaleTokenWallet
    ) public {
        fundsWallet = owner;
        pvtSaleTokenWallet = _pvtSaleTokenWallet;
        preSaleTokenWallet = _preSaleTokenWallet;
        startTime = _startTime;
        endTime = _endTime;
        exchangeRate = _exchangeRate;
        
        // transfer suppy to the funds wallet
        balances[fundsWallet] = totalSupply;
        
        // transfer tokens to account for the private sale
        balances[fundsWallet].sub(pvtSaleSupply);
        balances[pvtSaleTokenWallet].add(pvtSaleSupply);
        
        // transfer tokens to account for the pre sale
        balances[fundsWallet].sub(preSaleSupply);
        balances[preSaleTokenWallet].add(preSaleSupply);
        
        emit Transfer(0x0, fundsWallet, totalSupply);
        emit Transfer(fundsWallet, pvtSaleTokenWallet, pvtSaleSupply);
        emit Transfer(fundsWallet, preSaleTokenWallet, preSaleSupply);
        
        createWhiteListedMapping(_whitelistAddresses);
    }
    
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }
    
    function createWhiteListedMapping(address[] _addresses) private {
        for (uint i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }
    
    function() payable public {
        buyTokens();
    }
    
    function buyTokens() payable public {
        require(currentTime() >= startTime && currentTime() <= endTime);
        require(whiteListed[msg.sender]);
        uint ethAmount = msg.value;
        uint tokenAmount = msg.value.mul(exchangeRate);
        uint availableTokens;
        uint currentEthRaised = totalEthRaised;
        uint ethRefund = 0;
        
        
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
            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            fundsWallet.transfer(ethAmount);
            totalEthRaised.add(ethAmount);
            
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            emit Transfer(fundsWallet, msg.sender, tokenAmount);
        } else {
            require(balances[fundsWallet] >= tokenAmount);
            balances[fundsWallet] = balances[fundsWallet].sub(tokenAmount);
            balances[msg.sender] = balances[msg.sender].add(tokenAmount);
            
            fundsWallet.transfer(msg.value);
            totalEthRaised.add(msg.value);
            
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            emit Transfer(fundsWallet, msg.sender, tokenAmount);
        }
    }
    
    function burnRemainingTokensAfterClose() public returns (bool) {
        require(currentTime() >= endTime || balances[fundsWallet] == 0);
        if (balances[fundsWallet] > 0) {
            // burn unsold tokens
            balances[fundsWallet] = 0;
        }

        return true;
    }
    
    // Subsequent supply functions
    
    function increaseTotalSupplyAndAllocateTokens(address _newTokensWallet, uint _amount) onlyOwner public {
        totalSupply = totalSupply + _amount;
        balances[_newTokensWallet] = _amount;
    }
    
    function increaseEthRaisedBySubsequentSale(uint _amount) public {
        totalEthRaised = totalEthRaised + _amount;
    }
    
 // ERC20 function wrappers
    
    function transfer(address _to, uint _tokens) public returns (bool success) {
        require(currentTime() >= endTime);
        return super.transfer(_to, _tokens);
    }
    
    function transferFrom(address _from, address _to, uint _tokens) public returns (bool success) {
        require(currentTime() >= endTime);
        return super.transferFrom(_from, _to, _tokens);
    }
}