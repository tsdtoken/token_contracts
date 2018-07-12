pragma solidity ^0.4.23;

import "./BaseCrowdsaleContract.sol";

contract SecondaryCrowdsaleContract is BaseCrowdsaleContract {
    // Wallets
    // wallet that holds all PV/PRE tokens
    // this will be the wallet that deploys the contract - the first owner
    address public tokenFundsWallet;
    // wallet in the main contract used to convert PV/PRE to TSD
    address public distributionWallet;

    // Events
    event UpdatedTotalSupply(uint256 oldSupply, uint256 newSupply);
    event DistributedBalancesToTSDContract(address _presd, address _tsd, uint256 startIndex, uint256 endIndex);
    event FinalDistributionToTSDContract(address _presd, address _tsd);

    // After close functions
    // Burn any remaining tokens
    function burnRemainingTokens() external onlyOwner returns (bool) {
        require(currentTime() >= endTime, "can only burn tokens after token sale has concluded");
        if (balances[tokenFundsWallet] > 0) {
            // Subtracting the unsold tokens from the total supply.
            uint256 oldSupply = totalSupply;
            totalSupply = totalSupply.sub(balances[tokenFundsWallet]);
            balances[tokenFundsWallet] = 0;
            emit UpdatedTotalSupply(oldSupply, totalSupply);
        }

        return true;
    }

    function setDistributionWallet(address _distributionWallet) external onlyOwner {
        distributionWallet = _distributionWallet;
    }

    // This can only be called by the owner on or after the token release date.
    // This will be a two step process.
    // This function will be called by the distributionWallet
    // This wallet will need to be approved in the main contract to make these distributions
    // _numberOfTransfers states the number of transfers that can happen at one time
    function distributeTokens(uint256 _numberOfTransfers) external onlyRestricted returns (bool) {
        require(currentTime() >= tokensReleaseDate, "can only distribute after tokensReleaseDate");
        uint256 finalDistributionIndex = currentDistributionIndex.add(_numberOfTransfers);

        for (uint256 i = currentDistributionIndex; i < finalDistributionIndex; i++) {
            // end for loop when currentDistributionIndex reaches the length of the icoParticipants array
            if (i == icoParticipants.length) {
                emit FinalDistributionToTSDContract(address(this), TSDContractAddress);
                finalDistributionIndex = i;
                break;
            }
            // skip transfer if balances are empty
            if (balances[icoParticipants[i]] != 0) {
                dc.transferFrom(distributionWallet, icoParticipants[i], balances[icoParticipants[i]]);
                emit Transfer(distributionWallet, icoParticipants[i], balances[icoParticipants[i]]);

                // set balances to 0 to prevent re-transfer
                balances[icoParticipants[i]] = 0;
            }
        }

        // Event to say distribution is complete
        emit DistributedBalancesToTSDContract(address(this), TSDContractAddress, currentDistributionIndex, finalDistributionIndex);

        // after distribution is complete set the currentDistributionIndex to the latest finalDistributionIndex
        currentDistributionIndex = finalDistributionIndex;

        // Boolean is returned to give us a success state.
        return true;
    }
}
