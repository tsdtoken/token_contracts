pragma solidity ^0.4.23;

import "./FoundationContracts/Ownable.sol";
import "./TSD.sol";

contract TSDSubsequentSupply is Ownable {
    using SafeMath for uint256;
    
    TSD public dc;

    uint256 public subsequentTotalSupply;
    uint256 public exchangeRate;
    uint256 public decimals = 18;
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    // Wallet address that ether will be transferred to
    address public newFundsWallet;
    // Wallet address that will hold the new token amount in the main contract 
    address public newTokensWallet;
    bool public isOpen = false;

    // whitelisted addresses
    mapping(address => bool) whiteListed;
    
    constructor(address _contractAddress) public {
        dc = TSD(_contractAddress);
    }
    
    event IncreaseSupplyOfTSD(uint256 _newSupplyAdded);
    event NewTotalSupplyOfTSD(uint256 _totalSupply);
    event Transfer(address _from, address _to, uint256 _amount);
    event EthRaisedUpdated(uint256 _previousTotal, uint256 _newTotal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event SubsequentContractOpened(address _contract, bool _isOpen);
    event Debugger(string variable, uint256 value);
    event DebugStrings(string variable);
    event DebugAddress(string name, address _address);

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

    // creates the whitelist mapping
    function createWhiteListedMapping(address[] _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }

    function isWhiteListed(address _address) external view returns (bool) {
        if (whiteListed[_address]) {
            return true;
        } else {
            return false;
        }
    }

    // NOTE: when this contract is opened, the owner of the newTokensWallet
    // needs to approve this wallet as the spender
    // This will be done through the approve function in the main contract 

    function openSubsequentSale() onlyOwner external returns (bool) {
        require(newTokensWallet != 0x0);
        require(exchangeRate != 0);
        isOpen = true;

        emit SubsequentContractOpened(address(this), true);
        return true;
    }
    
    function closeSubsequentSale() onlyOwner external returns (bool) {
        isOpen = false;

        emit SubsequentContractOpened(address(this), false);
        return true;
    }
    
    function setTokenWalletAddressAndExchangeRate(address _newTokensWallet, address _newFundsWallet, uint256 _rate) onlyOwner external {
        updateTheExchangeRate(_rate);
        newFundsWallet = _newFundsWallet;
        newTokensWallet = _newTokensWallet;
    }
    
    function increaseTotalSupplyAndAllocateTokens(uint256 _amount) onlyOwner public {
        require(newTokensWallet != 0x0);
        uint256 increaseAmount = _amount.mul(decimalMultiplier);
        uint256 currentTotalSupply = dc.totalSupply();
        uint256 newTotalSupply = currentTotalSupply.add(increaseAmount);
        subsequentTotalSupply = increaseAmount;
        dc.increaseTotalSupplyAndAllocateTokens(newTokensWallet, increaseAmount);
        emit IncreaseSupplyOfTSD(_amount);
        emit NewTotalSupplyOfTSD(newTotalSupply);
    }

    function () payable public {
        buySubsequentTokens();
    }
    
    function buySubsequentTokens() payable public {
        require(isOpen);
        require(whiteListed[msg.sender]);
        // ETH received by spender
        uint256 ethAmount = msg.value;
        emit Debugger("ethAmount", ethAmount);
        // token amount based on ETH / exchangeRate result
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.div(exchangeRate).mul(decimalMultiplier);
        // tokens avaialble to sell are the remaining tokens in the newTokensWallet
        // get a reference to the total eth raised from the main contract
        uint256 availableTokens = dc.balanceOf(newTokensWallet);
        emit Debugger("availableTokens", availableTokens);
        uint256 ethRefund = 0;
        uint256 unavailableTokens;
        emit Debugger("totalTokenAmount", totalTokenAmount);
    
        if (totalTokenAmount > availableTokens) {
            emit DebugStrings("its greater");
            // additional tokens that aren't avaialble to be sold
            // tokenAmount is the tokens requested by buyer
            // availableTokens are all the tokens left in the supplying wallet i.e newTokensWallet
            unavailableTokens = totalTokenAmount.sub(availableTokens);
            emit Debugger("unavailableTokens", unavailableTokens);
            // determine the unused ether amount by seeing how many tokens were surplus
            // i.e 'availableTokens' and reverse calculating their ETH equivalent
            // divide by decimalMultiplier as unavailableTokens are 10^18
            ethRefund = unavailableTokens.mul(exchangeRate).div(decimalMultiplier);
            emit Debugger("ethRefund", ethRefund);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            emit Debugger("ethAmount", ethAmount);
            // make the transfer
            dc.transferFrom(newTokensWallet, msg.sender, availableTokens);
            // issue refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to our wallet
            // inherited transfer function will emit a Transfer event
            newFundsWallet.transfer(ethAmount);
            // increase the amount of eth raised in the main contract
            // event is emitted in main contract
            dc.increaseEthRaisedBySubsequentSale(ethAmount);
            // close sale as all tokens are sold
            isOpen = false;
        } else {
            require(availableTokens >= totalTokenAmount);
            // inherited transfer function will emit a Transfer event
            dc.transferFrom(newTokensWallet, msg.sender, totalTokenAmount);
            // transfer either to newFundsWallet
            newFundsWallet.transfer(ethAmount);
            // increase the amount of eth raised in the main contract
            // event is emitted in main contract
            dc.increaseEthRaisedBySubsequentSale(ethAmount);
        }
    }
}