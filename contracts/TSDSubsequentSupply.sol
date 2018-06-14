pragma solidity ^0.4.23;

import "./FoundationContracts/Ownable.sol";
import "./TSD.sol";

contract TSDSubsequentSupply is Ownable {
    using SafeMath for uint256;

    TSD public dc;

    uint256 public subsequentTotalSupply;
    uint256 public ethExchangeRate;
    uint256 public exchangeRate;
    uint256 public tokenPrice = 50; // 50 cents (USD)
    uint256 public decimals = 18;
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    // Wallet address that ether will be transferred to
    address public newFundsWallet;
    // Wallet address that will hold the new token amount in the main contract
    address public newTokensWallet;
    // Addresses for external helpers
    address private oracleAddress;

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
    event TokenPriceUpdated(uint256 _oldPrice, uint256 _newPrice);

    // Updates the ETH => TSD exchange rate
    function updateTheExchangeRate(uint256 _newRate) public onlyRestricted returns (bool) {
        ethExchangeRate = _newRate;
        uint256 currentRate = exchangeRate;
        uint256 oneSzabo = 1 szabo;
        uint256 tokenInSzabo = tokenPrice.mul(1000000).div(_newRate);
        exchangeRate = oneSzabo.mul(tokenInSzabo);
        emit ExhangeRateUpdated(currentRate, exchangeRate);
        return true;
    }

    // Updates the tokenPrice.
    // @param _newprice: the token price in USD cents
    function updateTokenPrice(uint256 _newPrice) external onlyOwner returns (bool) {
        uint256 _oldPrice = tokenPrice;
        tokenPrice = _newPrice;
        emit TokenPriceUpdated(_oldPrice, _newPrice);
        return true;
    }

    // Change the address of the oracle
    function changeOracleAddress(address _newAddress) external onlyOwner {
      oracleAddress = _newAddress;
    }

    // creates the whitelist mapping
    function createWhiteListedMapping(address[] _addresses) public onlyRestricted {
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

    function openSubsequentSale() external onlyOwner returns (bool) {
        require(newTokensWallet != 0x0);
        require(exchangeRate != 0);
        isOpen = true;

        emit SubsequentContractOpened(address(this), true);
        return true;
    }

    function closeSubsequentSale() external onlyOwner returns (bool) {
        isOpen = false;

        emit SubsequentContractOpened(address(this), false);
        return true;
    }

    function setTokenWalletAddressAndExchangeRate(address _newTokensWallet, address _newFundsWallet, uint256 _rate) external onlyOwner {
        updateTheExchangeRate(_rate);
        newFundsWallet = _newFundsWallet;
        newTokensWallet = _newTokensWallet;
    }

    function increaseTotalSupplyAndAllocateTokens(uint256 _amount) public onlyOwner {
        require(newTokensWallet != 0x0);
        uint256 increaseAmount = _amount.mul(decimalMultiplier);
        uint256 currentTotalSupply = dc.totalSupply();
        uint256 newTotalSupply = currentTotalSupply.add(increaseAmount);
        subsequentTotalSupply = increaseAmount;
        dc.increaseTotalSupplyAndAllocateTokens(newTokensWallet, increaseAmount);
        emit IncreaseSupplyOfTSD(_amount);
        emit NewTotalSupplyOfTSD(newTotalSupply);
    }

    function () public payable {
        buySubsequentTokens();
    }

    function buySubsequentTokens() public payable {
        require(isOpen);
        require(whiteListed[msg.sender]);
        // ETH received by spender
        uint256 ethAmount = msg.value;
        // token amount based on ETH / exchangeRate result
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.mul(decimalMultiplier).div(exchangeRate);
        // tokens avaialble to sell are the remaining tokens in the newTokensWallet
        // get a reference to the total eth raised from the main contract
        uint256 availableTokens = dc.balanceOf(newTokensWallet);
        uint256 ethRefund = 0;
        uint256 unavailableTokens;

        if (totalTokenAmount > availableTokens) {
            // additional tokens that aren't avaialble to be sold
            // tokenAmount is the tokens requested by buyer
            // availableTokens are all the tokens left in the supplying wallet i.e newTokensWallet
            unavailableTokens = totalTokenAmount.sub(availableTokens);
            // determine the unused ether amount by seeing how many tokens were surplus
            // i.e 'availableTokens' and reverse calculating their ETH equivalent
            // divide by decimalMultiplier as unavailableTokens are 10^18
            ethRefund = unavailableTokens.mul(exchangeRate).div(decimalMultiplier);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
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
            require(totalTokenAmount <= availableTokens);
            // inherited transfer function will emit a Transfer event
            dc.transferFrom(newTokensWallet, msg.sender, totalTokenAmount);
            // transfer either to newFundsWallet
            newFundsWallet.transfer(ethAmount);
            // increase the amount of eth raised in the main contract
            // event is emitted in main contract
            dc.increaseEthRaisedBySubsequentSale(ethAmount);
        }
    }

    modifier onlyRestricted () {
      require(msg.sender == owner || msg.sender == oracleAddress);
      _;
    }
}
