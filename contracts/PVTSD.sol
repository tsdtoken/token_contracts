pragma solidity ^0.4.23;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "./TSD.sol";

contract PVTSD is Standard, Ownable {
    using SafeMath for uint;
    // set up access to main contract for the future distribution
    TSD dc;
    
    string public name = "PRIVATE TSD COIN";
    string public symbol = "PVTSD";
    uint public decimals = 18;
    uint public million = 1000000 * (uint(10) ** decimals);
    uint public totalSupply = 55 * million;
    uint public minPurchase = 50 ether;
    uint public exchangeRate;
    uint public totalEthRaised = 0;
    uint public startTime;
    uint public endTime;
    uint public tokensReleaseDate;
    address public pvtFundsWallet;
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
        pvtFundsWallet = owner;
        startTime = _startTime;
        endTime = _endTime;
        exchangeRate = _exchangeRate;
        tokensReleaseDate = _tokensReleaseDate;
        
        // transfer suppy to the funds wallet
        balances[pvtFundsWallet] = totalSupply;
        emit Transfer(0x0, pvtFundsWallet, totalSupply);
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
        require(msg.value >= minPurchase);
        require(whiteListed[msg.sender]);
        uint ethAmount = msg.value;
        uint tokenAmount = msg.value.mul(exchangeRate);
        uint availableTokens;
        uint currentEthRaised = totalEthRaised;
        uint ethRefund = 0;
        
        if (tokenAmount > balances[pvtFundsWallet]) {
            // subtract the remaining bal from the original token amount
            availableTokens = tokenAmount.sub(balances[pvtFundsWallet]);
            // determine the unused ether amount by seeing how many tokens where
            // unavailable and dividing by the exchange rate
            ethRefund = tokenAmount.sub(availableTokens).div(exchangeRate);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            balances[pvtFundsWallet] = balances[pvtFundsWallet].sub(availableTokens);
            balances[msg.sender] = balances[msg.sender].add(availableTokens);
            emit Transfer(pvtFundsWallet, msg.sender, tokenAmount);
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
            // complete transfer and emit an event
            balances[pvtFundsWallet] = balances[pvtFundsWallet].sub(tokenAmount);
            balances[msg.sender] = balances[msg.sender].add(tokenAmount);
            emit Transfer(pvtFundsWallet, msg.sender, tokenAmount);
            
            // transfer ether to the wallet and emit and event regarding eth raised
            pvtFundsWallet.transfer(msg.value);
            totalEthRaised.add(msg.value);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);  
        }
    }

    // Any tokens that remain after the private sale has ended can be transferred back
    // into the main pool of tokens which will be avaialbe in the crowdsale
    function transferAnyRemainingTokensToCrowdsaleBalance() public onlyOwner returns (bool) {
        require(currentTime() >= endTime);
        if (balances[pvtFundsWallet] > 0) {
            // burn unsold tokens
            dc.transferFrom(dc.pvtSaleTokenWallet(), dc.fundsWallet(), balances[pvtFundsWallet]);
        }

        return true;
    }
    
    // Functionality to transfer token balances to the main contract
    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the pvtSaleTokenWallet
    // This wallet will need to be approved in the main contract to make these distributions
    function setMainContractAddress(address _t) onlyOwner public {
        dc = TSD(_t);
    }
    
    function distrubuteTokens() onlyOwner public {
        require(currentTime() >= tokensReleaseDate);
        address pvtSaleTokenWallet = dc.pvtSaleTokenWallet();
        for (uint8 i = 0; i < IcoParticipants.length; i++) {
            dc.transferFrom(pvtSaleTokenWallet, IcoParticipants[i], balances[IcoParticipants[i]]);
            emit Transfer(pvtSaleTokenWallet, IcoParticipants[i], balances[IcoParticipants[i]]);
        }
    }
}