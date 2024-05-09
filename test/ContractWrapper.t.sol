// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/StdMath.sol";
import "forge-std/Vm.sol";

import "src/wrapper/ContractWrapper.sol";

import { Test } from "src/Test.sol";

contract ContractWrapperTestee {
    bool public isConstructed;
    bytes32 public data;
    mapping(bytes32 => bool) public dataSet;
    mapping(bytes4 => uint) public countCalls;

    constructor(bytes32 _data) {
        isConstructed = true;
        data = _data;
        dataSet[bytes32(bytes1(0xAA))] = true;
    }

    function call1() public {
        console2.log("call1");
        countCalls[bytes4(msg.data)]++;
    }

    function call2() public {
        console2.log("call2");
        countCalls[bytes4(msg.data)]++;
    }
}

contract ContractWrapperTest is Test {
    ContractWrapperTestee cntra;
    ContractWrapperTestee contractWrapper;
    ContractWrapper wrapper;

    bytes4 call1Sel;
    bytes4 call2Sel;

    function setUpContracts() public override {
        disableAttackers();

        cntra = new ContractWrapperTestee(bytes32(bytes1(0xBB)));
    }

    function afterSetUpContracts() public override {
        address wrapperAddr = address(contract2Wrapper(address(cntra)));
        contractWrapper = ContractWrapperTestee(wrapperAddr);
        wrapper = ContractWrapper(payable(wrapperAddr));

        call1Sel = ContractWrapperTestee.call1.selector;
        call2Sel = ContractWrapperTestee.call2.selector;

        wrapper.enableNumCalls(call1Sel);
        wrapper.enableNumCalls(call2Sel);
    }

    function test_SetUp() public {
        assertEq(address(contractWrapper) != address(0), true);

        assertEq(cntra.isConstructed(), true);
        assertEq(cntra.data(), bytes32(bytes1(0xBB)));
        assertEq(cntra.dataSet(bytes32(bytes1(0xAA))), true);
        
        assertEq(contractWrapper.isConstructed(), true);
        assertEq(contractWrapper.data(), bytes32(bytes1(0xBB)));
        assertEq(contractWrapper.dataSet(bytes32(bytes1(0xAA))), true);
    }

    function test_EnableNumCalls() public {
        assertEq(address(contractWrapper) != address(0), true);

        assertEq(wrapper.enabledNumCalls(call1Sel), true);
        assertEq(wrapper.enabledNumCalls(call2Sel), true);

        contractWrapper.call1();
        assertEq(wrapper.numCalls(call1Sel), 1);
        assertEq(wrapper.numCalls(call1Sel), contractWrapper.countCalls(call1Sel));

        contractWrapper.call1();
        contractWrapper.call1();
        assertEq(wrapper.numCalls(call1Sel), 3);
        assertEq(wrapper.numCalls(call1Sel), contractWrapper.countCalls(call1Sel));

        contractWrapper.call2();
        contractWrapper.call2();
        contractWrapper.call2();
        contractWrapper.call2();
        assertEq(wrapper.numCalls(call2Sel), 4);
        assertEq(wrapper.numCalls(call2Sel), contractWrapper.countCalls(call2Sel));
    }

    function invariant_CallDistribution() public {
        console2.log("invariant_CallDistribution");
        console2.log(wrapper.numCalls(call1Sel), wrapper.numCalls(call2Sel));
        // bool enabled = wrapper.enabledNumCalls(call1Sel) && wrapper.enabledNumCalls(call2Sel);
        
        // if (enabled && wrapper.numCalls(call1Sel) >= 1 && wrapper.numCalls(call2Sel) >= 1) {
        //     uint a = wrapper.numCalls(call1Sel);
        //     uint b = wrapper.numCalls(call2Sel);
        //     uint percentage = stdMath.percentDelta(a, a+b);
        //     console2.log("assert", percentage);
        //     assertEq(percentage >= 5e17 || stdMath.delta(a, b) <= 10, true);
        // }
    }
}