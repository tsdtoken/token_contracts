pragma solidity ^0.4.23;

import "./FoundationContracts/BaseCrowdsaleContract.sol";

contract TSDSubsequentSupply is BaseCrowdsaleContract {

    uint256 public subsequentTotalSupply;
    // Wallet address that ether will be transferred to
    address public newFundsWallet;
    // Wallet address that will hold the new token amount in the main contract
    address public newTokensWallet;

    bool public isOpen = false;


    constructor(address _contractAddress) public {
        dc = TSD(_contractAddress);
    }

    event IncreaseSupplyOfTSD(uint256 _newSupplyAdded);
    event NewTotalSupplyOfTSD(uint256 _totalSupply);
    event SubsequentContractOpened(address _contract, bool _isOpen);
    event TokenPriceUpdated(uint256 _oldPrice, uint256 _newPrice);

    // Updates the tokenPrice.
    // @param _newprice: the token price in USD cents
    function updateTokenPrice(uint256 _newPrice) external onlyOwner returns (bool) {
        uint256 _oldPrice = tokenPrice;
        tokenPrice = _newPrice;
        emit TokenPriceUpdated(_oldPrice, _newPrice);
        return true;
    }

    // NOTE: when this contract is opened, the owner of the newTokensWallet
    // needs to approve this wallet as the spender
    // This will be done through the approve function in the main contract

    function openSubsequentSale() external onlyOwner returns (bool) {
        require(newTokensWallet != 0x0, "newTokensWallet is an invalid wallet address");
        require(exchangeRate != 0, "exchange rate is 0");
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
        require(newTokensWallet != 0x0, "newTokensWallet is an invalid wallet address");
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
        require(isOpen, "sale is closed");
        require(whiteListed[msg.sender], "address is not whitelisted");
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
            require(totalTokenAmount <= availableTokens, "availableTokens is less than totalTokenAmount");
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
