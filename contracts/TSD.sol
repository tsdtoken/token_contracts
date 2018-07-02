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
    uint256 public totalSupply = 600 * million;
    uint256 public mainTokenSupply = 96 * million;
    uint256 public pvtSaleSupply = 144 * million;
    uint256 public preSaleSupply = 240 * million;
    uint256 public foundersAndAdvisorsAllocation = 48 * million;
    uint256 public kapitalizedAllocation = 12 * million;
    uint256 public bountyCommunityIncentivesAllocation = 42 * million;
    uint256 public liquidityProgramAllocation = 18 * million;
    uint256 public totalEthRaised = 0;

    // distributions
    uint256 private distributionAllocation = mainTokenSupply.add(preSaleSupply).add(pvtSaleSupply);
    uint256 private remainingDistributionAfterInitAllocation = totalSupply.sub(distributionAllocation).sub(liquidityProgramAllocation).sub(kapitalizedAllocation.div(2));

    // Wallets
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;

    // Addresses for services and founders
    address public foundersAndAdvisors;
    address public bountyCommunityIncentives;
    address public liquidityProgram;
    address public kapitalized;

    // SubsequentContract Address
    address public subsequentContract;

    // authorisedContract Address
    address public authorisedContract;

    // Token tradability toggle
    bool public canTrade = false;

    // initializationCall
    bool private isInitialAllocationDone = false;

    // team wallets escrow structs
    struct TokenGrant {
        uint256 amount;
        uint256 cliffTime;
    }

    // team wallets escrow mapping
    mapping (address => TokenGrant) internal escrowBalances;

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
        address _liquidityProgram,
        address _kapitalized
    ) public {
        fundsWallet = owner;
        pvtSaleTokenWallet = _pvtSaleTokenWallet;
        preSaleTokenWallet = _preSaleTokenWallet;
        foundersAndAdvisors = _foundersAndAdvisors;
        bountyCommunityIncentives = _bountyCommunityIncentives;
        liquidityProgram = _liquidityProgram;
        kapitalized = _kapitalized;

        // transfer total tradeable suppy to the funds wallet
        // Private, Presale and Mainsale token amount
        // + liquidityProgram + kapitalized/2
        balances[fundsWallet] = distributionAllocation.add(liquidityProgramAllocation).add(kapitalizedAllocation.div(2));
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

        // tranfer tokens to the kapitalized wallet
        super.transfer(kapitalized, kapitalizedAllocation.div(2));

        // escrow tokens to kapitalized account
        escrowAccountAllocation(kapitalized, kapitalizedAllocation.div(2), 1530528101291);

        // escrow tokens to founders account
        escrowAccountAllocation(foundersAndAdvisors, foundersAndAdvisorsAllocation, 1530528101291);

        // escrow tokens to bounty and community incentives account
        escrowAccountAllocation(bountyCommunityIncentives, bountyCommunityIncentivesAllocation, 1530533101291);

        // transfer tokens to the liquidity program account
        super.transfer(liquidityProgram, liquidityProgramAllocation);

        // set the initialAllocationDone value to true
        isInitialAllocationDone = true;
        emit InitalTokenAllocation(isInitialAllocationDone);
    }

    function escrowAccountAllocation(address _targetAddress, uint256 _amount, uint256 _cliffTime) internal onlyOwner {
        TokenGrant memory newGrant = TokenGrant({
            amount: _amount,
            cliffTime: _cliffTime
        });

        escrowBalances[_targetAddress] = newGrant;
    }

    function withdrawFromEscrow() external isEscrowedWallet {
        // ensure that the calling wallet is calling at/after its elasped cliffTime
        require(currentTime() >= escrowBalances[msg.sender].cliffTime, "The current wallets escrow period has yet to lapse");
        uint256 amountToWithdraw = escrowBalances[msg.sender].amount;
        
        // ensure the sender has not already withdrawn
        require(escrowBalances[msg.sender].amount > 0, "This wallets escrow balance is not more than 0");
        // ensure no more than the initial supply is ever allocated
        // remainingDistribution should at maximum ever be the sum of distributionAllocation + foundersAndAdvisorsAllocation + bountyCommunityIncentivesAllocation
        require(remainingDistributionAfterInitAllocation >= escrowBalances[msg.sender].amount, "the amount in escrow is more than allowed");

        // set the senders escrow to 0
        escrowBalances[msg.sender].amount = 0;

        // reduce the remainingDistributionAfterInitAllocation by the amount in escrow for the caller wallet
        remainingDistributionAfterInitAllocation = remainingDistributionAfterInitAllocation.sub(escrowBalances[msg.sender].amount);

        // allocate the sender with their respective escrowed amount
        balances[msg.sender] = amountToWithdraw;
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

    modifier isEscrowedWallet() {
        // ensure it is only called by the two escrowed wallets
        require(msg.sender == foundersAndAdvisors || msg.sender == bountyCommunityIncentives || msg.sender == kapitalized, "An unauthorised wallet tried to call this method");
        _;
    }

    // Destroys the contract
    function selfDestruct() external onlyOwner {
        selfdestruct(owner);
    }
}
