// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

contract MyErc20 is ERC20 {
    constructor() ERC20("MyErc20", "MYE") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
