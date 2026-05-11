// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";

import {GoodSamaritan, Wallet, Coin} from "src/challenge-27-good-samaritan/GoodSamaritan.sol";
import {Notifyable} from "src/challenge-27-good-samaritan/Notifyable.sol";

contract GoodSamaritanTest is Test {
    GoodSamaritan goodSamaritan;
    Wallet wallet;
    Coin coin;
    Notifyable attacker;

    function setUp() public {
        goodSamaritan = new GoodSamaritan();
        wallet = goodSamaritan.wallet();
        coin = goodSamaritan.coin();
        attacker = new Notifyable(address(goodSamaritan));

        vm.label(address(goodSamaritan), "GoodSamaritan");
        vm.label(address(wallet), "Wallet");
        vm.label(address(coin), "Coin");
        vm.label(address(attacker), "Attacker");
    }

    function testRequestDonationTransfersAllCoinsToAttacker() public {
        uint256 walletBalanceBefore = coin.balances(address(wallet));
        uint256 attackerBalanceBefore = coin.balances(address(attacker));

        assertEq(walletBalanceBefore, 1_000_000);
        assertEq(attackerBalanceBefore, 0);

        // The attacker contract is msg.sender here
        // so Coin.transfer will call attacker.notify(amount)
        // and the custom error will trigger transferRemainder.
        attacker.attack();

        uint256 walletBalanceAfter = coin.balances(address(wallet));
        uint256 attackerBalanceAfter = coin.balances(address(attacker));

        assertEq(walletBalanceAfter, 0);
        assertEq(attackerBalanceAfter, 1_000_000);
    }
}
