// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {DSTest} from "../lib/ds-test/src/test.sol";
import {Reentrance} from "../src/challenge-10-re-entrancy/Reentrance.sol";
import {ReentranceAttacker} from "../src/challenge-10-re-entrancy/ReentranceAttacker.sol";

contract ReentranceTest is DSTest {
    Reentrance reentrance;
    ReentranceAttacker attacker;

    receive() external payable {}

    function setUp() public payable {
        emit log_named_uint("Test contract balance", address(this).balance);
        reentrance = new Reentrance();
        attacker = new ReentranceAttacker(address(reentrance));

        // Fund the vulnerable contract with ETH to steal
        (bool success,) = address(reentrance).call{value: 0.004 ether}("");
        require(success, "Funding Reentrance failed");
    }

    function testInitialSetup() public {
        assertEq(address(reentrance).balance, 0.004 ether);
        assertEq(address(attacker).balance, 0);
        assertEq(reentrance.balanceOf(address(attacker)), 0);
    }

    function testAttack() public payable {
        // Start the reentrancy attack
        attacker.attack{value: 0.001 ether}();

        // The target should be drained
        assertEq(address(reentrance).balance, 0);

        // The attacker contract should now hold the stolen ETH
        assertGt(address(attacker).balance, 0.001 ether);
    }
}
