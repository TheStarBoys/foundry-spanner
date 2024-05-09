// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/console2.sol";
import "forge-std/Vm.sol";

using RandLib for Rand global;

struct Rand {
    bytes32 seed;
    uint256 salt;
    bytes32[] candidates;
    mapping(uint256 => mapping (uint256 => uint256)) bounds;
}

library RandLib {
    uint256 private constant UINT256_MAX =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setBytes32Candidates(Rand storage r, bytes32[] memory candidates) internal {
        r.candidates = candidates;
    }

    function addBytes32Candidate(Rand storage r, bytes32 candidate) internal {
        r.candidates.push(candidate);
    }

    function setAddressCandidates(Rand storage r, address[] memory candidates) internal {
        bytes32[] memory vals = new bytes32[](candidates.length);
        for (uint i; i < candidates.length; i++) {
            vals[i] = bytes32(bytes20(uint160(candidates[i])));
        }
        r.candidates = vals;
        // console2.log("setAddressCandidates", r.candidates.length);
        // console2.logBytes32(r.candidates[0]);
    }

    function addAddressCandidate(Rand storage r, address candidate) internal {
        r.candidates.push(bytes32(bytes20(uint160(candidate))));
    }
    
    function getBytes32(Rand storage r) internal returns(bytes32 randNum) {
        r.salt++;
        
        randNum = keccak256(abi.encodePacked(r.seed, r.salt));

        // randNum = getRandBytes();
        
        if (r.candidates.length != 0) {
            uint index = uint256(randNum) % r.candidates.length;
            randNum = r.candidates[index];
            // console2.log("salt %s index %s", r.salt, index);
            // console2.logBytes32(r.seed);
            // console2.log("randNumber");
            // console2.logBytes32(randNum);
        }

        return randNum;
    }

    function getUint256(Rand storage r) internal returns(uint256) {
        return uint256(getBytes32(r));
    }

    function getAddress(Rand storage r) internal returns(address) {
        return address((uint160(bytes20(getBytes32(r)))));
    }

    function getRandBytes() internal returns(bytes32) {
        uint256 unixTime = vm.unixTime();
        string[] memory commandInput = new string[](2);
        // It doesnt work for treating "$RANDOM" as string.

        // commandInput[0] = "echo";
        // commandInput[1] = "$RANDOM";

        commandInput[0] = "bash";
        commandInput[1] = "script/randNumber.sh";

        bytes memory result = vm.ffi(commandInput);
        uint256 randNumber;

        try vm.parseUint(string(result)) returns(uint _randNumber) {
            randNumber = _randNumber;
        } catch {
            console2.log("parse rand number failed", string(result));
        }

        uint timeNumber = unixTime<<15|randNumber;

        // console2.log("getRandSeed, unixTime=%s, randNumber=%s, timeNumber=%s", unixTime, randNumber, timeNumber);

        return bytes32(keccak256(abi.encodePacked(bytes("random number"), timeNumber)));
    }
}