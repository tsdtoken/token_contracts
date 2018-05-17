pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/ERC20/Standard.sol";

contract TSDSubsequentSupply is Ownable {
    using SafeMath for uint;
    
    TSD dc;
    address TSDContractAddress;
    uint exchangeRate = 0;
    address newTokensWallet;
    bool isOpen;

    // NOTE: when this contract is opened the owner of the newTokensWallet
    // needs to approve this wallet as the spender
    // This will be done through the approve function in the main contract 
    
    constructor(address _contractAddress) public {
        dc = TSD(_contractAddress);
        newTokensWallet = owner;
    }
    
    event Transfer(address _from, address _to, uint _amount);
    event EthRaisedUpdated(uint _previousTotal, uint _newTotal);
    
    function setTokenHolderAddressAndExchangeRate(address _newTokensWallet, uint _rate) onlyOwner public {
        exchangeRate = _rate;
        newTokensWallet = _newTokensWallet;
    }
    
    function increaseTotalSupplyAndAllocateTokens(uint _amount) onlyOwner public {
        require(newTokensWallet != 0x0);
        dc.increaseTotalSupplyAndAllocateTokens(newTokensWallet, _amount);
    }
    
    function openSubsequentSale() onlyOwner public returns (bool) {
        require(newTokensWallet != 0x0);
        require(exchangeRate != 0);
        isOpen = true;
        
        return true;
    }
    
    function closeSubsequentSale() onlyOwner public returns (bool) {
        isOpen = false;
    }
    
    function buySubsequentTokens() payable public {
        require(isOpen);
        uint tokenAmount = msg.value.mul(exchangeRate);
        uint currentEthRaised = dc.totalEthRaised();
        address mainContractFundsWallet = dc.fundsWallet();
        
        // needs logic for is the whole amount isn't available
        dc.transferFrom(newTokensWallet, msg.sender, tokenAmount);
        mainContractFundsWallet.transfer(msg.value);
        dc.increaseEthRaisedBySubsequentSale(msg.value);
        
        emit Transfer(newTokensWallet, msg.sender, tokenAmount);
        emit EthRaisedUpdated(currentEthRaised, dc.totalEthRaised());
    }
}