// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBetHouse {
    function makeBet(address bettor_) external;
}

interface IPool {
    function lockDeposits() external;
}

contract BetHouseHelper {
    IPool public pool;
    IBetHouse public betHouse;

    constructor(address _pool, address _betHouse) {
        pool = IPool(_pool);
        betHouse = IBetHouse(_betHouse);
    }

    function lockAndBet(address targetBettor) external {
        pool.lockDeposits();
        betHouse.makeBet(targetBettor);
    }
}
