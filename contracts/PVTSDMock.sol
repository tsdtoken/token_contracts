pragma solidity ^0.4.18;

import "./PVTSD.sol";

contract PVTSDMock is PVTSD() {
    uint256 public _now;

    constructor (
        uint256 _currentTime,
        uint256 _exchangeRate,
        address[] _whitelistAddresses
    ) PVTSD (_exchangeRate, _whitelistAddresses) public {
        _now = _currentTime;
    }

    function currentTime() public view returns (uint256) {
        return _now;
    }

    function changeTime(uint256 _newTime) public {
        _now = _newTime;
    }
}
