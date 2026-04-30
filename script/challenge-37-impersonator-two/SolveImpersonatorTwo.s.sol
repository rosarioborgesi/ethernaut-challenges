// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

interface IImpersonatorTwo {
    function setAdmin(bytes memory signature, address newAdmin) external;
    function switchLock(bytes memory signature) external;
    function withdraw() external;
}

contract SolveImpersonatorTwo is Script {
    IImpersonatorTwo private impersonator;

    function run() external {
        address impersonatorAddress = vm.envAddress("IMPERSONATOR_TWO");
        address player = vm.envAddress("PLAYER");

        bytes memory setAdminSignature = vm.envBytes("SET_ADMIN_SIG");
        bytes memory switchLockSignature = vm.envBytes("SWITCH_LOCK_SIG");

        impersonator = IImpersonatorTwo(impersonatorAddress);

        vm.startBroadcast();
        impersonator.setAdmin(setAdminSignature, player);
        impersonator.switchLock(switchLockSignature);
        impersonator.withdraw();
        vm.stopBroadcast();
    }
}
