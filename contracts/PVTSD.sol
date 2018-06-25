pragma solidity ^0.4.23;

// import "./FoundationContracts/BaseToken.sol";
import "./FoundationContracts/Ownable.sol";
import "./TSD.sol";

contract PVTSD is Ownable {
    using SafeMath for uint256;
    // set up access to main contract for the future distribution
    TSD public dc;
    // when the connection is set to the main contract, save a reference for event purposes
    address public TSDContractAddress;
    address private oracleAddress;

    string public name = "PRIVATE TSD COIN";
    string public symbol = "PVTSD";
    uint256 public decimals = 18;
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    uint256 public million = 1000000 * decimalMultiplier;
    uint256 public totalSupply = 82500000 * decimalMultiplier;
    uint256 public minPurchase = 5000000; // 50,000.00 USD in cents
    uint256 public ethExchangeRate;
    uint256 public exchangeRate;
    uint256 public tokenPrice = 50; // 50 cents (USD)
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

    // Array of participants used when distributing tokens to main contract
    address[] public icoParticipants;

    // whitelisted addresses
    mapping (address => bool) public whiteListed;

    // balances
    mapping(address => uint256) balances;

    // When all tokens are sold this value will be set to false
    bool public tokensAvailable = true;

    // current distribution Index
    uint256 public currentDistributionIndex = 0;

    // Events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExchangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event DistributedAllBalancesToTSDContract(address _presd, address _tsd);
    event Transfer(address from, address to, uint256 value);
    event UpdatedTotalSupply(uint256 oldSupply, uint256 newSupply);

    constructor(
        uint256 _ethExchangeRate
    ) public {
        pvtFundsWallet = owner;

        // transfer suppy to the pvtFundsWallet
        balances[pvtFundsWallet] = totalSupply;
        emit Transfer(0x0, pvtFundsWallet, totalSupply);

        // set up the exchangeRate
        updateTheExchangeRate(_ethExchangeRate);
    }

    // Contract utility functions
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }

    // Checks the balance of the address. ERC20 standard.
    function balanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }

    // Called externally to create whitelist for  sale.
    // Only whitelisted addresses can participate in the ico.
    function createWhiteListedMapping(address[] _addresses) external onlyRestricted {
        for (uint64 i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }

    // Called to remove addresses from whitelist
    function removeFromWhitelist(address _address) external onlyRestricted {
        delete whiteListed[_address];
    }

    // Called externally to change the address of the oracle.
    // The oracle updates the exchange rate based on the current ETH value.
    function changeOracleAddress(address _newAddress) external onlyOwner {
        oracleAddress = _newAddress;
    }

    // Updates the ETH => TSD exchange rate
    // This is called when the contract is constructed and by the oracle to update the rate periodically
    function updateTheExchangeRate(uint256 _newRate) public onlyRestricted returns (bool) {
        ethExchangeRate = _newRate;
        uint256 currentRate = exchangeRate;
        uint256 oneSzabo = 1 szabo;
        uint256 tokenPriceInSzabo = tokenPrice.mul(1000000).div(_newRate);
        // The exchangerate is saved in Szabo.
        exchangeRate = oneSzabo.mul(tokenPriceInSzabo);
        emit ExchangeRateUpdated(currentRate, exchangeRate);
        return true;
    }

    // Can check to see if an address is whitelisted
    function isWhiteListed(address _address) external view returns (bool) {
        return whiteListed[_address];
    }

    // Buy functions
    // This is an un-named fallback function that is set to payable to accept ether.
    function() payable public {
        buyTokens();
    }

    function buyTokens() payable public {
        uint256 _currentTime = currentTime();
        uint256 _minPurchaseInWei = minPurchase.mul(decimalMultiplier).div(ethExchangeRate);
        require(tokensAvailable);
        require(_currentTime >= startTime && _currentTime <= endTime);
        require(msg.value >= _minPurchaseInWei);
        require(whiteListed[msg.sender]);

        // ETH received by spender
        uint256 ethAmount = msg.value;
        // token amount based on ETH / exchangeRate result
        // exchange rate is 1 TSD => x ETH
        // with a 40% discount attached
        uint256 discountedExchangeRate = exchangeRate.mul(70).div(100);
        // totalTokenAmount is the total tokens offered including the discount
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.mul(decimalMultiplier).div(discountedExchangeRate);
        // tokens avaialble to sell are the remaining tokens in the pvtFundsWallet
        uint256 availableTokens = balances[pvtFundsWallet];
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
            ethRefund = unavailableTokens.mul(discountedExchangeRate).div(decimalMultiplier);
            // subtract the refund amount from the eth amount received by the tx
            ethAmount = ethAmount.sub(ethRefund);
            // make the token purchase
            // will equal to 0 after these substractions occur
            balances[pvtFundsWallet] = balances[pvtFundsWallet].sub(availableTokens);

            // adding the buyer to the icoParticipants ONLY if they haven't already bought before
            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }

            // add total tokens to the senders balances and Emit transfer event
            balances[msg.sender] = balances[msg.sender].add(availableTokens);
            emit Transfer(pvtFundsWallet, msg.sender, availableTokens);

            // refund
            if (ethRefund > 0) {
                msg.sender.transfer(ethRefund);
            }
            // transfer ether to funds wallet
            pvtFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
            // close token sale as tokens are sold out
            tokensAvailable = false;
        } else {
            require(totalTokenAmount <= availableTokens);

            if (balances[msg.sender] == 0) {
                icoParticipants.push(msg.sender);
            }

            // complete transfer and emit an event
            balances[pvtFundsWallet] = balances[pvtFundsWallet].sub(totalTokenAmount);
            balances[msg.sender] = balances[msg.sender].add(totalTokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            pvtFundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit Transfer(pvtFundsWallet, msg.sender, totalTokenAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    // After close functions

    // Create an instance of the main contract
    function setMainContractAddress(address _t) external onlyOwner{
        dc = TSD(_t);
        TSDContractAddress = _t;
    }

   // Burn any remaining tokens
    function burnRemainingTokens() external onlyOwner returns (bool) {
        require(currentTime() >= endTime);
        if (balances[pvtFundsWallet] > 0) {
            // Subtracting the unsold tokens from the total supply.
            uint256 oldSupply = totalSupply;
            totalSupply = totalSupply.sub(balances[pvtFundsWallet]);
            balances[pvtFundsWallet] = 0;
            emit UpdatedTotalSupply(oldSupply, totalSupply);
        }

        return true;
    }

    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the pvtSaleTokenWallet
    // This wallet will need to be approved in the main contract to make these distributions
    // _numberOfTransfers states the number of transfers that can happen at one time
    function distributeTokens(uint256 _numberOfTransfers) external onlyOwner returns (bool) {
        require(currentTime() >= tokensReleaseDate);
        address pvtSaleTokenWallet = dc.pvtSaleTokenWallet();
        uint256 finalDistributionIndex = currentDistributionIndex.add(_numberOfTransfers);

        for (uint256 i = currentDistributionIndex; i < finalDistributionIndex; i++) {
            // end for loop when currentDistributionIndex reaches the length of the icoParticipants array
            if (i == icoParticipants.length) {
                return;
            }
            // skip transfer if balances are empty
            if (balances[icoParticipants[i]] != 0) {
                dc.transferFrom(pvtSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);
                emit Transfer(pvtSaleTokenWallet, icoParticipants[i], balances[icoParticipants[i]]);

                // set balances to 0 to prevent re-transfer
                balances[icoParticipants[i]] = 0;
            }
        }
        // after distribution is complete set the currentDistributionIndex to the latest finalDistributionIndex
        currentDistributionIndex = finalDistributionIndex;

        // Event to say distribution is complete
        emit DistributedAllBalancesToTSDContract(address(this), TSDContractAddress);

        // Boolean is returned to give us a success state.
        return true;
    }

    // sets start and end times
    function setStartTime(uint256 _startTime) external onlyOwner returns (bool) {
        // ensure the start time is before the end time
        require(_startTime < endTime);
        startTime = _startTime;
        return true;
    }

    function setEndTime(uint256 _endTime) external onlyOwner returns (bool) {
        // ensure the end time is after the start time
        // and that is after the current time
        require(_endTime > startTime && _endTime > currentTime());
        endTime = _endTime;
        return true;
    }

    // Destroys the contract
    function selfDestruct() external onlyOwner {
        selfdestruct(owner);
    }

    modifier onlyRestricted () {
        require(msg.sender == owner || msg.sender == oracleAddress);
        _;
    }
}
