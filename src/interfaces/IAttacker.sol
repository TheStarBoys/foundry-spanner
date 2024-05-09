// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAttacker {
    function attack(address victim) external;

    function attacked() external view returns(bool);

    function isOneTimeAttacker() external pure returns(bool);
}