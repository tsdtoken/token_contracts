pragma solidity ^0.4.23;

import "./PVTSD.sol";

contract PVTSDMock is PVTSD {
    uint256 public _now;

    constructor (
        uint256 _currentTime,
        uint256 _exchangeRate
    ) PVTSD (_exchangeRate) public {
        _now = _currentTime;
    }

    function currentTime() public view returns (uint256) {
        return _now;
    }

    function changeTime(uint256 _newTime) public {
        _now = _newTime;
    }
}
