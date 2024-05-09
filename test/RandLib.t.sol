// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import { Test } from "src/Test.sol";

contract Callee {
    address public lastSender;
    bool public called;
    function call() public {
        called = true;
        lastSender = msg.sender;
    }
}

contract RandLibTest is Test {
    bool isSetup;
    Callee callee;

    function setUpContracts() public override {
        isSetup = true;
        callee = new Callee();
        disableContractWrapper();
        disableAttackers();
    }

    function test_SetUp() public {
        assertEq(isSetup, true);
    }

    function test_NoRandSender() public {
        callee.call();
        assertEq(callee.lastSender(), address(this));
    }

    function test_RandSender() public fromRandSender {
        callee.call();
        assertEq(callee.lastSender() != address(this), true);
    }

    function test_RandSenderOnlyOne() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(0xA);
        randAddresses.setAddressCandidates(addresses);
        _testExpectedRandSender(address(0xA));
    }

    // function test_RandSenderOnlyTwo() public {
    //     address[] memory addresses = new address[](2);
    //     addresses[0] = address(0xA);
    //     addresses[1] = address(0xB);

    //     randAddresses.setAddressCandidates(addresses);
    //     _testExpectedRandSender(address(0xA));
    //     _testExpectedRandSender(address(0xB));
    //     _testExpectedRandSender(address(0xB));
    //     _testExpectedRandSender(address(0xB));
    // }

    // function test_RandSenderOnlyThree() public {
    //     randAddresses.addAddressCandidate(address(0xA));
    //     randAddresses.addAddressCandidate(address(0xB));
    //     randAddresses.addAddressCandidate(address(0xC));

    //     _testExpectedRandSender(address(0xA));
    //     _testExpectedRandSender(address(0xC));
    //     _testExpectedRandSender(address(0xC));
    //     _testExpectedRandSender(address(0xB));
    //     _testExpectedRandSender(address(0xA));
    //     _testExpectedRandSender(address(0xB));
    //     _testExpectedRandSender(address(0xB));
    //     _testExpectedRandSender(address(0xB));
    //     _testExpectedRandSender(address(0xA));
    // }

    function _testExpectedRandSender(address expectedSender) internal fromRandSender {
        callee.call();
        assertEq(callee.called(), true);
        assertEq(callee.lastSender(), expectedSender);
        // console2.log("sender", callee.lastSender());
    }
}

contract TargetSenderTest is Test {
    Callee callee;

    function setUpContracts() public override {
        disableAttackers();

        callee = new Callee();
        targetSender(address(0xA));
    }

    function invariant_TargetSender() public {
        _testExpectedRandSender(address(0xA));
    }

    function test_TargetSender() public {
        assertEq(targetSenders()[0], address(0xA));
        callee.call();
        assertEq(callee.lastSender() != address(0xA), true);
    }

    function _testExpectedRandSender(address expectedSender) internal {
        if (callee.called()) {
            assertEq(callee.lastSender(), expectedSender);
        }
    }
}