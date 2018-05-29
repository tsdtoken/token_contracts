pragma solidity ^0.4.18;

import "./PRETSD.sol";

contract PRETSDMock is PRETSD {
    uint256 public _now;

    constructor (
        uint256 _currentTime,
        uint256 _exchangeRate,
        address[] _whitelistAddresses
    ) PRETSD (_exchangeRate, _whitelistAddresses) public {
        _now = _currentTime;
    }

    function currentTime() public view returns (uint256) {
        return _now;
    }

    function changeTime(uint256 _newTime) public {
        _now = _newTime;
    }
}
