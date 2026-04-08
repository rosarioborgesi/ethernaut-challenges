// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDetectionBot, IForta} from "./DoubleEntryPoint.sol";
import {console} from "forge-std/Test.sol";

contract DetectionBot is IDetectionBot {
    address public vault;
    IForta public forta;

    constructor(address _vaultAddress, address _fortaAddress) {
        vault = _vaultAddress;
        forta = IForta(_fortaAddress);
    }

    function handleTransaction(address user, bytes calldata msgData) external override {
        (,, address origSender) = abi.decode(msgData[4:], (address, uint256, address));

        if (origSender == vault) {
            forta.raiseAlert(user);
        }
    }
}

