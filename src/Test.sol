// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "src/math/RandLib.sol";
import "src/attackers/Suicide.sol";
import "src/wrapper/ContractWrapper.sol";
import "src/interfaces/IAttacker.sol";
import "forge-std/console2.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


import { Test as StdTest} from "forge-std/Test.sol";

abstract contract TestBase is StdTest {
    using Strings for string;

    // Random helper
    Rand rand;
    Rand randAddresses;

    // Related to contract wrapper
    bool _enableContractWrapper = true;
    address[] public contractWrappers;
    mapping(address => ContractWrapper) _contract2Wrappers;
    mapping(ContractWrapper => address) _wrapper2Contracts;

    // Related to artifacts
    mapping(bytes32 => address[]) public codehash2Addresses;
    string[] public allArtifactPaths;
    mapping(string => bool) public ignorePaths;

    // Attacker contracts
    bool _enableAttackers = true;
    IAttacker[] public attackers;
    uint _currAttackerSeed;

    Suicide suicider;

    modifier fromRandSender() {
        address sender = randAddresses.getAddress();
        vm.startPrank(sender);
        _;
        vm.stopPrank();
    }

    function setUp() external {
        // console2.log("gas", gasleft());
        rand.seed = RandLib.getRandBytes();
        randAddresses.seed = RandLib.getRandBytes();

        vm.record();

        // console2.log("gas1", gasleft());

        uint64 thisNonce = vm.getNonce(address(this));
        setUpContracts();
        uint64 thisNonceAfter = vm.getNonce(address(this));

        // console2.log("gas2", gasleft());

        if (_enableContractWrapper) {
            // Get all contracts deployed in `setUpContracts` function.
            uint256 createdContractsLength = thisNonceAfter - thisNonce;
            address[] memory createdContracts = new address[](createdContractsLength);
            for (uint i; i < createdContractsLength; i++) {
                address cntra = computeCreateAddress(address(this), thisNonce+i);
                createdContracts[i] = cntra;
                console2.log("created contract", cntra);
                addTargetAddress(cntra);

                // No need to call the raw contract for invariant testing.
                excludeContract(cntra);
                // console2.log(targetContracts().length);

                ContractWrapper wrapper = new ContractWrapper(cntra);
                vm.label(address(wrapper), type(ContractWrapper).name);
                addTargetAddress(address(wrapper));

                _contract2Wrappers[cntra] = wrapper;
                _wrapper2Contracts[wrapper] = cntra;

                codehash2Addresses[cntra.codehash].push(cntra);

                // copy deployed contract's states to wrapper.
                bytes32[] memory writeSlots;
                (, writeSlots) = vm.accesses(cntra);
                for (uint j; j < writeSlots.length; j++) {
                    bytes32 slot = writeSlots[j];
                    bytes32 data = vm.load(cntra, slot);
                    console2.log("wrapper store", address(wrapper));
                    console2.logBytes32(slot);
                    console2.logBytes32(data);
                    console2.log("wrapper store over");

                    vm.store(address(wrapper), slot, data);
                }

                if (cntra.balance > 0) {
                    console2.log("deal address %s balance %s", address(wrapper), cntra.balance);
                    vm.deal(address(wrapper), cntra.balance);
                }
            }

            string memory rootPath = vm.projectRoot();
            ignorePaths[string.concat(rootPath, "/out/console.sol/console.json")] = true;
            ignorePaths[string.concat(rootPath, "/out/console2.sol/console2.json")] = true;
            ignorePaths[string.concat(rootPath, "/out/safeconsole.sol/safeconsole.json")] = true;

            Vm.DirEntry[] memory  dirEntries = vm.readDir("./out", 5);
            for (uint i; i < dirEntries.length; i++) {
                Vm.DirEntry memory entry = dirEntries[i];

                if (!entry.isDir) {
                    if (ignorePaths[entry.path]) {
                        continue;
                    }

                    bytes memory runtimeBytecode;

                    try vm.getDeployedCode(entry.path) returns(bytes memory _runtimeBytecode) {
                        runtimeBytecode = _runtimeBytecode;
                    } catch {
                        continue;
                    }

                    allArtifactPaths.push(entry.path);

                    // Get contract name
                    bytes memory rawBytes = bytes(entry.path);
                    int end = lastIndexOf(rawBytes, bytes(".json"));
                    int start = lastIndexOf(rawBytes, bytes("/"));
                    start = start == -1 ? -1 : start+1;
                    if (start == -1 || end == -1) {
                        continue;
                    }

                    string memory contractName = string(sliceBytes(rawBytes, uint(start), uint(end)));

                    string[] memory targets = new string[](1);
                    targets[0] = contractName;

                    // string memory content = vm.readFile(entry.path);
                    // string[] memory compilationTargetKeys = vm.parseJsonKeys(content, ".metadata.settings.compilationTarget");

                    // string[] memory targets = new string[](compilationTargetKeys.length);
                    // for (uint j; j < compilationTargetKeys.length; j++) {
                    //     console2.log(">>>>> compilationTargetKey", compilationTargetKeys[j]);
                    //     targets[j] = vm.parseJsonString(content, string.concat(".metadata.settings.compilationTarget.", compilationTargetKeys[j]));
                    // }

                    bytes32 runtimeBytecodeHash = keccak256(runtimeBytecode);
                    address[] memory relatedContracts = codehash2Addresses[runtimeBytecodeHash];
                    for (uint j; j < relatedContracts.length; j++) {
                        address wrapper = address(contract2Wrapper(relatedContracts[j]));
                        console2.log("load raw contract's (%s) artifacts to wrapper contract (%s)", relatedContracts[j], wrapper);
                        targetInterface(FuzzInterface({
                            addr: wrapper,
                            artifacts: targets
                        }));
                    }
                }
            }
        }

        vm.record();

        _registerAttackers();

        afterSetUpContracts();
    }

    function setUpContracts() public virtual;

    function afterSetUpContracts() public virtual {}

    function disableContractWrapper() public {
        _enableContractWrapper = false;
    }

    function addTargetAddress(address addr) public {
        console2.log("addTargetAddress", addr);
        randAddresses.addAddressCandidate(addr);
    }

    function _registerAttackers() internal {
        if (!_enableAttackers) { return; }

        registerAttacker(IAttacker(new Suicide{value: 1 ether}()));
    }

    function registerAttacker(IAttacker attacker) public {
        console2.log("register attack contract", address(attacker));

        attackers.push(attacker);
        
        excludeContract(address(attacker));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.inject_attack.selector;
        targetSelector(FuzzSelector({
            addr: address(this),
            selectors: selectors
        }));

        // addTargetAddress(address(attacker));
    }

    function inject_attack(uint seed) public {
        console2.log("inject_attack seed", seed);
        
        vm.record();

        IAttacker attacker = _nextAttacker();
        // bool isOneTimeAttacker = attacker.isOneTimeAttacker();
        // uint snapshot = vm.snapshot();

        // We need to use seed injected from foundry framework, but don't know why.
        randAddresses.seed = bytes32(seed);
        address victim = randAddresses.getAddress();
        uint balanceBefore = victim.balance;
        // victim = address(0xB);
        console2.log("inject attack, attacker=%s, victim=%s", address(attacker), victim);
        attacker.attack(victim);
        console2.log("balance after %s, %s", address(attacker).balance, victim.balance);

        // if (isOneTimeAttacker) {
        //     vm.revertTo(snapshot);
        // }

        uint balanceAfter = victim.balance;

        bytes32[] memory writeSlots;
        (, writeSlots) = vm.accesses(victim);
        for (uint j; j < writeSlots.length; j++) {
            bytes32 slot = writeSlots[j];
            bytes32 data = vm.load(victim, slot);

            console2.log("victim slot changed: slot=%s, data=%s", vm.toString(slot), vm.toString(data));
        }

        if (balanceBefore != balanceAfter) {
            console2.log("victim balance changed: before=%s, after=%s", balanceBefore, balanceAfter);
        }
    }

    function _nextAttacker() internal returns(IAttacker attacker) {
        return attackers[++_currAttackerSeed % attackers.length];
    }

    function disableAttackers() public {
        _enableAttackers = false;
    }

    function contract2Wrapper(address cntra) public view returns(ContractWrapper) {
        return _contract2Wrappers[cntra];
    }

    function wrapper2Contract(ContractWrapper wrapper) public view returns(address) {
        return _wrapper2Contracts[wrapper];
    }

    function lastIndexOf(bytes memory rawBytes, bytes memory findBytes) public pure returns(int) {
        // console2.log("lastIndexOf");

        for (int i = int(rawBytes.length-1); i >= 0; i--) {
            int j = int(findBytes.length-1);
            for (; j >= 0 && i-j >= 0; j--) {
                // console2.log("i", i);
                // console2.log("j", j);
                // console2.logBytes1(rawBytes[uint(i-j)]);
                // console2.logBytes1(findBytes[uint(j)]);

                if (rawBytes[uint(i-(int(findBytes.length) - 1 - j))] != findBytes[uint(j)]) {
                    break;
                }
            }

            if (j == -1) {
                // console2.log("find", i- int(findBytes.length) + 1);
                return i- int(findBytes.length) + 1;
            }
        }

        return -1;
    }

    function sliceBytes(bytes memory raw, uint start, uint end) public pure returns(bytes memory) {
        uint length = end - start;
        bytes memory result = new bytes(length);

        for (uint i; i < length; i++) {
            result[i] = raw[start+i];
        }

        return result;
    }

    function getRandSeed() public returns(bytes32 seed) {
        uint256 unixTime = vm.unixTime();
        string[] memory commandInput = new string[](2);
        // It doesnt work for treating "$RANDOM" as string.

        // commandInput[0] = "echo";
        // commandInput[1] = "$RANDOM";

        commandInput[0] = "bash";
        commandInput[1] = "script/randNumber.sh";

        bytes memory result = vm.ffi(commandInput);
        uint256 randNumber = vm.parseUint(string(result));

        uint timeNumber = unixTime<<15|randNumber;

        console2.log("getRandSeed, unixTime=%s, randNumber=%s, timeNumber=%s", unixTime, randNumber, timeNumber);

        return bytes32(keccak256(abi.encodePacked(bytes("random number"), timeNumber)));
    }
}

abstract contract Test is TestBase {}