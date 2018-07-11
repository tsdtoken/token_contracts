pragma solidity ^0.4.23;

import "./FoundationContracts/Ownable.sol";
import "./TSD.sol";

contract TSDCrowdSale is Ownable {
    using SafeMath for uint256;

    uint256 public decimals = 18;

    TSD public mainToken;

    uint256 public minPurchase = 50000; // 500.00 USD in cents
    uint256 public ethExchangeRate;
    uint256 public exchangeRate;
    uint256 public tokenPrice = 50; // 50 cents (USD)
    uint256 public totalEthRaised = 0;

    // Helper value from 1 million and 1 thousand
    uint256 public decimalMultiplier = uint256(10) ** decimals;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time "Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1535724000000).toUTCString() => "Fri, 31 Aug 2018 14:00:00 GMT"
    uint256 public startTime = 1535724000000;
    // End time "Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1538316000000).toUTCString() => "Sun, 30 Sep 2018 14:00:00 GMT"
    uint256 public endTime = 1538316000000;

    // TSD Contract address
    address public TSDContractAddress;

    // Wallets
    address public fundsWallet;

    // Addresses for external helpers
    address private oracleAddress;

    // SubsequentContract Address
    address public subsequentContract;

    // whitelisted addresses
    mapping (address => bool) public whiteListed;

    // ico concluded due to all tokens sold
    bool public tokensAvailable = true;

    // events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExchangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event IncreaseTotalSupply(uint256 additionalSupply);

    constructor(
        uint256 _ethExchangeRate,
        address _fundsWallet
    ) public {
        // set up the exchangeRate and ethExchangeRate
        updateTheExchangeRate(_ethExchangeRate);
        // allocate fundsWallet
        fundsWallet = _fundsWallet;
    }

    // Create an instance of the main contract
    function setMainContractAddress(address _t) external onlyOwner{
        mainToken = TSD(_t);
        TSDContractAddress = _t;
    }

    // Contract utility functions
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }

    // Called externally to create whitelist for  sale.
    // Only whitelisted addresses can participate in the ico.
    function createWhiteListedMapping(address[] _addresses) public onlyRestricted {
        for (uint64 i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }

    function isWhiteListed(address _address) external view returns (bool) {
        return whiteListed[_address];
    }
    
    // Called externally to change the address of the oracle.
    // The oracle updates the exchange rate based on the current ETH value.
    function changeOracleAddress(address _newAddress) external onlyOwner {
        oracleAddress = _newAddress;
    }

        // Updates the ETH => TSD exchange rate
    function updateTheExchangeRate(uint256 _newRate) public onlyRestricted returns (bool) {
        ethExchangeRate = _newRate;
        uint256 currentRate = exchangeRate;
        uint256 oneSzabo = 1 szabo;
        // 1 ETH = 1000000 szabo
        // The exchangerate is saved in Szabo.
        exchangeRate = oneSzabo.mul(tokenPrice).mul(1000000).div(_newRate);
        emit ExchangeRateUpdated(currentRate, exchangeRate);
        return true;
    }

    // Buy functions
    // This is an un-named fallback function that is set to payable to accept ether.
    function() payable public {
        buyTokens();
    }

    function buyTokens() payable public {
        uint256 _currentTime = currentTime();
        uint256 _minPurchaseInWei = minPurchase.mul(decimalMultiplier).div(ethExchangeRate);
        require(tokensAvailable, "no more tokens available");
        require(_currentTime >= startTime && _currentTime <= endTime, "current time is not in the purchase window frame");
        require(whiteListed[msg.sender], "user is not whitelisted");
        require(msg.value >= _minPurchaseInWei, "amount sent is below minimum purchase");

        // ETH received by spender
        uint256 ethAmount = msg.value;
        // token amount based on ETH / exchangeRate result
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.mul(decimalMultiplier).div(exchangeRate);
        // tokens avaialble to sell are the remaining tokens in the pvtFundsWallet
        uint256 availableTokens = mainToken.balanceOf(fundsWallet);
        uint256 currentEthRaised = totalEthRaised;
        uint256 ethRefund = 0;
        uint256 unavailableTokens;

        if (totalTokenAmount > availableTokens) {
            // additional tokens that aren't avaialble to be sold
            // tokenAmount is the tokens requested by buyer (not including the discount)
            // availableTokens are all the tokens left in the supplying wallet i.e pvtFundsWallet
            unavailableTokens = totalTokenAmount.sub(availableTokens);

            // determine the unused ether amount by seeing how many tokens were surplus
            // i.e 'availableTokens' and reverse calculating their ETH equivalent
            // divide by decimalMultiplier as unavailableTokens are 10^18
            ethRefund = unavailableTokens.mul(exchangeRate).div(decimalMultiplier);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // will equal to 0 after these substractions occur
            mainToken.safeTransferFrom(fundsWallet, msg.sender, availableTokens);
            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            fundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            // close token sale as tokens are sold out
            tokensAvailable = false;
        } else {
            require(totalTokenAmount <= availableTokens, "totalTokenAmount is greater than availableTokens");
            // complete a safeTransfer and emit an event
            mainToken.safeTransferFrom(fundsWallet, msg.sender, totalTokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            fundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    //  sets start and end times
    function setStartTime(uint256 _startTime) external onlyOwner {
        // ensure the start time is before the end time
        require(_startTime < endTime, "ensure start time is before end time");
        startTime = _startTime;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        // ensure the end time is after the start time
        // and that is after the current time
        require(_endTime > startTime, "ensure end time is after start time");
        endTime = _endTime;
    }

    // modifiers
    modifier onlyRestricted () {
        require(msg.sender == owner || msg.sender == oracleAddress, "sender is not owner nor oracleAddress");
        _;
    }
}