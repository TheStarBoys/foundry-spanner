// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract EtherStore {
    mapping(address => uint256) balances;
    uint256 public totalBalance;

    function deposit() public payable {
        require(msg.value > 0, "0 msg.value");
        balances[msg.sender] += msg.value;
        totalBalance += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "0 amount");
        require(balances[msg.sender] >= amount, "not enough");
        balances[msg.sender] -= amount;
        totalBalance -= amount;
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        deposit();
    }
}