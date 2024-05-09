// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import { Test } from "src/Test.sol";
import "./victims/EtherStore.sol";
import "src/wrapper/ContractWrapper.sol";

contract ForcelySendEtherTest is Test {
    EtherStore rawStore;
    EtherStore store;

    function setUpContracts() public override {
        rawStore = new EtherStore();
    }

    function afterSetUpContracts() public override {
        store = EtherStore(payable(contract2Wrapper(address(rawStore))));
    }

    // It'll fail.
    // function invariant_A() external {
    //     console2.log("invariant_A1", address(store));

    //     console2.log("invariant_A2", address(store).balance, store.totalBalance());
    //     assertEq(address(store).balance, store.totalBalance());
    // }

    // function invariant_B() external {
    //     assertGe(address(store).balance, store.totalBalance());
    // }
}