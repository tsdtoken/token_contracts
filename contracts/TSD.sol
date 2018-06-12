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
    uint256 public pvtSaleSupply = 55 * million;
    uint256 public preSaleSupply = 165 * million;
    uint256 public foundersAndAdvisorsAllocation = 44 * million;
    uint256 public bountyCommunityIncentivesAllocation = (16 * million).add(500 * thousand);
    uint256 public liquidityProgramAllocation = (16 * million).add(500 * thousand);
    // approx $50 USD
    // 0.0875 ETH
    uint256 public minPurchase = 87500000000000000;
    // 1 TSD = x ETH
    // Unit convertsions https://github.com/ethereum/web3.js/blob/0.15.0/lib/utils/utils.js#L40
    uint256 public exchangeRate;
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
    bool public icoOpen = true;

    // events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event ExhangeRateUpdated(uint256 prevExchangeRate, uint256 newExchangeRate);
    event Debugger(string variable, uint256 value);
    event DebugStrings(string variable);
    event DebugAddress(string name, address _address);

    constructor(
        uint256 _exchangeRate,
        address[] _whitelistAddresses,
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

        // transfer suppy to the funds wallet
        balances[fundsWallet] = totalSupply;
        emit Transfer(0x0, fundsWallet, totalSupply);

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

        // Set up the list of whitelisted addresses
        createWhiteListedMapping(_whitelistAddresses);

        // set up the exchangeRate
        updateTheExchangeRate(_exchangeRate);
    }

    function currentTime() public view returns (uint256) {
        return now * 1000;
    }

    // Utility functions

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

    function changeOracleAddress(address _newAddress) external onlyOwner {
        oracleAddress = _newAddress;
    }

    // Updates the ETH => TSD exchange rate
    function updateTheExchangeRate(uint256 _newRate) public onlyRestricted returns (bool) {
        uint256 currentRate = exchangeRate;
        // 0.000001 ETHER
        uint256 oneSzabo = 1 szabo;
        // 0.00001 ETH OTHERWISE 0.000001
        exchangeRate = (oneSzabo).mul(_newRate);
        emit ExhangeRateUpdated(currentRate, _newRate);
        return true;
    }

    // Buy functions

    function() payable public {
        buyTokens();
    }

    function buyTokens() payable public {
        require(icoOpen);
        require(currentTime() >= startTime && currentTime() <= endTime);
        require(msg.value >= minPurchase);
        require(whiteListed[msg.sender]);

        // ETH received by spender
        uint256 ethAmount = msg.value;
        // token amount based on ETH / exchangeRate result
        // Multiply with the decimalMultiplier to get total tokens (to 18 decimal place)
        uint256 totalTokenAmount = ethAmount.div(exchangeRate).mul(decimalMultiplier);
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
            icoOpen = false;
        } else {
            require(availableTokens >= totalTokenAmount);
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
    function burnRemainingTokensAfterClose() external onlyOwner returns (bool) {
        require(currentTime() >= endTime);
        if (balances[fundsWallet] > 0) {
            // burn unsold tokens
            balances[fundsWallet] = 0;
        }

        return true;
    }

    // ERC20 function wrappers
    function transfer(address _to, uint256 _tokens) public returns (bool) {
        require(currentTime() >= endTime);
        return super.transfer(_to, _tokens);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(currentTime() >= endTime);
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

    // modifier
    modifier isSubsequentContract() {
        require(msg.sender == subsequentContract);
        _;
    }

    modifier onlyRestricted () {
      require(msg.sender == owner || msg.sender == oracleAddress);
      _;
    }
}
