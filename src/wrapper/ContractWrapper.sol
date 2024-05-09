// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract ContractWrapper is Proxy {
    bytes32 constant IMPLEMENTATION_SLOT = 0x05a2cb615f4b25b14a9c575e2bc454a79f024bdfc54e3e48da67cb3a1a14f9b7; //keccak256(bytes("Implementation Slot"))
    bytes32 constant METRICS_SLOT = 0xcec2647f1bccc94df5325aedd80b7158da8085fcc3a9255bed9965af7893f1ef; // keccak256(bytes("Metrics Slot"))

    constructor(address addr) {
        assembly {
            sstore(IMPLEMENTATION_SLOT, addr)
        }
    }

    receive() external payable {}

    function implementation() public view returns (address impl) {
        return _implementation();
    }

    function _implementation() internal view override returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    function numCalls(bytes4 selector) public view returns(uint256) {
        return getMetrics(bytes32(selector));
    }

    function _setNumCalls(bytes4 selector, uint val) internal {
        setMetrics(bytes32(selector), val);
        require(getMetrics(bytes32(selector)) == val, "_setNumCalls failed");
    }

    // Only allowed to enable count the number of calling the function that do change the state of smart contract.
    function enableNumCalls(bytes4 selector) public {
        setMetrics(keccak256(abi.encodePacked(selector, "enable numCalls")), 1);
    }

    function enabledNumCalls(bytes4 selector) public view returns(bool) {
        return getMetrics(keccak256(abi.encodePacked(selector, "enable numCalls"))) & 1 == 1;
    }

    function _increaseNumCalls(bytes4 selector) internal {
        uint oldVal = numCalls(selector);
        _setNumCalls(selector, oldVal+1);
    }

    function getMetricsLocation(bytes32 key) public pure returns(uint) {
        return uint(keccak256(abi.encodePacked(key, METRICS_SLOT)));
    }

    function setMetrics(bytes32 key, uint value) public {
        // console2.log("setMetrics", value);
        // console2.logBytes32(key);

        uint loc = getMetricsLocation(key);

        assembly {
            sstore(loc, value)
        }

        // console2.log("after set", getMetrics(key));
    }

    function getMetrics(bytes32 key) public view returns(uint metric) {
        uint loc = getMetricsLocation(key);

        assembly {
            metric := sload(loc)
        }
    }

    function getStorageAt(uint slot) public view returns (bytes32 ret) {
        assembly {
            ret := sload(slot)
        }
    }

    function _fallback() internal override {
        bytes4 selector = bytes4(msg.data);
        // console2.log("fallback", numCalls(selector));
        if (enabledNumCalls(selector)) {
            // console2.log(uint(2222));
            _increaseNumCalls(selector);
        }
        // console2.log(uint(3333));
        
        super._fallback();
    }
}