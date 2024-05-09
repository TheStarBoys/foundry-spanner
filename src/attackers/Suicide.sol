// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import "./Attacker.sol";

contract Suicide is Attacker {
    constructor() payable {}
    
    function attack(address fundsTo) public override {
        super.attack(fundsTo);
        selfdestruct(payable(fundsTo));
    }

    function isOneTimeAttacker() public override pure returns(bool) {
        return true;
    }
}