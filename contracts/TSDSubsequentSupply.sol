pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./TSD.sol";

contract TSDSubsequentSupply is Ownable {
    using SafeMath for uint256;
    
    TSD dc;

    address TSDContractAddress;
    uint256 exchangeRate;
    // Wallet address that ether will be transferred to
    address newFundsWallet;
    // Wallet address that will hold the new token amount in the main contract 
    address newTokensWallet;
    bool isOpen;
    
    constructor(address _contractAddress) public {
        dc = TSD(_contractAddress);
    }
    
    event IncreaseSupplyOfTSD(uint256 _newSupplyAdded);
    event NewTotalSupplyOfTSD(uint256 _totalSupply);
    event Transfer(address _from, address _to, uint256 _amount);
    event EthRaisedUpdated(uint256 _previousTotal, uint256 _newTotal);
    event SubsequentContractOpened(address _contract, bool _isOpen);

    // NOTE: when this contract is opened, the owner of the newTokensWallet
    // needs to approve this wallet as the spender
    // This will be done through the approve function in the main contract 
    
    function setTokenWalletAddressAndExchangeRate(address _newTokensWallet, address _newFundsWallet, uint256 _rate) onlyOwner public {
        exchangeRate = _rate;
        newFundsWallet = _newFundsWallet;
        newTokensWallet = _newTokensWallet;
    }
    
    function increaseTotalSupplyAndAllocateTokens(uint256 _amount) onlyOwner public {
        require(newTokensWallet != 0x0);
        uint256 currentTotalSupply = dc.totalSupply();
        uint256 newTotalSupply = currentTotalSupply.add(_amount);
        dc.increaseTotalSupplyAndAllocateTokens(newTokensWallet, _amount);
        emit IncreaseSupplyOfTSD(_amount);
        emit NewTotalSupplyOfTSD(newTotalSupply);
    }
    
    function openSubsequentSale() onlyOwner public returns (bool) {
        require(newTokensWallet != 0x0);
        require(exchangeRate != 0);
        isOpen = true;

        emit SubsequentContractOpened(address(this), true);
        return true;
    }
    
    function closeSubsequentSale() onlyOwner public returns (bool) {
        isOpen = false;

        emit SubsequentContractOpened(address(this), false);
        return true;
    }

    function () payable public {
        buySubsequentTokens();
    }
    
    function buySubsequentTokens() payable public {
        require(isOpen);
        uint256 ethAmount = msg.value;
        uint256 tokenAmount = msg.value.mul(exchangeRate);
        uint256 currentEthRaised = dc.totalEthRaised();
        uint256 availableTokens;
        uint256 ethRefund = 0;
        // get current amount available
        uint256 currentAvailableTokens = dc.balanceOf(newTokensWallet);
        if (tokenAmount > currentAvailableTokens) {
            availableTokens = tokenAmount.sub(currentAvailableTokens);
            ethRefund = tokenAmount.sub(availableTokens).div(exchangeRate);
            ethAmount = ethAmount.sub(ethRefund);
            // make the transfer
            dc.transferFrom(newTokensWallet, msg.sender, availableTokens);
            emit Transfer(newTokensWallet, msg.sender, availableTokens);
            // issue refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to our wallet
            newFundsWallet.transfer(ethAmount);
            dc.increaseEthRaisedBySubsequentSale(msg.value);
        }
        
        require(currentAvailableTokens >= tokenAmount);
        dc.transferFrom(newTokensWallet, msg.sender, tokenAmount);
        emit Transfer(newTokensWallet, msg.sender, availableTokens);
        // transfer either to newFundsWallet
        newFundsWallet.transfer(msg.value);
        dc.increaseEthRaisedBySubsequentSale(msg.value);
        
        emit Transfer(newTokensWallet, msg.sender, tokenAmount);
        emit EthRaisedUpdated(currentEthRaised, dc.totalEthRaised());
    }
}