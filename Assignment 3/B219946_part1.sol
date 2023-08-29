// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

contract Token {
    address payable public immutable owner;

    string private name;
    string private symbol;
    uint128 private immutable price;
    uint private _totalSupply;

    mapping(address => uint) private balances;

    event Transfer(address indexed_from, address indexed_to, uint256 value);
    event Mint(address indexed_to, uint256 value);
    event Sell(address indexed_from, uint256 value);
    
    constructor() {
        owner = payable(msg.sender);
        name = "Test Token";
        symbol = "TEST_TOKEN";
        price = 600;
        _totalSupply = 0;
    }

    function totalSupply() public view returns (uint256){
        return _totalSupply;
    }

    function balanceOf(address _account) public view returns (uint256){
        return balances[_account];
    }

    function getName() public view returns (string memory){
        return name;
    }

    function getSymbol() public view returns (string memory){
        return symbol;
    }

    function getPrice() public view returns (uint128){
        return price;
    }

    function transfer(address to, uint256 value) public returns (bool){
        balances[msg.sender] =
            balances[msg.sender] - value;
        balances[to] =
            balances[to] + value;
        emit Transfer(msg.sender, to, value);
        return true;

    }

    function mint(address to, uint256 value) public returns (bool){
        require(payable(msg.sender) == owner);
        _totalSupply = _totalSupply + value; 
        balances[to] =
            balances[to] + value; 
        emit Mint(to, value);
        return true;
    } 

    function sell (uint256 value) public payable returns (bool){
        balances[msg.sender] =  balances[msg.sender] - value;
        balances[address(0)] = balances[address(0)] + value;
        _totalSupply = _totalSupply - value;
        payable(msg.sender).transfer(price * value);
        emit Sell (msg.sender, value);
        return true;
    }

    function close () public {
        require (payable(msg.sender) == owner);
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {
    }

}