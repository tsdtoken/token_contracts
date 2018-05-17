pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/ERC20/Standard.sol";

contract PVTSD is ERC20Interface, Ownable {
    using SafeMath for uint;
    // set up access to main contract for the future distribution
    TSD dc;
    
    string public name = "PRIVATE TSD COIN";
    string public symbol = "PVTSD";
    uint public decimals = 18;
    uint public million = 1000000 * (uint(10) ** decimals);
    uint public totalSupply = 10 * million;
    uint public exchangeRate;
    uint public totalEthRaised = 0;
    uint public startTime;
    uint public endTime;
    uint public tokensReleaseDate;
    address public fundsWallet;
    address[] public IcoParticipants;
    
    mapping (address => bool) public whiteListed;
    mapping (address => uint) public balances;
    
    event EthRaisedUpdated(uint oldEthRaisedVal, uint newEthRaisedVal);
    
    constructor(
        uint _exchangeRate,
        address[] _whitelistAddresses,
        uint _startTime,
        uint _endTime,
        uint _tokensReleaseDate
    ) public {
        fundsWallet = owner;
        startTime = _startTime;
        endTime = _endTime;
        exchangeRate = _exchangeRate;
        tokensReleaseDate = _tokensReleaseDate;
        
        // transfer suppy to the funds wallet
        balances[fundsWallet] = totalSupply;
        emit Transfer(0x0, fundsWallet, totalSupply);
        // set up the white listing mapping
        createWhiteListedMapping(_whitelistAddresses);
    }
    
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }
    
    function createWhiteListedMapping(address[] _addresses) public {
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
    
    function burnRemainingTokens() public {
        require(currentTime() >= endTime);
        if (balances[fundsWallet] > 0) {
            // burn any remaining tokens
            balances[fundsWallet] = 0;
        }
        finalised = true;
    }
    
    // Functionality to token balances to the main contract
    
    function setMainContractAddress(address _t) public {
        dc = TSD(_t);
    }
    
    function distrubuteTokens() public {
        address pvtSaleTokenWallet = dc.pvtSaleTokenWallet();
        for (uint8 i = 0; i < IcoParticipants.length; i++) {
            dc.transferFrom(pvtSaleTokenWallet, IcoParticipants[i], balances[IcoParticipants[i]]);
            emit Transfer(pvtSaleTokenWallet, IcoParticipants[i], balances[IcoParticipants[i]]);
        }
    }
    
    // ERC20 function wrappers
    
    function transfer(address _to, uint _tokens) public returns (bool success) {
        require(currentTime() >= tokensReleaseDate);
        return super.transfer(_to, _tokens);
    }
    
    function transferFrom(address _from, address _to, uint _tokens) public returns (bool success) {
        require(currentTime() >= tokensReleaseDate);
        return super.transferFrom(_from, _to, _tokens);
    }
    
}