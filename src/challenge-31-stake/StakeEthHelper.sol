// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStake {
    function StakeETH() external payable;
}

contract StakeEthHelper {
    IStake public stake;

    constructor(address _stake) {
        stake = IStake(_stake);
    }

    function stakeETH() external payable {
        stake.StakeETH{value: msg.value}();
    }

    receive() external payable {}
}
