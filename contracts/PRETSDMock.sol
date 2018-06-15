pragma solidity ^0.4.18;

import "./PRETSD.sol";

contract PRETSDMock is PRETSD {
    uint256 public _now;

    constructor (
        uint256 _currentTime,
        uint256 _exchangeRate
    ) PRETSD (_exchangeRate) public {
        _now = _currentTime;
    }

    function currentTime() public view returns (uint256) {
        return _now;
    }

    function changeTime(uint256 _newTime) public {
        _now = _newTime;
    }
}
