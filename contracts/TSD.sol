pragma solidity ^0.4.23;

import "./FoundationContracts/BaseToken.sol";
import "./FoundationContracts/Ownable.sol";

contract TSD is BaseToken, Ownable {
    using SafeMath for uint256;

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
    uint256 public totalEthRaised = 0;

    // Wallets
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;

    // Addresses for services and founders
    address public foundersAndAdvisors;
    address public bountyCommunityIncentives;
    address public liquidityProgram;

    // SubsequentContract Address
    address public subsequentContract;

    // authorisedContract Address
    address public authorisedContract;

    // Token tradability toggle
    bool public canTrade = false;

    // initializationCall
    bool private isInitialAllocationDone = false;

    // events
    event EthRaisedUpdated(uint256 oldEthRaisedVal, uint256 newEthRaisedVal);
    event UpdatedTotalSupply(uint256 oldSupply, uint256 newSupply);
    event TradingStatus(bool status);
    event InitalTokenAllocation(bool allocationStatus);
    event IncreaseTotalSupply(uint256 additionalSupply);

    constructor(
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
    }

    function contractInitialAllocation() external onlyOwner {
        // require the initialAllocationDone to be false, as it can only be called once 
        require(!isInitialAllocationDone, "Initial allocation has already completed");

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

    // Ability to burn tokens but only from the private pre or main sale contracts
    function burnRemainingTokensAfterClose(address _address) external onlyOwner returns (bool) {
        require(_address == pvtSaleTokenWallet || _address == preSaleTokenWallet || _address == fundsWallet, "only the private, pre or main wallets are allowed");

        uint256 oldSupply = totalSupply;

        if(_address == pvtSaleTokenWallet){
          // TODO: end time needs to be decided.
          // PVT escrow ends 6 months after main tsd ico closes
          uint256 pvtReleaseDate = 1555250400000;
          require(currentTime() >= pvtReleaseDate, "current time is before the pvt release date");
        }
        if(_address == preSaleTokenWallet){
          // TODO: end time needs to be decided.
          // PRE escrow ends 12 months after main tsd ico closes
          uint256 preReleaseDate = 1555250400000;
          require(currentTime() >= preReleaseDate, "current time is before the pre release date");
        }
        // burn unsold tokens and reduce total supply for TSD
        totalSupply = totalSupply.sub(balances[_address]);
        balances[_address] = 0;
        emit UpdatedTotalSupply(oldSupply, totalSupply);

        return true;
    }

    // ERC20 function wrappers
    function transfer(address _to, uint256 _tokens) public returns (bool) {
        // canTrade ensures trading can only occur when approved by TSD owners
        require(canTrade, "canTrade is currently false");
        return (super.transfer(_to, _tokens));
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(canTrade, "canTrade is currently false");
        return (super.transferFrom(_from, _to, _value));
    }

    // crowdsale functions
    // sets the crowndsale contract address or airdrop / designed to be used by any one external contract
    function setAuthorisedContractAddress(address _contractAddress) external onlyOwner returns (bool) {
        authorisedContract = _contractAddress;
        return true;
    }

    // ERC20 function only called by crowdsale
    // transfer & transferFrom used in this contract have a `canTrade` restriction
    function safeTransferFrom(address _from, address _to, uint256 _value) external isAuthorisedContract returns (bool) {
        // make transferFrom a safe method - reverting failed transfers
        require(super.transferFrom(_from, _to, _value), "could not safely transfer from authorised contract");
        return true;
    }

    // Subsequent supply functions
    function setSubsequentContract(address _contractAddress) external onlyOwner returns (bool) {
        subsequentContract = _contractAddress;
        return true;
    }

    function increaseTotalSupplyAndAllocateTokens(address _newTokensWallet, uint256 _amount) external isSubsequentContract returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_newTokensWallet] = _amount;
        emit IncreaseTotalSupply(_amount);
        return true;
    }

    function increaseEthRaisedBySubsequentSale(uint256 _amount) external isSubsequentContract {
        totalEthRaised = totalEthRaised.add(_amount);
        emit EthRaisedUpdated(totalEthRaised, _amount);
    }

     // modifiers
    modifier isSubsequentContract() {
        require(msg.sender == subsequentContract, "sender is not subsequentContract");
        _;
    }

    modifier isAuthorisedContract() {
        require(msg.sender == authorisedContract, "sender is not authorisedContract");
        _;
    }

    // Destroys the contract
    function selfDestruct() external onlyOwner {
        selfdestruct(owner);
    }
}
