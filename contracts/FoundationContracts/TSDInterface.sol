pragma solidity ^0.4.23;

contract TSDInterface {
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    function safeTransferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function increaseTotalSupplyAndAllocateTokens(address _newTokensWallet, uint256 _amount) external returns (bool);
    function increaseEthRaisedBySubsequentSale(uint256 _amount) external;

    // Wallets
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}