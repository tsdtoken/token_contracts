pragma solidity ^0.4.23;

import "./FoundationContracts/BaseToken.sol";
import "./FoundationContracts/Ownable.sol";

contract TSD is BaseToken, Ownable {
    string public name = "TSD COIN";
    string public symbol = "TSD";
    uint256 public decimals = 18;

    // Helper value from 1 million and 1 thousand
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    uint256 public million = 1000000 * decimalMultiplier;
    uint256 public thousand = 1000 * decimalMultiplier;

    // Allocations
    uint256 public totalSupply = 550 * million;
    uint256 public pvtSaleSupply = (82 * million).add(500 * thousand);
    uint256 public preSaleSupply = 165 * million;
    uint256 public foundersAndAdvisorsAllocation = 33 * million;
    uint256 public bountyCommunityIncentivesAllocation = (27 * million).add(500 * thousand);
    uint256 public liquidityProgramAllocation = (16 * million).add(500 * thousand);
    uint256 public minPurchase = 5000; // 50.00 USD in cents
    uint256 public ethExchangeRate;
    uint256 public exchangeRate;
    uint256 public tokenPrice = 50; // 50 cents (USD)
    uint256 public totalEthRaised = 0;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time "Sat Sep 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1535724000000).toUTCString() => "Fri, 31 Aug 2018 14:00:00 GMT"
    uint256 public startTime = 1535724000000;
    // End time "Mon Oct 01 2018 00:00:00 GMT+1000 (AEST)"
    // new Date(1538316000000).toUTCString() => "Sun, 30 Sep 2018 14:00:00 GMT"
    uint256 public endTime = 1538316000000;

    // Wallets
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;

    // Addresses for services and founders
    address public foundersAndAdvisors;
    address public bountyCommunityIncentives;
    address public liquidityProgram;

    // Addresses for external helpers
    address private oracleAddress;

    // SubsequentContract Address
    address public subsequentContract;

    // whitelisted addresses
    mapping (address => bool) public whiteListed;

    // ico concluded due to all tokens sold
    bool public tokensAvailable = true;

    // Token tradability toggle
    bool public canTrade = false;

    // initializationCall
    bool isInitialAllocationDone = false;

    // events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event UpdatedTotalSupply(uint256 oldSupply, uint256 newSupply);
    event TradingStatus(bool status);
    event InitalTokenAllocation(bool allocationStatus);

    constructor(
        uint256 _ethExchangeRate,
        address _pvtSaleTokenWallet,
        address _preSaleTokenWallet,
        address _foundersAndAdvisors,
        address _bountyCommunityIncentives,
        address _liquidityProgram
    ) public {
        fundsWallet = owner;
        pvtSaleTokenWallet = _pvtSaleTokenWallet;
        preSaleTokenWallet = _preSaleTokenWallet;
        foundersAndAdvisors = _foundersAndAdvisors;
        bountyCommunityIncentives = _bountyCommunityIncentives;
        liquidityProgram = _liquidityProgram;
        ethExchangeRate = _ethExchangeRate;

        // transfer suppy to the funds wallet
        balances[fundsWallet] = totalSupply;
        emit Transfer(0x0, fundsWallet, totalSupply);
    }

    function contractInitialAllocation() external onlyOwner {
        // require the initialAllocationDone to be false, as it can only be called once 
        require(!isInitialAllocationDone);

        // Transfer all of the allocations
        // The inherited transfer method from the StandardToken which inherits
        // from BasicToken emits Transfer events and subtracts/adds respective
        // amounts to respective accounts
        // transfer tokens to account for the private sale
        super.transfer(pvtSaleTokenWallet, pvtSaleSupply);

        // transfer tokens to account for the pre sale
        super.transfer(preSaleTokenWallet, preSaleSupply);

        // transfer tokens to founders account
        super.transfer(foundersAndAdvisors, foundersAndAdvisorsAllocation);

        // transfer tokens to bounty and community incentives account
        super.transfer(bountyCommunityIncentives, bountyCommunityIncentivesAllocation);

        // transfer tokens to the liquidity program account
        super.transfer(liquidityProgram, liquidityProgramAllocation);

        // set up the exchangeRate and ethExchangeRate
        updateTheExchangeRate(ethExchangeRate);

        // set the initialAllocationDone value to true
        isInitialAllocationDone = true;
        emit InitalTokenAllocation(isInitialAllocationDone);
    }

    // Contract utility functions
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }

    // Toggles the trading ability of TSD
    function toggleTrading() external onlyOwner {
      canTrade = !canTrade;
      emit TradingStatus(canTrade);
    }

    // Called externally to create whitelist for  sale.
    // Only whitelisted addresses can participate in the ico.
    function createWhiteListedMapping(address[] _addresses) public onlyRestricted {
        for (uint64 i = 0; i < _addresses.length; i++) {
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
        uint256 tokenPriceInSzabo = tokenPrice.mul(1000000).div(_newRate);
        // The exchangerate is saved in Szabo.
        exchangeRate = oneSzabo.mul(tokenPriceInSzabo);
        emit ExhangeRateUpdated(currentRate, exchangeRate);
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
        require(tokensAvailable);
        require(_currentTime >= startTime && _currentTime <= endTime);
        require(whiteListed[msg.sender]);
        require(msg.value >= _minPurchaseInWei);

        // ETH received by spender
        uint256 ethAmount = msg.value;
        // token amount based on ETH / exchangeRate result
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.mul(decimalMultiplier).div(exchangeRate);
        // tokens avaialble to sell are the remaining tokens in the pvtFundsWallet
        uint256 availableTokens = balances[fundsWallet];
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
            balances[fundsWallet] = balances[fundsWallet].sub(availableTokens);

            // add total tokens to the senders balances and Emit transfer event
            balances[msg.sender] = balances[msg.sender].add(availableTokens);
            emit Transfer(fundsWallet, msg.sender, availableTokens);
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
            require(totalTokenAmount <= availableTokens);
            // complete transfer and emit an event
            balances[fundsWallet] = balances[fundsWallet].sub(totalTokenAmount);
            balances[msg.sender] = balances[msg.sender].add(totalTokenAmount);

            // transfer ether to the wallet and emit and event regarding eth raised
            fundsWallet.transfer(ethAmount);
            totalEthRaised = totalEthRaised.add(ethAmount);
            emit Transfer(fundsWallet, msg.sender, totalTokenAmount);
            emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        }
    }

    // After close
    function burnRemainingTokensAfterClose(address _address) external onlyOwner returns (bool) {
        require(_address == pvtSaleTokenWallet || _address == preSaleTokenWallet || _address == fundsWallet);
        require(currentTime() >= endTime);

        uint256 oldSupply = totalSupply;

        if(_address == pvtSaleTokenWallet){
          // TODO: end time needs to be decided.
          // PVT escrow ends 6 months after main tsd ico closes
          uint256 pvtReleaseDate = 1555250400000;
          require(currentTime() >= pvtReleaseDate);
        }
        if(_address == preSaleTokenWallet){
          // TODO: end time needs to be decided.
          // PRE escrow ends 12 months after main tsd ico closes
          uint256 preReleaseDate = 1555250400000;
          require(currentTime() >= preReleaseDate);
        }
        // burn unsold tokens and reduce total supply for TSD
        totalSupply = totalSupply.sub(balances[_address]);
        balances[_address] = 0;
        emit UpdatedTotalSupply(oldSupply, totalSupply);

        return true;
    }

    // ERC20 function wrappers
    function transfer(address _to, uint256 _tokens) public returns (bool) {
        require(canTrade);
        return super.transfer(_to, _tokens);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(canTrade);
        return super.transferFrom(_from, _to, _value);
    }

    // Subsequent supply functions
    function setSubsequentContract(address _contractAddress) public onlyOwner returns (bool) {
        subsequentContract = _contractAddress;
        return true;
    }

    function increaseTotalSupplyAndAllocateTokens(address _newTokensWallet, uint256 _amount) public isSubsequentContract returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_newTokensWallet] = _amount;
        return true;
    }

    function increaseEthRaisedBySubsequentSale(uint256 _amount) public isSubsequentContract {
        uint256 newEthAmount = totalEthRaised.add(_amount);
        emit EthRaisedUpdated(totalEthRaised, newEthAmount);
    }

    // Destroys the contract
    function selfDestruct() external onlyOwner {
        selfdestruct(owner);
    }

    // modifiers
    modifier isSubsequentContract() {
        require(msg.sender == subsequentContract);
        _;
    }

    modifier onlyRestricted () {
        require(msg.sender == owner || msg.sender == oracleAddress);
        _;
    }
}
