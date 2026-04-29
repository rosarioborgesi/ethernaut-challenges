// script/challenge-36-cashback/02_DeployNonceSetter.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {NonceSetter} from "../../src/challenge-36-cashback/NonceSetter.sol";

contract DeployNonceSetterScript is Script {
    function run() external {
        vm.startBroadcast();

        NonceSetter nonceSetter = new NonceSetter();

        vm.stopBroadcast();

        console.log("NonceSetter:", address(nonceSetter));
    }
}