pragma solidity ^0.4.23;

import "./TSD.sol";

contract TSDMock is TSD {
    uint256 public _now;

    constructor (
        uint256 _currentTime,
        address _pvtSaleTokenWallet,
        address _preSaleTokenWallet,
        address _foundersAndAdvisors,
        address _bountyCommunityIncentives,
        address _liquidityProgram,
        address _projectImplementationServices
    ) TSD (
        _pvtSaleTokenWallet,
        _preSaleTokenWallet,
        _foundersAndAdvisors,
        _bountyCommunityIncentives,
        _liquidityProgram,
        _projectImplementationServices
    ) public {
        _now = _currentTime;
    }

    function currentTime() public view returns (uint256) {
        return _now;
    }

    function changeTime(uint256 _newTime) public {
        _now = _newTime;
    }
}
