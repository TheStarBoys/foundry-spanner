// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "src/interfaces/IAttacker.sol";

abstract contract Attacker is IAttacker {
    bool _attacked;
    
    function attack(address victim) public virtual {
        console2.log("%s attacks %s", address(this), victim);
        console2.log("balance before %s, %s", address(this).balance, victim.balance);
        _attacked = true;
    }

    function attacked() public view returns(bool) {
        return _attacked;
    }

    function isOneTimeAttacker() public virtual pure returns(bool) {
        return false;
    }
}