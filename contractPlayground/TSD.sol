pragma solidity ^0.4.23;

contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


    // @title Ownable
    // @dev The Ownable contract has an owner address, and provides basic authorization control
    // functions, this simplifies the implementation of "user permissions".
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


    // @dev The Ownable constructor sets the original `owner` of the contract to the sender
    // account.
  constructor() public {
    owner = msg.sender;
  }


    // @dev Throws if called by any account other than the owner.
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

    //@dev Allows the current owner to transfer control of the contract to a newOwner.
    // @param newOwner The address to transfer ownership to.
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }


    // @dev Allows the current owner to relinquish control of the contract.
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }
}

//@title SafeMath
//@dev Math operations with safety checks that throw on error

library SafeMath {

//   @dev Multiplies two numbers, throws on overflow.
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }


// @dev Integer division of two numbers, truncating the quotient.
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }


// @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

// @dev Adds two numbers, throws on overflow.
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

contract TSD is ERC20Interface, Ownable {
    using SafeMath for uint;
    
    string public name = 'PRE TSD COIN';
    string public symbol = 'PRETSD';
    uint public decimals = 18;
    uint public million = 1000000 * (uint(10) ** decimals);
    uint public totalSupply = 100 * million;
    uint public preSaleSupply = 20 * million;
    uint public pvtSaleSupply = 10 * million;
    uint public exchangeRate;
    uint public totalEthRaised = 0;
    uint public startTime;
    uint public endTime;
    address public fundsWallet;
    address public pvtSaleTokenWallet;
    address public preSaleTokenWallet;
    address[] public whitelistAddresses;
    
    // this bool tests whether the contract has been opened to increase supply
    bool public closed;
    
    mapping (address => bool) public whiteListed;
    mapping (address => uint) public balances;
    mapping(address => mapping(address => uint)) allowed;
    
    event EthRaisedUpdated(uint oldEthRaisedVal, uint newEthRaisedVal);
    
    constructor(
        uint _exchangeRate,
        address[] _whitelistAddresses,
        uint _startTime,
        uint _endTime,
        address _pvtSaleTokenWallet,
        address _preSaleTokenWallet
    ) public {
        fundsWallet = owner;
        pvtSaleTokenWallet = _pvtSaleTokenWallet;
        preSaleTokenWallet = _preSaleTokenWallet;
        startTime = _startTime;
        endTime = _endTime;
        whitelistAddresses = _whitelistAddresses;
        exchangeRate = _exchangeRate;
        
        // transfer suppy to the funds wallet
        balances[fundsWallet] = totalSupply;
        
        // transfer tokens to account for the private sale
        balances[fundsWallet].sub(pvtSaleSupply);
        balances[pvtSaleTokenWallet].add(pvtSaleSupply);
        
        // transfer tokens to account for the pre sale
        balances[fundsWallet].sub(preSaleSupply);
        balances[preSaleTokenWallet].add(preSaleSupply);
        
        emit Transfer(0x0, fundsWallet, totalSupply);
        emit Transfer(fundsWallet, pvtSaleTokenWallet, pvtSaleSupply);
        emit Transfer(fundsWallet, preSaleTokenWallet, preSaleSupply);
    }
    
    function currentTime() public view returns (uint256) {
        return now * 1000;
    }
    
    function createWhiteListedMapping(address[] _addresses) {
        for (uint i = 0; i < _addresses.length; i++) {
            whiteListed[_addresses[i]] = true;
        }
    }
    
    function() isSaleOpen payable public {
        buyTokens();
    }
    
    function buyTokens() isSaleOpen payable public {
        uint tokenAmount = msg.value.mul(exchangeRate);
        uint currentEthRaised = totalEthRaised;
        
        // Logic for handling the amount of tokens remaining will be handled on the frontend.
        // We can assume that there will always be enough tokens to accommodate the buy.
        // This can be handled here also???????
        // We will run a require just as a double check from this end.
        require(balances[fundsWallet] >= tokenAmount);
        balances[fundsWallet].sub(tokenAmount);
        balances[msg.sender].add(tokenAmount);
        
        fundsWallet.transfer(msg.value);
        
        totalEthRaised.add(msg.value);
        
        emit EthRaisedUpdated(currentEthRaised, totalEthRaised);
        emit Transfer(fundsWallet, msg.sender, tokenAmount);
    }
    
    function closeIco() public {
        require(currentTime() >= endTime || balances[fundsWallet] == 0);
        if (balances[fundsWallet] > 0) {
            
        }
    }
    
    // ERC20 standard functions
    
    function totalSupply() public constant returns (uint) {
        return totalSupply;
    }
    
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }
    
    function transfer(address to, uint tokens) transferAllowed public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }
    
    function approve(address spender, uint tokens) transferAllowed public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    
    function transferFrom(address from, address to, uint tokens) transferAllowed public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
    
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    
    // Modifiers
    
    modifier isSaleOpen() {
        require(currentTime() >= startTime);
        require(balances[fundsWallet] > 0);
        _;
    }
    
    modifier transferAllowed() {
        require(currentTime() >= endTime);
        _;
    }
}