// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Denial} from "src/challenge-20-denial/Denial.sol";
import {DenialAttacker} from "src/challenge-20-denial/DenialAttacker.sol";

contract DenialTest is Test {
    Denial public denial;
    DenialAttacker public attacker;
    address public owner;

    function setUp() public {
        denial = new Denial();
        attacker = new DenialAttacker(payable(address(denial)));
        (bool success,) = address(denial).call{value: 0.001 ether}("");
        if (!success) {
            revert("Failed to found denial contract");
        }
        owner = denial.owner();
    }

    function testAttack() public {
        attacker.setPartner();

        // We set a fixed amount of gas because Foundry uses a lot of gas and it's not very realistic
        // Should revert with Out of gas
        (bool success,) = address(denial).call{gas: 100000}(abi.encodeWithSignature("withdraw()"));

        assertFalse(success);
    }
}
