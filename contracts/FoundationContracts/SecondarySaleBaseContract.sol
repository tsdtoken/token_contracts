pragma solidity ^0.4.23;

// import "./FoundationContracts/BaseToken.sol";
import "./Ownable.sol";
import "../TSD.sol";

contract SecondarySaleBaseContract is Ownable {
    using SafeMath for uint256;
    // set up access to main contract for the future distribution
    TSD public dc;
    // when the connection is set to the main contract, save a reference for event purposes
    address public TSDContractAddress;
    address private oracleAddress;

    uint256 public decimals = 18;
    uint256 public decimalMultiplier = uint256(10) ** decimals;
    uint256 public million = 1000000 * decimalMultiplier;
    uint256 public tokenPrice = 50; // 50 cents (USD) - this is discounted accordingly to contract that inherits this contract
    uint256 public ethExchangeRate;
    uint256 public exchangeRate;
    uint256 public totalEthRaised = 0;

    // Coordinated Universal Time (abbreviated to UTC) is the primary time standard by which the world regulates clocks and time.

    // Start time
    uint256 public startTime;
    // End time 
    uint256 public endTime;
    // Token release date
    uint256 public tokensReleaseDate;

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
        // 1 ETH = 1000000 szabo
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

    // After close functions

    // Create an instance of the main contract
    function setMainContractAddress(address _t) external onlyOwner{
        dc = TSD(_t);
        TSDContractAddress = _t;
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

    // only ERC20 standard function, intended to be used for FIAT payments
    function safeTransfer(address _to, uint256 _value) external onlyOwner returns (bool) {
        // msg.sender will only be the owner of the contract
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        // only add to icoParticipants if they're not already part of it, for FIAT payments
        if (balances[msg.sender] == 0) {
            icoParticipants.push(msg.sender);
        }

        // SafeMath.sub will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);

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
