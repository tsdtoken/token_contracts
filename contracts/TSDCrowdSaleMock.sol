pragma solidity ^0.4.23;

import "./TSDCrowdSale.sol";

contract TSDCrowdSaleMock is TSDCrowdSale {
    uint256 public _now;

    constructor (
        uint256 _currentTime,
        uint256 _ethExchangeRate,
        address _fundsWallet
    ) TSDCrowdSale (
        _ethExchangeRate,
        _fundsWallet
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
